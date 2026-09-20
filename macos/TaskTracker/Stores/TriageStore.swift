import Foundation
import Observation
import TaskTrackerCore

/// Triyaj: bugüne ya da öncesine planlı, bitmemiş task'lar tek tek karara bağlanır.
/// Kuyruk = `GET /api/views/focus` (alan filtresiz). Kararları sunucu uygular
/// (`POST /api/triage/{id}`); burada yalnızca sıra ve giriş modları tutulur.
@Observable
final class TriageStore {
    enum Mode { case choose, date, project, confirmDelete }

    struct ProjectChoice: Identifiable, Equatable {
        /// `nil`: "yeni proje oluştur" satırı.
        let project: Project?
        let name: String
        var id: String { project?.id ?? "new:" + name }
    }

    private let backend: Backend
    private let projects: ProjectStore
    private var resolveTask: Task<Void, Never>?

    private(set) var today = ""
    private(set) var queue: [TaskItem] = []
    private(set) var index = 0
    /// Oturum başındaki kuyruk uzunluğu ve karara bağlanan sayı (ilerleme çubuğu).
    private(set) var total = 0
    private(set) var handled = 0
    private(set) var hasLoaded = false

    private(set) var mode: Mode = .choose
    var dateInput = "" { didSet { if dateInput != oldValue { resolveDate() } } }
    private(set) var resolvedDate: String?
    var projectQuery = "" { didSet { if projectQuery != oldValue { projectSelection = 0 } } }
    private(set) var projectSelection = 0

    init(backend: Backend, projects: ProjectStore) {
        self.backend = backend
        self.projects = projects
    }

    var current: TaskItem? { queue.indices.contains(index) ? queue[index] : nil }
    var upcoming: [TaskItem] { Array(queue.dropFirst(index + 1).prefix(6)) }
    var skipped: Int { min(index, queue.count) }
    var isTyping: Bool { mode == .date || mode == .project }

    // MARK: Kuyruk

    /// Görünüm açılınca: kuyruğu baştan kurar.
    func start() async {
        mode = .choose
        index = 0
        handled = 0
        await refresh()
        total = queue.count
        hasLoaded = true
    }

    /// Realtime olayında: kuyruğu yeniler, üzerinde durulan task'ı korur.
    func refresh() async {
        guard let view = await backend.run({ try await $0.focusView() }) else { return }
        let currentID = current?.id
        today = view.today
        queue = view.tasks
        if let currentID, let found = queue.firstIndex(where: { $0.id == currentID }) { index = found }
        total = max(total, handled + queue.count)
    }

    // MARK: Kararlar

    func postponeToTomorrow() { decide { try await $0.triage($1.id, .tomorrow) } }

    func markDone() { decide { _ = try await $0.updateTask($1.id, TaskPatch(status: .done)) } }

    func delete() {
        guard mode == .confirmDelete else { return }
        decide { try await $0.triage($1.id, .delete) }
    }

    func skip() {
        guard mode == .choose, current != nil else { return }
        index += 1
    }

    private func decide(_ work: @escaping (APIClient, TaskItem) async throws -> Void) {
        guard let task = current else { return }
        mode = .choose
        Task {
            guard await backend.run({ try await work($0, task) }) != nil else { return }
            handled += 1
            queue.removeAll { $0.id == task.id }
        }
    }

    // MARK: Giriş modları

    func begin(_ newMode: Mode) {
        guard current != nil else { return }
        dateInput = ""
        resolvedDate = nil
        projectQuery = ""
        projectSelection = 0
        mode = newMode
    }

    func cancel() { mode = .choose }

    /// Yazılan metni hızlı eklemenin tarih sözlüğüyle çözer ("cuma", "25.09").
    private func resolveDate() {
        resolveTask?.cancel()
        resolvedDate = nil
        let text = dateInput
        resolveTask = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            let date = try? await backend.api.resolveDate(text)
            guard !Task.isCancelled, text == dateInput else { return }
            resolvedDate = date
        }
    }

    func confirmDate() {
        guard mode == .date, let date = resolvedDate else { return }
        decide { try await $0.triage($1.id, .date(date)) }
    }

    /// Bitmemiş projeler + (tam eşleşme yoksa) "yeni proje" satırı.
    var projectChoices: [ProjectChoice] {
        let query = ActionRegistry.fold(projectQuery.trimmingCharacters(in: .whitespaces))
        let all = projects.byID.values.filter { $0.status != "done" }.sorted { $0.name < $1.name }
        let matches = all.filter { query.isEmpty || ActionRegistry.fold($0.name).contains(query) }
        var choices = matches.map { ProjectChoice(project: $0, name: $0.name) }
        if !query.isEmpty, !all.contains(where: { ActionRegistry.fold($0.name) == query }) {
            choices.append(ProjectChoice(project: nil, name: projectQuery.trimmingCharacters(in: .whitespaces)))
        }
        return choices
    }

    func moveProjectSelection(_ delta: Int) {
        let count = projectChoices.count
        guard count > 0 else { return }
        projectSelection = min(max(projectSelection + delta, 0), count - 1)
    }

    func confirmProject() {
        let choices = projectChoices
        guard mode == .project, choices.indices.contains(projectSelection), let task = current else { return }
        let choice = choices[projectSelection]
        mode = .choose
        Task {
            var projectID = choice.project?.id
            if projectID == nil {
                // Yeni proje task'ın alanını alır; alanı yoksa kişisel.
                projectID = await backend.run { try await $0.createProject(name: choice.name, area: task.area ?? .personal) }?.id
                await projects.reload()
            }
            guard let projectID, await backend.run({ try await $0.triage(task.id, .toProject(id: projectID, date: nil)) }) != nil else { return }
            handled += 1
            queue.removeAll { $0.id == task.id }
        }
    }
}
