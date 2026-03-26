# ScreenWatcher

macOS 메뉴바 앱 — 주기적으로 화면을 캡쳐해 Telegram으로 자동 전송합니다.

## 요구사항

- macOS 13.0 Ventura 이상
- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode 15.0 이상
- xcodegen (`brew install xcodegen`)

## 빌드

```bash
# 1. 의존성 설치
brew install xcodegen

# 2. 빌드 & 패키징
cd ScreenWatcher
chmod +x build.sh
./build.sh
```

빌드 완료 후 `ScreenWatcher-v0.1.0-arm64.zip` 파일이 생성됩니다.

## 설치

1. zip 파일 압축 해제
2. `ScreenWatcher.app`을 `/Applications` 폴더로 이동
3. 처음 실행 시 Gatekeeper에 의해 차단되면:
   ```bash
   xattr -cr /Applications/ScreenWatcher.app
   ```
4. 앱 실행 → 메뉴바에 카메라 아이콘 확인

## 설정

1. 메뉴바 아이콘 클릭 → 설정...
2. **Bot Token**: Telegram BotFather에서 발급
3. **Chat ID**: 아래 가이드 참조
4. 캡쳐 주기, 운영 시간, 요일 설정
5. 저장 후 활성화

## Telegram 봇 생성

1. 텔레그램에서 `@BotFather` 검색
2. `/newbot` → 봇 이름 입력 → **Bot Token** 발급
3. 봇에게 아무 메시지 전송
4. 브라우저에서 열기:
   ```
   https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates
   ```
5. 응답에서 `"chat":{"id": 숫자}` → 그 숫자가 **Chat ID**

## 권한

최초 실행 시 **화면 녹화** 권한 요청이 표시됩니다.
시스템 설정 > 개인 정보 보호 및 보안 > 화면 녹화에서 허용하세요.

## 라이선스

MIT
