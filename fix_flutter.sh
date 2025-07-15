#!/bin/bash

echo "🚗 Transportation 프로젝트 Flutter 환경 정리 중..."

# 현재 디렉토리 확인
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml이 없습니다. transportation 프로젝트 디렉토리에서 실행하세요."
    exit 1
fi

echo "📁 프로젝트 디렉토리: $(pwd)"

# Flutter 설치 확인
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter가 설치되지 않았습니다."
    echo "https://flutter.dev/docs/get-started/install 에서 Flutter를 설치하세요."
    exit 1
fi

echo "✅ Flutter 버전:"
flutter --version | head -n 1

echo ""
echo "🧹 프로젝트 정리 시작..."

# 1. Flutter clean
echo "1️⃣ Flutter 프로젝트 정리..."
flutter clean

# 2. 캐시 정리
echo "2️⃣ 캐시 및 임시 파일 정리..."
rm -rf .dart_tool/
rm -f .packages
rm -f .flutter-plugins
rm -f .flutter-plugins-dependencies

# 3. Pub cache clean
echo "3️⃣ Pub 캐시 정리..."
flutter pub cache clean

# 4. Get dependencies
echo "4️⃣ 의존성 재설치..."
flutter pub get

# 5. 코드 생성 (json_serializable 때문에)
echo "5️⃣ 코드 생성..."
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs

# 6. Android 관련 정리
if [ -d "android" ]; then
    echo "6️⃣ Android 프로젝트 정리..."
    cd android
    if [ -f "gradlew" ]; then
        ./gradlew clean
    fi
    rm -rf .gradle/
    rm -rf .kotlin/
    rm -f local.properties
    cd ..
fi

# 7. iOS 관련 정리 (macOS에서만)
if [[ "$OSTYPE" == "darwin"* ]] && [ -d "ios" ]; then
    echo "7️⃣ iOS 프로젝트 정리..."
    cd ios
    rm -rf Podfile.lock
    rm -rf Pods/
    rm -rf .symlinks/
    if command -v pod &> /dev/null; then
        pod install --repo-update
    fi
    cd ..
fi

# 8. 권한 관련 확인
echo "8️⃣ 권한 설정 확인..."
echo ""
echo "📍 위치 권한 설정 확인:"
echo "- Android: android/app/src/main/AndroidManifest.xml"
echo "- iOS: ios/Runner/Info.plist"
echo ""

# 9. 프로젝트 분석
echo "9️⃣ 프로젝트 분석..."
flutter analyze --no-fatal-infos

echo ""
echo "🔍 의존성 상태 확인..."
flutter pub deps

echo ""
echo "✅ 모든 정리 작업이 완료되었습니다!"
echo ""
echo "🎯 다음 단계:"
echo "1. 'flutter run'으로 앱을 실행해보세요"
echo "2. 네이버 지도 API 키가 설정되어 있는지 확인하세요"
echo "3. 위치 권한이 제대로 설정되어 있는지 확인하세요"
echo ""
echo "🗺️ 지도 관련 체크리스트:"
echo "- [ ] 네이버 지도 API 키 설정"
echo "- [ ] Android 위치 권한 설정"
echo "- [ ] iOS 위치 권한 설정"
echo "- [ ] WebView 권한 설정"
echo ""
echo "📱 테스트 권장사항:"
echo "- 실제 기기에서 테스트 (위치 서비스 때문에)"
echo "- GPS 기능이 켜진 상태에서 테스트"
echo "- 네트워크 연결 상태에서 테스트"
