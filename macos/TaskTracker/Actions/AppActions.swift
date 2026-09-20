import KeyboardShortcuts
import SwiftUI

/// Uygulamadaki bütün aksiyonların tanımı. Sıra, Ayarlar'daki listenin sırasıdır.
/// Buraya eklenen aksiyon kendiliğinden: tuşuna bağlanır, menüde (ana pencere
/// bağlamı) ve Ayarlar'da görünür, global kısayol atanabilir olur.
enum AppActions {
    static func all(for app: AppState) -> [AppAction] {
        global(app) + mainWindow(app) + todayList(app) + quickAddDocs
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
            AppAction(id: "task.new", title: "Yeni task (hızlı ekleme paneli)", context: .mainWindow,
                      keys: [KeyBinding(key: "n", modifiers: .command, display: "⌘N")]) { [weak app] in
                app?.quickAdd.show()
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
                      keys: [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")]) {
                today.moveSelection(1)
            },
            AppAction(id: "today.up", title: "Yukarı", context: .todayList,
                      keys: [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")]) {
                today.moveSelection(-1)
            },
            AppAction(id: "today.activate", title: "Aktif task yap / bırak", context: .todayList,
                      keys: [KeyBinding(key: .return, display: "↵")]) { [weak app] in
                guard let app, let task = app.today.selected else { return }
                app.active.toggle(task)
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
