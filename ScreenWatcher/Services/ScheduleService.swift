import Foundation
import os.log

// MARK: - 스케줄 서비스 (타이머 + 조건 판단)

@MainActor
final class ScheduleService: ObservableObject {

    static let shared = ScheduleService()
    private init() {}

    private let logger = Logger(subsystem: "com.screenwatcher.app", category: "Schedule")
    private var timer: Timer?

    // MARK: - 타이머 시작

    func start(coordinator: AppCoordinator) {
        stop()
        let intervalSeconds = TimeInterval(AppSettings.shared.effectiveIntervalMinutes * 60)
        logger.info("스케줄 시작: \(AppSettings.shared.effectiveIntervalMinutes)분 간격")

        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak coordinator] _ in
            Task { @MainActor in
                await coordinator?.triggerCapture()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("스케줄 중지")
    }

    func restart(coordinator: AppCoordinator) {
        start(coordinator: coordinator)
    }

    // MARK: - 조건 판단

    func shouldCapture(now: Date = Date()) -> SkipReason? {
        let settings = AppSettings.shared
        guard settings.isEnabled else { return .disabled }
        guard settings.isWithinOperatingHours(now: now) else { return .outsideTimeRange }
        guard settings.isActiveDay(now: now) else { return .inactiveDay }
        return nil
    }
}
