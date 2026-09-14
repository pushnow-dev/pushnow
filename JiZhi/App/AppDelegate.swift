import UIKit
import UserNotifications

 final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let payload = response.notification.request.content.userInfo["secure_v2"] as? [String: Any],
           let id = payload["message_id"] as? String, let user = payload["user_id"] as? String {
            Task { @MainActor in
                SecureNotificationRoute.pending = (id, user)
                NotificationCenter.default.post(name: .openSecureMessage, object: nil)
            }
        }
        completionHandler()
    }
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationCenter.default.post(name: .didReceiveAPNsToken, object: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(name: .didFailToRegisterForRemoteNotifications, object: error)
    }
}

extension Notification.Name {
    static let didReceiveAPNsToken = Notification.Name("PushnowDidReceiveAPNsToken")
    static let didFailToRegisterForRemoteNotifications = Notification.Name("PushnowDidFailToRegisterForRemoteNotifications")
    static let openSecureMessage = Notification.Name("PushnowOpenSecureMessage")
}

@MainActor enum SecureNotificationRoute {
    static var pending: (id: String, user: String)?
}
