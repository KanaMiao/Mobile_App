import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // iOS < 13 sẽ dùng thuộc tính window, iOS 13+ thường quản lý qua SceneDelegate
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Tuỳ chọn, có thể để trống
        return true
    }

    // MARK: UISceneSession Lifecycle (iOS 13+)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}
}
