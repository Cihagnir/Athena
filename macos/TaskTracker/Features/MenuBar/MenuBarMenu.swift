import SwiftUI

/// Menü çubuğu öğesinin menüsü. Etiket (`▸ 3/7`) `AppState.menuBarLabel`'dan gelir;
/// öğeler aksiyon kaydındaki aynı aksiyonları çalıştırır.
struct MenuBarMenu: View {
    @Environment(AppState.self) private var app

    private static let actionIDs = ["quickAdd.toggle", "mainWindow.show", "route.settings"]

    var body: some View {
        if app.phase == .loggedIn {
            Text(app.active.current?.task.map { "▸ " + $0.title } ?? "aktif task yok")
            Text("bugün \(app.today.done.count)/\(app.today.done.count + app.today.open.count)")
        } else {
            Text("giriş yapılmadı")
        }
        Divider()
        ForEach(app.registry.actions.filter { Self.actionIDs.contains($0.id) }) { action in
            Button(action.title + (action.globalDisplay.map { "   \($0)" } ?? ""), action: action.perform)
        }
        Divider()
        Button("Çıkış") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
