import SwiftUI

// MARK: - 설정 메인 화면

struct SettingsView: View {

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var coordinator = AppCoordinator.shared

    @State private var tokenInput: String = ""
    @State private var showToken: Bool = false
    @State private var showBotGuide: Bool = false
    @State private var showSavedConfirmation: Bool = false
    @State private var showAuthConfirmation: Bool = false
    @State private var now: Date = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    telegramSection
                    Divider()
                    variationalSection
                    Divider()
                    intervalSection
                    Divider()
                    filterSection
                    Divider()
                    systemSection
                }
                .padding(20)
            }

            Divider()

            // 하단 버튼
            HStack {
                Button("봇 만들기 가이드") {
                    showBotGuide = true
                }
                .buttonStyle(.link)

                Spacer()

                if showSavedConfirmation {
                    Text("저장됨")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Button("저장") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tokenInput.isEmpty && KeychainHelper.shared.readToken() == nil)

                Button("닫기") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .onAppear {
            tokenInput = KeychainHelper.shared.readToken() ?? ""
        }
        .onReceive(timer) { date in
            now = date
        }
        .sheet(isPresented: $showBotGuide) {
            BotGuideView()
        }
    }

    // MARK: - Telegram 섹션

    private var telegramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Telegram 설정", systemImage: "paperplane.fill")
                .font(.headline)

            // Bot Token
            HStack {
                Text("Bot Token")
                    .frame(width: 80, alignment: .leading)

                if showToken {
                    TextField("123456789:ABCdef...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Bot Token 입력", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                }

                Button(showToken ? "숨기기" : "보기") {
                    showToken.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("테스트") {
                    Task {
                        await coordinator.testConnection(token: tokenInput)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(tokenInput.isEmpty || coordinator.isTestingConnection)
            }

            // 테스트 결과
            if coordinator.isTestingConnection {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("연결 확인 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let msg = coordinator.connectionTestMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(msg.hasPrefix("연결 성공") ? .green : .red)
            }

            // Chat ID
            HStack {
                Text("Chat ID")
                    .frame(width: 80, alignment: .leading)
                TextField("예: 123456789 또는 -100...", text: $settings.chatId)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Variational 재인증 섹션

    private var variationalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Variational 재인증 관리", systemImage: "key.fill")
                .font(.headline)

            Text(walletStatusText)
                .font(.subheadline)
                .foregroundColor(walletStatusColor)

            Button("Variational 인증 완료") {
                showAuthConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .alert("Variational 인증 완료", isPresented: $showAuthConfirmation) {
                Button("확인", role: .destructive) {
                    coordinator.markVariationalAuthenticated()
                    now = Date()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("Variational 지갑 인증을 실제로 완료하셨나요?\n인증 타이머가 오늘 날짜로 초기화됩니다.")
            }

            Toggle("알림음 켜기 (무음 해제)", isOn: $settings.variationalNotificationSound)

            Text("마지막 인증으로부터 6일 경과 시 텔레그램 알림을 전송합니다.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var walletStatusColor: Color {
        // actor isolation 우회: 동기적으로 UserDefaults에서 직접 읽기
        guard let lastAuth = UserDefaults.standard.object(forKey: "variationalLastAuthDate") as? Date else {
            return .secondary
        }
        let elapsed = now.timeIntervalSince(lastAuth)
        if elapsed >= 7 * 86400 { return .red }
        if elapsed >= 6 * 86400 { return .orange }
        return .green
    }

    private var walletStatusText: String {
        guard let lastAuth = UserDefaults.standard.object(forKey: "variationalLastAuthDate") as? Date else {
            return "인증 기록 없음 — 인증 완료 버튼을 눌러 시작하세요."
        }
        let elapsed = now.timeIntervalSince(lastAuth)
        let days = Int(elapsed / 86400)
        let hours = Int((elapsed.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))

        if elapsed >= 7 * 86400 {
            return "⚠️ 만료 초과: \(days)일 \(hours)시간 \(minutes)분 \(seconds)초 경과"
        } else if elapsed >= 6 * 86400 {
            let remainHours = Int((7 * 86400 - elapsed) / 3600)
            return "경고: \(days)일 \(hours)시간 \(minutes)분 \(seconds)초 경과 (약 \(remainHours)시간 후 만료)"
        } else {
            let remainDays = 7 - days
            return "정상: \(days)일 \(hours)시간 \(minutes)분 \(seconds)초 경과 (\(remainDays)일 후 만료)"
        }
    }

    // MARK: - 캡쳐 주기 섹션

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("캡쳐 주기", systemImage: "clock.fill")
                .font(.headline)

            let presets = [1, 5, 10, 30, 60, 0]
            let presetLabels = ["1분", "5분", "10분", "30분", "1시간", "직접 입력"]

            HStack(spacing: 8) {
                ForEach(Array(zip(presets, presetLabels)), id: \.0) { preset, label in
                    Toggle(label, isOn: Binding(
                        get: { settings.captureIntervalPreset == preset },
                        set: { if $0 { settings.captureIntervalPreset = preset } }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.small)
                }
            }

            if settings.captureIntervalPreset == 0 {
                HStack {
                    Text("직접 입력:")
                    TextField("분", value: $settings.customIntervalMinutes, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("분 (최소 1분)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - 필터 섹션

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("운영 조건 필터", systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.headline)

            // 시간대 필터
            VStack(alignment: .leading, spacing: 8) {
                Toggle("시간대 제한 사용", isOn: $settings.useTimeFilter)

                if settings.useTimeFilter {
                    HStack {
                        Text("운영 시간:")
                            .foregroundColor(.secondary)

                        Picker("시작 시", selection: $settings.timeFilterStartHour) {
                            ForEach(0..<24, id: \.self) { Text("\($0)시") }
                        }
                        .frame(width: 70)

                        Picker("시작 분", selection: $settings.timeFilterStartMinute) {
                            ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { Text("\($0)분") }
                        }
                        .frame(width: 60)

                        Text("~")

                        Picker("종료 시", selection: $settings.timeFilterEndHour) {
                            ForEach(0..<24, id: \.self) { Text("\($0)시") }
                        }
                        .frame(width: 70)

                        Picker("종료 분", selection: $settings.timeFilterEndMinute) {
                            ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { Text("\($0)분") }
                        }
                        .frame(width: 60)
                    }
                }
            }

            // 요일 필터
            VStack(alignment: .leading, spacing: 8) {
                Toggle("요일 제한 사용", isOn: $settings.useDayFilter)

                if settings.useDayFilter {
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases) { day in
                            let isActive = settings.activeDays.contains(day)
                            Button(day.displayName) {
                                var days = settings.activeDays
                                if isActive { days.remove(day) } else { days.insert(day) }
                                settings.activeDays = days
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(isActive ? .white : .primary)
                            .background(isActive ? Color.accentColor : Color.clear)
                            .cornerRadius(4)
                        }

                        Spacer()

                        Button("평일") { settings.activeDays = Weekday.weekdays }
                            .buttonStyle(.link).controlSize(.small)
                        Button("주말") { settings.activeDays = Weekday.weekends }
                            .buttonStyle(.link).controlSize(.small)
                        Button("전체") { settings.activeDays = Weekday.all }
                            .buttonStyle(.link).controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - 시스템 섹션

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("시스템", systemImage: "gear")
                .font(.headline)

            Toggle("로그인 시 자동 시작", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { coordinator.setLaunchAtLogin($0) }
            ))

            Toggle("캡쳐 전 모니터 잠자기 해제", isOn: $settings.wakeDisplayBeforeCapture)

            Toggle("전송 후 모니터 잠자기 복원", isOn: $settings.sleepDisplayAfterCapture)
                .disabled(!settings.wakeDisplayBeforeCapture)
        }
    }

    // MARK: - 저장

    private func saveSettings() {
        if !tokenInput.isEmpty {
            _ = KeychainHelper.shared.saveToken(tokenInput)
        }
        coordinator.restartSchedule()

        withAnimation {
            showSavedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSavedConfirmation = false }
        }
    }
}
