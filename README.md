# ScreenWatcher

macOS 메뉴바 앱 — 주기적으로 화면을 캡쳐해 Telegram으로 자동 전송합니다.

## 주요 기능

- **자동 캡쳐**: 설정된 주기마다 화면 캡쳐
- **Telegram 전송**: 캡쳐한 이미지 자동으로 Telegram으로 전송
- **시간대 필터**: 특정 시간대에만 캡쳐 실행
- **요일 필터**: 특정 요일에만 캡쳐 실행
- **디스플레이 제어**: 캡쳐 전 모니터 자동 깨우기 / 전송 후 자동 복원 (v0.2.0+)
- **로그인 시 자동 시작**: LaunchAtLogin 지원
- **메뉴바 통합**: 빠른 접근 및 상태 확인

## 버전

- **최신**: v0.2.2 (2026-03-27)
  - 모니터 켜진 후 5초 안정화 대기 추가

- v0.2.1 (2026-03-27)
  - 모니터 잠자기 해제 미작동 버그 수정 (`caffeinate -u` 적용)

- v0.2.0 (2026-03-27)
  - 디스플레이 전력 관리 기능 추가
  - UI/UX 개선

- v0.1.0
  - 기본 캡쳐 및 전송 기능

## 요구사항

- **macOS**: 14.0 이상 (Sonoma 이상 권장)
- **칩**: Apple Silicon Mac (M1/M2/M3/M4)
- **Xcode**: 15.0 이상
- **빌드 도구**: xcodegen (`brew install xcodegen`)

## 빌드

```bash
# 1. 의존성 설치
brew install xcodegen

# 2. 빌드 & 패키징
cd /Users/bjun119/Documents/Claude/ScreenWatcher
chmod +x build.sh
./build.sh
```

빌드 완료 후 `ScreenWatcher-v0.2.2-arm64.zip` 파일이 생성됩니다.

## 설치

1. zip 파일 압축 해제
2. `ScreenWatcher.app`을 `/Applications` 폴더로 이동
3. 처음 실행 시 Gatekeeper에 의해 차단되면:
   ```bash
   xattr -cr /Applications/ScreenWatcher.app
   ```
4. 앱 실행 → 메뉴바에 카메라 아이콘 확인

## 설정

### 1단계: Telegram 봇 생성

1. 텔레그램에서 `@BotFather` 검색
2. `/newbot` → 봇 이름 입력 → **Bot Token** 발급
3. 봇에게 아무 메시지 전송
4. 브라우저에서 열기:
   ```
   https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates
   ```
5. 응답에서 `"chat":{"id": 숫자}` → 그 숫자가 **Chat ID**

### 2단계: 앱 설정

1. 메뉴바 아이콘 클릭 → 설정...
2. **Bot Token** 입력 후 [테스트] 버튼으로 연결 확인
3. **Chat ID** 입력
4. **캡쳐 주기** 설정 (1분, 5분, 10분, 30분, 1시간, 또는 직접 입력)
5. **운영 조건** 설정:
   - 시간대 제한: 특정 시간대에만 캡쳐
   - 요일 제한: 특정 요일에만 캡쳐
6. **시스템 옵션**:
   - 로그인 시 자동 시작
   - 캡쳐 전 모니터 잠자기 해제 (기본값: ON)
   - 전송 후 모니터 잠자기 복원 (기본값: ON)
7. [저장] 클릭

## 권한

최초 실행 시 다음 권한이 요청됩니다:

- **화면 녹화**: ScreenCaptureKit으로 화면 캡쳐
  - 시스템 설정 > 개인 정보 보호 및 보안 > 화면 녹화에서 허용

## 기술 스택

| 기술 | 용도 |
|------|------|
| Swift 5.9 | 메인 언어 |
| SwiftUI | UI 프레임워크 |
| ScreenCaptureKit | 화면 캡쳐 |
| caffeinate / pmset | 디스플레이 깨우기/복원 |
| Foundation | 시스템 통합 |

## 폴더 구조

```
ScreenWatcher/
├── ScreenWatcher/           # 메인 소스 코드
│   ├── ScreenWatcherApp.swift
│   ├── AppDelegate.swift
│   ├── AppCoordinator.swift
│   ├── Models/
│   │   ├── AppSettings.swift       # 설정 및 UserDefaults
│   │   ├── CaptureResult.swift
│   │   └── ...
│   ├── Services/
│   │   ├── CaptureService.swift    # ScreenCaptureKit + IOKit
│   │   ├── TelegramService.swift   # Telegram API
│   │   ├── ScheduleService.swift   # 스케줄링
│   │   ├── KeychainHelper.swift    # Token 저장
│   │   └── ...
│   └── Views/
│       ├── SettingsView.swift      # 설정 화면
│       ├── BotGuideView.swift      # Telegram 봇 생성 가이드
│       └── ...
├── README.md                # 이 파일
├── build.sh                 # 빌드 스크립트
└── docs/                    # 문서
    └── 04-report/
        ├── ScreenWatcher.report.md  # 세션 완료 보고서
        ├── changelog.md             # 변경 로그
        └── README.md                # 보고서 디렉토리 설명
```

