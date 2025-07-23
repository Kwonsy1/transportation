import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../models/hive/seoul_subway_station_hive.dart';
import '../services/seoul_subway_api_service.dart';
import '../services/nominatim_geocoding_service.dart';
export '../services/nominatim_geocoding_service.dart' show NominatimLocation;
import '../services/hive_subway_service.dart';
import '../utils/ksy_log.dart';

/// 서울 지하철 역 정보를 관리하는 프로바이더
class SeoulSubwayProvider extends ChangeNotifier {
  final SeoulSubwayApiService _apiService = SeoulSubwayApiService();
  final NominatimGeocodingService _geocodingService =
      NominatimGeocodingService();
  final HiveSubwayService _hiveService = HiveSubwayService.instance;

  // 상태 관리
  List<SeoulSubwayStation> _allStations = [];
  List<SeoulSubwayStation> _searchResults = [];
  List<SeoulSubwayStation> _nearbyStations = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 좌표 업데이트 상태
  bool _isUpdatingCoordinates = false;
  int _coordinateUpdateProgress = 0;
  int _totalStationsToUpdate = 0;
  String? _currentUpdatingStation;

  // Hive 초기화 상태
  bool _isHiveInitialized = false;

  // Getters
  List<SeoulSubwayStation> get allStations => _allStations;
  List<SeoulSubwayStation> get searchResults => _searchResults;
  List<SeoulSubwayStation> get nearbyStations => _nearbyStations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasStations => _allStations.isNotEmpty;

  // 좌표 업데이트 상태 Getters
  bool get isUpdatingCoordinates => _isUpdatingCoordinates;
  int get coordinateUpdateProgress => _coordinateUpdateProgress;
  int get totalStationsToUpdate => _totalStationsToUpdate;
  String? get currentUpdatingStation => _currentUpdatingStation;
  double get updateProgressPercent => _totalStationsToUpdate > 0
      ? (_coordinateUpdateProgress / _totalStationsToUpdate) * 100
      : 0.0;

