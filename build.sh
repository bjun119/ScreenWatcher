#!/bin/bash
# ScreenWatcher 빌드 & 패키징 스크립트
# 실행: chmod +x build.sh && ./build.sh

set -e

PROJECT_NAME="ScreenWatcher"
SCHEME="ScreenWatcher"
VERSION="0.3.0"
BUILD_DIR="build"

echo "=== ScreenWatcher 빌드 시작 ==="

# 1. xcodegen으로 .xcodeproj 생성 (최초 1회 또는 project.yml 변경 시)
if ! command -v xcodegen &> /dev/null; then
    echo "[!] xcodegen이 없습니다. 설치: brew install xcodegen"
    exit 1
fi

echo "[1/5] Xcode 프로젝트 생성..."
xcodegen generate

# 2. 빌드 디렉토리 초기화
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 3. Release Archive 빌드
echo "[2/5] Release Archive 빌드 중..."
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "${BUILD_DIR}/${PROJECT_NAME}.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS=arm64 \
    | grep -E "(error:|warning:|Build succeeded|Build FAILED)"

# 4. .app 추출
echo "[3/5] .app 추출 중..."
xcodebuild \
    -exportArchive \
    -archivePath "${BUILD_DIR}/${PROJECT_NAME}.xcarchive" \
    -exportPath "${BUILD_DIR}/export" \
    -exportOptionsPlist ExportOptions.plist

# 5. ad-hoc 코드 서명
echo "[4/5] ad-hoc 코드 서명..."
APP_PATH="${BUILD_DIR}/export/${PROJECT_NAME}.app"
codesign --deep --force --sign "-" "$APP_PATH"

# 6. 검증
echo "[5/5] 서명 검증..."
codesign --verify --deep --strict "$APP_PATH" && echo "    서명 검증 성공"

# 7. zip 패키징
ZIP_NAME="${PROJECT_NAME}-v${VERSION}-arm64.zip"
cd "${BUILD_DIR}/export"
zip -r "../../${ZIP_NAME}" "${PROJECT_NAME}.app"
cd ../..

echo ""
echo "=== 빌드 완료 ==="
echo "배포 파일: ${ZIP_NAME}"
echo ""
echo "설치 방법:"
echo "  1. ${ZIP_NAME} 압축 해제"
echo "  2. ScreenWatcher.app을 /Applications 으로 이동"
echo "  3. 처음 실행 시 Gatekeeper 차단될 경우:"
echo "     터미널에서: xattr -cr /Applications/ScreenWatcher.app"
echo "     그 후 다시 실행"
