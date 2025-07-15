# 네이버 지도 API 문제 해결 가이드

## 🎉 문제 해결 완료! (2025.07.16 업데이트)

**flutter_naver_map 패키지를 사용한 네이티브 네이버 지도 연동이 완료되었습니다!**

## 🎆 최종 해결책: 네이티브 네이버 지도 연동

### 🚀 flutter_naver_map 패키지 사용
- **네이티브 렌더링**: WebView 대신 네이티브 맵 위젯 사용
- **고성능**: 매끄러운 애니메이션 및 빠른 렌더링
- **안정성**: 네이버 공식 SDK 기반으로 안정적
- **풍부한 기능**: 마커, 오버레이, 카메라 제어 등 모든 기능 사용 가능

**새로 추가된 파일**: `lib/screens/naver_native_map_screen.dart`

### 📱 플랫폼 설정 완료
- **Android**: Client ID 및 Gradle 설정 완료
- **iOS**: Info.plist 설정 및 Git LFS 준비 완료
- **네이버 SDK 초기화**: main.dart에서 자동 초기화

**사용 방법**: `NAVER_NATIVE_MAP_GUIDE.md` 참고

---

## 🚨 기존 문제들
네이버 지도 API에서 다음 문제들이 발생했었습니다:

1. **500 Internal Server Error**: 서버 내부 오류
2. **API 서비스 종료 안내**: 기존 AI NAVER API가 점진적으로 종료 예정
3. **Android 네트워크 보안**: HTTP 평문 통신 차단

## 🛠️ 적용된 해결책

### 1. Android Network Security Config 설정 완료
- `android/app/src/main/res/xml/network_security_config.xml` 생성
- `AndroidManifest.xml`에 network security config 적용
- HTTP 평문 통신 허용 설정

### 2. 임시 지도 서비스 변경
- 네이버 지도 → OpenStreetMap (Leaflet.js) 기반으로 임시 변경
- `google_map_screen.dart` 생성 및 적용
- 동일한 기능 제공 (현재 위치, 지하철역 마커, 지도 이동 등)

## 🔧 네이버 클라우드 플랫폼으로 완전 전환 방법

### 1. 새로운 API 키 발급
1. [네이버 클라우드 플랫폼](https://www.ncloud.com) 접속
2. 회원가입 및 로그인
3. **AI·Application Service** → **Maps** 선택
4. **Application 등록** 클릭
5. 서비스명 입력 및 Web Dynamic Map 선택
6. Client ID 발급받기

### 2. API 키 교체
`lib/constants/api_constants.dart` 파일에서:
```dart
// 기존
static const String naverMapClientId = 'jpj5i2bvdl';

// 새로운 NCP API 키로 교체
static const String naverMapClientId = 'YOUR_NEW_NCP_CLIENT_ID';
```

### 3. 새로운 API 형식 적용
새로운 네이버 클라우드 플랫폼 API는 다음과 같이 사용:
```html
<script type="text/javascript" src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpClientId=YOUR_NCP_CLIENT_ID&submodules=geocoder"></script>
```

## 📱 현재 앱 상태

### ✅ 해결된 문제
- Android HTTP 통신 허용 설정 완료
- 지도 기능 정상 작동 (OpenStreetMap 사용)
- 지하철역 마커 표시 기능 유지
- 현재 위치 및 지도 이동 기능 유지

### 🔄 임시 해결책
- 네이버 지도 대신 OpenStreetMap 사용
- 동일한 사용자 경험 제공
- 무료 서비스로 안정적 운영

## 🎯 권장 사항

### 즉시 적용 가능한 옵션
1. **현재 상태 유지**: OpenStreetMap 사용 (무료, 안정적)
2. **Google Maps 전환**: Google Maps Platform API 사용
3. **카카오맵 전환**: 카카오 API 사용

### 장기적 해결책
1. **네이버 클라우드 플랫폼 전환**: 새로운 API 키 발급 후 적용
2. **다중 지도 서비스 지원**: 사용자가 지도 서비스를 선택할 수 있도록 구현

## 📞 참고 링크

- [네이버 클라우드 플랫폼 공지사항](https://www.ncloud.com/support/notice/all/1930)
- [신규 Maps API 가이드](https://navermaps.github.io/maps.js.ncp/docs/tutorial-2-Getting-Started.html)
- [Android Network Security Config](https://developer.android.com/training/articles/security-config)

## 🔄 롤백 방법

원래 네이버 지도로 돌아가려면:
1. `home_screen.dart`에서 `GoogleMapScreen` → `MapScreen`으로 변경
2. import 문 수정: `google_map_screen.dart` → `map_screen.dart`
3. 새로운 NCP API 키 적용 후 테스트

---

**현재 앱은 OpenStreetMap으로 정상 작동합니다!** 🎉
