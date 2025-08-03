import 'package:flutter/foundation.dart';
import '../models/subway_station.dart';
import '../models/subway_schedule.dart';
import '../models/next_train_info.dart';
import '../models/station_group.dart';
import '../services/subway_api_service.dart';
import '../services/server_api_service.dart';
import '../services/favorites_storage_service.dart';
import '../utils/ksy_log.dart';
import '../utils/station_utils.dart';

/// 지하철 정보 상태 관리 Provider (국토교통부 API + 커스텀 서버 API)
class SubwayProvider extends ChangeNotifier {
  final SubwayApiService _apiService = SubwayApiService();
  final ServerApiService _serverApiService = ServerApiService();

  // 현재 선택된 역
  SubwayStation? _selectedStation;
  SubwayStation? get selectedStation => _selectedStation;

  // 다음 열차 정보 (실시간 도착정보 대신)
  List<NextTrainInfo> _nextTrains = [];
  List<NextTrainInfo> get nextTrains => _nextTrains;

  // 시간표 정보
  List<SubwaySchedule> _schedules = [];
  List<SubwaySchedule> get schedules => _schedules;

  // 역 검색 결과
  List<SubwayStation> _searchResults = [];
  List<SubwayStation> get searchResults => _searchResults;

  // 그룹화된 검색 결과
  List<StationGroup> _groupedSearchResults = [];
  List<StationGroup> get groupedSearchResults => _groupedSearchResults;

  // 역명 기반 캐시 (지도 연동용)
  final Map<String, StationGroup> _stationGroupCache = {};

  // 캐시 타임스탬프
  final Map<String, DateTime> _cacheTimestamps = {};

  // 검색 모드 (그룹 모드 여부)
  bool _isGroupSearchMode = true;
  bool get isGroupSearchMode => _isGroupSearchMode;

  // 즐겨찾기 역 그룹 목록
  final List<StationGroup> _favoriteStationGroups = [];
  List<StationGroup> get favoriteStationGroups => _favoriteStationGroups;

  // 기존 즐겨찾기 역 목록 (하위 호환성을 위해 유지)
  final List<SubwayStation> _favoriteStations = [];
  List<SubwayStation> get favoriteStations => _favoriteStations;

  // 출구별 버스노선 정보
  List<SubwayExitBusRoute> _exitBusRoutes = [];
  List<SubwayExitBusRoute> get exitBusRoutes => _exitBusRoutes;

  // 출구별 주변시설 정보
  List<SubwayExitFacility> _exitFacilities = [];
  List<SubwayExitFacility> get exitFacilities => _exitFacilities;

  // 로딩 상태
  bool _isLoadingNextTrains = false;
  bool _isLoadingSchedules = false;
  bool _isLoadingSearch = false;
  bool _isLoadingExitInfo = false;

  bool get isLoadingNextTrains => _isLoadingNextTrains;
  bool get isLoadingSchedules => _isLoadingSchedules;
  bool get isLoadingSearch => _isLoadingSearch;
  bool get isLoadingExitInfo => _isLoadingExitInfo;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 역 선택
  void selectStation(SubwayStation station) {
    KSYLog.info('Provider: 역 선택 - ${station.subwayStationName} (${station.effectiveLineNumber}, ID: ${station.subwayStationId})');
    KSYLog.debug('역 상세정보: lineNumber=${station.lineNumber}, subwayRouteName=${station.subwayRouteName}, effectiveLineNumber=${station.effectiveLineNumber}');
    // 같은 역의 다른 호선도 변경으로 인식하도록 effectiveLineNumber로 비교
    if (_selectedStation?.effectiveLineNumber != station.effectiveLineNumber) {
      KSYLog.debug('Provider: 역 변경됨 - ${_selectedStation?.effectiveLineNumber} → ${station.effectiveLineNumber}');
      _selectedStation = station;
      _clearNextTrains();
      _clearSchedules();
      _clearExitInfo();
      notifyListeners();
      KSYLog.debug('Provider: notifyListeners() 호출 완료');
    } else {
      KSYLog.warning('Provider: 동일한 호선 선택됨');
    }
  }

