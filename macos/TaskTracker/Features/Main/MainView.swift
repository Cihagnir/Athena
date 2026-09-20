import SwiftUI

/// Ana pencere: oturum durumuna göre giriş ekranı ya da kenar çubuğu + görünüm.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch app.phase {
            case .checking:
                Text("bağlanıyor…").foregroundStyle(Theme.ink3).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loggedOut:
                LoginView()
            case .loggedIn:
                MainView()
            }
        }
        .font(Theme.font())
        .foregroundStyle(Theme.ink)
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.hairline))
        .overlay(alignment: .topLeading) { WindowControls().padding(.leading, 20).padding(.top, 14) }
        .background(WindowConfigurator(app: app))
        .ignoresSafeArea()
        .onAppear {
            app.openMainWindow = { openWindow(id: TaskTrackerApp.mainWindowID) }
        }
    }
}

struct MainView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            layout
            // Katmanlar opak ve çerçevelidir; arka plan karartılmaz (saydamlık yok).
            switch app.overlay {
            case .palette: PaletteView()
            case .help: HelpView()
            case nil: EmptyView()
            }
        }
        // Odaktaki görünümün işlemediği tuşlar buraya çıkar (ör. `?`).
        .onKeyPress(phases: .down) { app.registry.handle($0, in: .anyView) }
    }

    private var layout: some View {
        HStack(spacing: 0) {
            Sidebar()
            Rectangle().fill(Theme.ink).frame(width: Theme.hairline)
            VStack(spacing: 0) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let error = app.backend.lastError {
                    InkRule()
                    Text("? " + error).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32).padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch app.route {
        case .today: TodayView()
        case .triage: TriageView()
        case .week: WeekScreen()
        case .settings: SettingsView().keyboardFocus(unless: app.overlay != nil)
        default:
            Text("\(app.route.title.lowercased()) · yakında").foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .keyboardFocus(unless: app.overlay != nil)
        }
    }
}

/// Sistemin renkli pencere düğmelerinin monokrom karşılığı: kapat · küçült · tam ekran.
/// Her ekranda (giriş dahil) sol üstte durur.
private struct WindowControls: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 14) {
            control("✕", help: "Kapat — uygulama arka planda kalır (⌘W)") { app.mainWindow?.performClose(nil) }
            control("–", help: "Küçült; tam ekrandaysa önce tam ekrandan çıkar (⌘M)") { app.minimizeWindow() }
            control("□", help: "Tam ekran aç / kapat (⌃⌘F)") { app.toggleFullScreen() }
        }
    }

    private func control(_ glyph: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(Theme.font(bold: true)).foregroundStyle(Theme.ink2)
                .frame(width: 16, height: 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }
}

private struct Sidebar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Route.views.enumerated()), id: \.element) { index, route in
                row(route, key: "⌘\(index + 1)", count: count(for: route))
            }
            Spacer()
            row(.settings, key: "⌘,", count: nil)
        }
        .padding(.top, 44)
        .padding(.bottom, 24)
        .frame(width: 220)
    }

    /// ODAK: açık task'lar · TRİYAJ: başlama günü geçmiş olanlar.
    private func count(for route: Route) -> Int? {
        switch route {
        case .today: app.today.open.count
        case .triage: app.today.overdue.count
        default: nil
        }
    }

    private func row(_ route: Route, key: String, count: Int?) -> some View {
        let selected = app.route == route
        return Button {
            app.route = route
        } label: {
            HStack(spacing: 12) {
                Text(key).foregroundStyle(selected ? Theme.paper : Theme.ink2)
                Text(route.title).font(Theme.font(bold: selected))
                    .foregroundStyle(selected ? Theme.paper : route.isImplemented ? Theme.ink : Theme.ink3)
                Spacer()
                if let count, count > 0 { Text("\(count)") }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .foregroundStyle(selected ? Theme.paper : Theme.ink)
            .background(selected ? Theme.ink : Theme.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// Tuşların (`?` gibi) işlenebilmesi için görünümü klavye odağına alır; bir katman
/// açıkken odağı bırakır, kapanınca geri alır.
private struct KeyboardFocus: ViewModifier {
    let blocked: Bool
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onAppear { focused = !blocked }
            .onChange(of: blocked) { _, blocked in focused = !blocked }
    }
}

extension View {
    func keyboardFocus(unless blocked: Bool) -> some View { modifier(KeyboardFocus(blocked: blocked)) }
}

/// E-ink penceresi: başlık çubuğu ve renkli pencere düğmeleri yok (⌘W / ⌘M / ⌘Q /
/// ⌃⌘F çalışır), pencere arka plandan sürüklenir. Tam ekran durumu hatırlanır.
private struct WindowConfigurator: NSViewRepresentable {
    let app: AppState

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            app.mainWindow = window
            window.collectionBehavior.insert(.fullScreenPrimary)
            let settings = app.settings
            let center = NotificationCenter.default
            center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { settings.startsFullScreen = true }
            }
            center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { settings.startsFullScreen = false }
            }
            // macOS pencere durumunu her çıkışta geri yüklemez (⌘Q ile çıkışta sistem ayarına
            // bağlı); bu yüzden tam ekran durumu ayrıca saklanır. Pencere ekrana yerleşmeden
            // istenen geçiş yok sayıldığı için kısa bir gecikmeyle uygulanır.
            if settings.startsFullScreen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if !window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
                }
            }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = Theme.paperNS
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
