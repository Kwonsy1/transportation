# 🚇 Transportation - 지하철 정보 앱

Flutter로 개발된 국토교통부 지하철 정보 API를 활용한 지하철 시간표 조회 앱입니다.

## ✨ 주요 기능

- 🔍 **역 검색**: 지하철역 이름으로 검색
- ⏰ **다음 열차 정보**: 시간표 기반 다음 열차 도착 정보
- 📅 **시간표 조회**: 평일/주말/공휴일 시간표 확인
- 🚌 **출구별 버스노선**: 각 출구별 연결 버스노선 정보
- 🏢 **출구별 주변시설**: 각 출구별 주변 시설 정보
- 📍 **주변 역 찾기**: GPS를 이용한 주변 지하철역 검색
- 🗺️ **네이버 지도 연동**: 지하철역 위치 확인
- ❤️ **즐겨찾기**: 자주 이용하는 역 저장

## 🛠️ 사용된 기술

- **Framework**: Flutter 3.8.1+
- **상태 관리**: Provider 6.1.1
- **HTTP 통신**: Dio 5.4.0
- **지도**: 네이버 지도 네이티브 SDK 1.4.0 (flutter_naver_map)
- **로컬 저장소**: Hive 2.2.3 (고성능 NoSQL 데이터베이스)
- **위치 서비스**: Geolocator 10.1.0, Permission Handler 11.1.0
- **JSON 직렬화**: json_annotation 4.8.1, json_serializable 6.7.1

## 📋 필요한 API 키

이 앱을 실행하기 위해서는 다음 API 키들이 필요합니다:

