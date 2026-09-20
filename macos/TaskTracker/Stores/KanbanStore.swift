import Foundation
import Observation
import TaskTrackerCore

/// Kanban: bitmemiş bütün task'lar (tarihli ya da plansız) durumlarına göre üç sütunda,
/// dördüncü sütunda **bugün** tamamlananlar. Durum değişimi = `PATCH status`.
@Observable
final class KanbanStore {
    static let columns: [TaskStatus] = [.todo, .doing, .blocked, .done]

    private let backend: Backend
    private var pendingReload: Task<Void, Never>?

    private(set) var today = ""
    private(set) var tasks: [TaskItem] = []
    private(set) var hasLoaded = false
    var selectedID: String?
    var showsDetails = false

    init(backend: Backend) {
        self.backend = backend
    }

    func tasks(in status: TaskStatus) -> [TaskItem] { tasks.filter { $0.status == status } }
    var selected: TaskItem? { tasks.first { $0.id == selectedID } }

    // MARK: Yükleme

    func reload() async {
        guard let open = await backend.run({ try await $0.openTasks() }),
              let focus = await backend.run({ try await $0.focusView() }) else { return }
        today = focus.today
        tasks = open + focus.done
        hasLoaded = true
        if selected == nil { selectedID = Self.columns.lazy.compactMap { self.tasks(in: $0).first }.first?.id }
    }

    func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    func reset() {
        tasks = []
        selectedID = nil
        showsDetails = false
        hasLoaded = false
    }

    // MARK: Gezinme

    func moveSelection(_ delta: Int) {
        guard let task = selected else { return }
        let column = tasks(in: task.status)
        guard let index = column.firstIndex(where: { $0.id == task.id }) else { return }
        selectedID = column[min(max(index + delta, 0), column.count - 1)].id
    }

    /// Komşu sütuna geçer (boş sütunları atlar), aynı sıradaki karta yakın durur.
    func moveColumn(_ delta: Int) {
        guard let task = selected, var column = Self.columns.firstIndex(of: task.status) else { return }
        let row = tasks(in: task.status).firstIndex { $0.id == task.id } ?? 0
        while true {
            column += delta
            guard Self.columns.indices.contains(column) else { return }
            let target = tasks(in: Self.columns[column])
            if !target.isEmpty {
                selectedID = target[min(row, target.count - 1)].id
                return
            }
        }
    }

    // MARK: Aksiyonlar

    /// Seçili task'ı komşu duruma taşır: todo ↔ doing ↔ blocked ↔ done.
    func shiftStatus(_ delta: Int) {
        guard let task = selected, let index = Self.columns.firstIndex(of: task.status),
              Self.columns.indices.contains(index + delta) else { return }
        setStatus(Self.columns[index + delta], for: task.id)
    }

    func toggleDone() {
        guard let task = selected else { return }
        setStatus(task.isDone ? .todo : .done, for: task.id)
    }

    /// Sürükle-bırak da buradan geçer.
    func setStatus(_ status: TaskStatus, for id: String) {
        guard let task = tasks.first(where: { $0.id == id }), task.status != status else { return }
        selectedID = id
        Task {
            await backend.run { try await $0.updateTask(id, TaskPatch(status: status)) }
            await reload()
        }
    }

    func toggleDetails() {
        guard selected != nil else { return }
        showsDetails.toggle()
    }
}