## 설정 파일

### UserDefaults (로컬 저장)

| 키 | 기본값 | 설명 |
|----|--------|------|
| `chatId` | "" | Telegram Chat ID |
| `captureIntervalPreset` | 5 | 캡쳐 주기 (분) - 0=직접 입력 |
| `customIntervalMinutes` | 15 | 직접 입력 시 사용할 주기 (분) |
| `useTimeFilter` | false | 시간대 필터 사용 여부 |
| `timeFilterStartHour` | 9 | 시작 시간 (0~23) |
| `timeFilterEndHour` | 18 | 종료 시간 (0~23) |
| `useDayFilter` | false | 요일 필터 사용 여부 |
| `activeDaysRaw` | "" | 활성화된 요일 (JSON) |
| `isEnabled` | false | 앱 활성화 여부 |
| `launchAtLogin` | false | 로그인 시 자동 시작 |
| `wakeDisplayBeforeCapture` | true | 캡쳐 전 모니터 깨우기 |
| `sleepDisplayAfterCapture` | true | 전송 후 모니터 복원 |

### Keychain (보안 저장)

- **Bot Token**: Keychain의 "com.screenwatcher.telegram.token"에 저장
  - 민감한 정보이므로 Keychain으로 암호화 저장

## 로깅

앱은 `os.log` 시스템을 사용하여 진단 정보를 기록합니다.

### Console.app에서 확인

```
1. Console.app 열기
2. 왼쪽 "디바이스" → 현재 Mac 선택
3. 검색창에서 "screenwatcher" 검색
4. 로그 확인
```

### 주요 로그

| 범주 | 메시지 |
|------|--------|
| Capture | 화면 캡쳐 시작/완료/실패 |
| Coordinator | 캡쳐-전송 전체 흐름 |
| Schedule | 스케줄 실행/스킵 |
| Telegram | API 호출 결과 |

## 문제 해결

### Q: "화면 녹화 권한이 없습니다" 에러

**A**: 시스템 설정 확인
```
시스템 설정 > 개인 정보 보호 및 보안 > 화면 녹화 > ScreenWatcher 활성화
```

### Q: Telegram 연결 실패

**A**: Bot Token과 Chat ID 확인
1. Bot Token이 정확한지 확인
2. Chat ID가 숫자만 포함하는지 확인 (예: 123456789)
3. [테스트] 버튼으로 연결 재확인

### Q: 화면이 캡쳐되지 않음

**A**: 다음 설정 확인
1. 앱이 활성화되어 있는지 확인
2. 캡쳐 주기 설정 확인
3. 시간대 필터가 현재 시간을 포함하는지 확인
4. 요일 필터가 현재 요일을 포함하는지 확인

### Q: 모니터가 복원되지 않음

**A**:
1. "캡쳐 전 모니터 잠자기 해제" 옵션이 ON인지 확인
2. "전송 후 모니터 잠자기 복원" 옵션이 ON인지 확인
3. 직접 깨운 경우만 복원됩니다 (앱이 깨운 경우만 복원)

## 성능

| 작업 | 시간 |
|------|------|
| 화면 캡쳐 | 0.5~1초 |
| JPEG 압축 | 0.1~0.3초 |
| Telegram 전송 | 1~3초 (네트워크 의존) |
| 모니터 깨우기 + 안정화 | 0.3~20초 (caffeinate + 5초 대기) |
| 모니터 복원 | 즉시 |

## 보안

- **Bot Token**: Keychain에 암호화 저장
- **Chat ID**: UserDefaults에 평문 저장 (공개 가능한 정보)
- **캡쳐 이미지**: JPEG 압축 후 메모리에서 즉시 삭제
- **로그**: 민감한 정보(Token) 제외하고 기록

## 라이선스

MIT

## 개발자 정보

- **프로젝트**: ScreenWatcher macOS 메뉴바 앱
- **최종 업데이트**: 2026-03-27
- **보고서**: `/Users/bjun119/Documents/Claude/ScreenWatcher/docs/04-report/ScreenWatcher.report.md`

## 다음 계획

- [ ] v0.3.0 기능 계획
  - 다중 모니터 지원
  - 배터리 모드 감지
  - 상세한 진단 도구

---

**마지막 업데이트**: 2026-03-27 (v0.2.2)