### 1. 국토교통부 지하철정보 API 키
- [공공데이터포털](https://www.data.go.kr/) 회원가입 후 발급
- 서비스명: **지하철정보서비스**
- 제공기관: **국토교통부**
- 4가지 기능 제공:
  1. 키워드기반 지하철역 목록 조회
  2. 지하철역출구별 버스노선 목록 조회
  3. 지하철역출구별 주변 시설 목록 조회
  4. 지하철역별 시간표 목록조회

### 2. 네이버 지도 API 키
- [네이버 클라우드 플랫폼](https://www.ncloud.com/) 회원가입 후 발급
- Maps API 신청

## ⚙️ 설정 방법

### 1. 프로젝트 클론
```bash
git clone <repository-url>
cd transportation
```

### 2. 의존성 설치
```bash
flutter pub get
```

### 3. 네이버 지도 네이티브 SDK 설정
Git LFS 설정 (iOS 필수):
```bash
# macOS에서 Homebrew로 설치
brew install git-lfs
git lfs install

# iOS 의존성 업데이트
cd ios
pod update NMapsMap
cd ..
```

### 4. API 키 설정
`lib/constants/api_constants.dart` 파일에서 다음 부분을 실제 API 키로 교체:

```dart
class ApiConstants {
  // 국토교통부 지하철정보 API
  static const String subwayApiKey = 'YOUR_SUBWAY_API_KEY_HERE'; // 👈 실제 API 키로 교체
  
  // 네이버 지도 API
  static const String naverMapClientId = 'YOUR_API_KEY_HERE'; // 👈 실제 클라이언트 ID로 교체 완료
  static const String naverMapClientSecret = 'YOUR_API_KEY_HERE'; // 👈 실제 클라이언트 시크릿으로 교체 완료
}
```

### 5. Hive 어댑터 생성
```bash
# 방법 1: 제공된 스크립트 사용
chmod +x generate_hive_adapters.sh
./generate_hive_adapters.sh

# 방법 2: 직접 명령어 실행
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 6. JSON 직렬화 코드 생성
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 7. 앱 실행
```bash
flutter run
```

**새로운 네이티브 네이버 지도 기능을 사용하려면 `NAVER_NATIVE_MAP_GUIDE.md`를 참고하세요!**

## 📁 프로젝트 구조

```
lib/
├── constants/          # 상수 파일들
│   ├── api_constants.dart
│   └── app_constants.dart
├── models/             # 데이터 모델들
│   ├── hive/           # Hive 전용 모델들
│   │   ├── station_group_hive.dart
│   │   └── seoul_subway_station_hive.dart
│   ├── subway_station.dart
│   ├── subway_schedule.dart
│   ├── next_train_info.dart
│   ├── station_group.dart
│   └── api_response.dart
├── services/           # API 및 로컬 저장소 서비스들
│   ├── http_service.dart
│   ├── subway_api_service.dart
│   ├── location_service.dart
│   ├── favorites_storage_service.dart       # 즐겨찾기 저장소 (Hive 기반)
│   ├── hive_favorites_storage_service.dart  # Hive 즐겨찾기 서비스
│   └── hive_subway_service.dart             # Hive 지하철 정보 서비스
├── providers/          # 상태 관리 (Provider)
│   ├── subway_provider.dart
│   ├── location_provider.dart
│   └── seoul_subway_provider.dart     # 서울 지하철 전용 Provider
├── screens/            # 화면들
│   ├── home_screen.dart
│   ├── station_search_screen.dart
│   ├── multi_line_station_detail_screen.dart  # 다중 호선 지원 역 상세화면
│   ├── nearby_stations_screen.dart
│   ├── naver_native_map_screen.dart  # 네이버 네이티브 지도
│   ├── google_map_screen.dart        # OpenStreetMap (대체용)
│   ├── favorites_screen.dart
│   ├── favorites_debug_screen.dart   # 즐겨찾기 디버깅 화면
│   └── seoul_subway_test_screen.dart # 서울 지하철 테스트 화면
├── widgets/            # 재사용 가능한 위젯들
│   ├── station_card.dart
│   ├── next_train_card.dart
│   ├── schedule_card.dart
│   └── exit_info_card.dart
├── utils/              # 유틸리티 함수들
│   └── app_utils.dart
└── main.dart           # 앱 엔트리 포인트
```

## 🆕 최근 업데이트 (v2.0)

### SharedPreferences → Hive 마이그레이션
- **성능 향상**: 더 빠른 읽기/쓰기 성능
- **타입 안전성**: 컴파일 타임 오류 검출
- **메모리 효율성**: 필요한 데이터만 메모리에 로드
- **확장성**: 복잡한 객체 저장 가능

자세한 내용은 `HIVE_MIGRATION_GUIDE.md`를 참고하세요.

## 🔧 개발 환경 설정

### Flutter 버전
```bash
Flutter 3.8.1+ 권장
```

### 주요 의존성
```yaml
dependencies:
  dio: ^5.4.0                    # HTTP 클라이언트
  flutter_naver_map: ^1.4.0      # 네이버 지도 네이티브 SDK (업데이트됨)
  webview_flutter: ^4.4.2       # 웹뷰 (대체 지도 서비스용)
  geolocator: ^10.1.0           # 위치 서비스
  permission_handler: ^11.1.0    # 권한 관리
  provider: ^6.1.1              # 상태 관리
  json_annotation: ^4.8.1       # JSON 직렬화
  hive: ^2.2.3                  # 고성능 로컬 데이터베이스
  hive_flutter: ^1.1.0          # Flutter용 Hive 확장
  url_launcher: ^6.2.2          # URL 런처
  flutter_spinkit: ^5.2.0       # 로딩 인디케이터

dev_dependencies:
  build_runner: ^2.4.7          # 코드 생성
  json_serializable: ^6.7.1     # JSON 직렬화 코드 생성
  hive_generator: ^2.0.1        # Hive TypeAdapter 생성
```

## 📱 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web (네이버 지도 제한적 지원)

## 🚨 주의사항

1. **API 키 보안**: 
   - ⚠️ **중요**: 현재 소스코드에 API 키가 하드코딩되어 있습니다
   - 실제 배포 시에는 환경 변수나 별도 설정 파일로 분리 필요
   - `.env` 파일 사용 및 `.gitignore`에 추가 권장
2. **위치 권한**: Android/iOS에서 위치 권한이 필요합니다.
3. **인터넷 연결**: 모든 기능은 인터넷 연결이 필요합니다.
4. **API 제한**: 공공데이터 API는 일일 호출 제한이 있을 수 있습니다.
5. **실시간 정보**: 이 API는 실시간 도착정보가 아닌 시간표 기반 정보를 제공합니다.

## 🔒 권한 설정

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>주변 지하철역을 찾기 위해 위치 권한이 필요합니다.</string>
```

## 📊 API 응답 예시

### 1. 지하철역 검색 응답
```json
{
  "response": {
    "header": {
      "resultCode": "00",
      "resultMsg": "NORMAL SERVICE."
    },
    "body": {
      "items": [
        {
          "subwayStationId": "MTRS11133",
          "subwayStationName": "서울역",
          "subwayRouteName": "서울 1호선"
        }
      ],
      "totalCount": 1
    }
  }
}
```

### 2. 시간표 조회 응답
```json
{
  "response": {
    "header": {
      "resultCode": "00",
      "resultMsg": "NORMAL SERVICE."
    },
    "body": {
      "items": [
        {
          "subwayRouteId": "MTRS11",
          "subwayStationId": "MTRS11133",
          "subwayStationNm": "서울역",
          "dailyTypeCode": "01",
          "upDownTypeCode": "D",
          "depTime": "051930",
          "arrTime": "052000",
          "endSubwayStationId": "MTRKR1P177",
          "endSubwayStationNm": "신창(순천향대)"
        }
      ],
      "totalCount": 257
    }
  }
}
```

## 🐛 문제 해결

### 빌드 오류 시
1. Flutter clean 후 다시 빌드
```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

2. 플랫폼별 의존성 업데이트
```bash
cd android && ./gradlew clean && cd ..
cd ios && pod install && cd ..  # iOS만
```

### API 연결 문제
1. **API 키 보안 이슈**:
   - `lib/constants/api_constants.dart`에서 API 키가 올바른지 확인
   - ⚠️ 소스코드에 노출된 API 키를 환경변수로 분리 권장
2. 네트워크 연결 상태 확인
3. 공공데이터 API 서비스 상태 확인
4. API 호출 횟수 제한 확인

### 데이터 없음 문제
- 국토교통부 API는 키워드 기반 검색이므로 정확한 역명 입력이 필요합니다.
- 일부 역의 경우 데이터가 없을 수 있습니다.

### 보안 개선 방법
1. **API 키 분리**:
```bash
# .env 파일 생성
echo "SUBWAY_API_KEY=your_api_key_here" > .env
echo "NAVER_MAP_CLIENT_ID=your_client_id" >> .env
echo "NAVER_MAP_CLIENT_SECRET=your_client_secret" >> .env

# .gitignore에 .env 추가
echo ".env" >> .gitignore
```

## 🔄 API 비교: 서울시 vs 국토교통부

| 기능 | 서울시 API | 국토교통부 API |
|------|------------|-----------------|
| 실시간 도착정보 | ✅ 제공 | ❌ 미제공 |
| 시간표 정보 | ✅ 제공 | ✅ 제공 |
| 출구별 버스노선 | ❌ 미제공 | ✅ 제공 |
| 출구별 주변시설 | ❌ 미제공 | ✅ 제공 |
| 적용 범위 | 서울시만 | 전국 |
| 검색 방식 | 역명 직접 입력 | 키워드 기반 |

## 📞 문의 및 기여

프로젝트에 대한 문의사항이나 버그 리포트는 이슈로 등록해주세요.

---

**개발 기간**: 2024년 12월  
**개발자**: Transportation Team  
**API 제공**: 국토교통부 (공공데이터포털)  
**라이선스**: MIT License
