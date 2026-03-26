import SwiftUI

@main
struct ScreenWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 메뉴바 앱이므로 Settings Scene만 사용 (창은 AppDelegate에서 직접 관리)
        Settings {
            SettingsView()
        }
    }
}
