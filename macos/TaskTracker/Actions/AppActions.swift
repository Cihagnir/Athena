import KeyboardShortcuts
import SwiftUI

/// Uygulamadaki bütün aksiyonların tanımı. Sıra, Ayarlar'daki listenin sırasıdır.
/// Buraya eklenen aksiyon kendiliğinden: tuşuna bağlanır, menüde (ana pencere
/// bağlamı) ve Ayarlar'da görünür, global kısayol atanabilir olur.
enum AppActions {
    static func all(for app: AppState) -> [AppAction] {
        global(app) + mainWindow(app) + anyView(app) + todayList(app) + quickAddDocs
    }

    private static func global(_ app: AppState) -> [AppAction] {
        [
            AppAction(id: "quickAdd.toggle", title: "Hızlı ekleme panelini aç / kapat", context: .global,
                      defaultGlobal: .init(.space, modifiers: [.control, .option])) { [weak app] in
                guard let app, app.phase == .loggedIn else { app?.showMainWindow(); return }
                app.quickAdd.toggle()
            },
            AppAction(id: "mainWindow.show", title: "Ana pencereyi göster", context: .global,
                      defaultGlobal: .init(.t, modifiers: [.control, .option])) { [weak app] in
                app?.showMainWindow()
            },
        ]
    }

    private static func mainWindow(_ app: AppState) -> [AppAction] {
        let views = Route.views.enumerated().map { index, route in
            AppAction(id: "route.\(route.rawValue)", title: "\(route.title) görünümü", context: .mainWindow,
                      keys: [KeyBinding(key: KeyEquivalent(Character("\(index + 1)")), modifiers: .command, display: "⌘\(index + 1)")]) { [weak app] in
                app?.showMainWindow(route: route)
            }
        }
        return views + [
            AppAction(id: "route.settings", title: "Ayarlar", context: .mainWindow,
                      keys: [KeyBinding(key: ",", modifiers: .command, display: "⌘,")]) { [weak app] in
                app?.showMainWindow(route: .settings)
            },
            AppAction(id: "palette.toggle", title: "Komut paleti", context: .mainWindow,
                      keys: [KeyBinding(key: "k", modifiers: .command, display: "⌘K")], showsInPalette: false) { [weak app] in
                guard let app, app.phase == .loggedIn else { return }
                app.showMainWindow()
                app.overlay = app.overlay == .palette ? nil : .palette
            },
            AppAction(id: "window.fullScreen", title: "Tam ekran aç / kapat", context: .mainWindow,
                      keys: [KeyBinding(key: "f", modifiers: [.control, .command], display: "⌃⌘F")]) { [weak app] in
                app?.toggleFullScreen()
            },
            // ⌘M ve ⌘W'yi sistemin Pencere menüsü yakalar; burada palette/yardımda görünsünler
            // ve pencere düğmeleriyle aynı işi yapsınlar diye kayıtlıdır.
            AppAction(id: "window.minimize", title: "Pencereyi küçült (Dock'a)", context: .mainWindow,
                      keys: [KeyBinding(key: "m", modifiers: .command, display: "⌘M")]) { [weak app] in
                app?.minimizeWindow()
            },
            AppAction(id: "window.close", title: "Pencereyi kapat (uygulama arka planda kalır)", context: .mainWindow,
                      keys: [KeyBinding(key: "w", modifiers: .command, display: "⌘W")]) { [weak app] in
                app?.mainWindow?.performClose(nil)
            },
            AppAction(id: "task.new", title: "Yeni task (hızlı ekleme paneli)", context: .mainWindow,
                      keys: [KeyBinding(key: "n", modifiers: .command, display: "⌘N")]) { [weak app] in
                app?.quickAdd.show()
            },
        ]
    }

    private static func anyView(_ app: AppState) -> [AppAction] {
        [
            AppAction(id: "help.toggle", title: "Bu ekranın kısayolları", context: .anyView,
                      keys: [KeyBinding(key: "?", display: "?")]) { [weak app] in
                guard let app else { return }
                app.showMainWindow()
                app.overlay = app.overlay == .help ? nil : .help
            },
        ]
    }

    private static func todayList(_ app: AppState) -> [AppAction] {
        let today = app.today
        let priorities = (1...4).map { priority in
            AppAction(id: "today.priority.\(priority)", title: "Önceliği !\(priority) yap", context: .todayList,
                      keys: [KeyBinding(key: KeyEquivalent(Character("\(priority)")), display: "\(priority)")]) {
                today.setPriority(priority)
            }
        }
        return [
            AppAction(id: "today.down", title: "Aşağı", context: .todayList,
                      keys: [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")], showsInPalette: false) {
                today.moveSelection(1)
            },
            AppAction(id: "today.up", title: "Yukarı", context: .todayList,
                      keys: [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")], showsInPalette: false) {
                today.moveSelection(-1)
            },
            AppAction(id: "today.activate", title: "Aktif task yap / bırak", context: .todayList,
                      keys: [KeyBinding(key: .return, display: "↵")]) { [weak app] in
                guard let app, let task = app.today.selected else { return }
                app.active.toggle(task)
            },
            AppAction(id: "today.details", title: "Detayı aç / kapat", context: .todayList,
                      keys: [KeyBinding(key: "e", display: "E")]) {
                today.toggleDetails()
            },
            AppAction(id: "today.details.close", title: "Detayı kapat", context: .todayList,
                      keys: [KeyBinding(key: .escape, display: "esc")], showsInPalette: false) {
                today.showsDetails = false
            },
            AppAction(id: "today.done", title: "Tamamla / geri al", context: .todayList,
                      keys: [KeyBinding(key: "d", display: "D")]) {
                today.toggleDone()
            },
            AppAction(id: "today.tomorrow", title: "Yarına at", context: .todayList,
                      keys: [KeyBinding(key: "y", display: "Y")]) {
                today.postponeToTomorrow()
            },
        ] + priorities + [
            AppAction(id: "today.area", title: "Alan filtresi: hepsi → iş → kişisel", context: .todayList,
                      keys: [KeyBinding(key: .tab, display: "⇥")]) {
                today.cycleArea()
            },
        ]
    }

    /// Panelin tuşlarını metin alanı yakalar (QuickAddView); burada yalnızca
    /// Ayarlar'daki listede görünsünler diye belgelenir.
    private static let quickAddDocs: [AppAction] = [
        ("quickAdd.submit", "Ekle (panel açık kalır)", "↵"),
        ("quickAdd.details", "Açıklama alanına geç / başlığa dön", "⇥"),
        ("quickAdd.newline", "Açıklamada yeni satır", "⇧↵"),
        ("quickAdd.close", "Paneli kapat", "esc"),
    ].map { id, title, display in
        AppAction(id: id, title: title, context: .quickAdd,
                  keys: [KeyBinding(key: .escape, display: display)], isBindable: false) {}
    }
}
