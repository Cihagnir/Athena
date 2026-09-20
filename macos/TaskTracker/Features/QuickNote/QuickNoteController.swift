import AppKit
import Observation
import SwiftUI
import TaskTrackerCore

/// Hızlı not paneli: her yerden `⌃⌥N`. Hızlı eklemeyle aynı pencere türü ve konum
/// (`QuickAddPanel`); ayrıştırma sunucudadır (`/api/quicknote`): ilk satır başlık,
/// o satırdaki `#proje` bağ, kalanı gövde.
@Observable
final class QuickNoteController {
    private let backend: Backend
    private var panel: QuickAddPanel?
    private var previewTask: Task<Void, Never>?

    var text = "" { didSet { if text != oldValue { schedulePreview() } } }
    private(set) var focus = 0
    private(set) var preview: ParsedNote?
    private(set) var flashTitle: String?
    private(set) var error: String?

    init(backend: Backend) {
        self.backend = backend
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let panel = panel ?? {
            let created = QuickAddPanel(contentRect: NSRect(x: 0, y: 0, width: QuickAddController.width, height: 460))
            created.contentView = NSHostingView(rootView: QuickNoteView(model: self))
            return created
        }()
        self.panel = panel
        panel.placeSpotlight()
        panel.makeKeyAndOrderFront(nil)
        focus += 1
    }

    func hide() { panel?.orderOut(nil) }

    private func schedulePreview() {
        previewTask?.cancel()
        error = nil
        let current = text
        guard !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { preview = nil; return }
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            let result = try? await backend.api.quickNotePreview(text: current)
            guard !Task.isCancelled, current == text else { return }
            preview = result
        }
    }

    func submit() {
        let current = text
        guard !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, flashTitle == nil else { return }
        Task {
            do {
                let result = try await backend.api.quickNote(text: current)
                flashTitle = result.note.title
                text = ""
                preview = nil
                try? await Task.sleep(for: .milliseconds(140))
                flashTitle = nil
                focus += 1
            } catch APIError.unauthorized {
                backend.onUnauthorized()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct QuickNoteView: View {
    @Bindable var model: QuickNoteController

    var body: some View {
        VStack(spacing: 0) {
            if let flash = model.flashTitle {
                Text("▪ \(flash)")
                    .font(Theme.font(Theme.Size.title)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .foregroundStyle(Theme.paper).background(Theme.ink)
            } else {
                content.padding(.horizontal, 16).padding(.vertical, 14).background(Theme.paper)
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.focusLine))
        .frame(width: QuickAddController.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .font(Theme.font())
        .foregroundStyle(Theme.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("not").foregroundStyle(Theme.ink2)
                InkTextView(text: $model.text, multiline: true, tokens: model.preview?.tokens ?? [],
                            focusTrigger: model.focus, onSubmit: model.submit, onTab: {}, onCancel: model.hide)
                    .frame(height: 110)
            }
            Rectangle().fill(Theme.ink).frame(height: Theme.focusLine)

            if let preview = model.preview {
                HStack(spacing: 12) {
                    Text("→")
                    Text(preview.valid ? "başlık: " + preview.title : "başlık yok").lineLimit(1)
                    Text(preview.project.map { "#" + $0.name } ?? "projesiz")
                    if !preview.body.isEmpty { Text("\(preview.body.split(separator: "\n", omittingEmptySubsequences: false).count) satır") }
                }
                .foregroundStyle(Theme.ink2)
                if preview.warnings.contains("project_not_found") { Text("   ? proje bulunamadı, başlıkta kalacak") }
            }
            if let error = model.error { Text("? \(error)") }

            InkRule()
            HStack {
                InkHints("↵ kaydet, kutu açık kalır · ⇧↵ yeni satır · ilk satır başlık · #proje bağlar")
                Text("esc kapat").font(Theme.font(Theme.Size.small)).foregroundStyle(Theme.ink2)
            }
        }
    }
}
