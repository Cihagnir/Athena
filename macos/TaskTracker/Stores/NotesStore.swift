import Foundation
import Observation
import TaskTrackerCore

/// Notlar görünümünün durumu: kart ızgarası, proje filtresi, arama ve editör.
@Observable
final class NotesStore {
    enum Mode { case browse, editing, searching, confirmDelete }

    enum Filter: Equatable {
        case all, unassigned
        case project(String)
    }

    private let backend: Backend
    private let projects: ProjectStore
    private var pendingSave: Task<Void, Never>?
    private var pendingReload: Task<Void, Never>?

    private(set) var notes: [Note] = []
    private(set) var hasLoaded = false
    private(set) var filter: Filter = .all
    private(set) var mode: Mode = .browse
    var selectedID: String?
    var query = ""
    /// Izgaranın sütun sayısı; görünüm genişliğe göre ayarlar (↑↓ bir satır atlar).
    var columns = 3

    /// Editördeki tek metin: ilk satır başlık, kalanı gövde. Yazarken kendiliğinden kaydedilir.
    var editorText = "" { didSet { if mode == .editing && editorText != oldValue { scheduleSave() } } }
    /// Düzenlenen not; `nil` = henüz kaydedilmemiş yeni not.
    private(set) var editingID: String?

    init(backend: Backend, projects: ProjectStore) {
        self.backend = backend
        self.projects = projects
    }

    // MARK: Liste

    var visible: [Note] {
        let words = ActionRegistry.fold(query).split(separator: " ")
        return notes.filter { note in
            switch filter {
            case .all: break
            case .unassigned: if !note.project.isEmpty { return false }
            case .project(let id): if note.project != id { return false }
            }
            guard !words.isEmpty else { return true }
            let text = ActionRegistry.fold(note.title + " " + note.body)
            return words.allSatisfy { text.contains($0) }
        }
    }

    var selected: Note? { notes.first { $0.id == selectedID } }
    var isTyping: Bool { mode == .editing || mode == .searching }

    /// Filtre seçenekleri: hepsi, notu olan projeler, projesiz.
    var filters: [Filter] {
        let used = Set(notes.map(\.project)).subtracting([""])
        let named = used.compactMap { id in projects.byID[id] }.sorted { $0.name < $1.name }.map { Filter.project($0.id) }
        return [.all] + named + (notes.contains { $0.project.isEmpty } && !named.isEmpty ? [.unassigned] : [])
    }

    func reload() async {
        guard mode != .editing, let loaded = await backend.run({ try await $0.notes() }) else { return }
        notes = loaded
        hasLoaded = true
        if !filters.contains(filter) { filter = .all }
        if selected == nil || !visible.contains(where: { $0.id == selectedID }) { selectedID = visible.first?.id }
    }

    /// Realtime: düzenleme sırasında liste yenilenmez (yazılan metin ezilmesin).
    func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    func reset() {
        notes = []
        selectedID = nil
        mode = .browse
        query = ""
        filter = .all
        hasLoaded = false
    }

    // MARK: Gezinme

    func moveSelection(_ delta: Int) {
        let rows = visible
        guard !rows.isEmpty else { return }
        guard let index = rows.firstIndex(where: { $0.id == selectedID }) else { selectedID = rows[0].id; return }
        let target = index + delta
        if rows.indices.contains(target) { selectedID = rows[target].id }
    }

    func moveRow(_ delta: Int) { moveSelection(delta * max(columns, 1)) }

    func cycleFilter() {
        let all = filters
        let index = all.firstIndex(of: filter) ?? 0
        filter = all[(index + 1) % all.count]
        selectedID = visible.first?.id
    }

    // MARK: Arama

    func beginSearch() { mode = .searching }

    func endSearch(clear: Bool) {
        if clear { query = "" }
        mode = .browse
        selectedID = visible.first?.id
    }

    // MARK: Editör

    func openSelected() {
        guard let note = selected else { return }
        mode = .browse
        editingID = note.id
        editorText = note.text
        mode = .editing
    }

    func beginNew() {
        mode = .browse
        editingID = nil
        editorText = ""
        mode = .editing
    }

    func closeEditor() {
        pendingSave?.cancel()
        let text = editorText
        let id = editingID
        mode = .browse
        Task {
            await save(text, id: id)
            await reload()
            if let editingID { selectedID = editingID }
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let text = editorText
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await save(text, id: editingID)
        }
    }

    /// Boş yeni not oluşturulmaz; mevcut notun başlığı boşaltılırsa kayıt atlanır.
    private func save(_ text: String, id: String?) async {
        let parts = Note.split(text)
        guard !parts.title.isEmpty else { return }
        if let id {
            guard let note = notes.first(where: { $0.id == id }), note.title != parts.title || note.body != parts.body else { return }
            if let updated = await backend.run({ try await $0.updateNote(id, NotePatch(title: parts.title, body: parts.body)) }),
               let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index] = updated
            }
        } else {
            let project: String = if case .project(let projectID) = filter { projectID } else { "" }
            if let created = await backend.run({ try await $0.createNote(title: parts.title, body: parts.body, project: project) }) {
                notes.insert(created, at: 0)
                editingID = created.id
            }
        }
    }

    // MARK: Aksiyonlar

    func togglePinned() {
        guard let note = selected else { return }
        Task {
            await backend.run { try await $0.updateNote(note.id, NotePatch(pinned: !note.pinned)) }
            await reload()
        }
    }

    func beginDelete() {
        if selected != nil { mode = .confirmDelete }
    }

    func cancel() { mode = .browse }

    func confirmDelete() {
        guard mode == .confirmDelete, let note = selected else { return }
        let rows = visible
        let index = rows.firstIndex { $0.id == note.id } ?? 0
        mode = .browse
        Task {
            await backend.run { try await $0.deleteNote(note.id) }
            selectedID = nil
            await reload()
            let remaining = visible
            selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        }
    }
}
