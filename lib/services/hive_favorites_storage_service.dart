import 'package:hive_flutter/hive_flutter.dart';
import '../models/station_group.dart';
import '../models/hive/station_group_hive.dart';
import '../utils/ksy_log.dart';

/// Hive 기반 즐겨찾기 데이터 저장 서비스
class HiveFavoritesStorageService {
  static const String _favoritesBoxName = 'favorite_station_groups';
  static const String _settingsBoxName = 'favorites_settings';
  static const String _lastUpdateKey = 'last_update_timestamp';

  static HiveFavoritesStorageService? _instance;
  Box<StationGroupHive>? _favoritesBox;
  Box? _settingsBox;

  HiveFavoritesStorageService._();

  static HiveFavoritesStorageService get instance {
    _instance ??= HiveFavoritesStorageService._();
    return _instance!;
  }

  /// Hive 초기화
  Future<void> initialize() async {
    try {
      // Hive 초기화
      await Hive.initFlutter();
      
      // 어댑터 등록
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(StationGroupHiveAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(SubwayStationHiveAdapter());
      }
      
      // Box 열기
      _favoritesBox = await Hive.openBox<StationGroupHive>(_favoritesBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      
      KSYLog.info('✅ 즐겨찾기 Hive 초기화 완료');
      KSYLog.info('📊 저장된 즐겨찾기 수: ${_favoritesBox?.length ?? 0}개');
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 Hive 초기화 오류', e);
      rethrow;
    }
  }

  /// 즐겨찾기 스테이션 그룹 저장
  Future<void> saveFavoriteStationGroups(List<StationGroup> stationGroups) async {
    try {
      if (_favoritesBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      KSYLog.info('=== 즐겨찾기 저장 시작 ===');
      KSYLog.info('저장할 그룹 개수: ${stationGroups.length}');

      // 기존 데이터 클리어
      await _favoritesBox!.clear();

      // 새 데이터 저장
      for (int i = 0; i < stationGroups.length; i++) {
        final group = stationGroups[i];
        final hiveGroup = StationGroupHive.fromStationGroup(group);
        
        KSYLog.debug('그룹 $i: ${group.stationName} (역 개수: ${group.stations.length})');
        for (int j = 0; j < group.stations.length; j++) {
          final station = group.stations[j];
          KSYLog.debug('  역 $j: ${station.subwayStationName} (${station.subwayRouteName})');
        }

        // 역명을 키로 사용하여 저장
        await _favoritesBox!.put(group.stationName, hiveGroup);
      }

      // 마지막 업데이트 시간 저장
      await _settingsBox?.put(_lastUpdateKey, DateTime.now().toIso8601String());

      KSYLog.info('💾 즐겨찾기 ${stationGroups.length}개 저장 완료');
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 저장 오류', e, StackTrace.current);
      throw Exception('즐겨찾기 저장에 실패했습니다: $e');
    }
  }

  /// 즐겨찾기 스테이션 그룹 로드
  Future<List<StationGroup>> loadFavoriteStationGroups() async {
    try {
      if (_favoritesBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      KSYLog.info('=== 즐겨찾기 로드 시작 ===');
      
      final hiveStationGroups = _favoritesBox!.values.toList();
      KSYLog.info('저장된 데이터 개수: ${hiveStationGroups.length}');

      if (hiveStationGroups.isEmpty) {
        KSYLog.info('저장된 즐겨찾기 없음');
        return [];
      }

      final stationGroups = <StationGroup>[];
      for (int i = 0; i < hiveStationGroups.length; i++) {
        try {
          final hiveGroup = hiveStationGroups[i];
          final stationGroup = hiveGroup.toStationGroup();
          stationGroups.add(stationGroup);
          KSYLog.debug('그룹 $i 변환 성공: ${stationGroup.stationName}');
        } catch (e) {
          KSYLog.warning('그룹 $i 변환 실패: $e');
          // 개별 그룹 실패시 건너뛰고 계속
        }
      }

      KSYLog.info('즐겨찾기 ${stationGroups.length}개 로드 완료');
      return stationGroups;
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 로드 오류', e, StackTrace.current);
      // 에러 발생시 빈 리스트 반환
      return [];
    }
  }

  /// 특정 즐겨찾기 스테이션 그룹 추가
  Future<void> addFavoriteStationGroup(StationGroup stationGroup) async {
    try {
      if (_favoritesBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      // 중복 확인
      final isDuplicate = _favoritesBox!.containsKey(stationGroup.stationName);
      
      if (!isDuplicate) {
        final hiveGroup = StationGroupHive.fromStationGroup(stationGroup);
        await _favoritesBox!.put(stationGroup.stationName, hiveGroup);
        KSYLog.info('즐겨찾기에 ${stationGroup.cleanStationName} 추가');
      } else {
        KSYLog.warning('이미 즐겨찾기에 있는 역: ${stationGroup.cleanStationName}');
      }
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 추가 오류', e);
      throw Exception('즐겨찾기 추가에 실패했습니다: $e');
    }
  }

  /// 특정 즐겨찾기 스테이션 그룹 제거
  Future<void> removeFavoriteStationGroup(StationGroup stationGroup) async {
    try {
      if (_favoritesBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      await _favoritesBox!.delete(stationGroup.stationName);
      KSYLog.info('즐겨찾기에서 ${stationGroup.cleanStationName} 제거');
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 제거 오류', e);
      throw Exception('즐겨찾기 제거에 실패했습니다: $e');
    }
  }

  /// 모든 즐겨찾기 제거
  Future<void> clearAllFavorites() async {
    try {
      if (_favoritesBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      await _favoritesBox!.clear();
      await _settingsBox?.clear();
      KSYLog.info('모든 즐겨찾기 제거 완료');
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 전체 제거 오류', e);
      throw Exception('즐겨찾기 전체 제거에 실패했습니다: $e');
    }
  }

  /// 특정 역명이 즐겨찾기에 있는지 확인
  Future<bool> isFavoriteStation(String stationName) async {
    try {
      if (_favoritesBox == null) {
        return false;
      }

      final cleanName = stationName.replaceAll('역', '').trim();
      
      // 정확한 키 매칭 먼저 시도
      if (_favoritesBox!.containsKey(cleanName)) {
        return true;
      }

      // 부분 매칭으로 검색
      final allGroups = _favoritesBox!.values;
      return allGroups.any((group) => group.cleanStationName == cleanName);
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 확인 오류', e);
      return false;
    }
  }

  /// 즐겨찾기 개수 반환
  Future<int> getFavoritesCount() async {
    try {
      if (_favoritesBox == null) {
        return 0;
      }
      return _favoritesBox!.length;
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 개수 확인 오류', e);
      return 0;
    }
  }

  /// SharedPreferences에서 Hive로 데이터 마이그레이션
  Future<void> migrateFromSharedPreferences() async {
    try {
      // SharedPreferences 기반 서비스 임포트가 필요한 경우
      // 기존 FavoritesStorageService에서 데이터 로드하여 Hive로 이전
      KSYLog.info('📦 SharedPreferences에서 Hive로 마이그레이션 시작');
      
      // 기존 데이터가 있다면 로드
      // final legacyFavorites = await FavoritesStorageService.loadFavoriteStationGroups();
      // if (legacyFavorites.isNotEmpty) {
      //   await saveFavoriteStationGroups(legacyFavorites);
      //   KSYLog.info('✅ ${legacyFavorites.length}개 즐겨찾기 마이그레이션 완료');
      // }
    } catch (e) {
      KSYLog.error('❌ 마이그레이션 오류', e);
    }
  }

  /// 저장소 상태 확인 (디버그용)
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      if (_favoritesBox == null) {
        return {'error': 'Box not initialized'};
      }

      final lastUpdateString = _settingsBox?.get(_lastUpdateKey) as String?;
      DateTime? lastUpdate;
      if (lastUpdateString != null) {
        lastUpdate = DateTime.parse(lastUpdateString);
      }

      return {
        'favorites_count': _favoritesBox!.length,
        'last_update': lastUpdate?.toIso8601String(),
        'box_path': _favoritesBox!.path,
        'box_size': _favoritesBox!.length,
      };
    } catch (e) {
      KSYLog.error('❌ 저장소 정보 확인 오류', e);
      return {'error': e.toString()};
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    try {
      await _favoritesBox?.close();
      await _settingsBox?.close();
      KSYLog.info('🔒 즐겨찾기 Hive Box 닫기 완료');
    } catch (e) {
      KSYLog.error('❌ 즐겨찾기 Hive 리소스 정리 오류', e);
    }
  }
}
