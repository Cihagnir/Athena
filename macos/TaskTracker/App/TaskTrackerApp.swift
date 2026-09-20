import SwiftUI

@main
struct TaskTrackerApp: App {
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app = AppState()

    var body: some Scene {
        Window("task_tracker", id: Self.mainWindowID) {
            RootView()
                .environment(app)
                .onAppear { delegate.app = app }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            // Ana pencere bağlamındaki aksiyonlar menü komutu olur → uygulama
            // öndeyken, hangi görünüm odakta olursa olsun çalışırlar.
            CommandGroup(replacing: .appSettings) { menuItems(ids: ["route.settings"]) }
            CommandGroup(replacing: .newItem) { menuItems(ids: ["task.new"]) }
            CommandMenu("Görünüm") {
                menuItems(ids: Route.views.map { "route.\($0.rawValue)" })
            }
        }
    }

    @ViewBuilder private func menuItems(ids: [String]) -> some View {
        ForEach(app.registry.actions(in: .mainWindow).filter { ids.contains($0.id) }) { action in
            if let key = action.keys.first {
                Button(action.title, action: action.perform).keyboardShortcut(key.key, modifiers: key.modifiers)
            }
        }
    }
}

/// Pencere kapanınca uygulama arka planda yaşamaya devam eder: global kısayollar
/// ve hızlı ekleme paneli çalışır. Dock simgesine tıklamak pencereyi geri getirir.
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var app: AppState?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { app?.showMainWindow() }
        return true
    }
}
