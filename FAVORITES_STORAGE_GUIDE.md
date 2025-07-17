# SharedPreferences를 이용한 즐겨찾기 로컬 저장 기능 구현

## 변경사항 요약

### 1. 의존성 추가
- `pubspec.yaml`에 `shared_preferences: ^2.2.2` 추가

### 2. 새로운 서비스 클래스 추가
- `lib/services/favorites_storage_service.dart` 생성
- SharedPreferences를 사용한 즐겨찾기 데이터 저장/로드 기능

### 3. SubwayProvider 수정
- 즐겨찾기 관련 메서드들을 async로 변경
- 실제 로컬 저장소 연동
- 앱 시작 시 자동 로드 기능

### 4. UI 컴포넌트 수정
- `FavoritesScreen`: async 호출 적용
- `StationGroupCard`: async 호출 적용
- 모든 즐겨찾기 제거 기능 개선

### 5. 주요 기능

#### 로컬 저장 기능
- 즐겨찾기 추가/제거 시 자동 저장
- JSON 형태로 안전한 데이터 저장
- 에러 처리로 앱 안정성 보장

#### 데이터 마이그레이션
- 기존 개별 역 즐겨찾기 → 역 그룹 즐겨찾기로 자동 변환
- 하위 호환성 유지

#### 추가 기능
- 즐겨찾기 개수 확인
- 특정 역 즐겨찾기 여부 확인
- 모든 즐겨찾기 일괄 제거
- 저장소 초기화 (디버그용)

## 사용법

### 패키지 설치
```bash
flutter pub get
```

### 주요 메서드

#### 즐겨찾기 추가
```dart
await provider.addFavoriteStationGroup(stationGroup);
```

#### 즐겨찾기 제거
```dart
await provider.removeFavoriteStationGroup(stationGroup);
```

#### 모든 즐겨찾기 제거
```dart
await provider.clearAllFavorites();
```

#### 즐겨찾기 로드 (앱 시작 시 자동 실행)
```dart
await provider.loadFavoritesFromLocal();
```

## 기술적 세부사항

### 저장 형식
- 키: `favorite_station_groups`
- 형식: JSON 문자열 (StationGroup 리스트)
- 위치: SharedPreferences

### 에러 처리
- 저장/로드 실패 시 로그 출력
- 앱 동작에는 영향 없음
- 빈 데이터로 대체 처리

### 성능 최적화
- 비동기 처리로 UI 블로킹 방지
- Provider 패턴으로 상태 관리
- 필요시에만 저장소 접근

## 테스트 방법

1. 앱 실행 후 역 검색
2. 즐겨찾기 추가
3. 앱 종료 후 재시작
4. 즐겨찾기가 유지되는지 확인

## 향후 개선사항

- 즐겨찾기 순서 변경 기능
- 카테고리별 즐겨찾기 분류
- 즐겨찾기 사용 빈도 통계
- 클라우드 동기화 지원
