# SharedPreferences에서 Hive로 마이그레이션 가이드

## 개요

이 문서는 transportation 플러터 프로젝트에서 SharedPreferences 기반 로컬 저장소를 Hive 기반으로 변경한 내용을 설명합니다.

## 변경 사항

### 1. 의존성 변경

**변경 전 (pubspec.yaml):**
```yaml
dependencies:
  shared_preferences: ^2.2.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
```

**변경 후 (pubspec.yaml):**
```yaml
dependencies:
  # shared_preferences: ^2.2.2  # Hive로 대체됨
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
```

### 2. 모델 변경

#### 새로 추가된 파일들

1. **`lib/models/hive/station_group_hive.dart`**
   - StationGroupHive: Hive용 즐겨찾기 스테이션 그룹 모델
   - SubwayStationHive: Hive용 지하철역 모델
   - JSON 모델과 Hive 모델 간 변환 메서드 제공

2. **`lib/models/hive/station_group_hive.g.dart`**
   - Hive TypeAdapter 자동 생성 파일

### 3. 서비스 변경

#### 새로 추가된 서비스

1. **`lib/services/hive_favorites_storage_service.dart`**
   - Hive 기반 즐겨찾기 저장소 서비스
   - 싱글톤 패턴으로 구현
   - Box 관리 및 CRUD 작업 제공

#### 변경된 서비스

1. **`lib/services/favorites_storage_service.dart`**
   - 기존 SharedPreferences 코드를 모두 제거
   - HiveFavoritesStorageService를 래핑하는 인터페이스로 변경
   - 기존 API 호환성 유지

### 4. 초기화 변경

**`lib/main.dart`에서 Hive 초기화 추가:**
```dart
/// Hive 데이터베이스 초기화
Future<void> _initializeHive() async {
  try {
    // 지하철 정보 Hive 초기화
    await HiveSubwayService.instance.initialize();
    
    // 즐겨찾기 Hive 초기화
    await FavoritesStorageService.initialize();
    
    print('✅ Hive 데이터베이스 초기화 성공');
  } catch (e) {
    print('❌ Hive 초기화 오류: $e');
  }
}
```

## 마이그레이션 혜택

### 1. 성능 향상
- **타입 안전성**: Hive는 강타입 시스템으로 컴파일 타임에 오류 검출
- **빠른 읽기/쓰기**: SharedPreferences보다 훨씬 빠른 I/O 성능
- **메모리 효율성**: 필요한 데이터만 메모리에 로드

### 2. 개발자 경험 개선
- **코드 생성**: Hive 어댑터 자동 생성으로 보일러플레이트 코드 감소
- **타입 안전**: 런타임 에러 방지
- **디버깅**: 구조화된 데이터로 디버깅 용이

### 3. 확장성
- **복잡한 객체**: 중첩된 객체나 리스트도 쉽게 저장
- **인덱싱**: 대용량 데이터에서 빠른 검색 지원
- **압축**: 자동 데이터 압축으로 저장 공간 절약

## API 호환성

기존 `FavoritesStorageService` API는 모두 유지됩니다:

```dart
// 기존 코드 그대로 사용 가능
await FavoritesStorageService.saveFavoriteStationGroups(groups);
final favorites = await FavoritesStorageService.loadFavoriteStationGroups();
await FavoritesStorageService.addFavoriteStationGroup(group);
await FavoritesStorageService.removeFavoriteStationGroup(group);
```

## 데이터 마이그레이션

기존 SharedPreferences 데이터는 앱 업데이트 시 자동으로 마이그레이션되지 않습니다. 필요한 경우 다음과 같이 수동 마이그레이션을 구현할 수 있습니다:

```dart
await FavoritesStorageService.migrateFromSharedPreferences();
```

## 디버깅

즐겨찾기 디버그 화면(`FavoritesDebugScreen`)에서 Hive 저장소 상태를 확인할 수 있습니다:
- 저장된 데이터 개수
- Box 경로 및 크기
- 저장/로드 테스트

## 주의사항

1. **앱 첫 실행**: 기존 SharedPreferences 데이터는 자동으로 이전되지 않음
2. **타입 ID**: Hive TypeAdapter의 typeId는 변경하지 말 것 (데이터 호환성)
3. **Box 닫기**: 앱 종료 시 `FavoritesStorageService.dispose()` 호출 권장

## 성능 비교

| 기능 | SharedPreferences | Hive |
|------|------------------|------|
| 타입 안전성 | ❌ | ✅ |
| 복잡한 객체 저장 | ❌ | ✅ |
| 성능 | 보통 | 빠름 |
| 메모리 사용량 | 많음 | 적음 |
| 디버깅 용이성 | 어려움 | 쉬움 |

## 향후 확장 가능성

Hive를 도입함으로써 다음과 같은 확장이 가능합니다:

1. **사용자 설정**: 앱 설정을 Hive로 저장
2. **캐시 시스템**: API 응답 캐싱
3. **오프라인 지원**: 오프라인 모드 데이터 저장
4. **검색 기록**: 사용자 검색 이력 저장
5. **통계 데이터**: 앱 사용 패턴 분석 데이터

이러한 변경으로 앱의 성능과 안정성이 크게 향상되었습니다.
