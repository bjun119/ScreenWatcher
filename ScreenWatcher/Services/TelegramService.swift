import Foundation
import os.log

// MARK: - Telegram Bot API 서비스

actor TelegramService {

    static let shared = TelegramService()
    private init() {}

    private let logger = Logger(subsystem: "com.screenwatcher.app", category: "Telegram")
    private let baseURL = "https://api.telegram.org"

    // MARK: - 사진 전송

    func sendPhoto(_ imageData: Data) async throws {
        let settings = AppSettings.shared
        guard let token = KeychainHelper.shared.readToken(), !token.isEmpty else {
            throw SendError.tokenNotConfigured
        }
        guard !settings.chatId.isEmpty else {
            throw SendError.chatIdNotConfigured
        }

        let urlString = "\(baseURL)/bot\(token)/sendPhoto"
        guard let url = URL(string: urlString) else {
            throw SendError.telegramApiError(description: "잘못된 URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        let boundary = "ScreenWatcher-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let caption = formatCaption()
        request.httpBody = buildMultipartBody(
            imageData: imageData,
            chatId: settings.chatId,
            caption: caption,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SendError.networkError(statusCode: 0)
        }

        guard httpResponse.statusCode == 200 else {
            let desc = parseErrorDescription(from: data) ?? "HTTP \(httpResponse.statusCode)"
            logger.error("Telegram sendPhoto failed: \(desc)")
            if httpResponse.statusCode == 429 {
                throw SendError.networkError(statusCode: 429)
            } else {
                throw SendError.telegramApiError(description: desc)
            }
        }

        logger.info("Telegram sendPhoto success")
    }

    // MARK: - 연결 테스트 (Bot 이름 반환)

    func testConnection(token: String) async throws -> String {
        let urlString = "\(baseURL)/bot\(token)/getMe"
        guard let url = URL(string: urlString) else {
            throw SendError.telegramApiError(description: "잘못된 URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SendError.telegramApiError(description: "Bot Token이 유효하지 않습니다")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? [String: Any],
           let username = result["username"] as? String {
            return "@\(username)"
        }
        return "연결 성공"
    }

    // MARK: - Private Helpers

    private func buildMultipartBody(
        imageData: Data,
        chatId: String,
        caption: String,
        boundary: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        func appendField(_ name: String, value: String) {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
            body.append("\(value)\(crlf)")
        }

        appendField("chat_id", value: chatId)
        appendField("caption", value: caption)
        appendField("disable_notification", value: "true")

        // 이미지 파트
        body.append("--\(boundary)\(crlf)")
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"screenshot.jpg\"\(crlf)")
        body.append("Content-Type: image/jpeg\(crlf)\(crlf)")
        body.append(imageData)
        body.append("\(crlf)--\(boundary)--\(crlf)")

        return body
    }

    private func formatCaption() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    private func parseErrorDescription(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let description = json["description"] as? String
        else { return nil }
        return description
    }
}

// MARK: - Data 편의 확장

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
