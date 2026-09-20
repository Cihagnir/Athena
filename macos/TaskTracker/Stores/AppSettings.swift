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