  /// 지하철 역 데이터 초기화
  Future<void> initialize() async {
    if (_allStations.isNotEmpty) return;

    _setLoading(true);
    _clearError();

    try {
      // Hive 초기화
      await _initializeHive();

      // Hive에서 먼저 시도
      final cachedStations = await _loadFromHive();
      if (cachedStations.isNotEmpty) {
        _allStations = cachedStations;
        notifyListeners();

        final stats = getCoordinateStatistics();
        KSYLog.info('Hive에서 ${_allStations.length}개 역 정보 로드됨');
        KSYLog.info(
          '📍 좌표 통계: ${stats['hasCoordinates']}/${stats['total']} (미업데이트: ${stats['missingCoordinates']})',
        );

        // 백그라운드에서 업데이트 시도 (좌표 보존)
        _updateInBackground();
        _setLoading(false);
        return;
      }

      // Hive에 데이터가 없으면 API에서 가져오기
      await _fetchStationsFromApi();
    } catch (e) {
      _setError('지하철 역 정보를 불러오는데 실패했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 기존 좌표 데이터를 새 데이터에 병합
  List<SeoulSubwayStation> _mergeCoordinateData(
    List<SeoulSubwayStation> existingStations,
    List<SeoulSubwayStation> newStations,
  ) {
    final mergedStations = <SeoulSubwayStation>[];
    int coordinatesPreserved = 0;
    int coordinatesLost = 0;

    for (final newStation in newStations) {
      // 기존 데이터에서 동일한 역 찾기 (호선도 함께 비교)
      SeoulSubwayStation? existingStation;
      try {
        existingStation = existingStations
            .where(
              (existing) =>
                  _isSameStation(
                    existing.stationName,
                    newStation.stationName,
                  ) &&
                  existing.lineName == newStation.lineName,
            )
            .first;
      } catch (e) {
        // 호선이 다르면 역명만으로 찾기
        try {
          existingStation = existingStations
              .where(
                (existing) => _isSameStation(
                  existing.stationName,
                  newStation.stationName,
                ),
              )
              .first;
        } catch (e) {
          existingStation = null;
        }
      }

      if (existingStation != null &&
          existingStation.latitude != 0.0 &&
          existingStation.longitude != 0.0) {
        // 기존에 좌표가 있으면 기존 좌표 사용
        mergedStations.add(
          SeoulSubwayStation(
            stationName: newStation.stationName,
            lineName: newStation.lineName,
            latitude: existingStation.latitude, // 기존 좌표 보존
            longitude: existingStation.longitude, // 기존 좌표 보존
            stationCode: newStation.stationCode,
            subwayTypeName: newStation.subwayTypeName,
          ),
        );
        coordinatesPreserved++;
      } else {
        // 기존에 좌표가 없으면 새 데이터 사용
        mergedStations.add(newStation);
        if (existingStation != null) {
          coordinatesLost++;
        }
      }
    }

    KSYLog.info('🔄 데이터 병합 완료: ${mergedStations.length}개 역');
    KSYLog.info('📍 좌표 보존: $coordinatesPreserved개, 손실: $coordinatesLost개');
    return mergedStations;
  }

  /// Hive 초기화
  Future<void> _initializeHive() async {
    if (_isHiveInitialized) return;

    try {
      await _hiveService.initialize();
      _isHiveInitialized = true;
      KSYLog.database('Initialize', 'Hive subway service', null);
    } catch (e) {
      KSYLog.error('Hive 초기화 실패', e);
      rethrow;
    }
  }

  /// API에서 역 정보 가져오기
  Future<void> _fetchStationsFromApi() async {
    KSYLog.debug('API에서 지하철 역 정보 가져오는 중...');

    final stations = await _apiService.getAllStations();

    if (stations.isNotEmpty) {
      _allStations = stations;
      await _saveToHive(stations);
      KSYLog.info('API에서 ${_allStations.length}개 역 정보 로드됨');
      notifyListeners();
    } else {
      throw Exception('API에서 데이터를 가져올 수 없습니다');
    }
  }

  /// 백그라운드에서 데이터 업데이트
  Future<void> _updateInBackground() async {
    try {
      // 캐시가 만료되었는지 확인
      if (!_hiveService.isCacheExpired()) {
        KSYLog.info('Hive 캐시가 아직 유효함 - 백그라운드 업데이트 건너뛰기');
        return;
      }

      KSYLog.warning('⚠️ 백그라운드 업데이트 시작 - 좌표 데이터 손실 위험!');

      // 기존 좌표 통계 확인
      final beforeStats = getCoordinateStatistics();
      KSYLog.info(
        '📊 업데이트 전 좌표 통계: ${beforeStats['hasCoordinates']}/${beforeStats['total']}',
      );

      final stations = await _apiService.getAllStations();
      if (stations.isNotEmpty && stations.length != _allStations.length) {
        // 새로 받은 데이터에 기존 좌표 정보 병합
        final mergedStations = _mergeCoordinateData(_allStations, stations);

        _allStations = mergedStations;
        await _saveToHive(mergedStations);
        notifyListeners();

        final afterStats = getCoordinateStatistics();
        KSYLog.info(
          '📊 업데이트 후 좌표 통계: ${afterStats['hasCoordinates']}/${afterStats['total']}',
        );
        KSYLog.info('백그라운드에서 역 정보 업데이트됨 (좌표 보존)');
      }
    } catch (e) {
      KSYLog.error('백그라운드 업데이트 실패', e);
      // 에러는 무시 (사용자에게 표시하지 않음)
    }
  }

  /// 역명으로 검색
  Future<void> searchStations(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      // 로컬 데이터가 있으면 로컬에서 검색
      if (_allStations.isNotEmpty) {
        _searchResults = _allStations.where((station) {
          final stationName = station.stationName.toLowerCase();
          final searchQuery = query.toLowerCase();
          return stationName.contains(searchQuery) ||
              stationName
                  .replaceAll('역', '')
                  .contains(searchQuery.replaceAll('역', ''));
        }).toList();
      } else {
        // 로컬 데이터가 없으면 API 검색
        _searchResults = await _apiService.searchStationsByName(query);
      }

      KSYLog.info('검색 결과: ${_searchResults.length}개 역');
    } catch (e) {
      _setError('검색 중 오류가 발생했습니다: $e');
      _searchResults = [];
    } finally {
      _setLoading(false);
    }
  }

  /// 주변 역 검색
  Future<void> searchNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // 로컬 데이터가 없으면 먼저 초기화
      if (_allStations.isEmpty) {
        await initialize();
      }

      _nearbyStations = await _apiService.searchNearbyStations(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      KSYLog.info('주변 역 검색 결과: ${_nearbyStations.length}개 역');
    } catch (e) {
      _setError('주변 역 검색 중 오류가 발생했습니다: $e');
      _nearbyStations = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Hive에서 데이터 로드
  Future<List<SeoulSubwayStation>> _loadFromHive() async {
    try {
      final hiveStations = _hiveService.getAllStations();
      return hiveStations
          .map((hiveStation) => hiveStation.toSeoulSubwayStation())
          .toList();
    } catch (e) {
      KSYLog.error('Hive 로드 오류', e);
      return [];
    }
  }

  /// Hive에 데이터 저장
  Future<void> _saveToHive(List<SeoulSubwayStation> stations) async {
    try {
      await _hiveService.saveStations(stations);
      KSYLog.info('💾 ${stations.length}개 역 정보가 Hive에 저장되었습니다');

      // 즈시 검증
      await _immediateVerification(stations);
    } catch (e) {
      KSYLog.error('Hive 저장 오류', e);
    }
  }

  /// 즈시 저장 검증
  Future<void> _immediateVerification(
    List<SeoulSubwayStation> originalStations,
  ) async {
    try {
      // 즈시 다시 로드해서 비교
      final reloadedStations = await _loadFromHive();

      final originalStats = _calculateStats(originalStations);
      final reloadedStats = _calculateStats(reloadedStations);

      KSYLog.debug(
        '🔍 즉시 검증: 원본 ${originalStats['hasCoordinates']} vs 로드 ${reloadedStats['hasCoordinates']}',
      );

      if (originalStats['hasCoordinates'] != reloadedStats['hasCoordinates']) {
        KSYLog.warning('⚠️ 좌표 데이터 손실 발견! Hive 저장/로드 과정에 문제 있음');
      } else {
        KSYLog.info('✅ 좌표 데이터 보존 확인됨');
      }
    } catch (e) {
      KSYLog.error('❌ 즉시 검증 오류', e);
    }
  }

  /// 통계 계산 헬퍼
  Map<String, int> _calculateStats(List<SeoulSubwayStation> stations) {
    int hasValidCoordinates = 0;
    for (final station in stations) {
      if (station.latitude != 0.0 && station.longitude != 0.0) {
        hasValidCoordinates++;
      }
    }
    return {
      'total': stations.length,
      'hasCoordinates': hasValidCoordinates,
      'missingCoordinates': stations.length - hasValidCoordinates,
    };
  }

  /// Hive 데이터 초기화
  /// [preserveCoordinates] 좌표 데이터 보존 여부 (기본값: false)
  Future<void> clearCache({bool preserveCoordinates = false}) async {
    try {
      if (preserveCoordinates) {
        // 좌표가 있는 역들의 백업 생성
        final stationsWithCoordinates = _allStations
            .where(
              (station) => station.latitude != 0.0 && station.longitude != 0.0,
            )
            .toList();

        KSYLog.info('🔒 좌표 보존 모드: ${stationsWithCoordinates.length}개 역의 좌표 데이터 백업');

        // 전체 데이터 삭제
        await _hiveService.clearAllData();

        // 좌표 데이터만 복원
        if (stationsWithCoordinates.isNotEmpty) {
          await _saveToHive(stationsWithCoordinates);
          KSYLog.info('📍 좌표 데이터 복원 완료: ${stationsWithCoordinates.length}개 역');
        }
      } else {
        await _hiveService.clearAllData();
        KSYLog.info('🗑️ 모든 Hive 데이터가 초기화되었습니다');
      }
    } catch (e) {
      KSYLog.error('❌ Hive 초기화 오류', e);
    }
  }

  /// 데이터 새로고침 (좌표 데이터 보존)
  /// [forceFullRefresh] 강제 전체 새로고침 (좌표 데이터도 삭제)
  Future<void> refresh({bool forceFullRefresh = false}) async {
    _setLoading(true);
    _clearError();

    try {
      if (forceFullRefresh) {
        // 강제 전체 새로고침 (기존 방식)
        KSYLog.info('🔄 강제 전체 새로고침 시작');
        await clearCache();
        _allStations = [];
        _searchResults = [];
        _nearbyStations = [];
        await initialize();
        KSYLog.info('✅ 강제 전체 새로고침 완료');
        return;
      }

      // 스마트 새로고침 (좌표 데이터 보존)
      final existingStations = List<SeoulSubwayStation>.from(_allStations);
      final beforeStats = getCoordinateStatistics();
      KSYLog.info(
        '📋 기존 좌표 데이터 백업: ${existingStations.length}개 역 (좌표 있음: ${beforeStats['hasCoordinates']}개)',
      );

      // 검색 결과 초기화
      _searchResults = [];
      _nearbyStations = [];

      // API에서 최신 데이터 가져오기
      final freshStations = await _apiService.getAllStations();
      KSYLog.info('🔄 API에서 새로운 데이터 ${freshStations.length}개 역 받음');

      if (freshStations.isNotEmpty) {
        // 기존 좌표 데이터를 새 데이터에 병합
        final mergedStations = _mergeCoordinateData(
          existingStations,
          freshStations,
        );

        _allStations = mergedStations;

        // 병합된 데이터를 Hive에 저장
        await _saveToHive(mergedStations);

        final afterStats = getCoordinateStatistics();
        KSYLog.info('✅ 스마트 새로고침 완료: ${_allStations.length}개 역');
        KSYLog.info(
          '📍 좌표 보존 결과: ${beforeStats['hasCoordinates']} → ${afterStats['hasCoordinates']}개',
        );

        if (afterStats['hasCoordinates']! < beforeStats['hasCoordinates']!) {
          KSYLog.warning('⚠️ 경고: 좌표 데이터 일부 손실 발생!');
        }
      } else {
        KSYLog.warning('⚠️ API에서 새로운 데이터를 받지 못함 - 기존 데이터 유지');
      }
    } catch (e) {
      _setError('새로고침 중 오류가 발생했습니다: $e');
      KSYLog.error('❌ 새로고침 오류', e);
    } finally {
      _setLoading(false);
    }
  }

  /// 특정 역의 SubwayStation 객체 반환
  SubwayStation? getSubwayStation(String stationName) {
    try {
      final station = _allStations.firstWhere(
        (station) => station.stationName == stationName,
      );
      return station.toSubwayStation();
    } catch (e) {
      return null;
    }
  }

  /// 특정 역명의 모든 호선 정보 반환
  List<SeoulSubwayStation> getStationsByName(String stationName) {
    final normalizedSearchName = _normalizeStationName(stationName);
    
    return _allStations.where((station) {
      final normalizedStationName = _normalizeStationName(station.stationName);
      return normalizedStationName == normalizedSearchName;
    }).toList();
  }

  /// 모든 역을 SubwayStation 리스트로 변환
  List<SubwayStation> getAllSubwayStations() {
    return _allStations.map((station) => station.toSubwayStation()).toList();
  }

  /// 좌표 업데이트 상태 초기화
  void clearCoordinateUpdateResults() {
    _coordinateUpdateProgress = 0;
    _totalStationsToUpdate = 0;
    _currentUpdatingStation = null;
    notifyListeners();
  }

  /// 서울 지하철 역들의 좌표 업데이트 (Nominatim API 사용)
  ///
  /// 서울 API에서 받은 역들의 좌표를 Nominatim API로 업데이트
  Future<void> updateCoordinatesForSubwayStations(
    List<SubwayStation> stations,
  ) async {
    if (_isUpdatingCoordinates) {
      throw Exception('이미 좌표 업데이트가 진행 중입니다.');
    }

    _isUpdatingCoordinates = true;
    _coordinateUpdateProgress = 0;
    // 모든 역을 대상으로 하도록 수정 (기존 좌표도 업데이트)
    _totalStationsToUpdate = stations.length;
    _clearError();
    notifyListeners();

    try {
      KSYLog.info('📍 좌표 업데이트 시작: 총 $_totalStationsToUpdate개 역');

      final updatedStations = await _geocodingService
          .batchUpdateStationCoordinates(
            stations: stations,
            forceUpdate: true, // 강제 업데이트 활성화
            onProgress: (current, total) {
              _coordinateUpdateProgress = current;
              KSYLog.debug('🔄 진행률: $current/$total');
              notifyListeners();
            },
            onStationUpdated: (updatedStation) {
              _currentUpdatingStation = updatedStation.subwayStationName;
              KSYLog.debug('📍 업데이트 완료: ${updatedStation.subwayStationName}');
              notifyListeners();
            },
          );

      KSYLog.info('✅ 좌표 업데이트 완료: ${updatedStations.length}개 역');

      // 업데이트된 역 수 세기
      final coordinatesUpdated = updatedStations
          .where((s) => s.latitude != null && s.longitude != null)
          .length;

      KSYLog.info('📍 좌표가 업데이트된 역: $coordinatesUpdated개');

      // 업데이트된 데이터를 서울 지하철 데이터에도 반영
      await _updateSeoulStationsWithCoordinates(updatedStations);
    } catch (e) {
      _setError('좌표 업데이트 중 오류가 발생했습니다: $e');
      KSYLog.error('😨 좌표 업데이트 오류', e);
    } finally {
      _isUpdatingCoordinates = false;
      _currentUpdatingStation = null;
      notifyListeners();
    }
  }

  /// 역명 정규화 ("역" 제거 및 공백 정리)
  String _normalizeStationName(String stationName) {
    return stationName.replaceAll('역', '').replaceAll(' ', '').toLowerCase();
  }

  /// 두 역명이 같은 역인지 확인 (정규화 후 비교)
  bool _isSameStation(String stationName1, String stationName2) {
    final normalized1 = _normalizeStationName(stationName1);
    final normalized2 = _normalizeStationName(stationName2);
    return normalized1 == normalized2;
  }

  /// 업데이트된 좌표를 서울 지하철 데이터에 반영
  Future<void> _updateSeoulStationsWithCoordinates(
    List<SubwayStation> updatedStations,
  ) async {
    try {
      int updateCount = 0;
      int matchFailCount = 0;

      KSYLog.info('🔄 좌표 반영 시작: ${updatedStations.length}개 역 처리');

      // 업데이트된 좌표를 서울 지하철 데이터에 적용
      for (final updatedStation in updatedStations) {
        // 역명 정규화를 통한 매칭
        final index = _allStations.indexWhere(
          (station) => _isSameStation(
            station.stationName,
            updatedStation.subwayStationName,
          ),
        );

        if (index != -1 &&
            updatedStation.latitude != null &&
            updatedStation.longitude != null &&
            updatedStation.latitude != 0.0 &&
            updatedStation.longitude != 0.0) {
          // 기존 서울 지하철 데이터에 좌표 업데이트
          final originalStation = _allStations[index];
          final updatedSeoulStation = SeoulSubwayStation(
            stationName: originalStation.stationName,
            lineName: originalStation.lineName,
            latitude: updatedStation.latitude!,
            longitude: updatedStation.longitude!,
            stationCode: originalStation.stationCode,
            subwayTypeName: originalStation.subwayTypeName,
          );

          _allStations[index] = updatedSeoulStation;
          updateCount++;

          KSYLog.debug(
            '📍 ${originalStation.stationName} 좌표 업데이트: ${updatedStation.latitude}, ${updatedStation.longitude}',
          );

          // 즉시 Hive에 개별 업데이트
          await _hiveService.updateStationCoordinates(
            originalStation.stationName,
            originalStation.lineName,
            updatedStation.latitude!,
            updatedStation.longitude!,
          );
        } else {
          matchFailCount++;

          if (updatedStation.latitude == null ||
              updatedStation.longitude == null ||
              updatedStation.latitude == 0.0 ||
              updatedStation.longitude == 0.0) {
            KSYLog.debug(
              '❌ 좌표 없음: "${updatedStation.subwayStationName}" (좌표: ${updatedStation.latitude}, ${updatedStation.longitude})',
            );
          } else {
            KSYLog.debug(
              '❌ 매칭 실패: "${updatedStation.subwayStationName}" (좌표: ${updatedStation.latitude}, ${updatedStation.longitude})',
            );

            // 디버깅을 위해 가장 유사한 역명 찾기
            final similarStations = _allStations
                .where(
                  (station) =>
                      station.stationName.contains(
                        _normalizeStationName(updatedStation.subwayStationName),
                      ) ||
                      _normalizeStationName(
                        updatedStation.subwayStationName,
                      ).contains(_normalizeStationName(station.stationName)),
                )
                .take(3)
                .toList();

            if (similarStations.isNotEmpty) {
              KSYLog.debug(
                '   🔍 유사한 역명들: ${similarStations.map((s) => s.stationName).join(", ")}',
              );
            }
          }
        }
      }

      KSYLog.info('💾 업데이트 결과: 성공 $updateCount개, 매칭실패 $matchFailCount개');

      // 전체 데이터를 Hive에 저장 (백업)
      await _saveToHive(_allStations);
      notifyListeners();

      KSYLog.info('💾 업데이트된 좌표 데이터가 Hive에 저장되었습니다.');

      // 저장 후 검증
      await _verifyHiveSave();
    } catch (e) {
      KSYLog.error('😨 서울 지하철 데이터 업데이트 오류', e);
    }
  }

  /// 특정 역의 좌표 검색
  ///
  /// [stationName] 검색할 역명
  Future<List<NominatimLocation>> searchStationCoordinates(
    String stationName,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final locations = await _geocodingService.searchStationCoordinates(
        stationName: stationName,
        includeCountry: true,
        limitResults: 5,
      );

      KSYLog.info('📍 $stationName 검색 결과: ${locations.length}개');
      return locations;
    } catch (e) {
      _setError('좌표 검색 중 오류가 발생했습니다: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// 강제 전체 새로고침 (좌표 포함 모든 데이터 삭제)
  Future<void> forceFullRefresh() async {
    KSYLog.info('🔄 강제 전체 새로고침 시작 - 모든 데이터 삭제');
    await refresh(forceFullRefresh: true);
  }

  /// 좌표가 없는(null 또는 0.0) 역들만 선택적으로 업데이트
  Future<void> updateMissingCoordinatesOnly() async {
    if (_isUpdatingCoordinates) {
      throw Exception('이미 좌표 업데이트가 진행 중입니다.');
    }

    KSYLog.info('🔍 좌표 상태 분석 시작...');

    // 좌표가 없는 역들만 필터링
    final stationsNeedingUpdate = _allStations
        .where((station) => station.latitude == 0.0 || station.longitude == 0.0)
        .toList();

    KSYLog.info('📊 전체 역 수: ${_allStations.length}');
    KSYLog.info('📊 좌표가 없는 역 수: ${stationsNeedingUpdate.length}');

    // 디버깅: 좌표가 없는 역들 목록 출력 (처음 5개만)
    final sampleStations = stationsNeedingUpdate.take(5).toList();
    for (final station in sampleStations) {
      KSYLog.debug(
        '❌ ${station.stationName}: lat=${station.latitude}, lng=${station.longitude}',
      );
    }

    if (stationsNeedingUpdate.isEmpty) {
      KSYLog.info('✅ 모든 역에 좌표가 이미 설정되어 있습니다.');
      return;
    }

    KSYLog.info('📍 좌표가 없는 ${stationsNeedingUpdate.length}개 역만 업데이트 시작');

    // SubwayStation으로 변환
    final subwayStations = stationsNeedingUpdate
        .map((station) => station.toSubwayStation())
        .toList();

    // 변환된 SubwayStation 객체들도 확인
    KSYLog.debug('🔄 SubwayStation 변환 완료: ${subwayStations.length}개');
    for (int i = 0; i < math.min(3, subwayStations.length); i++) {
      final station = subwayStations[i];
      KSYLog.debug(
        '🔄 변환된 역 $i: ${station.subwayStationName} (lat: ${station.latitude}, lng: ${station.longitude})',
      );
    }

    _isUpdatingCoordinates = true;
    _coordinateUpdateProgress = 0;
    _totalStationsToUpdate = subwayStations.length;
    _clearError();
    notifyListeners();

    try {
      KSYLog.info('🚀 Nominatim 업데이트 시작: ${subwayStations.length}개 역');

      final updatedStations = await _geocodingService.batchUpdateStationCoordinates(
        stations: subwayStations,
        forceUpdate: false, // 이미 좌표가 있는 역은 건너뛰기
        onProgress: (current, total) {
          _coordinateUpdateProgress = current;
          KSYLog.debug('🔄 진행률: $current/$total');
          notifyListeners();
        },
        onStationUpdated: (updatedStation) {
          _currentUpdatingStation = updatedStation.subwayStationName;
          KSYLog.debug(
            '📍 업데이트 완료: ${updatedStation.subwayStationName} (${updatedStation.latitude}, ${updatedStation.longitude})',
          );
          notifyListeners();
        },
      );

      KSYLog.info('✅ 선택적 좌표 업데이트 완료: ${updatedStations.length}개 역');

      // 실제로 좌표가 업데이트된 역 수 확인
      final successfulUpdates = updatedStations
          .where(
            (station) =>
                station.latitude != null &&
                station.longitude != null &&
                station.latitude != 0.0 &&
                station.longitude != 0.0,
          )
          .length;

      KSYLog.info('📍 실제로 좌표가 업데이트된 역: $successfulUpdates개');

      // 업데이트된 데이터를 서울 지하철 데이터에도 반영
      await _updateSeoulStationsWithCoordinates(updatedStations);
    } catch (e) {
      _setError('좌표 업데이트 중 오류가 발생했습니다: $e');
      KSYLog.error('😨 좌표 업데이트 오류', e);
    } finally {
      _isUpdatingCoordinates = false;
      _currentUpdatingStation = null;
      notifyListeners();
    }
  }

  /// 좌표 상태 분석 - 통계 정보 반환
  Map<String, int> getCoordinateStatistics() {
    // Hive 서비스에서 통계 정보 가져오기
    if (_isHiveInitialized) {
      return _hiveService.getCoordinateStatistics();
    }

    // Fallback: 메모리에 있는 데이터로 계산
    int totalStations = _allStations.length;
    int hasValidCoordinates = 0;
    int missingCoordinates = 0;

    for (final station in _allStations) {
      if (station.latitude != 0.0 && station.longitude != 0.0) {
        hasValidCoordinates++;
      } else {
        missingCoordinates++;
      }
    }

    return {
      'total': totalStations,
      'hasCoordinates': hasValidCoordinates,
      'missingCoordinates': missingCoordinates,
    };
  }

  /// Hive 저장 후 검증
  Future<void> _verifyHiveSave() async {
    try {
      final reloadedStations = await _loadFromHive();

      // 몇 개 역의 좌표를 무작위로 검증
      final sampleStations = ['명동역', '강남역', '홍대입구역'];

      for (final stationName in sampleStations) {
        try {
          final memoryStation = _allStations
              .where(
                (s) => s.stationName.contains(stationName.replaceAll('역', '')),
              )
              .first;
          final hiveStation = reloadedStations
              .where(
                (s) => s.stationName.contains(stationName.replaceAll('역', '')),
              )
              .first;

          KSYLog.debug(
            '🔍 $stationName 검증: '
            '메모리(${memoryStation.latitude}, ${memoryStation.longitude}) '
            'vs Hive(${hiveStation.latitude}, ${hiveStation.longitude})',
          );

          if (memoryStation.latitude != hiveStation.latitude ||
              memoryStation.longitude != hiveStation.longitude) {
            KSYLog.warning('⚠️ $stationName 좌표 불일치 발견!');
          }
        } catch (e) {
          KSYLog.debug('🔍 $stationName: 검증 대상 역을 찾을 수 없음');
        }
      }
    } catch (e) {
      KSYLog.error('❌ Hive 저장 검증 오류', e);
    }
  }

  /// 검색 결과 초기화
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// 주변 역 결과 초기화
  void clearNearbyResults() {
    _nearbyStations = [];
    notifyListeners();
  }

  // 내부 메서드들
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    KSYLog.error('SeoulSubwayProvider 오류: $error');
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Hive 리소스 정리
    _hiveService.dispose();
    super.dispose();
  }
}
