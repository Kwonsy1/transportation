#!/bin/bash

# Hive 어댑터 생성 스크립트
echo "🔄 Hive 어댑터 생성 중..."

# 프로젝트 디렉토리로 이동
cd "$(dirname "$0")"

# Flutter 의존성 업데이트
echo "📦 Flutter 의존성 업데이트 중..."
flutter pub get

# 기존 생성된 파일 삭제 (선택사항)
echo "🗑️ 기존 생성 파일 정리 중..."
flutter packages pub run build_runner clean

# Hive 어댑터 생성
echo "⚙️ Hive TypeAdapter 생성 중..."
flutter packages pub run build_runner build --delete-conflicting-outputs

echo "✅ Hive 어댑터 생성 완료!"
echo ""
echo "📋 생성된 파일들:"
echo "   - lib/models/hive/station_group_hive.g.dart"
echo "   - lib/models/hive/seoul_subway_station_hive.g.dart"
echo ""
echo "🚀 이제 앱을 실행할 수 있습니다:"
echo "   flutter run"