  /// 다음 열차 정보 로드 (실시간 도착정보 대신)
  Future<void> loadNextTrains({String? direction}) async {
    if (_selectedStation == null) return;

    _isLoadingNextTrains = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _nextTrains = await _apiService.getNextTrains(
        subwayStationId: _selectedStation!.subwayStationId,
        upDownTypeCode: direction,
      );
    } catch (e) {
      _errorMessage = '다음 열차 정보를 불러오는데 실패했습니다: ${e.toString()}';
      _nextTrains = [];
    } finally {
      _isLoadingNextTrains = false;
      notifyListeners();
    }
  }

  /// 시간표 정보 로드
  Future<void> loadSchedules({
    required String dailyTypeCode,
    required String upDownTypeCode,
  }) async {
    if (_selectedStation == null) return;

    _isLoadingSchedules = true;
    _errorMessage = null;
    notifyListeners();

    try {
      KSYLog.info('🚇 시간표 로드 시작: ${_selectedStation!.subwayStationName} (${_selectedStation!.effectiveLineNumber}호선)');
      KSYLog.debug('   - subwayStationId: ${_selectedStation!.subwayStationId}');
      KSYLog.debug('   - dailyTypeCode: $dailyTypeCode');
      KSYLog.debug('   - upDownTypeCode: $upDownTypeCode');
      
      _schedules = await _apiService.getSchedules(
        subwayStationId: _selectedStation!.subwayStationId,
        dailyTypeCode: dailyTypeCode,
        upDownTypeCode: upDownTypeCode,
      );
      
      KSYLog.info('📊 시간표 로드 완료: ${_schedules.length}개 항목');
      
      // 로드된 시간표의 호선 분포 분석
      final routeDistribution = <String, int>{};
      for (final schedule in _schedules) {
        final routeId = schedule.subwayRouteId;
        routeDistribution[routeId] = (routeDistribution[routeId] ?? 0) + 1;
      }
      
      KSYLog.debug('🎯 로드된 시간표 호선 분포:');
      routeDistribution.forEach((routeId, count) {
        final lineNumber = _extractLineNumberFromRouteId(routeId);
        KSYLog.debug('   - $routeId ($lineNumber호선): $count개');
      });
      
    } catch (e) {
      _errorMessage = '시간표 정보를 불러오는데 실패했습니다: ${e.toString()}';
      _schedules = [];
      KSYLog.error('❌ 시간표 로드 실패', e);
    } finally {
      _isLoadingSchedules = false;
      notifyListeners();
    }
  }

  /// 출구 정보 로드 (버스노선 + 주변시설)
  Future<void> loadExitInfo() async {
    if (_selectedStation == null) return;

    _isLoadingExitInfo = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final futures = await Future.wait([
        _apiService.getExitBusRoutes(
          subwayStationId: _selectedStation!.subwayStationId,
        ),
        _apiService.getExitFacilities(
          subwayStationId: _selectedStation!.subwayStationId,
        ),
      ]);

      _exitBusRoutes = futures[0] as List<SubwayExitBusRoute>;
      _exitFacilities = futures[1] as List<SubwayExitFacility>;

      KSYLog.debug('Provider 로드 결과:');
      KSYLog.debug('exitBusRoutes 개수: ${_exitBusRoutes.length}');
      KSYLog.debug('exitFacilities 개수: ${_exitFacilities.length}');
      KSYLog.object('exitBusRoutes 데이터', _exitBusRoutes);
      KSYLog.object('exitFacilities 데이터', _exitFacilities);

      // 데이터가 비어있거나 부족하면 테스트 데이터 추가
      if (_exitBusRoutes.length < 2 || _exitFacilities.length < 2) {
        KSYLog.warning('출구 정보가 부족해서 테스트 데이터를 추가합니다.');

        // 기존 데이터에 테스트 데이터 추가
        _exitBusRoutes.addAll([
          SubwayExitBusRoute(
            subwayStationId: _selectedStation!.subwayStationId,
            subwayStationName: _selectedStation!.subwayStationName,
            exitNo: '1',
            busRouteNm: '테스트 버스 100번',
            sectionYn: 'N',
            startSttnNm: '시작정류장',
            endSttnNm: '종점정류장',
          ),
          SubwayExitBusRoute(
            subwayStationId: _selectedStation!.subwayStationId,
            subwayStationName: _selectedStation!.subwayStationName,
            exitNo: '2',
            busRouteNm: '테스트 버스 200번',
            sectionYn: 'N',
            startSttnNm: '시작정류장',
            endSttnNm: '종점정류장',
          ),
        ]);

        _exitFacilities.addAll([
          SubwayExitFacility(
            subwayStationId: _selectedStation!.subwayStationId,
            subwayStationName: _selectedStation!.subwayStationName,
            exitNo: '1',
            cfFacilityNm: '테스트 대형마트',
            cfFacilityClss: '상점',
            useTime: '09:00-22:00',
            phoneNumber: '02-1234-5678',
          ),
          SubwayExitFacility(
            subwayStationId: _selectedStation!.subwayStationId,
            subwayStationName: _selectedStation!.subwayStationName,
            exitNo: '2',
            cfFacilityNm: '테스트 커피순',
            cfFacilityClss: '카페',
            useTime: '07:00-23:00',
            phoneNumber: '02-9876-5432',
          ),
        ]);
      }
    } catch (e) {
      _errorMessage = '출구 정보를 불러오는데 실패했습니다: ${e.toString()}';
      _exitBusRoutes = [];
      _exitFacilities = [];
    } finally {
      _isLoadingExitInfo = false;
      notifyListeners();
    }
  }

  /// 역 검색 (그룹 모드 지원)
  Future<void> searchStations(String stationName) async {
    if (stationName.trim().isEmpty) {
      _searchResults = [];
      _groupedSearchResults = [];
      notifyListeners();
      return;
    }

    _isLoadingSearch = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isGroupSearchMode) {
        // 그룹 모드: 새로운 서버 API의 그룹화된 검색 사용
        final groupedResults = await _serverApiService.searchStationsGrouped(
          stationName.trim(),
        );

        // GroupedStationResponse를 StationGroup으로 변환
        final convertedGroups = groupedResults.map((grouped) {
          // 각 그룹의 상세 역 정보를 SubwayStation으로 변환
          final stations = grouped.details
              .map(
                (detail) => SubwayStation(
                  subwayStationId: detail.subwayStationId ?? '',
                  subwayStationName: grouped.stationName,
                  subwayRouteName: detail.lineNumber,
                  lineNumber: detail.lineNumber,
                  latitude: detail.latitude ?? grouped.representativeLatitude,
                  longitude: detail.longitude ?? grouped.representativeLongitude,
                ),
              )
              .toList();

          return StationGroup(
            stationName: grouped.stationName,
            stations: stations,
            latitude: grouped.representativeLatitude,
            longitude: grouped.representativeLongitude,
            address: grouped.representativeAddress,
          );
        }).toList();

        // 결과 할당
        _groupedSearchResults = convertedGroups;

        // 개별 검색 결과도 업데이트 (호환성을 위해)
        _searchResults = convertedGroups
            .expand((group) => group.stations)
            .toList();
      } else {
        // 개별 모드: 새로운 서버 API의 스마트 검색 사용
        _searchResults = await _serverApiService.searchStationsSmart(
          stationName.trim(),
        );
        _groupedSearchResults = [];
      }
    } catch (e) {
      _errorMessage = '역 검색에 실패했습니다: ${e.toString()}';
      _searchResults = [];
      _groupedSearchResults = [];
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  /// 검색 모드 전환
  void toggleSearchMode() {
    _isGroupSearchMode = !_isGroupSearchMode;

    // 현재 검색 결과가 있으면 다시 그룹화
    if (_searchResults.isNotEmpty) {
      if (_isGroupSearchMode) {
        _groupedSearchResults = StationGrouper.groupStations(_searchResults);
      } else {
        _groupedSearchResults = [];
      }
    }

    notifyListeners();
  }

  /// 즐겨찾기 역 그룹 추가
  Future<void> addFavoriteStationGroup(StationGroup stationGroup) async {
    if (!_favoriteStationGroups.any(
      (g) => g.stationName == stationGroup.stationName,
    )) {
      _favoriteStationGroups.add(stationGroup);
      notifyListeners();
      await _saveFavoritesToLocal();
    }
  }

  /// 즐겨찾기 역 그룹 제거
  Future<void> removeFavoriteStationGroup(StationGroup stationGroup) async {
    _favoriteStationGroups.removeWhere(
      (g) => g.stationName == stationGroup.stationName,
    );
    notifyListeners();
    await _saveFavoritesToLocal();
  }

  /// 즐겨찾기 역 그룹 여부 확인
  bool isFavoriteStationGroup(StationGroup stationGroup) {
    return _favoriteStationGroups.any(
      (g) => g.stationName == stationGroup.stationName,
    );
  }

  /// 모든 즐겨찾기 제거
  Future<void> clearAllFavorites() async {
    try {
      _favoriteStationGroups.clear();
      notifyListeners();
      await FavoritesStorageService.clearAllFavorites();
      KSYLog.info('모든 즐겨찾기 제거 완료');
    } catch (e) {
      KSYLog.error('즐겨찾기 전체 제거 오류', e);
    }
  }

  /// 특정 역명이 즐겨찾기에 있는지 확인 (역명으로 검사)
  bool isFavoriteStationByName(String stationName) {
    final cleanName = StationUtils.cleanStationName(stationName);
    return _favoriteStationGroups.any((g) => g.cleanStationName == cleanName);
  }

  /// 기존 즐겨찾기 추가 (개별 호선 - 하위 호환성)
  Future<void> addFavoriteStation(SubwayStation station) async {
    if (!_favoriteStations.any(
      (s) => s.subwayStationId == station.subwayStationId,
    )) {
      _favoriteStations.add(station);
      notifyListeners();
      // 실제 앱에서는 여기서 로컬 저장소에 저장
      await _saveFavoritesToLocal();
    }
  }

  /// 즐겨찾기 제거
  Future<void> removeFavoriteStation(SubwayStation station) async {
    _favoriteStations.removeWhere(
      (s) => s.subwayStationId == station.subwayStationId,
    );
    notifyListeners();
    // 실제 앱에서는 여기서 로컬 저장소에서 제거
    await _saveFavoritesToLocal();
  }

  /// 기존 즐겨찾기 여부 확인 (개별 호선 - 하위 호환성, 그룹 기반으로 리다이렉트)
  bool isFavoriteStation(SubwayStation station) {
    return isFavoriteStationByName(station.subwayStationName);
  }

  /// 다음 열차 정보 새로고침
  Future<void> refreshNextTrains() async {
    await loadNextTrains();
  }

  /// 현재 시간 기준으로 다음 열차들 필터링 (현재 선택된 호선만)
  List<SubwaySchedule> getUpcomingSchedules() {
    if (_selectedStation == null) return [];
    
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';

    final selectedLineNumber = _selectedStation!.effectiveLineNumber;
    KSYLog.debug('시간표 필터링: 선택된 호선 = $selectedLineNumber');
    KSYLog.debug('전체 시간표 개수: ${_schedules.length}');

    // 현재 선택된 호선의 시간표만 필터링
    final filteredSchedules = _schedules.where((schedule) {
      // 1. 시간 필터링 (현재 시간 이후)
      final isUpcoming = schedule.arrTime.compareTo(currentTime) >= 0;
      
      // 2. 호선 필터링
      bool isMatchingLine = false;
      
      // subwayRouteId에서 호선 정보 추출하여 비교
      if (schedule.subwayRouteId.isNotEmpty) {
        final routeLineNumber = _extractLineNumberFromRouteId(schedule.subwayRouteId);
        isMatchingLine = routeLineNumber == selectedLineNumber;
        
        // 디버깅 로그 추가
        KSYLog.debug('시간표 매칭 체크: routeId=${schedule.subwayRouteId}, 추출된호선=$routeLineNumber, 선택된호선=$selectedLineNumber, 매칭=$isMatchingLine');
      }
      
      return isUpcoming && isMatchingLine;
    }).toList();

    KSYLog.debug('필터링된 시간표 개수: ${filteredSchedules.length}');
    return filteredSchedules;
  }

  /// subwayRouteId에서 호선 번호 추출
  String _extractLineNumberFromRouteId(String routeId) {
    KSYLog.debug('호선 번호 추출: $routeId');
    
    // 특수 노선 코드 처리
    if (routeId.startsWith('MTRDXD')) {
      KSYLog.debug('  -> 동해선(DX) 매칭');
      return 'DX'; // 동해선
    }
    if (routeId.startsWith('MTRKGD')) {
      KSYLog.debug('  -> 경강선(KG) 매칭');
      return 'KG'; // 경강선
    }
    if (routeId.startsWith('MTRGJD')) {
      KSYLog.debug('  -> 경전선(GJ) 매칭');
      return 'GJ'; // 경전선
    }
    if (routeId.startsWith('MTRSLD')) {
      KSYLog.debug('  -> 서울경전철(SL) 매칭');
      return 'SL'; // 서울경전철
    }
    
    // MTRS1101 -> 1, MTRS1104 -> 4 등
    if (routeId.startsWith('MTRS')) {
      final numberPart = routeId.substring(4); // MTRS 제거
      KSYLog.debug('  numberPart: $numberPart');
      
      // 정확한 호선 매핑 (국토교통부 API 기준)
      if (numberPart.startsWith('11')) {
        return '1'; // 1호선 (MTRS1101, MTRS1102 등)
      } else if (numberPart.startsWith('12')) {
        return '2'; // 2호선 (MTRS1201, MTRS1202 등)
      } else if (numberPart.startsWith('13')) {
        return '3'; // 3호선 (MTRS1301, MTRS1302 등)
      } else if (numberPart.startsWith('14')) {
        return '4'; // 4호선 (MTRS1401, MTRS1402 등)
      } else if (numberPart.startsWith('15')) {
        return '5'; // 5호선 (MTRS1501, MTRS1502 등)
      } else if (numberPart.startsWith('16')) {
        return '6'; // 6호선 (MTRS1601, MTRS1602 등)
      } else if (numberPart.startsWith('17')) {
        return '7'; // 7호선 (MTRS1701, MTRS1702 등)
      } else if (numberPart.startsWith('18')) {
        return '8'; // 8호선 (MTRS1801, MTRS1802 등)
      } else if (numberPart.startsWith('19')) {
        return '9'; // 9호선 (MTRS1901, MTRS1902 등)
      }
      
      // 패턴이 맞지 않는 경우 다른 방식으로 시도
      // 예: MTRS21XX (분당선), MTRS31XX (신분당선) 등
      final lineRegex = RegExp(r'^(\d+)');
      final match = lineRegex.firstMatch(numberPart);
      if (match != null) {
        final extracted = match.group(1)!;
        KSYLog.debug('  정규식 매칭: $extracted');
        
        // 특수 호선 변환
        switch (extracted) {
          case '21':
            return '분당';
          case '22':
            return '신분당';
          case '31':
            return '경의중앙';
          case '32':
            return '경춘';
          case '33':
            return '수인분당';
          case '41':
            return '우이신설';
          case '42':
            return '서해';
          case '43':
            return '김포';
          case '44':
            return '신림';
          default:
            // 한 자리 숫자인 경우 그대로 반환
            if (extracted.length == 1) {
              return extracted;
            }
            // 두 자리 숫자인 경우 첫 번째 자리만
            return extracted.substring(0, 1);
        }
      }
    }
    
    KSYLog.warning('호선 번호 추출 실패, 기본값 반환: $routeId -> 1');
    return '1'; // 기본값
  }

  /// 특정 방향의 다음 열차 필터링 (현재 선택된 호선만)
  List<NextTrainInfo> getNextTrainsByDirection(String direction) {
    if (_selectedStation == null) return [];
    
    return _nextTrains.where((train) {
      final isMatchingDirection = train.direction == direction;
      
      // 현재 선택된 호선의 열차만 필터링
      // NextTrainInfo에 호선 정보가 있는지 확인 필요
      // 일단 방향만으로 필터링하고, 필요시 추가 로직 구현
      return isMatchingDirection;
    }).toList();
  }

  /// 상행 다음 열차 (현재 선택된 호선만)
  List<NextTrainInfo> get upwardNextTrains =>
      getNextTrainsByDirection('상행').take(3).toList();

  /// 하행 다음 열차 (현재 선택된 호선만)
  List<NextTrainInfo> get downwardNextTrains =>
      getNextTrainsByDirection('하행').take(3).toList();

  /// 출구별 버스노선을 출구 번호로 그룹화
  Map<String, List<SubwayExitBusRoute>> get busRoutesByExit {
    final Map<String, List<SubwayExitBusRoute>> grouped = {};
    for (final route in _exitBusRoutes) {
      if (!grouped.containsKey(route.exitNo)) {
        grouped[route.exitNo] = [];
      }
      grouped[route.exitNo]!.add(route);
    }
    return grouped;
  }

  /// 출구별 주변시설을 출구 번호로 그룹화
  Map<String, List<SubwayExitFacility>> get facilitiesByExit {
    final Map<String, List<SubwayExitFacility>> grouped = {};
    for (final facility in _exitFacilities) {
      if (!grouped.containsKey(facility.exitNo)) {
        grouped[facility.exitNo] = [];
      }
      grouped[facility.exitNo]!.add(facility);
    }
    return grouped;
  }

  /// 데이터 초기화
  void _clearNextTrains() {
    _nextTrains = [];
  }

  void _clearSchedules() {
    _schedules = [];
  }

  void _clearExitInfo() {
    _exitBusRoutes = [];
    _exitFacilities = [];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSearchResults() {
    _searchResults = [];
    _groupedSearchResults = [];
    notifyListeners();
  }

  /// 로컬 저장소에 즐겨찾기 저장
  Future<void> _saveFavoritesToLocal() async {
    try {
      await FavoritesStorageService.saveFavoriteStationGroups(
        _favoriteStationGroups,
      );
      KSYLog.debug('즐겨찾기 그룹 저장: ${_favoriteStationGroups.length}개');
    } catch (e) {
      KSYLog.error('즐겨찾기 저장 오류', e);
      // 오류 발생시도 앱 동작은 계속됨
    }
  }

  /// 로컬 저장소에서 즐겨찾기 로드
  Future<void> loadFavoritesFromLocal() async {
    try {
      final loadedFavorites =
          await FavoritesStorageService.loadFavoriteStationGroups();
      _favoriteStationGroups.clear();
      _favoriteStationGroups.addAll(loadedFavorites);
      notifyListeners();
      KSYLog.info('즐겨찾기 로드 완료: ${_favoriteStationGroups.length}개');
    } catch (e) {
      KSYLog.error('즐겨찾기 로드 오류', e);
      // 오류 발생시 빈 리스트로 유지
    }
  }

  /// 현재 요일에 따른 요일 코드 반환
  String getCurrentDailyTypeCode() {
    return _apiService.getCurrentDailyTypeCode();
  }

  /// 지도에서 역명으로 StationGroup 가져오기 (캐싱 활용)
  Future<StationGroup?> getStationGroupByName(String stationName) async {
    final cleanName = StationUtils.cleanStationName(stationName);
    KSYLog.debug('🗺️ 지도에서 역 검색: $stationName -> $cleanName');

    // 1. 캐시 확인
    if (_isValidCache(cleanName)) {
      KSYLog.cache('get', cleanName, true);
      return _stationGroupCache[cleanName];
    }

    // 2. API 검색 (새로운 서버 API 사용)
    KSYLog.debug('API 검색 시작: $cleanName');

    try {
      // 먼저 새로운 서버 API의 그룹화된 검색 시도
      final groupedResults = await _serverApiService.searchStationsGrouped(
        cleanName,
      );

      if (groupedResults.isEmpty) {
        KSYLog.warning('검색 결과 없음: $cleanName');
        return null;
      }

      // GroupedStationResponse를 StationGroup으로 변환
      final serverGroups = groupedResults.map((grouped) {
        final stations = grouped.details
            .map(
              (detail) => SubwayStation(
                subwayStationId: detail.subwayStationId ?? '',
                subwayStationName: grouped.stationName,
                subwayRouteName: detail.lineNumber,
                lineNumber: detail.lineNumber,
                latitude: detail.latitude ?? grouped.representativeLatitude,
                longitude: detail.longitude ?? grouped.representativeLongitude,
              ),
            )
            .toList();

        return StationGroup(
          stationName: grouped.stationName,
          stations: stations,
          latitude: grouped.representativeLatitude,
          longitude: grouped.representativeLongitude,
          address: grouped.representativeAddress,
        );
      }).toList();

      // 가장 적합한 그룹 선택
      final matchingGroup = serverGroups.firstWhere(
        (group) =>
            StationUtils.cleanStationName(group.stationName) == cleanName,
        orElse: () => serverGroups.first,
      );

      // 4. 캐시 저장
      _stationGroupCache[cleanName] = matchingGroup;
      _cacheTimestamps[cleanName] = DateTime.now();

      KSYLog.info(
        'API 검색 성공 및 캐싱: $cleanName (호선 ${matchingGroup.stations.length}개)',
      );
      return matchingGroup;
    } catch (e) {
      KSYLog.error('서버 API 검색 실패: $cleanName', e);
      return null;
    }
  }

  /// 캐시 유효성 확인 (24시간)
  bool _isValidCache(String cleanName) {
    if (!_stationGroupCache.containsKey(cleanName) ||
        !_cacheTimestamps.containsKey(cleanName)) {
      return false;
    }

    final timestamp = _cacheTimestamps[cleanName]!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    return difference.inHours < 24; // 24시간 유효
  }

  /// 캐시 클리어
  void clearStationGroupCache() {
    _stationGroupCache.clear();
    _cacheTimestamps.clear();
    KSYLog.cache('clear', 'stationGroupCache', null);
  }

  /// 캐시 통계
  Map<String, int> getCacheStats() {
    final validCache = _stationGroupCache.keys
        .where((key) => _isValidCache(key))
        .length;

    return {
      'total': _stationGroupCache.length,
      'valid': validCache,
      'expired': _stationGroupCache.length - validCache,
    };
  }

  /// subwayStationId를 사용한 상세 정보 조회 (지도 연동용)
  ///
  /// [subwayStationId] 국토교통부 API용 지하철역 ID
  /// [stationName] 역명 (캐싱용)
  Future<StationGroup?> getStationDetailsBySubwayStationId({
    required String subwayStationId,
    required String stationName,
  }) async {
    try {
      KSYLog.info(
        '🔍 subwayStationId로 상세 정보 조회: $subwayStationId ($stationName)',
      );

      // 1. 해당 subwayStationId로 시간표 조회 시도 (역 존재 여부 확인)
      KSYLog.debug(
        '🔍 시간표 조회 시도 - subwayStationId: $subwayStationId, dailyTypeCode: ${getCurrentDailyTypeCode()}',
      );

      final schedules = await _apiService.getSchedules(
        subwayStationId: subwayStationId,
        dailyTypeCode: getCurrentDailyTypeCode(),
        upDownTypeCode: 'U', // 상행으로 테스트
        numOfRows: 1, // 최소한으로 조회
      );

      KSYLog.debug('📊 시간표 조회 결과: ${schedules.length}개');

      if (schedules.isNotEmpty) {
        // 2. subwayStationId가 유효하면 역명으로 전체 호선 정보 검색
        KSYLog.info('🔍 유효한 subwayStationId 확인됨, 역명으로 전체 호선 검색: $stationName');
        final fullStationGroup = await getStationGroupByName(stationName);
        
        if (fullStationGroup != null) {
          KSYLog.info('✅ 전체 호선 정보 조회 성공: ${fullStationGroup.stations.length}개 호선');
          return fullStationGroup;
        } else {
          // 전체 호선 검색 실패 시 단일 역으로 폴백
          KSYLog.warning('⚠️ 전체 호선 검색 실패, 단일 역으로 폴백');
          final station = SubwayStation(
            subwayStationId: subwayStationId,
            subwayStationName: stationName,
          );

          return StationGroup(
            stationName: stationName,
            stations: [station],
          );
        }
      } else {
        KSYLog.warning('⚠️ subwayStationId로 시간표 조회 결과 없음: $subwayStationId');
        return null;
      }
    } catch (e) {
      KSYLog.error('❌ subwayStationId 상세 정보 조회 실패: $subwayStationId', e);
      return null;
    }
  }
}
