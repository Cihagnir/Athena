import AppKit
import Observation
import SwiftUI
import TaskTrackerCore

/// Yüzen panelin durumu + penceresi. Tek pencere iki biçimde görünür: **mini**
/// (yalnızca aktif task) ve onun yerini alan **liste** (bugünün task'ları).
///
/// Klavye modeli (docs/PLAN.md → Katman 2): panel normalde *pasif*tir. Global
/// kısayol ya da tıklama ona klavye odağını verir (*dinliyor*, çerçeve 2 px) —
/// uygulama öne gelmeden. Tek atımlık aksiyonlardan sonra odak kendiliğinden
/// önceki uygulamaya döner (`release`).
@Observable
final class PanelController {
    enum Mode { case mini, list }

    static let width: CGFloat = 320
    /// Pencere sabit yükseklikte ve saydamdır; içerik bir kenara yaslanır, kalan
    /// kısım tıklamaları geçirir. Böylece içerik büyüyünce pencere oynamaz.
    private static let windowHeight: CGFloat = 560
    private static let margin: CGFloat = 20

    private let settings: AppSettings
    private let active: ActiveTaskStore
    private let today: TodayStore
    private var panel: FloatingPanel?
    private var observers: [NSObjectProtocol] = []
    private var reanchor: Task<Void, Never>?

    private(set) var mode: Mode = .mini
    private(set) var isListening = false
    private(set) var isExpanded = false
    private(set) var isPinned = false
    /// `nil` değilse süre girişi modu: yazılan dakika.
    private(set) var timerInput: String?
    /// İçerik pencerenin üstüne mi altına mı yaslı — ekranın hangi yarısındaysa.
    private(set) var anchorsTop = true
    /// Görünümün ölçtüğü içerik yüksekliği (yeniden yaslama hesabı için).
    var contentHeight: CGFloat = 0

    init(settings: AppSettings, active: ActiveTaskStore, today: TodayStore) {
        self.settings = settings
        self.active = active
        self.today = today
    }

    // MARK: Görünürlük

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Oturum açılınca: kullanıcı gizlemediyse paneli pasif olarak gösterir.
    func showIfEnabled(content: () -> AnyView) {
        if panel == nil { panel = makePanel(content: content()) }
        if settings.showsPanel { panel?.orderFrontRegardless() }
    }

    func hide() {
        panel?.orderOut(nil)
        resetTransientState()
    }

    func toggleVisibility() {
        settings.showsPanel.toggle()
        if settings.showsPanel { panel?.orderFrontRegardless() } else { hide() }
    }

    // MARK: Klavye odağı

    /// Global kısayol: paneli gösterir ve klavyeyi ona verir; zaten o biçimde
    /// dinliyorsa bırakır.
    func toggleListening(_ target: Mode) {
        guard let panel else { return }
        if isListening && mode == target {
            if target == .list { backToMini() }
            release()
            return
        }
        settings.showsPanel = true
        mode = target
        if target == .list { Task { await today.reload() } }
        panel.makeKeyAndOrderFront(nil)
    }

    /// Klavyeyi önceki uygulamaya geri verir; panel pasif olarak görünür kalır.
    func release() {
        guard let panel, panel.isKeyWindow else { return }
        panel.orderOut(nil)
        if settings.showsPanel { panel.orderFrontRegardless() }
    }

    private func keyStatusChanged(_ isKey: Bool) {
        isListening = isKey
        guard !isKey else { return }
        timerInput = nil
        isExpanded = false
        if mode == .list && !isPinned { mode = .mini }
    }

    private func resetTransientState() {
        isListening = false
        isExpanded = false
        timerInput = nil
        if !isPinned { mode = .mini }
    }

    #if DEBUG
    /// Görsel doğrulama için: klavye odağı olmadan bir hali zorlar (TT_DEBUG_PANEL).
    func debugForce(_ state: String) {
        isListening = true
        mode = state == "list" ? .list : .mini
        isExpanded = state == "expanded"
        timerInput = state == "timer" ? "25" : nil
        if mode == .list { Task { await today.reload() } }
    }
    #endif

