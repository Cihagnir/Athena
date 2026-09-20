import KeyboardShortcuts
import Observation
import SwiftUI

/// Bir aksiyonun geçerli olduğu yer. Aynı tuş farklı bağlamlarda farklı iş görebilir.
enum ActionContext: String, CaseIterable {
    /// Her uygulamadan — yalnızca global kısayolla.
    case global
    /// Uygulama öndeyken — menü komutu olarak.
    case mainWindow
    /// Odak listesi klavyeyi dinlerken — modifier'sız tek tuşlar.
    case todayList
    /// Hızlı ekleme paneli — tuşları metin alanı yakalar; burada yalnızca belgelenir.
    case quickAdd

    var title: String {
        switch self {
        case .global: "HER YERDEN"
        case .mainWindow: "ANA PENCERE"
        case .todayList: "ODAK LİSTESİ"
        case .quickAdd: "HIZLI EKLEME"
        }
    }
}

struct KeyBinding {
    let key: KeyEquivalent
    var modifiers: EventModifiers = []
    /// Ayarlarda ve ipuçlarında görünen yazım: "⌘1", "↵", "D".
    let display: String

    private static let compared: EventModifiers = [.command, .option, .control]

    func matches(_ press: KeyPress) -> Bool {
        let pressed = Character(press.key.character.lowercased())
        return pressed == key.character
            && press.modifiers.intersection(Self.compared) == modifiers.intersection(Self.compared)
    }
}

struct AppAction: Identifiable {
    let id: String
    let title: String
    let context: ActionContext
    var keys: [KeyBinding] = []
    /// Kullanıcı atamadan önce geçerli olan global kısayol (çoğu aksiyonda yok).
    var defaultGlobal: KeyboardShortcuts.Shortcut?
    /// `false`: yalnızca belgeleme amaçlı (tuşu başka bir katman yakalıyor).
    var isBindable = true
    let perform: () -> Void

    /// Her aksiyonun ayarlardan atanabilen bir global kısayol yuvası vardır.
    var globalName: KeyboardShortcuts.Name { .init("action.\(id)", default: defaultGlobal) }
    var keysDisplay: String { keys.map(\.display).joined(separator: " ") }
}

/// Aksiyonların tek kaydı. Odak listesinin tuşları, menü komutları, global
/// kısayollar ve Ayarlar'daki kısayol listesi bu diziden türer.
///
/// Yeni aksiyon eklemek: `AppActions.swift`'e bir `AppAction` yaz — başka hiçbir
/// yere dokunmadan menüde/ayarlarda görünür ve global kısayol atanabilir olur.
@Observable
final class ActionRegistry {
    private(set) var actions: [AppAction] = []

    func register(_ newActions: [AppAction]) {
        actions.append(contentsOf: newActions)
        for action in newActions where action.isBindable {
            KeyboardShortcuts.onKeyUp(for: action.globalName) { action.perform() }
        }
    }

    func actions(in context: ActionContext) -> [AppAction] {
        actions.filter { $0.context == context }
    }

    /// SwiftUI `onKeyPress` için: tuş bu bağlamda bir aksiyona bağlıysa çalıştırır.
    func handle(_ press: KeyPress, in context: ActionContext) -> KeyPress.Result {
        guard let action = actions(in: context).first(where: { $0.keys.contains { $0.matches(press) } }) else {
            return .ignored
        }
        action.perform()
        return .handled
    }
}
