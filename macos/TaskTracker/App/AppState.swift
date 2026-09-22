import AppKit
import Observation
import SwiftUI
import TaskTrackerCore

enum Route: String, CaseIterable, Identifiable {
    case today, triage, week, kanban, projects, notes, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "ODAK"
        case .triage: "TRİYAJ"
        case .week: "HAFTA"
        case .kanban: "KANBAN"
        case .projects: "PROJELER"
        case .notes: "NOTLAR"
        case .settings: "AYARLAR"
        }
    }

    /// Kenar çubuğundaki ⌘1…⌘6 görünümleri (Ayarlar ayrı durur: ⌘,).
    static let views: [Route] = [.today, .triage, .week, .kanban, .projects, .notes]
    var isImplemented: Bool { true }

    /// Görünümün kendi tuş bağlamı (`?` yardımında ilk sırada gösterilir).
    var context: ActionContext? {
        switch self {
        case .today: .todayList
        case .triage: .triage
        case .week: .week
        case .kanban: .kanban
        case .projects: .projects
        case .notes: .notes
        case .settings: nil
        }
    }
}

/// Ana pencerenin üstüne açılan, klavyeyi devralan katmanlar.
enum Overlay {
    case palette, help, editTask
}

/// Uygulamanın kökü: oturum, yönlendirme, store'lar ve realtime döngüsü.
/// Tek örnek `TaskTrackerApp` içinde yaşar ve görünümlere environment ile geçer.
@Observable
final class AppState {
    enum Phase { case checking, loggedOut, loggedIn }

    let settings = AppSettings()
    let registry = ActionRegistry()
    let backend: Backend
    let today: TodayStore
    let projects: ProjectStore
    let active: ActiveTaskStore
    let triage: TriageStore
    let week: WeekStore
    let kanban: KanbanStore
    let projectsScreen: ProjectsScreenStore
    let notes: NotesStore
    let quickNote: QuickNoteController
    let taskEditor: TaskEditorModel
    let quickAdd: QuickAddController
    let panel: PanelController

    private(set) var phase: Phase = .checking
    var route: Route = .today { didSet { overlay = nil } }
    var overlay: Overlay?
    /// Kök görünüm açılışta doldurur; pencere kapalıyken yeniden açmak için.
    var openMainWindow: () -> Void = {}
    /// `WindowConfigurator` doldurur (tam ekran gibi pencere düzeyi işler için).
    @ObservationIgnored weak var mainWindow: NSWindow?
    @ObservationIgnored private var keyMonitor: Any?
    /// Artınca `keyboardFocus(unless:)` görünümleri klavye odağını yeniden alır.
    var focusTick = 0

    private var realtimeTask: Task<Void, Never>?

    init() {
        backend = Backend(url: settings.serverURL, token: settings.token, apiKey: settings.apiKey)
        today = TodayStore(backend: backend)
        projects = ProjectStore(backend: backend)
        active = ActiveTaskStore(backend: backend)
        triage = TriageStore(backend: backend, projects: projects)
        week = WeekStore(backend: backend)
        kanban = KanbanStore(backend: backend)
        projectsScreen = ProjectsScreenStore(backend: backend, projects: projects)
        notes = NotesStore(backend: backend, projects: projects)
        quickNote = QuickNoteController(backend: backend)
        taskEditor = TaskEditorModel(backend: backend, projects: projects)
        quickAdd = QuickAddController(backend: backend)
        panel = PanelController(settings: settings, active: active, today: today)
        backend.onUnauthorized = { [weak self] in self?.endSession(message: "Oturum süresi doldu, yeniden giriş yap.") }
        taskEditor.onFinished = { [weak self] saved in
            guard let self else { return }
            overlay = nil
            if saved { Task { await self.reloadVisibleTasks() } }
        }
        registry.register(AppActions.all(for: self))
        installKeyFallback()
        // Görünümden bağımsız: pencere açılışta kapalı olsa da (login item) oturum kurulur.
        Task { await bootstrap() }
    }

    /// Menü çubuğu öğesinin metni: aktif task varsa `▸`, ardından bugün biten / toplam.
    var menuBarLabel: String {
        guard phase == .loggedIn, today.hasLoaded else { return "–" }
        let total = today.done.count + today.open.count
        return (active.taskID == nil ? "" : "▸ ") + "\(today.done.count)/\(total)"
    }