    // MARK: Mini panel aksiyonları

    func toggleExpanded() {
        guard active.current?.task != nil else { return }
        isExpanded.toggle()
    }

    /// `T`: zamanlayıcı çalışıyorsa durdurur, yoksa süre girişini açar.
    func timerKey() {
        guard active.current?.task != nil else { return }
        if active.current?.timerEnd != nil {
            active.stopTimer()
            release()
        } else {
            timerInput = ""
        }
    }

    func completeActive() {
        active.completeCurrent()
        release()
    }

    func openList() {
        mode = .list
        Task { await today.reload() }
    }

    func backToMini() {
        mode = .mini
        isPinned = false
    }

    func escape() {
        if mode == .list { backToMini() }
        isExpanded = false
        release()
    }

    // MARK: Liste paneli aksiyonları

    /// `↵`: seçili task'ı aktif yapar; sabitlenmemişse mini panele döner.
    func activateSelected() {
        guard let task = today.selected, !task.isDone else { return }
        if active.taskID != task.id { active.toggle(task) }
        if !isPinned { mode = .mini }
        release()
    }

    /// `P`: liste klavyeyi bıraksa da açık kalır (pasif dashboard).
    func togglePinned() { isPinned.toggle() }

    // MARK: Süre girişi

    /// Süre girişi açıkken tuşları devralır: rakamlar, ⌫, ↵ başlat, esc vazgeç.
    func handleTimerInput(_ press: KeyPress) -> Bool {
        guard var input = timerInput else { return false }
        switch press.key {
        case .return:
            timerInput = nil
            if let minutes = Int(input), minutes > 0 {
                active.startTimer(minutes: minutes)
                release()
            }
        case .escape:
            timerInput = nil
        case .delete:
            if !input.isEmpty { input.removeLast() }
            timerInput = input
        default:
            if let digit = press.characters.first, digit.isNumber, input.count < 3 {
                timerInput = input + String(digit)
            }
        }
        return true
    }

    // MARK: Pencere

    private func makePanel(content: AnyView) -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.windowHeight))
        panel.contentView = NSHostingView(rootView: content)
        panel.setFrameOrigin(restoredOrigin())
        updateAnchor(for: panel)

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyStatusChanged(true) }
            },
            center.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyStatusChanged(false) }
            },
            center.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.panelMoved() }
            },
        ]
        return panel
    }

    /// İlk açılış: ana ekranın sağ üstü (menü çubuğunun altı, kenarlardan 20 px).
    private func restoredOrigin() -> NSPoint {
        if let saved = settings.panelOrigin, NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -Self.width, dy: -Self.windowHeight).contains(saved) }) {
            return saved
        }
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: area.maxX - Self.margin - Self.width, y: area.maxY - Self.margin - Self.windowHeight)
    }

    /// Sürükleme bitince konumu saklar ve içerik ekranın diğer yarısına geçtiyse
    /// yaslamayı çevirir — içerik yerinde kalsın diye pencereyi aynı anda kaydırır.
    private func panelMoved() {
        reanchor?.cancel()
        reanchor = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, NSEvent.pressedMouseButtons == 0, let panel else { return }
            let wasTop = anchorsTop
            let contentMidY = wasTop ? panel.frame.maxY - contentHeight / 2 : panel.frame.minY + contentHeight / 2
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
            let nowTop = contentMidY >= screen.visibleFrame.midY
            if nowTop != wasTop {
                let shift = Self.windowHeight - contentHeight
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY + (nowTop ? -shift : shift)))
                anchorsTop = nowTop
            }
            settings.panelOrigin = panel.frame.origin
        }
    }

    private func updateAnchor(for panel: NSPanel) {
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        anchorsTop = panel.frame.midY >= screen.visibleFrame.midY
    }
}

/// Çerçevesiz, odağı çalmayan, her masaüstünde ve tam ekran uygulamaların üstünde
/// duran panel. Arka plandan sürüklenir.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
}
