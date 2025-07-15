#!/bin/bash

# Git LFS 설치 및 설정 스크립트

echo "Git LFS 설치 및 설정을 시작합니다..."

# macOS에서 Git LFS 설치
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS에서 Git LFS를 설치합니다..."
    
    # Homebrew가 설치되어 있는지 확인
    if command -v brew &> /dev/null; then
        echo "Homebrew를 사용하여 Git LFS를 설치합니다..."
        brew install git-lfs
    else
        echo "Homebrew가 설치되어 있지 않습니다."
        echo "Git LFS를 수동으로 설치해주세요: https://git-lfs.github.io/"
        exit 1
    fi
else
    echo "다른 운영체제에서는 수동으로 Git LFS를 설치해주세요: https://git-lfs.github.io/"
    exit 1
fi

# Git LFS 초기화
echo "Git LFS를 초기화합니다..."
git lfs install

# iOS 폴더로 이동하여 pod 업데이트
echo "iOS 의존성을 업데이트합니다..."
cd ios
pod update NMapsMap
cd ..

echo "Git LFS 설정이 완료되었습니다!"
echo ""
echo "다음 단계:"
echo "1. 네이버 클라우드 플랫폼에서 Client ID를 발급받으세요"
echo "2. lib/constants/api_constants.dart에서 API 키를 업데이트하세요"
echo "3. flutter pub get을 실행하세요"
echo "4. flutter run으로 앱을 실행하세요"
