import Foundation
import Observation
import TaskTrackerCore

/// Hafta görünümünün durumu: `GET /api/views/week` + imleç + haftalar arası gezinme.
@Observable
final class WeekStore {
    private let backend: Backend
    private var pendingReload: Task<Void, Never>?

    private(set) var week: WeekView?
    /// `nil` = bugünden başlayan hafta.
    private(set) var start: String?
    var selectedID: String?
    var showsDetails = false

    init(backend: Backend) {
        self.backend = backend
    }

    var today: String { week?.today ?? "" }
    var isCurrentWeek: Bool { start == nil }
    /// Ekrandaki sıra: gecikenler, sonra gün gün.
    var ordered: [TaskItem] { (week?.overdue ?? []) + (week?.days.flatMap(\.tasks) ?? []) }
    var selected: TaskItem? { ordered.first { $0.id == selectedID } }
    /// Yük şeridinde ölçek: haftanın en yoğun günü.
    var peakLoad: Int { max(week?.days.map(\.openCount).max() ?? 0, 1) }

    // MARK: Yükleme

    func reload() async {
        guard let view = await backend.run({ try await $0.weekView(start: self.start) }) else { return }
        week = view
        if selected == nil { selectedID = ordered.first { !$0.isDone }?.id ?? ordered.first?.id }
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
        week = nil
        start = nil
        selectedID = nil
        showsDetails = false
    }

    // MARK: Gezinme

    func moveSelection(_ delta: Int) {
        let rows = ordered
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : rows.count)
        selectedID = rows[min(max(index + delta, 0), rows.count - 1)].id
    }

    /// Haftayı 7 gün kaydırır; bugünün haftasına dönünce `start` yeniden `nil` olur.
    func shiftWeek(_ delta: Int) {
        guard let week else { return }
        let target = Day.adding(7 * delta, to: week.start)
        start = target <= week.today ? nil : target
        selectedID = nil
        Task { await reload() }
    }

    func showCurrentWeek() {
        guard start != nil else { return }
        start = nil
        selectedID = nil
        Task { await reload() }
    }

    // MARK: Aksiyonlar

    /// Seçili task'ı bir gün ileri/geri taşır. Geçmişe taşınmaz: en erken bugün;
    /// gecikmiş bir task ileri itilince bugüne gelir.
    func shiftDay(_ delta: Int) {
        guard let task = selected, !task.isDone, !task.scheduledDate.isEmpty, !today.isEmpty else { return }
        let base = task.scheduledDate < today ? Day.adding(-1, to: today) : task.scheduledDate
        let target = max(Day.adding(delta, to: base), today)
        guard target != task.scheduledDate else { return }
        update(task, TaskPatch(scheduledDate: target))
    }

    func moveToToday() {
        guard let task = selected, !task.isDone, task.scheduledDate != today, !today.isEmpty else { return }
        update(task, TaskPatch(scheduledDate: today))
    }

    func toggleDone() {
        guard let task = selected else { return }
        update(task, TaskPatch(status: task.isDone ? .todo : .done))
    }

    func toggleDetails() {
        guard selected != nil else { return }
        showsDetails.toggle()
    }

    private func update(_ task: TaskItem, _ patch: TaskPatch) {
        Task {
            await backend.run { try await $0.updateTask(task.id, patch) }
            await reload()
        }
    }
}
