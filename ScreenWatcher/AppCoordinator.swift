import Foundation
import SwiftUI
import ServiceManagement
import os.log

// MARK: - 앱 전체 오케스트레이터

@MainActor
final class AppCoordinator: ObservableObject {

    static let shared = AppCoordinator()
    private init() {}

    private let logger = Logger(subsystem: "com.screenwatcher.app", category: "Coordinator")

    // MARK: - 발행 속성 (메뉴바 UI 업데이트용)

    @Published var isEnabled: Bool = false {
        didSet {
            AppSettings.shared.isEnabled = isEnabled
            isEnabled ? startSchedule() : stopSchedule()
            updateMenuBarIcon()
        }
    }

    @Published var lastResult: SendResult? = nil
    @Published var isSending: Bool = false
    @Published var isTestingConnection: Bool = false
    @Published var connectionTestMessage: String? = nil

    // MARK: - 초기화

    func setup() {
        isEnabled = AppSettings.shared.isEnabled
        if isEnabled { startSchedule() }
    }

    // MARK: - 스케줄 제어

    private func startSchedule() {
        ScheduleService.shared.start(coordinator: self)
    }

    private func stopSchedule() {
        ScheduleService.shared.stop()
    }

    func restartSchedule() {
        guard isEnabled else { return }
        ScheduleService.shared.restart(coordinator: self)
    }

    // MARK: - 캡쳐 + 전송 (스케줄러에서 호출)

    func triggerCapture() async {
        if let skipReason = ScheduleService.shared.shouldCapture() {
            logger.debug("캡쳐 스킵: \(skipReason.description)")
            lastResult = .skipped(reason: skipReason, at: Date())
            return
        }
        await performCaptureSend()
    }

    // MARK: - 즉시 전송

    func sendNow() {
        Task {
            await performCaptureSend()
        }
    }

    // MARK: - 캡쳐 + 전송 핵심 로직

    private func performCaptureSend() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        updateMenuBarIcon()

        do {
            let imageData = try await CaptureService.shared.captureMainDisplay()
            try await TelegramService.shared.sendPhoto(imageData)
            lastResult = .success(sentAt: Date())
            logger.info("전송 성공")
        } catch let error as SendError {
            lastResult = .failure(error: error, at: Date())
            logger.error("전송 실패: \(error.errorDescription ?? "unknown")")

            if case .capturePermissionDenied = error {
                CaptureService.shared.openScreenCapturePreferences()
            }
        } catch {
            lastResult = .failure(error: .captureFailure(underlying: error), at: Date())
        }

        updateMenuBarIcon()
    }

    // MARK: - 연결 테스트

    func testConnection(token: String) async {
        isTestingConnection = true
        connectionTestMessage = nil
        defer { isTestingConnection = false }

        do {
            let botName = try await TelegramService.shared.testConnection(token: token)
            connectionTestMessage = "연결 성공: \(botName)"
            _ = KeychainHelper.shared.saveToken(token)
        } catch let error as SendError {
            connectionTestMessage = "실패: \(error.errorDescription ?? "오류")"
        } catch {
            connectionTestMessage = "실패: \(error.localizedDescription)"
        }
    }

    // MARK: - LaunchAtLogin

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            AppSettings.shared.launchAtLogin = enabled
        } catch {
            logger.error("LaunchAtLogin 설정 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 상태 문자열 (메뉴 표시용)

    var statusSummary: String {
        if isSending { return "전송 중..." }
        switch lastResult {
        case .success(let date):
            return "마지막 전송: \(timeString(date))"
        case .failure(let error, let date):
            return "실패 (\(timeString(date))): \(error.errorDescription ?? "")"
        case .skipped(let reason, _):
            return "스킵: \(reason.description)"
        case nil:
            return isEnabled ? "대기 중" : "비활성화"
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    // MARK: - 메뉴바 아이콘 업데이트 (AppDelegate에서 관찰)

    @Published var menuBarIconNeedsUpdate: Bool = false

    private func updateMenuBarIcon() {
        menuBarIconNeedsUpdate.toggle()
    }
}
