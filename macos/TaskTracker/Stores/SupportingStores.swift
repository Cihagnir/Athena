import Foundation
import Observation
import TaskTrackerCore

/// Proje adları (satırlardaki `#ad` etiketi için).
@Observable
final class ProjectStore {
    private let backend: Backend
    private(set) var byID: [String: Project] = [:]

    init(backend: Backend) {
        self.backend = backend
    }

    func reload() async {
        guard let projects = await backend.run({ try await $0.projects() }) else { return }
        byID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func name(for id: String) -> String? { byID[id]?.name }
}

/// Aktif task + zamanlayıcı (`focus_state`). Tüm istemcilerde ortaktır.
@Observable
final class ActiveTaskStore {
    private let backend: Backend
    private(set) var current: ActiveState? { didSet { scheduleExpiry() } }
    private var expiry: Task<Void, Never>?

    init(backend: Backend) {
        self.backend = backend
    }

    var taskID: String? { current?.task?.id }

    // MARK: Zamanlayıcı

    func startTimer(minutes: Int) {
        TimerAlert.requestPermission()
        Task {
            if let state = await backend.run({ try await $0.startTimer(seconds: minutes * 60) }) { current = state }
        }
    }

    func stopTimer() {
        Task {
            if let state = await backend.run({ try await $0.stopTimer() }) { current = state }
        }
    }

    /// Aktif task'ı tamamlar; sunucu aktif task'ı ve zamanlayıcıyı kendisi boşaltır.
    func completeCurrent() {
        guard let id = taskID else { return }
        Task {
            await backend.run { try await $0.updateTask(id, TaskPatch(status: .done)) }
            await reload()
        }
    }

    /// Server tıklamaz: bitiş anı istemcide beklenir. Süre dolunca ses + bildirim
    /// verilir ve zamanlayıcı sunucuda temizlenir (diğer istemciler de sıfırlansın).
    /// Uygulama kapalıyken dolmuş eski bir zamanlayıcı sessizce temizlenir.
    private func scheduleExpiry() {
        expiry?.cancel()
        guard let end = current?.timerEnd, let title = current?.task?.title else { return }
        let remaining = end.timeIntervalSinceNow
        expiry = Task {
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            if remaining > -5 { TimerAlert.fire(taskTitle: title) }
            stopTimer()
        }
    }

    func reload() async {
        if let state = await backend.run({ try await $0.activeState() }) { current = state }
    }

    /// Aktif yapar; zaten aktifse bırakır.
    func toggle(_ task: TaskItem) {
        guard !task.isDone else { return }
        Task {
            let isActive = taskID == task.id
            if let state = await backend.run({ isActive ? try await $0.clearActive() : try await $0.setActive(task.id) }) {
                current = state
            }
        }
    }

    func reset() { current = nil }  // didSet bekleyen süre dolumunu da iptal eder
}
