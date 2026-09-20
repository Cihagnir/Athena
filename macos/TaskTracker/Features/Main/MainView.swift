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
        .background(WindowConfigurator())
        .ignoresSafeArea()
        .task {
            app.openMainWindow = { openWindow(id: TaskTrackerApp.mainWindowID) }
            await app.bootstrap()
        }
    }
}

struct MainView: View {
    @Environment(AppState.self) private var app

    var body: some View {
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
        case .settings: SettingsView()
        default:
            Text("\(app.route.title.lowercased()) · yakında").foregroundStyle(Theme.ink3)
        }
    }
}

private struct Sidebar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Route.views.enumerated()), id: \.element) { index, route in
                row(route, key: "⌘\(index + 1)", count: route == .today ? app.today.open.count : nil)
            }
            Spacer()
            row(.settings, key: "⌘,", count: nil)
        }
        .padding(.top, 44)
        .padding(.bottom, 24)
        .frame(width: 220)
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

/// E-ink penceresi: başlık çubuğu ve renkli pencere düğmeleri yok (⌘W / ⌘M / ⌘Q
/// çalışır), pencere arka plandan sürüklenir.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
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
