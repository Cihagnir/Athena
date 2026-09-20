import Foundation
import Observation
import TaskTrackerCore

/// Projeler görünümünün durumu. Proje verisinin kendisi `ProjectStore`'dadır (satırlardaki
/// `#ad` etiketleri de oradan okur); burada seçim ve giriş modları tutulur.
@Observable
final class ProjectsScreenStore {
    enum Mode { case browse, creating, renaming, editing, confirmDelete }

    private let backend: Backend
    private let projects: ProjectStore
    private var pendingSave: Task<Void, Never>?

    var selectedID: String?
    private(set) var mode: Mode = .browse
    /// `creating` / `renaming` modlarındaki ad satırı.
    var nameInput = ""
    /// `editing` modundaki tanım metni; yazarken kendiliğinden kaydedilir.
    var detailsInput = "" { didSet { if mode == .editing && detailsInput != oldValue { scheduleSave() } } }

    init(backend: Backend, projects: ProjectStore) {
        self.backend = backend
        self.projects = projects
    }

    /// Aktif → beklemede → bitti, her grup ad sırasıyla.
    var ordered: [Project] {
        let rank: [ProjectStatus: Int] = [.active: 0, .onHold: 1, .done: 2]
        return projects.byID.values.sorted {
            (rank[$0.status] ?? 0, $0.name.lowercased()) < (rank[$1.status] ?? 0, $1.name.lowercased())
        }
    }

    var selected: Project? { selectedID.flatMap { projects.byID[$0] } }
    var isTyping: Bool { mode == .creating || mode == .renaming || mode == .editing }

    func count(_ status: ProjectStatus) -> Int { projects.byID.values.filter { $0.status == status }.count }

    func load() async {
        await projects.reload()
        if selected == nil { selectedID = ordered.first?.id }
    }

    func reset() {
        selectedID = nil
        mode = .browse
    }

    // MARK: Gezinme

    func moveSelection(_ delta: Int) {
        let rows = ordered
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : rows.count)
        selectedID = rows[min(max(index + delta, 0), rows.count - 1)].id
    }

    // MARK: Modlar

    func beginCreating() {
        nameInput = ""
        mode = .creating
    }

    func beginRenaming() {
        guard let project = selected else { return }
        nameInput = project.name
        mode = .renaming
    }

    func beginEditing() {
        guard let project = selected else { return }
        mode = .browse
        detailsInput = project.details
        mode = .editing
    }

    func beginDelete() {
        if selected != nil { mode = .confirmDelete }
    }

    /// `esc`: düzenlemeden çıkarken bekleyen kayıt hemen yazılır.
    func cancel() {
        if mode == .editing { saveDetailsNow() }
        mode = .browse
    }

    func confirmName() {
        let name = nameInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let creating = mode == .creating
        let target = selected
        mode = .browse
        Task {
            if creating {
                if let project = await backend.run({ try await $0.createProject(name: name, area: .personal) }) {
                    await projects.reload()
                    selectedID = project.id
                }
            } else if let target, target.name != name {
                await backend.run { try await $0.updateProject(target.id, ProjectPatch(name: name)) }
                await projects.reload()
            }
        }
    }

    func confirmDelete() {
        guard mode == .confirmDelete, let project = selected else { return }
        let rows = ordered
        let index = rows.firstIndex { $0.id == project.id } ?? 0
        mode = .browse
        Task {
            await backend.run { try await $0.deleteProject(project.id) }
            await projects.reload()
            let remaining = ordered
            selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        }
    }

    // MARK: Alanlar

    func cycleStatus() {
        guard let project = selected else { return }
        let next: ProjectStatus = switch project.status {
        case .active: .onHold
        case .onHold: .done
        case .done: .active
        }
        patch(project, ProjectPatch(status: next))
    }

    func toggleArea() {
        guard let project = selected else { return }
        patch(project, ProjectPatch(area: project.area == .work ? .personal : .work))
    }

    private func patch(_ project: Project, _ patch: ProjectPatch) {
        Task {
            await backend.run { try await $0.updateProject(project.id, patch) }
            await projects.reload()
        }
    }

    // MARK: Tanım kaydı

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveDetailsNow()
        }
    }

    private func saveDetailsNow() {
        pendingSave?.cancel()
        guard let project = selected, project.details != detailsInput else { return }
        let text = detailsInput
        Task {
            await backend.run { try await $0.updateProject(project.id, ProjectPatch(details: text)) }
            await projects.reload()
        }
    }
}
