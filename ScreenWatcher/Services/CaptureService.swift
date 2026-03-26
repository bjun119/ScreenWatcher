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

    // MARK: - 메인 디스플레이 캡쳐

    func captureMainDisplay() async throws -> Data {
        // 권한 확인
        guard await hasScreenCapturePermission() else {
            throw SendError.capturePermissionDenied
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
