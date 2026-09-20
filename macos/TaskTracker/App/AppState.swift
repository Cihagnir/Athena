import AppKit
import Observation
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
    var isImplemented: Bool { self == .today || self == .settings }

    /// Görünümün kendi tuş bağlamı (`?` yardımında ilk sırada gösterilir).
    var context: ActionContext? { self == .today ? .todayList : nil }
}

/// Ana pencerenin üstüne açılan, klavyeyi devralan katmanlar.
enum Overlay {
    case palette, help
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
    let quickAdd: QuickAddController

    private(set) var phase: Phase = .checking
    var route: Route = .today { didSet { overlay = nil } }
    var overlay: Overlay?
    /// Kök görünüm açılışta doldurur; pencere kapalıyken yeniden açmak için.
    var openMainWindow: () -> Void = {}
    /// `WindowConfigurator` doldurur (tam ekran gibi pencere düzeyi işler için).
    @ObservationIgnored weak var mainWindow: NSWindow?

    private var realtimeTask: Task<Void, Never>?

    init() {
        backend = Backend(url: settings.serverURL, token: settings.token)
        today = TodayStore(backend: backend)
        projects = ProjectStore(backend: backend)
        active = ActiveTaskStore(backend: backend)
        quickAdd = QuickAddController(backend: backend)
        backend.onUnauthorized = { [weak self] in self?.endSession(message: "Oturum süresi doldu, yeniden giriş yap.") }
        registry.register(AppActions.all(for: self))
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
    func login(server: String, email: String, password: String) async -> String? {
        guard let url = AppSettings.normalizedURL(server) else { return "Adres http:// ya da https:// ile başlamalı." }
        do {
            let session = try await APIClient(baseURL: url).login(email: email, password: password)
            settings.serverAddress = url.absoluteString
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
    func changeServer(to address: String) async -> String? {
        guard let url = AppSettings.normalizedURL(address) else { return "Adres http:// ya da https:// ile başlamalı." }
        do {
            try await APIClient(baseURL: url).health()
        } catch {
            return error.localizedDescription
        }
        settings.serverAddress = url.absoluteString
        endSession(message: nil)
        return nil
    }

    private func beginSession(_ session: AuthSession) {
        settings.token = session.token
        backend.configure(url: settings.serverURL, token: session.token)
        backend.lastError = nil
        phase = .loggedIn
        realtimeTask?.cancel()
        realtimeTask = Task { await runRealtime() }
        applyDebugLaunchOptions()
    }

    /// Yalnızca DEBUG: ekranları klavyesiz doğrulamak için (macos/README.md → Doğrulama).
    ///   TT_DEBUG_ROUTE=settings   TT_DEBUG_OVERLAY=palette|help
    ///   TT_DEBUG_QUICKADD="Rapor yaz salı son:cuma // not"
    private func applyDebugLaunchOptions() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let route = env["TT_DEBUG_ROUTE"].flatMap(Route.init(rawValue:)) { self.route = route }
        switch env["TT_DEBUG_OVERLAY"] {
        case "palette": overlay = .palette
        case "help": overlay = .help
        default: break
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
        backend.configure(url: settings.serverURL, token: nil)
        backend.lastError = message
        today.reset()
        active.reset()
        quickAdd.hide()
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
            let stream = RealtimeClient(api: backend.api).events(topics: ["tasks", "projects", "focus_state"]) { [weak self] in
                await self?.reloadAll()
            }
            do {
                for try await event in stream {
                    delay = 1.0
                    switch event.topic {
                    case "tasks":
                        today.scheduleReload()
                        if event.recordID == active.taskID { await active.reload() }
                    case "projects":
                        await projects.reload()
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

    // MARK: Pencere

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
