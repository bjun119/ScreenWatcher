import Foundation
import ScreenCaptureKit
import AppKit
import os.log

// MARK: - 화면 캡쳐 서비스 (ScreenCaptureKit)

actor CaptureService {

    static let shared = CaptureService()
    private init() {}

    private let logger = Logger(subsystem: "com.screenwatcher.app", category: "Capture")
    private let maxImageSizeBytes = 2_000_000  // 2MB
    private var didWakeDisplay = false

    // MARK: - 메인 디스플레이 캡쳐

    func captureMainDisplay() async throws -> Data {
        // 권한 확인
        guard await hasScreenCapturePermission() else {
            throw SendError.capturePermissionDenied
        }

        // 디스플레이 잠자기 상태 확인 후 깨우기 (설정에서 활성화된 경우만)
        if await AppSettings.shared.wakeDisplayBeforeCapture {
            await wakeDisplayIfNeeded()
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            logger.error("SCShareableContent 로드 실패: \(error.localizedDescription)")
            throw SendError.captureFailure(underlying: error)
        }

        guard let display = content.displays.first else {
            throw SendError.captureFailure(underlying: nil)
        }

        let config = SCStreamConfiguration()
        let maxDimension = 3840
        let scale = min(1.0, Double(maxDimension) / Double(max(display.width, display.height)))
        config.width = Int(Double(display.width) * scale)
        config.height = Int(Double(display.height) * scale)
        config.scalesToFit = true
        config.showsCursor = false

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            logger.error("SCScreenshotManager 캡쳐 실패: \(error.localizedDescription)")
            throw SendError.captureFailure(underlying: error)
        }

        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        return try compressToJPEG(nsImage)
    }

    // MARK: - JPEG 압축 (최대 크기 보장)

    private func compressToJPEG(_ image: NSImage) throws -> Data {
        let qualities: [CGFloat] = [0.8, 0.6, 0.4, 0.2]

        for quality in qualities {
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: quality]
                  )
            else { continue }

            if jpegData.count <= maxImageSizeBytes {
                logger.debug("JPEG 압축 완료: \(jpegData.count) bytes (quality=\(quality))")
                return jpegData
            }
        }

        throw SendError.imageTooLarge
    }

    // MARK: - 디스플레이 잠자기 해제

    private func wakeDisplayIfNeeded() async {
        let displayID = CGMainDisplayID()
        guard CGDisplayIsAsleep(displayID) != 0 else { return }

        logger.info("디스플레이 잠자기 감지 - 깨우기 시도")

        // caffeinate -u: 디스플레이가 꺼져 있으면 켠다 (man caffeinate 참조)
        // IOPMAssertionDeclareUserActivity는 잠자기 방지 API이므로 사용 불가
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-u", "-t", "10"]
        try? task.run()

        didWakeDisplay = true
        logger.info("caffeinate -u 실행 - 켜질 때까지 대기 (최대 15초)")

        let maxPolls = 50  // 0.3s × 50 = 최대 15초
        for _ in 0..<maxPolls {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if CGDisplayIsAsleep(CGMainDisplayID()) == 0 {
                logger.info("디스플레이 활성화 확인")
                break
            }
        }
    }

    // MARK: - 디스플레이 잠자기 복원

    func sleepDisplayIfWoken() {
        guard didWakeDisplay else { return }
        didWakeDisplay = false

        logger.info("디스플레이 잠자기 복원")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    // MARK: - 권한 확인

    func hasScreenCapturePermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 시스템 설정 > 화면 녹화 열기

    @MainActor
    func openScreenCapturePreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