    // MARK: Oturum

    /// Açılışta: kayıtlı token varsa yenilemeyi dener.
    func bootstrap() async {
        settings.appearance.apply()
        guard settings.token != nil else { phase = .loggedOut; return }
        do {
            let session = try await backend.api.refresh()
            beginSession(session)
        } catch APIError.unauthorized {
            endSession(message: nil)
        } catch {
            // Sunucuya ulaşılamıyor: token'ı atma, giriş ekranında durumu göster.
            backend.lastError = error.localizedDescription
            phase = .loggedOut
        }
    }

    /// Başarısızsa hata mesajını döndürür.
    func login(server: String, apiKey: String, email: String, password: String) async -> String? {
        guard let url = AppSettings.normalizedURL(server) else { return "Adres http:// ya da https:// ile başlamalı." }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let session = try await APIClient(baseURL: url, apiKey: key).login(email: email, password: password)
            settings.serverAddress = url.absoluteString
            settings.apiKey = key
            settings.email = email
            beginSession(session)
            return nil
        } catch let error as APIError {
            if case .http(let status, _) = error, status == 400 { return "E-posta ya da parola hatalı." }
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    func logout() {
        endSession(message: nil)
    }

    /// Sunucu adresi değişince: token o sunucuya ait olduğu için oturum kapanır.
    /// Başarısızsa hata mesajını döndürür.
    func changeServer(to address: String, apiKey: String) async -> String? {
        guard let url = AppSettings.normalizedURL(address) else { return "Adres http:// ya da https:// ile başlamalı." }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await APIClient(baseURL: url, apiKey: key).health()
        } catch {
            return error.localizedDescription
        }
        settings.serverAddress = url.absoluteString
        settings.apiKey = key
        endSession(message: nil)
        return nil
    }

    private func beginSession(_ session: AuthSession) {
        settings.token = session.token
        backend.configure(url: settings.serverURL, token: session.token, apiKey: settings.apiKey)
        backend.lastError = nil
        phase = .loggedIn
        realtimeTask?.cancel()
        realtimeTask = Task { await runRealtime() }
        panel.showIfEnabled { AnyView(PanelView().environment(self)) }
        applyDebugLaunchOptions()
    }

