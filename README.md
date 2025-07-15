# 🚇 Transportation - 지하철 정보 앱

Flutter로 개발된 국토교통부 지하철 정보 API를 활용한 지하철 시간표 조회 앱입니다.

## ✨ 주요 기능

- 🔍 **역 검색**: 지하철역 이름으로 검색
- ⏰ **다음 열차 정보**: 시간표 기반 다음 열차 도착 정보
- 📅 **시간표 조회**: 평일/주말/공휴일 시간표 확인
- 🚌 **출구별 버스노선**: 각 출구별 연결 버스노선 정보
- 🏢 **출구별 주변시설**: 각 출구별 주변 시설 정보
- 📍 **주변 역 찾기**: GPS를 이용한 주변 지하철역 검색
- 🗺️ **향상된 네이버 지도**: 지하철역 위치 확인 및 인터랙티브 지도
  - ✨ **지하철역 선택**: 지도 위의 지하철역 마커 클릭으로 선택
  - 💬 **향상된 팝업**: 아름다운 디자인의 역 정보 팝업
  - 🎆 **상세페이지 이동**: 팝업에서 '상세정보 보기' 버튼으로 원클릭 이동
  - 🎨 **호선별 색상**: 각 지하철 호선의 고유 색상으로 직관적 구분
  - 🔍 **노선별 필터**: 1-9호선, 공항철도, 경의중앙선 등 선택 가능
- ❤️ **즐겨찾기**: 자주 이용하는 역 저장

## 🛠️ 사용된 기술

- **Framework**: Flutter 3.8.1+
- **상태 관리**: Provider
- **HTTP 통신**: Dio
- **지도**: 네이버 지도 API (WebView)
- **위치 서비스**: Geolocator, Permission Handler
- **JSON 직렬화**: json_annotation, json_serializable

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

### 3. API 키 설정
`lib/constants/api_constants.dart` 파일에서 다음 부분을 실제 API 키로 교체:

```dart
class ApiConstants {
  // 국토교통부 지하철정보 API
  static const String subwayApiKey = 'YOUR_SUBWAY_API_KEY_HERE'; // 👈 실제 API 키로 교체
  
  // 네이버 지도 API
  static const String naverMapClientId = 'YOUR_KEY_HERE'; // 👈 실제 클라이언트 ID로 교체 완료
  static const String naverMapClientSecret = 'YOUR_KEY_HERE'; // 👈 실제 클라이언트 시크릿으로 교체 완료
}
```

### 4. JSON 직렬화 코드 생성
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 5. 앱 실행
```bash
flutter run
```

## 📁 프로젝트 구조

```
lib/
├── constants/          # 상수 파일들
│   ├── api_constants.dart
│   └── app_constants.dart
├── models/             # 데이터 모델들
│   ├── subway_station.dart
│   ├── subway_schedule.dart
│   ├── next_train_info.dart
│   └── api_response.dart
├── services/           # API 서비스들
│   ├── http_service.dart
│   ├── subway_api_service.dart
│   └── location_service.dart
├── providers/          # 상태 관리 (Provider)
│   ├── subway_provider.dart
│   └── location_provider.dart
├── screens/            # 화면들
│   ├── home_screen.dart
│   ├── station_search_screen.dart
│   ├── station_detail_screen.dart
│   ├── nearby_stations_screen.dart
│   ├── map_screen.dart
│   └── favorites_screen.dart
├── widgets/            # 재사용 가능한 위젯들
│   ├── station_card.dart
│   ├── next_train_card.dart
│   ├── schedule_card.dart
│   └── exit_info_card.dart
├── utils/              # 유틸리티 함수들
│   └── app_utils.dart
└── main.dart           # 앱 엔트리 포인트
```

## 🔧 개발 환경 설정

### Flutter 버전
```bash
Flutter 3.8.1+ 권장
```

### 주요 의존성
```yaml
dependencies:
  dio: ^5.4.0                    # HTTP 클라이언트
  webview_flutter: ^4.4.2       # 웹뷰 (네이버 지도)
  geolocator: ^10.1.0           # 위치 서비스
  permission_handler: ^11.1.0    # 권한 관리
  provider: ^6.1.1              # 상태 관리
  json_annotation: ^4.8.1       # JSON 직렬화
  url_launcher: ^6.2.2          # URL 런처
  flutter_spinkit: ^5.2.0       # 로딩 인디케이터

dev_dependencies:
  build_runner: ^2.4.7          # 코드 생성
  json_serializable: ^6.7.1     # JSON 직렬화 코드 생성
```

## 📱 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web (네이버 지도 제한적 지원)

## 🚨 주의사항

1. **API 키 보안**: 실제 배포 시에는 API 키를 안전하게 관리해야 합니다.
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
1. API 키가 올바른지 확인
2. 네트워크 연결 상태 확인
3. 공공데이터 API 서비스 상태 확인
4. API 호출 횟수 제한 확인

### 데이터 없음 문제
- 국토교통부 API는 키워드 기반 검색이므로 정확한 역명 입력이 필요합니다.
- 일부 역의 경우 데이터가 없을 수 있습니다.

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
