import KeyboardShortcuts
import SwiftUI

/// Uygulamadaki bütün aksiyonların tanımı. Sıra, Ayarlar'daki listenin sırasıdır.
/// Buraya eklenen aksiyon kendiliğinden: tuşuna bağlanır, menüde (ana pencere
/// bağlamı) ve Ayarlar'da görünür, global kısayol atanabilir olur.
enum AppActions {
    static func all(for app: AppState) -> [AppAction] {
        global(app) + mainWindow(app) + anyView(app) + todayList(app) + triage(app) + week(app) + kanban(app) + projects(app) + notes(app) + miniPanel(app) + listPanel(app) + quickAddDocs
    }

    private static func global(_ app: AppState) -> [AppAction] {
        [
            AppAction(id: "quickAdd.toggle", title: "Hızlı ekleme panelini aç / kapat", context: .global,
                      defaultGlobal: .init(.space, modifiers: [.control, .option])) { [weak app] in
                guard let app, app.phase == .loggedIn else { app?.showMainWindow(); return }
                app.quickAdd.toggle()
            },
            AppAction(id: "quickNote.toggle", title: "Hızlı not panelini aç / kapat", context: .global,
                      defaultGlobal: .init(.n, modifiers: [.control, .option])) { [weak app] in
                guard let app, app.phase == .loggedIn else { app?.showMainWindow(); return }
                app.quickNote.toggle()
            },
            AppAction(id: "panel.listen", title: "Mini panel: klavyeyi ver / bırak", context: .global,
                      defaultGlobal: .init(.m, modifiers: [.control, .option])) { [weak app] in
                guard let app, app.phase == .loggedIn else { return }
                app.panel.toggleListening(.mini)
            },
            AppAction(id: "panel.list", title: "Liste panelini aç / kapat", context: .global,
                      defaultGlobal: .init(.l, modifiers: [.control, .option])) { [weak app] in
                guard let app, app.phase == .loggedIn else { return }
                app.panel.toggleListening(.list)
            },
            AppAction(id: "panel.visibility", title: "Yüzen paneli göster / gizle", context: .global) { [weak app] in
                guard let app, app.phase == .loggedIn else { return }
                app.panel.toggleVisibility()
            },
            AppAction(id: "panel.resetPosition", title: "Yüzen paneli varsayılan konuma al (sağ üst)", context: .global) { [weak app] in
                guard let app, app.phase == .loggedIn else { return }
                app.panel.resetPosition()
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
            AppAction(id: "today.details", title: "Detayı aç · açıkken düzenle", context: .todayList,
                      keys: [KeyBinding(key: "e", display: "E")]) { [weak app] in
                if today.showsDetails { app?.editTask(today.selected) } else { today.toggleDetails() }
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

    private static func triage(_ app: AppState) -> [AppAction] {
        let store = app.triage
        func action(_ id: String, _ title: String, _ key: KeyEquivalent, _ display: String, _ perform: @escaping () -> Void) -> AppAction {
            AppAction(id: "triage." + id, title: title, context: .triage,
                      keys: [KeyBinding(key: key, display: display)], showsInPalette: false, perform: perform)
        }
        return [
            action("tomorrow", "Yarına at", "1", "1") { if store.mode == .choose { store.postponeToTomorrow() } },
            action("date", "Tarih seç", "2", "2") { if store.mode == .choose { store.begin(.date) } },
            action("project", "Projeye taşı (yoksa oluşturur)", "3", "3") { if store.mode == .choose { store.begin(.project) } },
            action("delete", "Sil (↵ ile onaylanır)", "4", "4") { if store.mode == .choose { store.begin(.confirmDelete) } },
            action("done", "Tamamlandı say", "d", "D") { if store.mode == .choose { store.markDone() } },
            action("skip", "Atla", .space, "␣") { store.skip() },
            action("confirm", "Silmeyi onayla", .return, "↵") { store.delete() },
            action("escape", "Vazgeç / Odak'a dön", .escape, "esc") { [weak app] in
                if store.mode == .choose { app?.route = .today } else { store.cancel() }
            },
        ]
    }

    private static func week(_ app: AppState) -> [AppAction] {
        let store = app.week
        func action(_ id: String, _ title: String, _ keys: [KeyBinding], _ perform: @escaping () -> Void) -> AppAction {
            AppAction(id: "week." + id, title: title, context: .week, keys: keys, showsInPalette: false, perform: perform)
        }
        return [
            action("down", "Aşağı", [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")]) { store.moveSelection(1) },
            action("up", "Yukarı", [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")]) { store.moveSelection(-1) },
            action("later", "Task'ı bir gün ileri taşı", [KeyBinding(key: .rightArrow, display: "→"), KeyBinding(key: "l", display: "L")]) { store.shiftDay(1) },
            action("earlier", "Task'ı bir gün geri taşı (en erken bugün)", [KeyBinding(key: .leftArrow, display: "←"), KeyBinding(key: "h", display: "H")]) { store.shiftDay(-1) },
            action("today", "Task'ı bugüne al", [KeyBinding(key: "b", display: "B")]) { store.moveToToday() },
            action("done", "Tamamla / geri al", [KeyBinding(key: "d", display: "D")]) { store.toggleDone() },
            action("details", "Detayı aç · açıkken düzenle", [KeyBinding(key: "e", display: "E")]) { [weak app] in
                if store.showsDetails { app?.editTask(store.selected) } else { store.toggleDetails() }
            },
            action("activate", "Aktif task yap / bırak", [KeyBinding(key: .return, display: "↵")]) { [weak app] in
                guard let app, let task = app.week.selected else { return }
                app.active.toggle(task)
            },
            action("next", "Sonraki hafta", [KeyBinding(key: ".", display: ".")]) { store.shiftWeek(1) },
            action("previous", "Önceki hafta (bu haftadan geriye gidilmez)", [KeyBinding(key: ",", display: ",")]) { store.shiftWeek(-1) },
            action("current", "Bu haftaya dön", [KeyBinding(key: "0", display: "0")]) { store.showCurrentWeek() },
            action("escape", "Detayı kapat", [KeyBinding(key: .escape, display: "esc")]) { store.showsDetails = false },
        ]
    }

    private static func kanban(_ app: AppState) -> [AppAction] {
        let store = app.kanban
        func action(_ id: String, _ title: String, _ keys: [KeyBinding], _ perform: @escaping () -> Void) -> AppAction {
            AppAction(id: "kanban." + id, title: title, context: .kanban, keys: keys, showsInPalette: false, perform: perform)
        }
        return [
            action("down", "Aşağı", [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")]) { store.moveSelection(1) },
            action("up", "Yukarı", [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")]) { store.moveSelection(-1) },
            action("right", "Sağdaki sütun", [KeyBinding(key: .rightArrow, display: "→"), KeyBinding(key: "l", display: "L")]) { store.moveColumn(1) },
            action("left", "Soldaki sütun", [KeyBinding(key: .leftArrow, display: "←"), KeyBinding(key: "h", display: "H")]) { store.moveColumn(-1) },
            action("forward", "Kartı sonraki duruma taşı", [KeyBinding(key: .rightArrow, modifiers: .shift, display: "⇧→")]) { store.shiftStatus(1) },
            action("back", "Kartı önceki duruma taşı", [KeyBinding(key: .leftArrow, modifiers: .shift, display: "⇧←")]) { store.shiftStatus(-1) },
            action("done", "Tamamla / geri al", [KeyBinding(key: "d", display: "D")]) { store.toggleDone() },
            action("details", "Açıklamayı aç · açıkken düzenle", [KeyBinding(key: "e", display: "E")]) { [weak app] in
                if store.showsDetails { app?.editTask(store.selected) } else { store.toggleDetails() }
            },
            action("activate", "Aktif task yap / bırak", [KeyBinding(key: .return, display: "↵")]) { [weak app] in
                guard let app, let task = app.kanban.selected else { return }
                app.active.toggle(task)
            },
            action("escape", "Açıklamayı kapat", [KeyBinding(key: .escape, display: "esc")]) { store.showsDetails = false },
        ]
    }

    private static func projects(_ app: AppState) -> [AppAction] {
        let store = app.projectsScreen
        func action(_ id: String, _ title: String, _ keys: [KeyBinding], _ perform: @escaping () -> Void) -> AppAction {
            AppAction(id: "projects." + id, title: title, context: .projects, keys: keys, showsInPalette: false, perform: perform)
        }
        // Onay modunda yalnızca ↵ ve esc anlamlıdır.
        func browsing(_ work: @escaping () -> Void) -> () -> Void { { if store.mode == .browse { work() } } }
        return [
            action("down", "Aşağı", [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")], browsing { store.moveSelection(1) }),
            action("up", "Yukarı", [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")], browsing { store.moveSelection(-1) }),
            action("new", "Yeni proje", [KeyBinding(key: "n", display: "N")], browsing { store.beginCreating() }),
            action("edit", "Tanımı düzenle", [KeyBinding(key: "e", display: "E"), KeyBinding(key: .return, display: "↵")]) {
                if store.mode == .confirmDelete { store.confirmDelete() } else if store.mode == .browse { store.beginEditing() }
            },
            action("rename", "Yeniden adlandır", [KeyBinding(key: "r", display: "R")], browsing { store.beginRenaming() }),
            action("status", "Durum: aktif → beklemede → bitti", [KeyBinding(key: "s", display: "S")], browsing { store.cycleStatus() }),
            action("area", "Alan: iş ↔ kişisel", [KeyBinding(key: "a", display: "A")], browsing { store.toggleArea() }),
            action("delete", "Sil (↵ ile onaylanır)", [KeyBinding(key: .delete, display: "⌫")], browsing { store.beginDelete() }),
            action("escape", "Vazgeç", [KeyBinding(key: .escape, display: "esc")]) { store.cancel() },
        ]
    }

    private static func notes(_ app: AppState) -> [AppAction] {
        let store = app.notes
        func action(_ id: String, _ title: String, _ keys: [KeyBinding], _ perform: @escaping () -> Void) -> AppAction {
            AppAction(id: "notes." + id, title: title, context: .notes, keys: keys, showsInPalette: false, perform: perform)
        }
        func browsing(_ work: @escaping () -> Void) -> () -> Void { { if store.mode == .browse { work() } } }
        return [
            action("right", "Sonraki not", [KeyBinding(key: .rightArrow, display: "→"), KeyBinding(key: "l", display: "L")], browsing { store.moveSelection(1) }),
            action("left", "Önceki not", [KeyBinding(key: .leftArrow, display: "←"), KeyBinding(key: "h", display: "H")], browsing { store.moveSelection(-1) }),
            action("down", "Alt satır", [KeyBinding(key: .downArrow, display: "↓"), KeyBinding(key: "j", display: "J")], browsing { store.moveRow(1) }),
            action("up", "Üst satır", [KeyBinding(key: .upArrow, display: "↑"), KeyBinding(key: "k", display: "K")], browsing { store.moveRow(-1) }),
            action("open", "Aç / düzenle", [KeyBinding(key: .return, display: "↵"), KeyBinding(key: "e", display: "E")]) {
                if store.mode == .confirmDelete { store.confirmDelete() } else if store.mode == .browse { store.openSelected() }
            },
            action("new", "Yeni not", [KeyBinding(key: "n", display: "N")], browsing { store.beginNew() }),
            action("pin", "Sabitle / bırak", [KeyBinding(key: "p", display: "P")], browsing { store.togglePinned() }),
            action("filter", "Proje filtresi", [KeyBinding(key: .tab, display: "⇥")], browsing { store.cycleFilter() }),
            action("search", "Ara", [KeyBinding(key: "/", display: "/")], browsing { store.beginSearch() }),
            action("delete", "Sil (↵ ile onaylanır)", [KeyBinding(key: .delete, display: "⌫")], browsing { store.beginDelete() }),
            action("escape", "Vazgeç / aramayı temizle", [KeyBinding(key: .escape, display: "esc")]) {
                if store.mode == .confirmDelete { store.cancel() } else if !store.query.isEmpty { store.endSearch(clear: true) }
            },
        ]
    }

    private static func miniPanel(_ app: AppState) -> [AppAction] {
        let panel = app.panel
        return [
            AppAction(id: "mini.expand", title: "Detayları genişlet / daralt", context: .miniPanel,
                      keys: [KeyBinding(key: "e", display: "E")], showsInPalette: false) { panel.toggleExpanded() },
            AppAction(id: "mini.timer", title: "Zamanlayıcı: dakika yaz + ↵ · çalışıyorsa durdur", context: .miniPanel,
                      keys: [KeyBinding(key: "t", display: "T")], showsInPalette: false) { panel.timerKey() },
            AppAction(id: "mini.done", title: "Aktif task'ı tamamla", context: .miniPanel,
                      keys: [KeyBinding(key: "d", display: "D")]) { panel.completeActive() },
            AppAction(id: "mini.note", title: "Aktif task'a not düş (açıklamaya eklenir)", context: .miniPanel,
                      keys: [KeyBinding(key: "n", display: "N")], showsInPalette: false) { panel.beginNote() },
            AppAction(id: "mini.pick", title: "Aktif task seç (liste paneli açılır)", context: .miniPanel,
                      keys: [KeyBinding(key: .space, display: "␣")], showsInPalette: false) { panel.openList() },
            AppAction(id: "mini.hide", title: "Paneli gizle", context: .miniPanel,
                      keys: [KeyBinding(key: "h", display: "H")], showsInPalette: false) { panel.toggleVisibility() },
            AppAction(id: "mini.escape", title: "Klavyeyi önceki uygulamaya geri ver", context: .miniPanel,
                      keys: [KeyBinding(key: .escape, display: "esc")], showsInPalette: false) { panel.escape() },
        ]
    }

    private static func listPanel(_ app: AppState) -> [AppAction] {
        let panel = app.panel
        return [
            AppAction(id: "list.activate", title: "Aktif yap ve mini panele dön", context: .listPanel,
                      keys: [KeyBinding(key: .return, display: "↵")], showsInPalette: false) { panel.activateSelected() },
            AppAction(id: "list.pin", title: "Listeyi sabitle / bırak (pasif dashboard)", context: .listPanel,
                      keys: [KeyBinding(key: "p", display: "P")], showsInPalette: false) { panel.togglePinned() },
            AppAction(id: "list.escape", title: "Mini panele dön", context: .listPanel,
                      keys: [KeyBinding(key: .escape, display: "esc")], showsInPalette: false) { panel.escape() },
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
