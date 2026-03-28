import Foundation
import SwiftUI

// MARK: - 앱 설정 (UserDefaults 영속화)

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: Telegram

    @AppStorage("chatId")
    var chatId: String = ""

    // Bot Token은 Keychain에 저장 (KeychainHelper 통해 접근)

    // MARK: 캡쳐 주기

    /// 0 = 직접 입력(customIntervalMinutes 사용)
    @AppStorage("captureIntervalPreset")
    var captureIntervalPreset: Int = 5

    @AppStorage("customIntervalMinutes")
    var customIntervalMinutes: Int = 15

    var effectiveIntervalMinutes: Int {
        captureIntervalPreset == 0 ? max(1, customIntervalMinutes) : captureIntervalPreset
    }

    // MARK: 시간대 필터

    @AppStorage("useTimeFilter")
    var useTimeFilter: Bool = false

    @AppStorage("timeFilterStartHour")
    var timeFilterStartHour: Int = 9

    @AppStorage("timeFilterStartMinute")
    var timeFilterStartMinute: Int = 0

    @AppStorage("timeFilterEndHour")
    var timeFilterEndHour: Int = 18

    @AppStorage("timeFilterEndMinute")
    var timeFilterEndMinute: Int = 0

    // MARK: 요일 필터

    @AppStorage("useDayFilter")
    var useDayFilter: Bool = false

    /// JSON 인코딩된 [Int] (Weekday.rawValue 배열)
    @AppStorage("activeDaysRaw")
    private var activeDaysRaw: String = ""

    var activeDays: Set<Weekday> {
        get {
            guard !activeDaysRaw.isEmpty,
                  let data = activeDaysRaw.data(using: .utf8),
                  let ints = try? JSONDecoder().decode([Int].self, from: data)
            else { return Weekday.weekdays }
            return Set(ints.compactMap { Weekday(rawValue: $0) })
        }
        set {
            let ints = newValue.map { $0.rawValue }.sorted()
            if let data = try? JSONEncoder().encode(ints),
               let str = String(data: data, encoding: .utf8) {
                activeDaysRaw = str
            }
        }
    }

    // MARK: Variational 재인증

    /// Variational 마지막 인증 일시 (WalletAuthReminderService가 직접 UserDefaults에 저장)
    var lastVariationalAuthDate: Date? {
        get { UserDefaults.standard.object(forKey: "variationalLastAuthDate") as? Date }
    }

    /// true = 알림음 켜짐 (disable_notification: false)
    @AppStorage("variationalNotificationSound")
    var variationalNotificationSound: Bool = true

    // MARK: 시스템

    @AppStorage("isEnabled")
    var isEnabled: Bool = false

    @AppStorage("launchAtLogin")
    var launchAtLogin: Bool = false

    @AppStorage("wakeDisplayBeforeCapture")
    var wakeDisplayBeforeCapture: Bool = true

    @AppStorage("sleepDisplayAfterCapture")
    var sleepDisplayAfterCapture: Bool = true

    // MARK: 검증

    var isTelegramConfigured: Bool {
        let token = KeychainHelper.shared.readToken()
        return !(token?.isEmpty ?? true) && !chatId.isEmpty
    }

    // MARK: 시간 조건 판단

    func isWithinOperatingHours(now: Date = Date()) -> Bool {
        guard useTimeFilter else { return true }

        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        guard let hour = comps.hour, let minute = comps.minute else { return true }

        let nowMinutes = hour * 60 + minute
        let startMinutes = timeFilterStartHour * 60 + timeFilterStartMinute
        let endMinutes = timeFilterEndHour * 60 + timeFilterEndMinute

        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            // 자정 넘기는 경우 (예: 22:00 ~ 06:00)
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }

    func isActiveDay(now: Date = Date()) -> Bool {
        guard useDayFilter else { return true }
        let cal = Calendar.current
        let weekdayInt = cal.component(.weekday, from: now)
        guard let weekday = Weekday(rawValue: weekdayInt) else { return true }
        return activeDays.contains(weekday)
    }
}
