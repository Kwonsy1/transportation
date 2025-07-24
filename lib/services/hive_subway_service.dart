import 'package:hive_flutter/hive_flutter.dart';
import '../models/hive/seoul_subway_station_hive.dart';
import '../models/seoul_subway_station.dart';
import '../utils/ksy_log.dart';
import '../utils/location_utils.dart';
import '../utils/station_utils.dart';

/// Hive를 사용한 지하철역 정보 저장 서비스
class HiveSubwayService {
  static const String _boxName = 'seoul_subway_stations';
  static const String _settingsBoxName = 'subway_settings';
  static const String _lastUpdateKey = 'last_update_timestamp';
  static const Duration _cacheExpiration = Duration(days: 7);

  static HiveSubwayService? _instance;
  Box<SeoulSubwayStationHive>? _stationBox;
  Box? _settingsBox;

  HiveSubwayService._();

  static HiveSubwayService get instance {
    _instance ??= HiveSubwayService._();
    return _instance!;
  }

  /// Hive 초기화
  Future<void> initialize() async {
    try {
      // Hive 초기화
      await Hive.initFlutter();

      // 어댑터 등록
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SeoulSubwayStationHiveAdapter());
      }

      // Box 열기
      _stationBox = await Hive.openBox<SeoulSubwayStationHive>(_boxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);

      KSYLog.info('✅ Hive 초기화 완료');
      KSYLog.info('📊 저장된 역 수: ${_stationBox?.length ?? 0}개');
    } catch (e) {
      KSYLog.error('❌ Hive 초기화 오류', e);
      rethrow;
    }
  }

  /// 모든 지하철역 정보 조회
  List<SeoulSubwayStationHive> getAllStations() {
    try {
      if (_stationBox == null) {
        KSYLog.warning('⚠️ Hive Box가 초기화되지 않음');
        return [];
      }

      final stations = _stationBox!.values.toList();
      KSYLog.debug('📖 Hive에서 ${stations.length}개 역 조회');
      return stations;
    } catch (e) {
      KSYLog.error('❌ 역 정보 조회 오류', e);
      return [];
    }
  }

  /// 지하철역 정보 저장 (일괄)
  Future<void> saveStations(List<SeoulSubwayStation> stations) async {
    try {
      if (_stationBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      // 기존 데이터 클리어
      await _stationBox!.clear();

      // 새 데이터 저장
      final hiveStations = stations
          .map(
            (station) => SeoulSubwayStationHive.fromSeoulSubwayStation(station),
          )
          .toList();

      // 역명을 키로 사용하여 저장
      final Map<String, SeoulSubwayStationHive> stationMap = {};
      for (final station in hiveStations) {
        final key = '${station.stationName}_${station.lineName}';
        stationMap[key] = station;
      }

      await _stationBox!.putAll(stationMap);

      // 마지막 업데이트 시간 저장
      await _settingsBox?.put(_lastUpdateKey, DateTime.now().toIso8601String());

      KSYLog.info('💾 ${stations.length}개 역 정보가 Hive에 저장됨');
    } catch (e) {
      KSYLog.error('❌ 역 정보 저장 오류', e);
      rethrow;
    }
  }

  /// 특정 역의 좌표 업데이트
  Future<void> updateStationCoordinates(
    String stationName,
    String lineName,
    double latitude,
    double longitude,
  ) async {
    try {
      if (_stationBox == null) {
        throw Exception('Hive Box가 초기화되지 않음');
      }

      final key = '${stationName}_$lineName';
      final existingStation = _stationBox!.get(key);

      if (existingStation != null) {
        final updatedStation = existingStation.updateCoordinates(
          latitude,
          longitude,
        );
        await _stationBox!.put(key, updatedStation);
        KSYLog.debug('📍 $stationName 좌표 업데이트: $latitude, $longitude');
      } else {
        KSYLog.warning('⚠️ 역을 찾을 수 없음: $stationName ($lineName)');
      }
    } catch (e) {
      KSYLog.error('❌ 좌표 업데이트 오류', e);
      rethrow;
    }
  }

  /// 좌표가 없는 역들 조회
  List<SeoulSubwayStationHive> getStationsWithoutCoordinates() {
    try {
      final allStations = getAllStations();
      return allStations.where((station) => station.isCoordinateEmpty).toList();
    } catch (e) {
      KSYLog.error('❌ 좌표 없는 역 조회 오류', e);
      return [];
    }
  }

  /// 좌표 통계 정보
  Map<String, int> getCoordinateStatistics() {
    try {
      final allStations = getAllStations();
      int hasValidCoordinates = 0;
      int missingCoordinates = 0;

      for (final station in allStations) {
        if (station.isCoordinateValid) {
          hasValidCoordinates++;
        } else {
          missingCoordinates++;
        }
      }

      return {
        'total': allStations.length,
        'hasCoordinates': hasValidCoordinates,
        'missingCoordinates': missingCoordinates,
      };
    } catch (e) {
      KSYLog.error('❌ 좌표 통계 조회 오류', e);
      return {'total': 0, 'hasCoordinates': 0, 'missingCoordinates': 0};
    }
  }

  /// 캐시가 만료되었는지 확인
  bool isCacheExpired() {
    try {
      final lastUpdateString = _settingsBox?.get(_lastUpdateKey) as String?;
      if (lastUpdateString == null) return true;

      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();

      return now.difference(lastUpdate) > _cacheExpiration;
    } catch (e) {
      KSYLog.error('❌ 캐시 만료 확인 오류', e);
      return true;
    }
  }

  /// 특정 역 검색
  List<SeoulSubwayStationHive> searchStations(String query) {
    try {
      final allStations = getAllStations();
      return StationUtils.searchStations(
        allStations,
        query,
        (station) => station.stationName,
      );
    } catch (e) {
      KSYLog.error('❌ 역 검색 오류', e);
      return [];
    }
  }

  /// 주변 역 검색
  List<SeoulSubwayStationHive> searchNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
  }) {
    try {
      final allStations = getAllStations()
          .where((station) => station.isCoordinateValid)
          .toList();

      final nearbyStations = <SeoulSubwayStationHive>[];

      for (final station in allStations) {
        final distance = LocationUtils.calculateDistanceKm(
          latitude,
          longitude,
          station.latitude,
          station.longitude,
        );

        if (distance <= radiusKm) {
          nearbyStations.add(station);
        }
      }

      // 거리순으로 정렬
      nearbyStations.sort((a, b) {
        final distanceA = LocationUtils.calculateDistanceKm(
          latitude,
          longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = LocationUtils.calculateDistanceKm(
          latitude,
          longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyStations;
    } catch (e) {
      KSYLog.error('❌ 주변 역 검색 오류', e);
      return [];
    }
  }

  /// 모든 데이터 삭제
  Future<void> clearAllData() async {
    try {
      await _stationBox?.clear();
      await _settingsBox?.clear();
      KSYLog.info('🗑️ 모든 Hive 데이터 삭제됨');
    } catch (e) {
      KSYLog.error('❌ 데이터 삭제 오류', e);
      rethrow;
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    try {
      await _stationBox?.close();
      await _settingsBox?.close();
      KSYLog.info('🔒 Hive Box 닫기 완료');
    } catch (e) {
      KSYLog.error('❌ Hive 리소스 정리 오류', e);
    }
  }

}
