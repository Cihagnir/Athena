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

    private(set) var mode: Mode = .mini
    private(set) var isListening = false
    private(set) var isExpanded = false
    private(set) var isPinned = false
    /// `nil` değilse süre girişi modu: yazılan dakika.
    private(set) var timerInput: String?
    /// `nil` değilse not düşme modu: aktif task'ın açıklamasına eklenecek satır.
    private(set) var noteInput: String?
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
        noteInput = nil
        isExpanded = false
        if mode == .list && !isPinned { mode = .mini }
    }

    private func resetTransientState() {
        isListening = false
        isExpanded = false
        timerInput = nil
        noteInput = nil
        if !isPinned { mode = .mini }
    }

    #if DEBUG
    /// Görsel doğrulama için: klavye odağı olmadan bir hali zorlar (TT_DEBUG_PANEL).
    func debugForce(_ state: String) {
        isListening = true
        mode = state == "list" ? .list : .mini
        isExpanded = state == "expanded"
        timerInput = state == "timer" ? "25" : nil
        noteInput = state == "note" ? "KDV satırını ayrı göster" : nil
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

    // MARK: Not düşme

    func beginNote() {
        guard active.current?.task != nil else { return }
        timerInput = nil
        noteInput = ""
    }

    /// Not modu açıkken tuşları devralır: yazı, ⌫, ↵ ekle, esc vazgeç.
    func handleNoteInput(_ press: KeyPress) -> Bool {
        guard var input = noteInput else { return false }
        switch press.key {
        case .return:
            noteInput = nil
            let line = input.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                active.appendNote(line)
                release()
            }
        case .escape:
            noteInput = nil
        case .delete:
            if !input.isEmpty { input.removeLast() }
            noteInput = input
        default:
            let typed = press.characters.filter { !$0.isNewline && $0 != "\t" }
            if !typed.isEmpty, press.modifiers.intersection([.command, .control]).isEmpty, input.count < 300 {
                noteInput = input + typed
            }
        }
        return true
    }

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
        place(panel)

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyStatusChanged(true) }
            },
            center.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyStatusChanged(false) }
            },
            // Ekran takılıp çıkarılınca panel görünmeyen bir yerde kalmasın.
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.settle() }
            },
        ]
        return panel
    }

    // MARK: Konum
    //
    // Saklanan şey içeriğin sabit köşesidir (`settings.panelAnchor` + `panelAnchorsTop`);
    // pencerenin konumu her zaman ondan türetilir. İçerik üste yaslıysa aşağı, alta yaslıysa
    // yukarı doğru büyür (mini ↔ geniş ↔ liste) ve köşesi yerinde kalır.

    private var dragOffset: NSPoint?

    /// Kayıtlı konum görünür bir ekrandaysa onu, değilse varsayılanı uygular.
    private func place(_ panel: NSPanel) {
        if let anchor = settings.panelAnchor,
           NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -8, dy: -8).contains(anchor) }) {
            anchorsTop = settings.panelAnchorsTop
            apply(anchor: anchor, to: panel)
        } else {
            resetPosition(of: panel)
        }
    }

    /// İlk açılış ve "varsayılan konuma al": ana ekranın sağ üstü (menü çubuğunun altı, 20 px).
    private func resetPosition(of panel: NSPanel) {
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let anchor = NSPoint(x: area.maxX - Self.margin - Self.width, y: area.maxY - Self.margin)
        anchorsTop = true
        apply(anchor: anchor, to: panel)
        settings.panelAnchor = anchor
        settings.panelAnchorsTop = true
    }

    func resetPosition() {
        guard let panel else { return }
        settings.showsPanel = true
        resetPosition(of: panel)
        panel.orderFrontRegardless()
    }

    private func apply(anchor: NSPoint, to panel: NSPanel) {
        panel.setFrameOrigin(NSPoint(x: anchor.x, y: anchorsTop ? anchor.y - Self.windowHeight : anchor.y))
    }

    /// Sürükleme: pencere farenin altında taşınır. SwiftUI'nin verdiği öteleme pencere
    /// oynadıkça kaydığı için doğrudan farenin ekran konumu kullanılır.
    func dragChanged() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        if dragOffset == nil { dragOffset = NSPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY) }
        guard let offset = dragOffset else { return }
        panel.setFrameOrigin(NSPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
    }

    func dragEnded() {
        dragOffset = nil
        settle()
    }

    /// İçeriği bulunduğu ekranın içine çeker, hangi yarıdaysa oraya yaslar ve konumu saklar.
    /// Yaslama değişirse pencere aynı anda kaydırılır; içerik yerinden oynamaz.
    private func settle() {
        guard let panel else { return }
        let height = max(contentHeight, 40)
        var content = NSRect(x: panel.frame.minX, y: anchorsTop ? panel.frame.maxY - height : panel.frame.minY,
                             width: Self.width, height: height)
        let center = NSPoint(x: content.midX, y: content.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame.insetBy(dx: 4, dy: 4)
        content.origin.x = min(max(content.minX, area.minX), area.maxX - content.width)
        content.origin.y = min(max(content.minY, area.minY), area.maxY - content.height)

        anchorsTop = content.midY >= area.midY
        let anchor = NSPoint(x: content.minX, y: anchorsTop ? content.maxY : content.minY)
        apply(anchor: anchor, to: panel)
        settings.panelAnchor = anchor
        settings.panelAnchorsTop = anchorsTop
    }
}

/// Çerçevesiz, odağı çalmayan, her masaüstünde ve tam ekran uygulamaların üstünde
/// duran panel. Herhangi bir yerinden sürüklenir (PanelView'daki sürükleme hareketi).
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
        // Sürüklemeyi PanelController yönetir: içerik odaklanabilir olduğu için sistemin
        // "arka plandan taşı" davranışı fare olaylarını hiç görmüyordu.
        isMovableByWindowBackground = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
}
