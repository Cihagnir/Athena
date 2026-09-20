import KeyboardShortcuts
import Observation
import SwiftUI

/// Bir aksiyonun geçerli olduğu yer. Aynı tuş farklı bağlamlarda farklı iş görebilir.
enum ActionContext: String, CaseIterable {
    /// Her uygulamadan — yalnızca global kısayolla.
    case global
    /// Uygulama öndeyken — menü komutu olarak.
    case mainWindow
    /// Ana pencerenin her görünümünde — modifier'sız tuşlar (metin alanı odaktayken çalışmaz).
    case anyView
    /// Odak listesi klavyeyi dinlerken — modifier'sız tek tuşlar.
    case todayList
    /// Hızlı ekleme paneli — tuşları metin alanı yakalar; burada yalnızca belgelenir.
    case quickAdd

    var title: String {
        switch self {
        case .global: "HER YERDEN"
        case .mainWindow: "ANA PENCERE"
        case .anyView: "HER GÖRÜNÜM"
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
    /// `false`: ⌘K paletinde listelenmez (gezinme tuşları, paletin kendisi…).
    var showsInPalette = true
    let perform: () -> Void

    /// Her aksiyonun ayarlardan atanabilen bir global kısayol yuvası vardır.
    var globalName: KeyboardShortcuts.Name { .init("action.\(id)", default: defaultGlobal) }
    var keysDisplay: String { keys.map(\.display).joined(separator: " ") }

    /// Kullanıcının (ya da varsayılanın) atadığı global kısayol: "⌃⌥Space".
    var globalDisplay: String? {
        guard isBindable, let shortcut = KeyboardShortcuts.getShortcut(for: globalName) else { return nil }
        return "\(shortcut)"
    }

    /// Yerel tuşlar + global kısayol, tek satırda.
    var allKeysDisplay: String {
        [keysDisplay, globalDisplay ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
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

    /// ⌘K paleti: sorgudaki her kelime başlıkta geçmeli (Türkçe/büyük-küçük harf duyarsız).
    func search(_ query: String) -> [AppAction] {
        let words = Self.fold(query).split(separator: " ")
        return actions.filter { action in
            guard action.isBindable, action.showsInPalette else { return false }
            let title = Self.fold(action.title)
            return words.allSatisfy { title.contains($0) }
        }
    }

    static func fold(_ text: String) -> String {
        text.replacingOccurrences(of: "İ", with: "i").replacingOccurrences(of: "I", with: "i").lowercased()
            .replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g").replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o").replacingOccurrences(of: "ç", with: "c")
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
