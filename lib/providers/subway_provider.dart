import 'package:flutter/foundation.dart';
import '../models/subway_station.dart';
import '../models/subway_schedule.dart';
import '../models/next_train_info.dart';
import '../models/api_response.dart';
import '../services/subway_api_service.dart';

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

  // 즐겨찾기 역 목록
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

  /// 역 검색
  Future<void> searchStations(String stationName) async {
    if (stationName.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoadingSearch = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _apiService.searchStations(
        stationName: stationName.trim(),
      );
    } catch (e) {
      _errorMessage = '역 검색에 실패했습니다: ${e.toString()}';
      _searchResults = [];
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  /// 즐겨찾기 추가
  void addFavoriteStation(SubwayStation station) {
    if (!_favoriteStations.any(
      (s) => s.subwayStationId == station.subwayStationId,
    )) {
      _favoriteStations.add(station);
      notifyListeners();
      // 실제 앱에서는 여기서 로컬 저장소에 저장
      _saveFavoritesToLocal();
    }
  }

  /// 즐겨찾기 제거
  void removeFavoriteStation(SubwayStation station) {
    _favoriteStations.removeWhere(
      (s) => s.subwayStationId == station.subwayStationId,
    );
    notifyListeners();
    // 실제 앱에서는 여기서 로컬 저장소에서 제거
    _saveFavoritesToLocal();
  }

  /// 즐겨찾기 여부 확인
  bool isFavoriteStation(SubwayStation station) {
    return _favoriteStations.any(
      (s) => s.subwayStationId == station.subwayStationId,
    );
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
    notifyListeners();
  }

  /// 로컬 저장소에 즐겨찾기 저장 (더미 구현)
  void _saveFavoritesToLocal() {
    // 실제 구현에서는 shared_preferences 등을 사용
    print('즐겨찾기 저장: ${_favoriteStations.length}개');
  }

  /// 로컬 저장소에서 즐겨찾기 로드 (더미 구현)
  Future<void> loadFavoritesFromLocal() async {
    // 실제 구현에서는 shared_preferences 등을 사용
    print('즐겨찾기 로드');
  }

  /// 현재 요일에 따른 요일 코드 반환
  String getCurrentDailyTypeCode() {
    return _apiService.getCurrentDailyTypeCode();
  }
}