    /// Yalnızca DEBUG: ekranları klavyesiz doğrulamak için (macos/README.md → Doğrulama).
    ///   TT_DEBUG_ROUTE=settings   TT_DEBUG_OVERLAY=palette|help   TT_DEBUG_DETAILS=1
    ///   TT_DEBUG_KEYCODES=36,53   (sentetik tuşlar; aşağıda)
    ///   TT_DEBUG_EDIT=1   (Odak'ta seçili task'ın düzenleme katmanı)
    ///   TT_DEBUG_TRIAGE=choose|date|project
    ///   TT_DEBUG_PANEL=listen|expanded|timer|list   (yüzen panelin halleri)
    ///   TT_DEBUG_QUICKNOTE="Başlık #proje\\ngövde"
    ///   TT_DEBUG_QUICKADD="Rapor yaz salı son:cuma // not"
    private func applyDebugLaunchOptions() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let route = env["TT_DEBUG_ROUTE"].flatMap(Route.init(rawValue:)) { self.route = route }
        if env["TT_DEBUG_DETAILS"] != nil { today.showsDetails = true }
        // Uygulamanın içinden sentetik tuş: sistem izni gerektirmez ve tuşlar gerçek yoldan
        // (pencere → SwiftUI → metin alanı) geçer; klavye akışlarını ölçmeyi sağlar.
        //   TT_DEBUG_ROUTE=notes TT_DEBUG_KEYCODES=36,53   (↵ aç, esc kapat) → her tuştan sonra durum yazdırılır
        //   TT_DEBUG_KEYCODES=r:notes,45   (önce Notlar'a geç, sonra N) — "r:<görünüm>" kenar çubuğu tıklamasını taklit eder
        if let codes = env["TT_DEBUG_KEYCODES"] {
            let characters: [UInt16: String] = [53: "\u{1b}", 36: "\r", 48: "\t", 49: " ", 14: "e", 45: "n", 2: "d", 15: "r", 35: "p", 44: "/"]
            Task {
                try? await Task.sleep(for: .seconds(4))
                NSApp.activate()
                mainWindow?.makeKeyAndOrderFront(nil)
                try? await Task.sleep(for: .seconds(1))
                print("TTKEY başlangıç anahtarPencere=\(mainWindow?.isKeyWindow ?? false)"); fflush(stdout)
                for token in codes.split(separator: ",") {
                    // "r:notes" → kenar çubuğuna tıklamış gibi görünüm değiştirir
                    if token.hasPrefix("r:"), let target = Route(rawValue: String(token.dropFirst(2))) {
                        route = target
                        try? await Task.sleep(for: .milliseconds(1200))
                        print("TTKEY \(token) → route=\(route) birinciYanıtlayıcı=\(mainWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "yok")"); fflush(stdout)
                        continue
                    }
                    // "c:100:198" → pencerenin sol üstünden (x, y) noktasına fare tıklaması
                    if token.hasPrefix("c:"), let window = mainWindow {
                        let parts = token.dropFirst(2).split(separator: ":").compactMap { Double($0) }
                        if parts.count == 2 {
                            let point = NSPoint(x: parts[0], y: (window.contentView?.bounds.height ?? 0) - parts[1])
                            for (type, clicks) in [(NSEvent.EventType.leftMouseDown, 1), (.leftMouseUp, 1)] {
                                if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1) {
                                    // Düğmeler fare bırakmayı olay kuyruğundan bekler → kuyruğa konur.
                                    NSApp.postEvent(event, atStart: false)
                                }
                            }
                            try? await Task.sleep(for: .milliseconds(1200))
                            print("TTKEY \(token) → route=\(route) notlar=\(notes.mode) seçili=\(notes.selectedID ?? "-")"); fflush(stdout)
                        }
                        continue
                    }
                    // "f:" → SwiftUI klavye odağını düşürür (tıklamanın yaptığı şeyi taklit eder)
                    if token == "f:" {
                        mainWindow?.makeFirstResponder(nil)
                        try? await Task.sleep(for: .milliseconds(600))
                        print("TTKEY f: → birinciYanıtlayıcı=\(mainWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "yok")"); fflush(stdout)
                        continue
                    }
                    guard let code = UInt16(token) else { continue }
                    let text = characters[code] ?? ""
                    if let window = mainWindow,
                       let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                    windowNumber: window.windowNumber, context: nil, characters: text,
                                                    charactersIgnoringModifiers: text, isARepeat: false, keyCode: code) {
                        // Gerçek klavyeyle aynı yol: NSApp → izleyiciler → pencere.
                        NSApp.sendEvent(event)
                    }
                    try? await Task.sleep(for: .milliseconds(1200))
                    print("TTKEY \(code) → route=\(route) overlay=\(overlay.map { "\($0)" } ?? "yok") detay=\(today.showsDetails) notlar=\(notes.mode) projeler=\(projectsScreen.mode) triyaj=\(triage.mode)"); fflush(stdout)
                }
            }
        }
        if env["TT_DEBUG_EDIT"] != nil {
            Task {
                try? await Task.sleep(for: .seconds(2))
                editTask(today.selected)
            }
        }
        if let mode = env["TT_DEBUG_TRIAGE"] {
            route = .triage
            Task { [triage] in
                try? await Task.sleep(for: .seconds(2))
                if mode == "date" { triage.begin(.date); triage.dateInput = "cuma" }
                if mode == "project" { triage.begin(.project); triage.projectQuery = "Ev işleri" }
            }
        }
        if let mode = env["TT_DEBUG_PANEL"] {
            panel.debugForce(mode)
        }
        switch env["TT_DEBUG_OVERLAY"] {
        case "palette": overlay = .palette
        case "help": overlay = .help
        default: break
        }
        if let text = env["TT_DEBUG_QUICKNOTE"] {
            quickNote.show()
            quickNote.text = text.replacingOccurrences(of: "\\n", with: "\n")
        }
        if let text = env["TT_DEBUG_QUICKADD"] {
            quickAdd.show()
            quickAdd.text = text
        }
        #endif
    }

    private func endSession(message: String?) {
        realtimeTask?.cancel()
        realtimeTask = nil
        settings.token = nil
        backend.configure(url: settings.serverURL, token: nil, apiKey: settings.apiKey)
        backend.lastError = message
        today.reset()
        week.reset()
        kanban.reset()
        projectsScreen.reset()
        notes.reset()
        quickNote.hide()
        active.reset()
        quickAdd.hide()
        panel.hide()
        overlay = nil
        phase = .loggedOut
    }

    // MARK: Realtime

    private func reloadAll() async {
        await today.reload()
        await projects.reload()
        await active.reload()
    }

    /// Bağlantı koptukça artan aralıklarla yeniden bağlanır. Her bağlantıda tam
    /// yenileme yapılır; kopukluk sırasında kaçan olaylar böylece telafi edilir.
    private func runRealtime() async {
        var delay = 1.0
        while !Task.isCancelled {
            let stream = RealtimeClient(api: backend.api).events(topics: ["tasks", "projects", "notes", "focus_state"]) { [weak self] in
                await self?.reloadAll()
            }
            do {
                for try await event in stream {
                    delay = 1.0
                    switch event.topic {
                    case "tasks":
                        today.scheduleReload()
                        if route == .triage { await triage.refresh() }
                        if route == .week { week.scheduleReload() }
                        if route == .kanban { kanban.scheduleReload() }
                        if event.recordID == active.taskID { await active.reload() }
                    case "projects":
                        await projects.reload()
                    case "notes":
                        if route == .notes { notes.scheduleReload() }
                    case "focus_state":
                        await active.reload()
                    default:
                        break
                    }
                }
            } catch APIError.unauthorized {
                endSession(message: "Oturum süresi doldu, yeniden giriş yap.")
                return
            } catch {
                if !Task.isCancelled { backend.lastError = "Canlı bağlantı koptu, yeniden deneniyor…" }
            }
            try? await Task.sleep(for: .seconds(delay))
            delay = min(delay * 2, 30)
        }
    }

    // MARK: Klavye güvenlik ağı

    /// SwiftUI tuşları yalnızca klavye odağı ekranın içindeyken dinler; fare tıklaması (ör.
    /// kenar çubuğundan görünüm değiştirmek) odağı düşürebiliyor ve o zaman `N`, `D`… hiçbir
    /// yere gitmiyordu. Bu izleyici ana pencereye gelen her tuşa bakar: SwiftUI tuşu görmediyse
    /// (`sawKeyPress` kalkmadıysa), bir metin alanı yazmada değilse ve katman açık değilse tuşu
    /// doğrudan o görünümün bağlamına yönlendirir ve odağı geri alır. Çift işleme olmaz.
    private func installKeyFallback() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = mainWindow, event.window === window else { return event }
            registry.sawKeyPress = false
            DispatchQueue.main.async { [weak self] in
                guard let self, !registry.sawKeyPress, phase == .loggedIn, overlay == nil,
                      !(window.firstResponder is NSTextView) else { return }
                registry.handle(event, in: [route.context, .anyView].compactMap { $0 })
                focusTick += 1
            }
            return event
        }
    }

    // MARK: Task düzenleme

    /// Detay açıkken `E`: düzenleme katmanını açar.
    func editTask(_ task: TaskItem?) {
        guard let task else { return }
        taskEditor.begin(task)
        overlay = .editTask
    }

    private func reloadVisibleTasks() async {
        await today.reload()
        if route == .week { await week.reload() }
        if route == .kanban { await kanban.reload() }
        await active.reload()
    }

    // MARK: Pencere

    var isFullScreen: Bool { mainWindow?.styleMask.contains(.fullScreen) ?? false }

    /// Tam ekrandayken pencere küçültülemez; önce tam ekrandan çıkılır.
    func minimizeWindow() {
        guard let window = mainWindow else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        } else {
            window.miniaturize(nil)
        }
    }

    func toggleFullScreen() {
        showMainWindow()
        mainWindow?.toggleFullScreen(nil)
    }

    func showMainWindow(route: Route? = nil) {
        if let route { self.route = route }
        NSApp.activate()
        openMainWindow()
    }
}
