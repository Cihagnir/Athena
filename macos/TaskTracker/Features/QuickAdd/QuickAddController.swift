import AppKit
import Observation
import SwiftUI
import TaskTrackerCore

/// Hızlı ekleme panelinin durumu + penceresi.
///
/// Panel Spotlight gibi davranır: `.nonactivatingPanel` sayesinde öndeki uygulama
/// önde kalır, yalnızca klavye odağı panele geçer. Kapanınca odak kendiliğinden
/// önceki uygulamaya döner.
@Observable
final class QuickAddController {
    enum Field { case title, details }

    private let backend: Backend
    private var panel: QuickAddPanel?
    private var previewTask: Task<Void, Never>?

    var text = "" { didSet { if text != oldValue { schedulePreview() } } }
    var details = ""
    private(set) var showsDetails = false
    private(set) var field: Field = .title
    /// Alan değişiminde artar; `InkTextView` odağı buna bakarak alır.
    private(set) var titleFocus = 0
    private(set) var detailsFocus = 0
    private(set) var preview: ParsedInput?
    /// Ekleme sonrası tek karelik ters flaşta gösterilen başlık.
    private(set) var flashTitle: String?
    private(set) var error: String?

    static let width: CGFloat = 640

    init(backend: Backend) {
        self.backend = backend
    }

    // MARK: Pencere

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.placeSpotlight()
        panel.makeKeyAndOrderFront(nil)
        focus(.title)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> QuickAddPanel {
        let panel = QuickAddPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 420))
        panel.contentView = NSHostingView(rootView: QuickAddView(model: self))
        return panel
    }

    // MARK: Alanlar

    func switchField() {
        if field == .title {
            showsDetails = true
            focus(.details)
        } else {
            if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { showsDetails = false }
            focus(.title)
        }
    }

    private func focus(_ target: Field) {
        field = target
        if target == .title { titleFocus += 1 } else { detailsFocus += 1 }
    }

    // MARK: Önizleme + ekleme

    private func schedulePreview() {
        previewTask?.cancel()
        error = nil
        let current = text
        guard !current.trimmingCharacters(in: .whitespaces).isEmpty else { preview = nil; return }
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            let result = try? await backend.api.quickAddPreview(text: current)
            // Yanıt gelene kadar metin değiştiyse bu önizleme eskidir.
            guard !Task.isCancelled, current == text else { return }
            preview = result
        }
    }

    func submit() {
        let current = text
        guard !current.trimmingCharacters(in: .whitespaces).isEmpty, flashTitle == nil else { return }
        Task {
            do {
                let result = try await backend.api.quickAdd(text: current, description: details)
                flashTitle = result.task.title
                text = ""
                details = ""
                preview = nil
                showsDetails = false
                try? await Task.sleep(for: .milliseconds(140))
                flashTitle = nil
                focus(.title)
            } catch APIError.unauthorized {
                backend.onUnauthorized()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// Çerçevesiz, odağı çalmayan, her masaüstünde görünen panel.
final class QuickAddPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }

    /// Yatayda ortada, üstten ekranın ~%22'si (Spotlight konumu). Panel içeriği
    /// yukarı yaslıdır; pencerenin kalanı saydam ve tıklamaları geçirir.
    func placeSpotlight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        let top = area.maxY - area.height * 0.22
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: top - frame.height))
    }
}
