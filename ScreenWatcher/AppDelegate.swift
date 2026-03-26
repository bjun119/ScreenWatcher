import AppKit
import SwiftUI

// MARK: - 앱 델리게이트 (메뉴바 아이콘 + NSMenu 관리)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var coordinatorObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘 숨김 (Info.plist LSUIElement=true와 이중 보장)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        AppCoordinator.shared.setup()

        // AppCoordinator 상태 변경 시 메뉴 갱신
        coordinatorObserver = NotificationCenter.default.addObserver(
            forName: .init("com.screenwatcher.updateMenu"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMenu()
            }
        }

        // @Published 변경 감지
        Task { @MainActor in
            for await _ in AppCoordinator.shared.$menuBarIconNeedsUpdate.values {
                updateMenu()
            }
        }
    }

    // MARK: - StatusItem 초기화

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenu()
    }

    // MARK: - 메뉴 갱신

    @MainActor
    func updateMenu() {
        guard let button = statusItem?.button else { return }
        let coordinator = AppCoordinator.shared

        // 아이콘 설정
        let imageName: String
        if coordinator.isSending {
            imageName = "arrow.up.circle.fill"
        } else if coordinator.isEnabled {
            imageName = "camera.fill"
        } else {
            imageName = "camera"
        }
        button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "ScreenWatcher")
        button.image?.isTemplate = true

        // 메뉴 구성
        let menu = NSMenu()

        // 상태 표시 (비활성 항목)
        let statusItem = NSMenuItem(title: coordinator.statusSummary, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // 활성화
        let enableItem = NSMenuItem(title: "활성화", action: #selector(enableCapture), keyEquivalent: "e")
        enableItem.target = self
        enableItem.state = coordinator.isEnabled ? .on : .off
        menu.addItem(enableItem)

        // 비활성화
        let disableItem = NSMenuItem(title: "비활성화", action: #selector(disableCapture), keyEquivalent: "d")
        disableItem.target = self
        disableItem.state = coordinator.isEnabled ? .off : .on
        menu.addItem(disableItem)

        // 즉시 전송
        let sendNowItem = NSMenuItem(
            title: "지금 즉시 전송",
            action: #selector(sendNow),
            keyEquivalent: "s"
        )
        sendNowItem.target = self
        sendNowItem.isEnabled = coordinator.isEnabled && !coordinator.isSending
        menu.addItem(sendNowItem)

        menu.addItem(.separator())

        // 설정
        let settingsItem = NSMenuItem(
            title: "설정...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // 종료
        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func enableCapture() {
        AppCoordinator.shared.isEnabled = true
    }

    @objc private func disableCapture() {
        AppCoordinator.shared.isEnabled = false
    }

    @objc private func sendNow() {
        Task { @MainActor in
            AppCoordinator.shared.sendNow()
        }
    }

    @objc private func openSettings() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenWatcher 설정"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
