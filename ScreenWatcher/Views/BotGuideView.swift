import SwiftUI

// MARK: - Telegram 봇 생성 가이드

struct BotGuideView: View {

    @Environment(\.dismiss) private var dismiss

    private let getUpdatesURL = "https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Telegram 봇 생성 가이드")
                .font(.title2.bold())

            Divider()

            stepView(
                number: "1",
                title: "BotFather로 봇 생성",
                content: """
                1. 텔레그램에서 @BotFather 검색 후 시작
                2. /newbot 입력
                3. 봇 이름 입력 (예: My Monitor Bot)
                4. 봇 사용자명 입력 (예: mymonitor_bot)
                5. 발급된 Bot Token 복사
                   (예: 123456789:ABCdefGHI...)
                """
            )

            stepView(
                number: "2",
                title: "Chat ID 확인",
                content: """
                1. 생성한 봇에게 아무 메시지 전송
                2. 아래 URL을 브라우저에서 열기
                   (YOUR_TOKEN을 실제 토큰으로 교체)
                3. 응답에서 "chat":{"id": 숫자} 찾기
                   → 그 숫자가 Chat ID
                """
            )

            HStack {
                Text(getUpdatesURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Spacer()

                Button("복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(getUpdatesURL, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)

            stepView(
                number: "3",
                title: "앱에 입력",
                content: "Bot Token과 Chat ID를 설정 화면에 입력한 후 [테스트] 버튼으로 연결을 확인하세요."
            )

            Spacer()

            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
    }

    private func stepView(number: String, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(content)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
