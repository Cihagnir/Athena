import Foundation
import Observation
import TaskTrackerCore

/// Odak ekranının durumu: `GET /api/views/focus` + klavye imleci (seçim).
/// Her değişiklikten sonra liste sunucudan yeniden çekilir; realtime olayları da
/// aynı yenilemeyi tetikler — istemcide ayrı bir doğruluk kaynağı tutulmaz.
@Observable
final class TodayStore {
    private let backend: Backend
    private var pendingReload: Task<Void, Never>?

    private(set) var today = ""
    private(set) var open: [TaskItem] = []
    private(set) var done: [TaskItem] = []
    private(set) var hasLoaded = false
    /// `nil` = hepsi
    private(set) var areaFilter: Area?
    var selectedID: String?

    init(backend: Backend) {
        self.backend = backend
    }

    // MARK: Bölümler

    /// Başlama günü geçmiş olanlar.
    var overdue: [TaskItem] { open.filter { $0.scheduledDate < today } }
    var current: [TaskItem] { open.filter { $0.scheduledDate >= today } }
    /// Ekrandaki sıra; ↑↓ bu dizide gezer.
    var ordered: [TaskItem] { overdue + current + done }
    var selected: TaskItem? { ordered.first { $0.id == selectedID } }

    var progress: Double {
        let total = open.count + done.count
        return total == 0 ? 0 : Double(done.count) / Double(total)
    }

    // MARK: Yükleme

    func reload() async {
        guard let view = await backend.run({ try await $0.focusView(area: self.areaFilter) }) else { return }
        today = view.today
        open = view.tasks
        done = view.done
        hasLoaded = true
        if selected == nil { selectedID = ordered.first?.id }
    }

    /// Art arda gelen realtime olaylarını tek yenilemede toplar.
    func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    func reset() {
        open = []
        done = []
        today = ""
        selectedID = nil
        hasLoaded = false
    }

    // MARK: Aksiyonlar (ActionRegistry üzerinden çağrılır)

    func moveSelection(_ delta: Int) {
        let rows = ordered
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : rows.count)
        selectedID = rows[min(max(index + delta, 0), rows.count - 1)].id
    }

    func cycleArea() {
        switch areaFilter {
        case nil: areaFilter = .work
        case .work: areaFilter = .personal
        case .personal: areaFilter = nil
        }
        Task { await reload() }
    }

    /// Tamamla / geri al. Tamamlanınca imleç bir sonraki açık task'a geçer.
    func toggleDone() {
        guard let task = selected else { return }
        let next = neighbour(of: task)
        Task {
            await backend.run { try await $0.updateTask(task.id, TaskPatch(status: task.isDone ? .todo : .done)) }
            if !task.isDone { selectedID = next }
            await reload()
        }
    }

    func postponeToTomorrow() {
        guard let task = selected, !task.isDone else { return }
        let next = neighbour(of: task)
        Task {
            await backend.run { try await $0.triage(task.id, .tomorrow) }
            selectedID = next
            await reload()
        }
    }

    func setPriority(_ priority: Int) {
        guard let task = selected else { return }
        Task {
            await backend.run { try await $0.updateTask(task.id, TaskPatch(priority: priority)) }
            await reload()
        }
    }

    private func neighbour(of task: TaskItem) -> String? {
        let rows = open
        guard let index = rows.firstIndex(where: { $0.id == task.id }) else { return selectedID }
        if index + 1 < rows.count { return rows[index + 1].id }
        return index > 0 ? rows[index - 1].id : nil
    }
}
