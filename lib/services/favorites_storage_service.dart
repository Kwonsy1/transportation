import '../models/station_group.dart';
import './hive_favorites_storage_service.dart';

/// 즐겨찾기 데이터 저장 서비스 (Hive 기반)
/// 
/// 기존 SharedPreferences 기반에서 Hive 기반으로 변경됨
/// 기존 코드와의 호환성을 위해 동일한 인터페이스 유지
class FavoritesStorageService {
  /// Hive 기반 서비스 인스턴스
  static final HiveFavoritesStorageService _hiveService = 
      HiveFavoritesStorageService.instance;

  /// 서비스 초기화
  /// 앱 시작 시 한 번 호출 필요
  static Future<void> initialize() async {
    await _hiveService.initialize();
  }

  /// 즐겨찾기 스테이션 그룹 저장
  static Future<void> saveFavoriteStationGroups(List<StationGroup> stationGroups) async {
    await _hiveService.saveFavoriteStationGroups(stationGroups);
  }

  /// 즐겨찾기 스테이션 그룹 로드
  static Future<List<StationGroup>> loadFavoriteStationGroups() async {
    return await _hiveService.loadFavoriteStationGroups();
  }

  /// 특정 즐겨찾기 스테이션 그룹 추가
  static Future<void> addFavoriteStationGroup(StationGroup stationGroup) async {
    await _hiveService.addFavoriteStationGroup(stationGroup);
  }

  /// 특정 즐겨찾기 스테이션 그룹 제거
  static Future<void> removeFavoriteStationGroup(StationGroup stationGroup) async {
    await _hiveService.removeFavoriteStationGroup(stationGroup);
  }

  /// 모든 즐겨찾기 제거
  static Future<void> clearAllFavorites() async {
    await _hiveService.clearAllFavorites();
  }

  /// 특정 역명이 즐겨찾기에 있는지 확인
  static Future<bool> isFavoriteStation(String stationName) async {
    return await _hiveService.isFavoriteStation(stationName);
  }

  /// 즐겨찾기 개수 반환
  static Future<int> getFavoritesCount() async {
    return await _hiveService.getFavoritesCount();
  }

  /// 저장소 초기화 (디버그용)
  /// 
  /// 모든 즐겨찾기 데이터를 삭제합니다.
  static Future<void> resetStorage() async {
    await _hiveService.clearAllFavorites();
  }

  /// 저장소 상태 확인 (디버그용)
  static Future<Map<String, dynamic>> getStorageInfo() async {
    return await _hiveService.getStorageInfo();
  }

  /// SharedPreferences에서 Hive로 마이그레이션
  /// 
  /// 기존 SharedPreferences 데이터가 있는 경우 Hive로 이전
  static Future<void> migrateFromSharedPreferences() async {
    await _hiveService.migrateFromSharedPreferences();
  }

  /// 리소스 정리
  /// 
  /// 앱 종료 시 호출하여 Hive 리소스 정리
  static Future<void> dispose() async {
    await _hiveService.dispose();
  }
}
