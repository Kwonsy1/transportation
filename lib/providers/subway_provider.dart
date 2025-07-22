import 'package:flutter/foundation.dart';
import '../models/subway_station.dart';
import '../models/subway_schedule.dart';
import '../models/next_train_info.dart';
import '../models/api_response.dart';
import '../models/station_group.dart';
import '../services/subway_api_service.dart';
import '../services/favorites_storage_service.dart';

/// 지하철 정보 상태 관리 Provider (국토교통부 API 기준)
class SubwayProvider extends ChangeNotifier {
  final SubwayApiService _apiService = SubwayApiService();

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
    _selectedStation = station;
    _clearNextTrains();
    _clearSchedules();
    _clearExitInfo();
    notifyListeners();
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
      _schedules = await _apiService.getSchedules(
        subwayStationId: _selectedStation!.subwayStationId,
        dailyTypeCode: dailyTypeCode,
        upDownTypeCode: upDownTypeCode,
      );
    } catch (e) {
      _errorMessage = '시간표 정보를 불러오는데 실패했습니다: ${e.toString()}';
      _schedules = [];
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
      
      print('Provider 로드 결과:');
      print('exitBusRoutes 개수: ${_exitBusRoutes.length}');
      print('exitFacilities 개수: ${_exitFacilities.length}');
      print('exitBusRoutes 데이터: $_exitBusRoutes');
      print('exitFacilities 데이터: $_exitFacilities');
      
      // 데이터가 비어있거나 부족하면 테스트 데이터 추가
      if (_exitBusRoutes.length < 2 || _exitFacilities.length < 2) {
        print('출구 정보가 부족해서 테스트 데이터를 추가합니다.');
        
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
      // 기본 검색 수행
      _searchResults = await _apiService.searchStations(
        stationName: stationName.trim(),
      );

      // 그룹 모드일 때 그룹화 수행
      if (_isGroupSearchMode) {
        _groupedSearchResults = StationGrouper.groupStations(_searchResults);
      } else {
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
      print('모든 즐겨찾기 제거 완료');
    } catch (e) {
      print('즐겨찾기 전체 제거 오류: $e');
    }
  }

  /// 특정 역명이 즐겨찾기에 있는지 확인 (역명으로 검사)
  bool isFavoriteStationByName(String stationName) {
    final cleanName = stationName.replaceAll('역', '').trim();
    return _favoriteStationGroups.any(
      (g) => g.cleanStationName == cleanName,
    );
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

  /// 현재 시간 기준으로 다음 열차들 필터링
  List<SubwaySchedule> getUpcomingSchedules() {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';

    return _schedules
        .where((schedule) => schedule.arrTime.compareTo(currentTime) >= 0)
        .toList();
  }

  /// 특정 방향의 다음 열차 필터링
  List<NextTrainInfo> getNextTrainsByDirection(String direction) {
    return _nextTrains.where((train) => train.direction == direction).toList();
  }

  /// 상행 다음 열차
  List<NextTrainInfo> get upwardNextTrains =>
      getNextTrainsByDirection('상행').take(3).toList();

  /// 하행 다음 열차
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
      await FavoritesStorageService.saveFavoriteStationGroups(_favoriteStationGroups);
      print('즐겨찾기 그룹 저장: ${_favoriteStationGroups.length}개');
    } catch (e) {
      print('즐겨찾기 저장 오류: $e');
      // 오류 발생시도 앱 동작은 계속됨
    }
  }

  /// 로컬 저장소에서 즐겨찾기 로드
  Future<void> loadFavoritesFromLocal() async {
    try {
      final loadedFavorites = await FavoritesStorageService.loadFavoriteStationGroups();
      _favoriteStationGroups.clear();
      _favoriteStationGroups.addAll(loadedFavorites);
      notifyListeners();
      print('즐겨찾기 로드 완료: ${_favoriteStationGroups.length}개');
    } catch (e) {
      print('즐겨찾기 로드 오류: $e');
      // 오류 발생시 빈 리스트로 유지
    }
  }

  /// 현재 요일에 따른 요일 코드 반환
  String getCurrentDailyTypeCode() {
    return _apiService.getCurrentDailyTypeCode();
  }

  /// 지도에서 역명으로 StationGroup 가져오기 (캐싱 활용)
  Future<StationGroup?> getStationGroupByName(String stationName) async {
    final cleanName = _cleanStationName(stationName);
    print('🗺️ 지도에서 역 검색: $stationName -> $cleanName');
    
    // 1. 캐시 확인
    if (_isValidCache(cleanName)) {
      print('✅ 캐시에서 반환: $cleanName');
      return _stationGroupCache[cleanName];
    }
    
    // 2. API 검색
    print('🔍 API 검색 시작: $cleanName');
    
    try {
      final searchResults = await _apiService.searchStations(
        stationName: cleanName,
      );
      
      if (searchResults.isEmpty) {
        print('❌ 검색 결과 없음: $cleanName');
        return null;
      }
      
      // 3. 그룹화
      final groupedResults = StationGrouper.groupStations(searchResults);
      final matchingGroup = groupedResults.firstWhere(
        (group) => _cleanStationName(group.stationName) == cleanName,
        orElse: () => groupedResults.first,
      );
      
      // 4. 캐시 저장
      _stationGroupCache[cleanName] = matchingGroup;
      _cacheTimestamps[cleanName] = DateTime.now();
      
      print('✅ API 검색 성공 및 캐싱: $cleanName (호선 ${matchingGroup.stations.length}개)');
      return matchingGroup;
      
    } catch (e) {
      print('❌ API 검색 실패: $cleanName - $e');
      return null;
    }
  }
  
  /// 역명 정규화 (캐싱 키용)
  String _cleanStationName(String stationName) {
    return stationName
        .replaceAll(RegExp(r'역$'), '') // 마지막 "역"만 제거
        .replaceAll(RegExp(r'\(.*?\)'), '') // 괄호 제거
        .replaceAll(RegExp(r'\d+호선'), '') // 호선 번호 제거
        .trim()
        .toLowerCase();
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
    print('🗑️ 역 그룹 캐시 클리어');
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
}
