import Foundation
import UserNotifications

struct SwitchNotification: Equatable {
    var title: String
    var body: String
}

protocol Notifying {
    func requestAuthorization() async -> Bool
    func deliver(_ notification: SwitchNotification) async
}

final class Notifier: Notifying {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func deliver(_ notification: SwitchNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
