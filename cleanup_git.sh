#!/bin/bash

echo "🚗 Transportation 프로젝트 Git 정리를 시작합니다..."
echo "(.dart_tool 폴더 및 빌드 파일 정리 포함)"

# 현재 디렉토리 확인
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml이 없습니다. transportation 프로젝트 디렉토리에서 실행하세요."
    exit 1
fi

echo "📁 현재 위치: $(pwd)"

# Git 저장소인지 확인
if [ ! -d ".git" ]; then
    echo "🔧 Git 저장소를 초기화합니다..."
    git init
    echo "✅ Git 저장소 초기화 완료"
else
    echo "✅ Git 저장소가 이미 존재합니다."
fi

# .gitignore 파일 확인
if [ ! -f ".gitignore" ]; then
    echo "⚠️  .gitignore 파일이 없습니다."
else
    echo "✅ .gitignore 파일이 존재합니다."
fi

echo ""
echo "🔍 현재 Git에서 추적 중인 불필요한 파일들 확인..."

# Git에서 추적 중인 파일들 중 .gitignore에 포함된 것들 확인
echo ""
echo "📋 Git에서 추적 중이지만 .gitignore에 포함된 파일들:"
git ls-files -i --exclude-standard 2>/dev/null || echo "제외할 파일이 없거나 Git이 초기화되지 않았습니다."

echo ""
echo "🧹 Git에서 불필요한 파일들을 안전하게 제거합니다..."

# 제거할 파일/폴더 목록 (Flutter 지도 앱 특화)
FILES_TO_REMOVE=(
    # Flutter 핵심 빌드 파일들
    "build/"
    ".dart_tool/"
    ".packages"
    ".flutter-plugins"
    ".flutter-plugins-dependencies"
    
    # Android 관련
    "android/.gradle/"
    "android/.kotlin/"
    "android/local.properties"
    "android/app/debug/"
    "android/app/profile/"
    "android/app/release/"
    
    # iOS 관련
    "ios/Pods/"
    "ios/Podfile.lock"
    "ios/.symlinks/"
    "ios/Flutter/.last_build_id"
    
    # 시스템 파일
    ".DS_Store"
    "*.iml"
    
    # IDE 관련
    ".idea/"
    ".vscode/"
    
    # 생성된 파일들
    "lib/generated_plugin_registrant.dart"
    "**/*.g.dart"
    "**/*.freezed.dart"
    "**/*.gr.dart"
    
    # 웹 관련
    "web/.dart_tool/"
    
    # 로그 파일
    "*.log"
)

removed_count=0
for file in "${FILES_TO_REMOVE[@]}"; do
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        echo "🗑️  제거 중: $file"
        if git rm -r --cached "$file" 2>/dev/null; then
            echo "   ✅ 성공"
            ((removed_count++))
        else
            echo "   ⚠️  이미 제거됨 또는 에러"
        fi
    else
        # 파일이 존재하지만 Git에서 추적되지 않는 경우도 체크
        if [ -e "$file" ]; then
            echo "📁 존재하지만 추적안됨: $file"
        fi
    fi
done

echo ""
echo "🔐 API 키 및 민감한 정보 확인..."

# API 키가 포함된 파일들 체크 (지도 앱 특화)
SENSITIVE_FILES=(
    "lib/config/keys.dart"
    "lib/config/secrets.dart"
    "lib/keys.dart"
    "lib/secrets.dart"
    "lib/naver_map_keys.dart"
    "lib/google_maps_api_key.dart"
    "lib/location_keys.dart"
    ".env"
    "android/app/google-services.json"
    "ios/Runner/GoogleService-Info.plist"
    "android/local.properties"
)

sensitive_found=0
echo "⚠️  다음 민감한 파일들을 확인합니다:"
for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "🔑 발견: $file"
        ((sensitive_found++))
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            echo "   ⚠️  WARNING: 이 파일이 Git에 추적되고 있습니다!"
            echo "   🔧 제거 중..."
            git rm --cached "$file" 2>/dev/null && echo "   ✅ Git에서 제거됨"
        else
            echo "   ✅ Git에서 제외됨"
        fi
    fi
done

if [ $sensitive_found -eq 0 ]; then
    echo "✅ 민감한 파일이 발견되지 않았습니다."
fi

echo ""
echo "📊 정리 결과:"
echo "- 제거된 파일/폴더: $removed_count개"
echo "- 발견된 민감한 파일: $sensitive_found개"

echo ""
echo "✅ 정리 완료!"
echo ""
echo "🗺️ Transportation 앱 정보:"
echo "- 타입: Flutter 지도 & 위치 서비스 앱"
echo "- 주요 기능: 네이버 지도, 위치 추적, HTTP 통신"
echo "- 사용 패키지: webview_flutter, geolocator, permission_handler, dio"

echo ""
echo "📋 다음 단계:"
echo "1. git add ."
echo "2. git commit -m 'Add proper .gitignore and remove build files'"
echo "3. git remote add origin <your-repository-url>"
echo "4. git push origin main"

echo ""
echo "🔐 중요 보안 참고사항:"
echo "- 네이버 지도 API 키를 코드에 직접 포함하지 마세요"
echo "- Google Maps API 키도 안전하게 관리하세요"
echo "- 위치 정보 관련 민감한 데이터는 별도 관리하세요"
echo "- .dart_tool 폴더는 자동 생성되므로 Git에서 제외되었습니다"

echo ""
echo "🔧 개발 시 참고사항:"
echo "- .dart_tool 폴더는 Flutter 도구가 자동 생성합니다"
echo "- build 폴더도 빌드 시 자동 생성됩니다"
echo "- json_serializable 코드 생성 시 *.g.dart 파일들도 제외됩니다"

echo ""
echo "📊 현재 Git 상태:"
git status --short
