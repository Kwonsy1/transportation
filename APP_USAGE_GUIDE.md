# 지하철 정보 앱 사용 가이드

## 주요 기능

### 1. 네이버 지도에서 지하철역 확인
- **위치**: `lib/screens/naver_native_map_screen.dart`
- **기능**: 
  - 현재 위치 표시 (파란색 원형 마커)
  - 주변 지하철역 표시 (호선별 색상의 기차 아이콘)
  - 지하철역 마커 클릭 시 상세 페이지로 이동

### 2. 지하철역 상세 정보 화면
- **위치**: `lib/screens/station_detail_screen.dart`
- **기능**:
  - 역명, 노선 정보, 현재 위치로부터의 거리
  - 출발/도착 설정 버튼
  - 즐겨찾기 및 공유 기능
  - 실시간 열차 정보 (상행/하행)
  - 전체 시간표
  - 출구 정보

## 설정 방법

### 1. API 키 설정
`lib/constants/api_constants.dart` 파일에서 다음 키들을 본인의 키로 교체하세요:

```dart
// 국토교통부 지하철정보 API 키
static const String subwayApiKey = '여기에_본인의_API_키_입력';

// 네이버 지도 API 키
static const String naverMapClientId = '여기에_본인의_클라이언트_ID_입력';
static const String naverMapClientSecret = '여기에_본인의_클라이언트_시크릿_입력';
```

### 2. 안드로이드 설정
`android/app/src/main/AndroidManifest.xml`에 네이버 지도 클라이언트 ID 추가:

```xml
<meta-data
    android:name="com.naver.maps.map.CLIENT_ID"
    android:value="여기에_본인의_클라이언트_ID_입력" />
```

### 3. iOS 설정 (필요한 경우)
`ios/Runner/Info.plist`에 네이버 지도 설정 추가:

```xml
<key>NMFClientId</key>
<string>여기에_본인의_클라이언트_ID_입력</string>
```

## 앱 실행 방법

### 1. 의존성 설치
```bash
cd transportation
flutter pub get
```

### 2. 앱 실행
```bash
flutter run
```

## 마커 스타일 변경사항

### 현재 위치 마커
- 파란색 원형 마커 (24x24 크기)
- 흰색 테두리와 그림자 효과
- 파란색 글로우 이펙트

### 지하철역 마커  
- 호선별 색상의 원형 마커 (28x28 크기)
- 기차 아이콘 표시
- 흰색 테두리와 그림자 효과
- 클릭 시 상세 페이지로 이동 (기존 정보창 대신)

## 상세 화면 개선사항

### 스크린샷 스타일로 개편
- 단일 스크롤 화면으로 모든 정보 표시
- 역명과 노선 정보를 헤더에 표시
- 출발/도착 버튼 추가
- 즐겨찾기 및 공유 버튼
- 실시간 열차 정보 (상행/하행 구분)
- 시간표 정보 (다음 6개 열차)
- 출구 정보 (번호별 표시)

## 주요 파일 구조

```
lib/
├── screens/
│   ├── naver_native_map_screen.dart    # 네이버 지도 화면
│   └── station_detail_screen.dart      # 지하철역 상세 화면
├── models/
│   └── subway_station.dart             # 지하철역 모델
├── providers/
│   ├── location_provider.dart          # 위치 정보 관리
│   └── subway_provider.dart            # 지하철 정보 관리
├── services/
│   ├── subway_api_service.dart         # 지하철 API 서비스
│   └── location_service.dart           # 위치 서비스
└── constants/
    ├── api_constants.dart              # API 키 설정
    └── app_constants.dart              # 앱 상수
```

## 주요 특징

1. **실제 좌표 기반**: 서울시 주요 지하철역의 실제 좌표를 사용하여 정확한 위치 표시
2. **스크린샷 스타일**: 제공해주신 스크린샷과 유사한 UI/UX
3. **실시간 정보**: 국토교통부 API를 통한 실시간 열차 정보
4. **직관적 네비게이션**: 마커 클릭 시 바로 상세 페이지로 이동
5. **반응형 디자인**: 다양한 화면 크기에 대응

## 문제 해결

### 지도가 표시되지 않는 경우
1. 네이버 지도 API 키가 올바르게 설정되었는지 확인
2. 인터넷 연결 상태 확인
3. 권한 설정 확인 (위치, 인터넷)

### 지하철 정보가 표시되지 않는 경우
1. 국토교통부 API 키가 올바르게 설정되었는지 확인
2. API 사용량 한도 확인

### 위치 정보를 가져올 수 없는 경우
1. 위치 권한 허용 확인
2. GPS 설정 활성화 확인
3. 실내에서는 GPS 정확도가 떨어질 수 있음

이제 앱을 실행하면 네이버 지도에서 지하철역을 현재 위치처럼 표시하고, 클릭하면 스크린샷과 유사한 상세 정보를 볼 수 있습니다!
