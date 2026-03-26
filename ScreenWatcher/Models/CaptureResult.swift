import Foundation

// MARK: - 요일 열거형

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday:    return "일"
        case .monday:    return "월"
        case .tuesday:   return "화"
        case .wednesday: return "수"
        case .thursday:  return "목"
        case .friday:    return "금"
        case .saturday:  return "토"
        }
    }

    static var weekdays: Set<Weekday> { [.monday, .tuesday, .wednesday, .thursday, .friday] }
    static var weekends: Set<Weekday> { [.saturday, .sunday] }
    static var all: Set<Weekday> { Set(allCases) }
}

// MARK: - 전송 결과

enum SendResult {
    case success(sentAt: Date)
    case failure(error: SendError, at: Date)
    case skipped(reason: SkipReason, at: Date)
}

// MARK: - 에러 타입

enum SendError: Error, LocalizedError {
    case capturePermissionDenied
    case captureFailure(underlying: Error?)
    case networkError(statusCode: Int)
    case telegramApiError(description: String)
    case imageTooLarge
    case tokenNotConfigured
    case chatIdNotConfigured

    var errorDescription: String? {
        switch self {
        case .capturePermissionDenied:
            return "화면 녹화 권한이 없습니다. 시스템 설정에서 허용해 주세요."
        case .captureFailure:
            return "화면 캡쳐에 실패했습니다."
        case .networkError(let code):
            return "네트워크 오류 (HTTP \(code))"
        case .telegramApiError(let desc):
            return "Telegram 오류: \(desc)"
        case .imageTooLarge:
            return "이미지 크기가 너무 큽니다."
        case .tokenNotConfigured:
            return "Bot Token이 설정되지 않았습니다."
        case .chatIdNotConfigured:
            return "Chat ID가 설정되지 않았습니다."
        }
    }
}

// MARK: - 스킵 이유

enum SkipReason {
    case disabled
    case outsideTimeRange
    case inactiveDay

    var description: String {
        switch self {
        case .disabled:         return "비활성화 상태"
        case .outsideTimeRange: return "운영 시간 외"
        case .inactiveDay:      return "비활성 요일"
        }
    }
}
