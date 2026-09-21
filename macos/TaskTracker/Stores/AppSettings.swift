import AppKit
import Foundation
import Observation

/// Kalıcı kullanıcı ayarları (UserDefaults).
///
/// Oturum token'ı da burada durur: yerel (ad-hoc) imzada Keychain her yeniden
/// derlemede izin sorduğu için bilinçli olarak kullanılmadı — bkz. macos/README.md.
@Observable
final class AppSettings {
    static let defaultServer = "http://127.0.0.1:8090"

    private let defaults = UserDefaults.standard

    var serverAddress: String { didSet { defaults.set(serverAddress, forKey: "serverAddress") } }
    var email: String { didSet { defaults.set(email, forKey: "email") } }
    var token: String? { didSet { defaults.set(token, forKey: "token") } }
    /// İnternete açık sunucu için `X-API-Key`; yerel sunucuda boş bırakılır.
    var apiKey: String { didSet { defaults.set(apiKey, forKey: "apiKey") } }
    /// Ana pencere en son tam ekranda mıydı — açılışta aynı halde başlar.
    var startsFullScreen: Bool { didSet { defaults.set(startsFullScreen, forKey: "startsFullScreen") } }
    /// Yüzen panel görünür mü (H / "Paneli göster-gizle" ile değişir).
    var showsPanel: Bool { didSet { defaults.set(showsPanel, forKey: "showsPanel") } }
    /// Yüzen panel **içeriğinin** sabit köşesi (ekran koordinatı): sol kenar + üste yaslıysa
    /// üst kenar, alta yaslıysa alt kenar. Pencere değil içerik saklanır — pencere içerikten
    /// uzun ve saydamdır; pencere konumundan yaslama çıkarmak paneli kaydırıyordu.
    var panelAnchor: NSPoint? {
        didSet { defaults.set(panelAnchor.map { [$0.x, $0.y] }, forKey: "panelAnchor") }
    }
    var panelAnchorsTop: Bool { didSet { defaults.set(panelAnchorsTop, forKey: "panelAnchorsTop") } }
    var showsMenuBarItem: Bool { didSet { defaults.set(showsMenuBarItem, forKey: "showsMenuBarItem") } }
    var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            appearance.apply()
        }
    }

    init() {
        serverAddress = defaults.string(forKey: "serverAddress") ?? Self.defaultServer
        email = defaults.string(forKey: "email") ?? ""
        token = defaults.string(forKey: "token")
        apiKey = defaults.string(forKey: "apiKey") ?? ""
        startsFullScreen = defaults.bool(forKey: "startsFullScreen")
        showsMenuBarItem = defaults.object(forKey: "showsMenuBarItem") as? Bool ?? true
        showsPanel = defaults.object(forKey: "showsPanel") as? Bool ?? true
        if let xy = defaults.array(forKey: "panelAnchor") as? [Double], xy.count == 2 {
            panelAnchor = NSPoint(x: xy[0], y: xy[1])
        } else {
            panelAnchor = nil
        }
        panelAnchorsTop = defaults.object(forKey: "panelAnchorsTop") as? Bool ?? true
        defaults.removeObject(forKey: "panelOrigin")  // eski, hatalı konum kaydı
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
    }

    /// Kullanıcının yazdığı adresi doğrular: şema zorunlu, sondaki "/" atılır.
    static func normalizedURL(_ address: String) -> URL? {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), let scheme = url.scheme,
              ["http", "https"].contains(scheme), url.host() != nil else { return nil }
        return url
    }

    var serverURL: URL { Self.normalizedURL(serverAddress) ?? URL(string: Self.defaultServer)! }
}
