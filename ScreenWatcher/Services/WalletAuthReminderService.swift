import Foundation
import os.log

// MARK: - Variational 재인증 알림 서비스

actor WalletAuthReminderService {

    static let shared = WalletAuthReminderService()
    private init() {}

    private let logger = Logger(subsystem: "com.screenwatcher.app", category: "WalletReminder")

    // MARK: - 단계 정의

    enum ReminderStage {
        /// 아직 알림 불필요 (6일 미만)
        case safe
        /// 1단계: 6일 ~ 6일12h — 12시간 간격
        case stage1(elapsed: TimeInterval)
        /// 2단계: 6일12h ~ 6일21h — 3시간 간격
        case stage2(elapsed: TimeInterval)
        /// 3단계: 6일21h ~ 7일 — 1시간 간격
        case stage3(elapsed: TimeInterval)
        /// 4단계: 7일 초과 — 30분 간격
        case expired(elapsed: TimeInterval)

        var notifyInterval: TimeInterval {
            switch self {
            case .safe:    return .infinity
            case .stage1:  return 12 * 3600
            case .stage2:  return 3 * 3600
            case .stage3:  return 1 * 3600
            case .expired: return 30 * 60
            }
        }

        var message: String {
            switch self {
            case .safe:
                return ""
            case .stage1(let elapsed):
                let remaining = 7 * 86400 - elapsed
                let hours = Int(remaining / 3600)
                return "⚠️ [Variational 재인증] \(elapsedDescription(elapsed)) 경과 — 약 \(hours)시간 후 만료됩니다. 재인증을 준비하세요."
            case .stage2(let elapsed):
                let remaining = 7 * 86400 - elapsed
                let hours = Int(remaining / 3600)
                return "⚠️⚠️ [Variational 재인증] \(elapsedDescription(elapsed)) 경과 — \(hours)시간 후 만료됩니다. 지금 재인증하세요!"
            case .stage3(let elapsed):
                let remaining = 7 * 86400 - elapsed
                let minutes = Int(remaining / 60)
                return "🚨 [Variational 재인증 긴급] \(elapsedDescription(elapsed)) 경과 — \(minutes)분 후 만료됩니다. 즉시 재인증하세요!"
            case .expired(let elapsed):
                let overMinutes = Int((elapsed - 7 * 86400) / 60)
                return "🚨🚨 [Variational 재인증 만료 초과] 만료 후 \(overMinutes)분 경과 — 봇 오류 발생 가능! 즉시 재인증 필수!"
            }
        }

        var isActive: Bool {
            if case .safe = self { return false }
            return true
        }
    }

    // MARK: - 상태 계산

    func currentStage(now: Date = Date()) -> ReminderStage {
        guard let lastAuth = lastAuthDate else { return .safe }
        let elapsed = now.timeIntervalSince(lastAuth)

        let day6    = 6 * 86400.0
        let day6h12 = (6 * 24 + 12) * 3600.0
        let day6h21 = (6 * 24 + 21) * 3600.0
        let day7    = 7 * 86400.0

        switch elapsed {
        case ..<day6:    return .safe
        case day6..<day6h12: return .stage1(elapsed: elapsed)
        case day6h12..<day6h21: return .stage2(elapsed: elapsed)
        case day6h21..<day7:  return .stage3(elapsed: elapsed)
        default:         return .expired(elapsed: elapsed)
        }
    }

    // MARK: - 알림 전송 판단

    func checkAndNotify(now: Date = Date()) async {
        let stage = currentStage(now: now)
        guard stage.isActive else { return }

        let interval = stage.notifyInterval
        if let lastNotified = lastNotifiedDate,
           now.timeIntervalSince(lastNotified) < interval {
            return
        }

        let message = stage.message
        logger.info("Variational 재인증 알림 전송: \(message)")

        do {
            let silent = !AppSettings.shared.variationalNotificationSound
            try await TelegramService.shared.sendMessage(text: message, silent: silent)
            lastNotifiedDate = now
        } catch {
            logger.error("알림 전송 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 인증 완료 처리

    func markAuthenticated(at date: Date = Date()) {
        lastAuthDate = date
        lastNotifiedDate = nil
        logger.info("Variational 인증 완료 기록: \(date)")
    }

    // MARK: - UserDefaults 영속화

    private let authDateKey    = "variationalLastAuthDate"
    private let notifiedDateKey = "variationalLastNotifiedDate"

    var lastAuthDate: Date? {
        get { UserDefaults.standard.object(forKey: authDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: authDateKey) }
    }

    var lastNotifiedDate: Date? {
        get { UserDefaults.standard.object(forKey: notifiedDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: notifiedDateKey) }
    }

    // MARK: - 상태 요약 (UI 표시용)

    func statusDescription(now: Date = Date()) -> String {
        guard let lastAuth = lastAuthDate else {
            return "인증 기록 없음"
        }
        let elapsed = now.timeIntervalSince(lastAuth)
        let days = Int(elapsed / 86400)
        let hours = Int((elapsed.truncatingRemainder(dividingBy: 86400)) / 3600)
        return "마지막 Variational 인증: \(days)일 \(hours)시간 전"
    }
}

// MARK: - Private Helper

private func elapsedDescription(_ elapsed: TimeInterval) -> String {
    let totalHours = Int(elapsed / 3600)
    let days = totalHours / 24
    let hours = totalHours % 24
    if hours == 0 { return "\(days)일" }
    return "\(days)일 \(hours)시간"
}
