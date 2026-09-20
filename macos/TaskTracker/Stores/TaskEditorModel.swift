import Foundation
import Observation
import TaskTrackerCore

/// Task düzenleme katmanının durumu. Alanlar düz metindir; kaydederken doğrulanır:
/// tarihler hızlı eklemenin sözlüğüyle sunucuda çözülür (`cuma`, `25.09`, `05.09.2026`),
/// proje ada/öneke göre eşleşir. Hata varsa kayıt yapılmaz, ilgili alan işaretlenir.
@Observable
final class TaskEditorModel {
    enum Field: Int, CaseIterable {
        case title, start, due, priority, area, project, details

        var label: String {
            switch self {
            case .title: "başlık"
            case .start: "başla"
            case .due: "son"
            case .priority: "öncelik"
            case .area: "alan"
            case .project: "proje"
            case .details: "açıklama"
            }
        }

        var placeholder: String {
            switch self {
            case .title: ""
            case .start: "bugün · cuma · 25.09 · boş = plansız"
            case .due: "cuma · 25.09 · boş = yok"
            case .priority: "1–4"
            case .area: "iş · kişisel · boş"
            case .project: "ad ya da önek · boş = projesiz"
            case .details: "⇧↵ yeni satır"
            }
        }
    }

    private let backend: Backend
    private let projects: ProjectStore
    private var resolveTasks: [Field: Task<Void, Never>] = [:]

    private(set) var task: TaskItem?
    var values: [Field: String] = [:]
    private(set) var field: Field = .title
    /// Alan değişince artar; `InkTextView` odağı buna bakarak alır.
    private(set) var focusTick = 0
    /// Tarih alanlarının canlı çözümü: alan → "YYYY-MM-DD".
    private(set) var resolvedDates: [Field: String] = [:]
    private(set) var errors: [Field: String] = [:]
    private(set) var isSaving = false
    /// Kayıttan sonra çağrılır (görünümü yenilemek + katmanı kapatmak için).
    var onFinished: (_ saved: Bool) -> Void = { _ in }

    init(backend: Backend, projects: ProjectStore) {
        self.backend = backend
        self.projects = projects
    }

    func begin(_ task: TaskItem) {
        self.task = task
        values = [
            .title: task.title,
            .start: task.scheduledDate.isEmpty ? "" : Day.full(task.scheduledDate),
            .due: task.dueDate.isEmpty ? "" : Day.full(task.dueDate),
            .priority: String(task.priority),
            .area: task.area.map { $0 == .work ? "iş" : "kişisel" } ?? "",
            .project: projects.name(for: task.project) ?? "",
            .details: task.details,
        ]
        resolvedDates = [.start: task.scheduledDate, .due: task.dueDate].filter { !$0.value.isEmpty }
        errors = [:]
        field = .title
        focusTick += 1
    }

    func text(_ field: Field) -> String { values[field] ?? "" }

    func setText(_ field: Field, _ text: String) {
        guard values[field] != text else { return }
        values[field] = text
        errors[field] = nil
        if field == .start || field == .due { resolveLive(field) }
    }

    func move(_ delta: Int) {
        let all = Field.allCases
        field = all[(field.rawValue + delta + all.count) % all.count]
        focusTick += 1
    }

    /// Alan fareyle tıklanarak odaklandı: vurguyu taşı, odağı yeniden isteme.
    func didFocus(_ newField: Field) {
        if field != newField { field = newField }
    }

    func cancel() { onFinished(false) }

    /// Alanın altında gösterilen çözüm: tarih etiketi ya da eşleşen proje adı.
    func resolution(_ field: Field) -> String? {
        switch field {
        case .start, .due:
            return resolvedDates[field].map { "→ " + Day.label($0) }
        case .project:
            let raw = text(.project)
            guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return matchProject(raw).map { "→ #" + $0.name }
        default:
            return nil
        }
    }

    private func resolveLive(_ field: Field) {
        resolveTasks[field]?.cancel()
        resolvedDates[field] = nil
        let text = text(field)
        resolveTasks[field] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let date = try? await backend.api.resolveDate(text)
            guard !Task.isCancelled, text == self.text(field) else { return }
            resolvedDates[field] = date
        }
    }

    // MARK: Kayıt

    func save() {
        guard let task, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            guard let patch = await validatedPatch(for: task) else { return }
            if await backend.run({ try await $0.updateTask(task.id, patch) }) != nil { onFinished(true) }
        }
    }

    private func validatedPatch(for task: TaskItem) async -> TaskPatch? {
        var problems: [Field: String] = [:]

        let title = text(.title).trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { problems[.title] = "başlık boş olamaz" }

        var dates: [Field: String] = [:]
        for field in [Field.start, .due] {
            let raw = text(field).trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { dates[field] = ""; continue }
            if let date = try? await backend.api.resolveDate(raw) { dates[field] = date } else { problems[field] = "tarih anlaşılmadı" }
        }

        let priority = Int(text(.priority).trimmingCharacters(in: .whitespaces)) ?? 0
        if !(1...4).contains(priority) { problems[.priority] = "1–4 arası" }

        var area = ""
        let areaText = ActionRegistry.fold(text(.area).trimmingCharacters(in: .whitespaces))
        if !areaText.isEmpty {
            if "is".hasPrefix(areaText) || areaText == "work" { area = Area.work.rawValue }
            else if "kisisel".hasPrefix(areaText) || areaText == "ks" || areaText == "personal" { area = Area.personal.rawValue }
            else { problems[.area] = "iş ya da kişisel" }
        }

        var projectID = ""
        let projectText = text(.project).trimmingCharacters(in: .whitespaces)
        if !projectText.isEmpty {
            if let project = matchProject(projectText) { projectID = project.id } else { problems[.project] = "proje bulunamadı" }
        }

        errors = problems
        if let first = Field.allCases.first(where: { problems[$0] != nil }) {
            field = first
            focusTick += 1
            return nil
        }
        return TaskPatch(title: title, details: text(.details).trimmingCharacters(in: .whitespacesAndNewlines), priority: priority,
                         scheduledDate: dates[.start], dueDate: dates[.due], project: projectID, area: area)
    }

    /// Hızlı eklemedeki kural: tam ad (boşluk ↔ tire fark etmez), yoksa tekil önek.
    private func matchProject(_ raw: String) -> Project? {
        func key(_ text: String) -> String {
            ActionRegistry.fold(text.trimmingCharacters(in: .whitespaces)).replacingOccurrences(of: " ", with: "-")
        }
        let wanted = key(raw.hasPrefix("#") ? String(raw.dropFirst()) : raw)
        guard !wanted.isEmpty else { return nil }
        let all = Array(projects.byID.values)
        if let exact = all.first(where: { key($0.name) == wanted }) { return exact }
        let prefixed = all.filter { key($0.name).hasPrefix(wanted) }
        return prefixed.count == 1 ? prefixed[0] : nil
    }
}
