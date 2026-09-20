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
    private(set) var current: ActiveState?

    init(backend: Backend) {
        self.backend = backend
    }

    var taskID: String? { current?.task?.id }

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

    func reset() { current = nil }
}
