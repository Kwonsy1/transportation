# 🔧 Transportation 앱 에러 해결 가이드

## 📋 주요 수정 사항

### ✅ 완료된 수정사항
1. **JSON Serialization 파일 문제 해결**
   - 모든 모델 클래스에서 `.g.dart` import를 임시 주석처리
   - 수동 `fromJson`, `toJson` 메서드 구현

2. **Import 문제 해결**
   - `station_detail_screen.dart`에 `api_constants.dart` import 추가
   - `app_utils.dart`에 `flutter/material.dart` import 추가

3. **사용하지 않는 파일 정리**
   - `arrival_card.dart` 파일 내용 정리

## 🚀 앱 실행 단계

### 1단계: 의존성 설치
```bash
cd /Users/kwonsy/Source/transportation
flutter pub get
```

### 2단계: API 키 설정 확인
`lib/constants/api_constants.dart` 파일에서 다음 확인:
```dart
static const String subwayApiKey = 'YOUR_ACTUAL_API_KEY'; // ✅ 실제 키 입력됨
static const String naverMapClientId = 'YOUR_CLIENT_ID'; // ✅ 실제 ID 입력됨
```

### 3단계: 앱 실행
```bash
flutter run
```

## 🐛 발생 가능한 에러들

### 1. JSON Serialization 에러
**에러 메시지**: `The name '_$ClassNameFromJson' isn't defined`

**해결 방법**:
```bash
# JSON 파일 생성
flutter packages pub run build_runner build --delete-conflicting-outputs

# 생성 후 모델 파일에서 주석 해제
# part 'model_name.g.dart'; // 주석 해제
# factory ModelName.fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);
```

### 2. Import 에러
**에러 메시지**: `Target of URI doesn't exist`

**해결 방법**: 
- 모든 import 경로가 올바른지 확인
- 파일명 오타 확인

### 3. API 호출 에러
**에러 메시지**: `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`

**해결 방법**:
- API 키가 올바르게 설정되었는지 확인
- 공공데이터포털에서 서비스 신청 상태 확인

### 4. 위치 권한 에러
**에러 메시지**: `Location permissions are denied`

**해결 방법**:
- Android/iOS 설정에서 앱 위치 권한 허용
- 시뮬레이터에서는 위치 시뮬레이션 설정

## 📱 테스트 순서

### 1. 기본 빌드 테스트
```bash
flutter analyze
flutter test
```

### 2. 화면별 테스트
1. **홈 화면**: 하단 네비게이션 동작 확인
2. **역 검색**: '서울역' 검색 테스트
3. **역 상세**: 검색된 역 클릭 후 상세 정보 확인
4. **주변 역**: 위치 권한 허용 후 주변 역 표시 확인

### 3. API 연동 테스트
1. **역 검색 API**: 키워드로 역 검색
2. **시간표 API**: 선택된 역의 시간표 조회
3. **출구 정보 API**: 버스노선/주변시설 정보 조회

## 🔍 디버깅 팁

### 1. 로그 확인
```bash
flutter logs
```

### 2. API 응답 확인
- `SubwayApiService` 클래스의 print 문으로 API 응답 확인
- 브라우저에서 API URL 직접 테스트

### 3. 네트워크 문제 확인
- 인터넷 연결 상태 확인
- 방화벽/프록시 설정 확인

## 📞 추가 도움

문제가 지속되면 다음 정보와 함께 문의:
1. 정확한 에러 메시지
2. Flutter 버전 (`flutter --version`)
3. 발생한 단계 (빌드/실행/특정 기능)
4. 테스트 환경 (Android/iOS/에뮬레이터/실제기기)

---

**중요**: 모든 수정사항이 적용되었으므로 대부분의 빌드 에러는 해결되었을 것입니다. 
만약 여전히 에러가 발생한다면 구체적인 에러 메시지를 알려주세요.
