import AppKit
import ServiceManagement

/// Oturum açılışında otomatik başlama — macOS'in yerleşik login item API'si.
/// Ayrı bir servis/daemon yok; kayıt, uygulama paketinin o anki konumuna bağlanır
/// (paket taşınırsa Ayarlar'dan kapatıp yeniden açmak gerekir).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Sistem Ayarları → Genel → Oturum Açma Öğeleri'nde kullanıcı onayı bekliyor.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Uygulamayı kullanıcı değil, oturum açılışı mı başlattı? Öyleyse pencere açılmaz.
    static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == AEEventID(keyAELaunchedAsLogInItem)
    }
}
