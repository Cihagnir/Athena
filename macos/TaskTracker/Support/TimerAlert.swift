import AppKit
import UserNotifications

/// Zamanlayıcı dolunca: kısa ses + macOS bildirimi (panel gizliyken de haber verir).
/// Akışı kesen bir soru yoktur.
enum TimerAlert {
    /// İlk zamanlayıcı başlatıldığında bildirim izni istenir.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func fire(taskTitle: String) {
        NSSound(named: "Glass")?.play()
        let content = UNMutableNotificationContent()
        content.title = "Süre doldu"
        content.body = taskTitle
        let request = UNNotificationRequest(identifier: "timer-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
