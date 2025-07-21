import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/subway_station.dart';
import '../services/location_service.dart';
// import '../services/subway_api_service.dart'; // 사용하지 않음

/// 위치 정보 상태 관리 Provider (국토교통부 API 기준)
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService.instance;
  // final SubwayApiService _subwayApiService = SubwayApiService(); // 사용하지 않음

  // 서울시 주요 지하철역 좌표 데이터 (하드코딩)
  static const Map<String, Map<String, dynamic>> _seoulStationCoordinates = {
    '서울역': {'lat': 37.5546, 'lng': 126.9707, 'lines': ['1', '4', '경의중앙', '공항철도']},
    '강남역': {'lat': 37.4979, 'lng': 127.0276, 'lines': ['2', '신분당']},
    '홍대입구역': {'lat': 37.5563, 'lng': 126.9243, 'lines': ['2', '6', '공항철도', '경의중앙']},
    '건대입구역': {'lat': 37.5401, 'lng': 127.0699, 'lines': ['2', '7']},
    '잠실역': {'lat': 37.5132, 'lng': 127.1000, 'lines': ['2', '8']},
    '역삼역': {'lat': 37.5000, 'lng': 127.0364, 'lines': ['2']},
    '선릉역': {'lat': 37.5044, 'lng': 127.0489, 'lines': ['2', '분당']},
    '삼성역': {'lat': 37.5090, 'lng': 127.0633, 'lines': ['2']},
    '신도림역': {'lat': 37.5087, 'lng': 126.8913, 'lines': ['1', '2']},
    '명동역': {'lat': 37.5636, 'lng': 126.9866, 'lines': ['4']},
    '종로3가역': {'lat': 37.5706, 'lng': 126.9915, 'lines': ['1', '3', '5']},
    '동대문역사문화공원역': {'lat': 37.5665, 'lng': 127.0079, 'lines': ['2', '4', '5']},
    '용산역': {'lat': 37.5299, 'lng': 126.9648, 'lines': ['1', '경의중앙']},
    '이태원역': {'lat': 37.5346, 'lng': 126.9946, 'lines': ['6']},
    '여의도역': {'lat': 37.5219, 'lng': 126.9245, 'lines': ['5', '9']},
    '마포역': {'lat': 37.5444, 'lng': 126.9456, 'lines': ['5']},
    '송파역': {'lat': 37.5048, 'lng': 127.1116, 'lines': ['8']},
    '강서구청역': {'lat': 37.5509, 'lng': 126.8227, 'lines': ['5']},
    '노원역': {'lat': 37.6541, 'lng': 127.0618, 'lines': ['4', '7']},
    '도봉산역': {'lat': 37.6689, 'lng': 127.0471, 'lines': ['1', '7']},
    '성북역': {'lat': 37.5894, 'lng': 127.0180, 'lines': ['4']},
    '중랑역': {'lat': 37.5956, 'lng': 127.0742, 'lines': ['경의중앙']},
    '동작역': {'lat': 37.5127, 'lng': 126.9797, 'lines': ['4', '9']},
    '관악역': {'lat': 37.4765, 'lng': 126.9816, 'lines': ['1']},
    '서초역': {'lat': 37.4837, 'lng': 127.0119, 'lines': ['2']},
    '강동역': {'lat': 37.5269, 'lng': 127.1265, 'lines': ['5']},
    '양천구청역': {'lat': 37.5170, 'lng': 126.8665, 'lines': ['5']},
    '구로역': {'lat': 37.5030, 'lng': 126.8818, 'lines': ['1']},
    '금천구청역': {'lat': 37.4569, 'lng': 126.8955, 'lines': ['1']},
    '영등포구청역': {'lat': 37.5244, 'lng': 126.8962, 'lines': ['2', '5']},
    '압구정역': {'lat': 37.5273, 'lng': 127.0287, 'lines': ['3']},
    '청담역': {'lat': 37.5197, 'lng': 127.0533, 'lines': ['7']},
    '신촌역': {'lat': 37.5561, 'lng': 126.9364, 'lines': ['2']},
    '동대문운동장역': {'lat': 37.5662, 'lng': 127.0093, 'lines': ['2', '4', '5']},
  };

  // 현재 위치
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // 주변 역 목록
  List<SubwayStation> _nearbyStations = [];
  List<SubwayStation> get nearbyStations => _nearbyStations;

  // 전체 역 목록 (캐시용)
  List<SubwayStation> _allStations = [];
  bool _allStationsLoaded = false;

  // 위치 권한 상태
  bool _hasLocationPermission = false;
  bool get hasLocationPermission => _hasLocationPermission;

  // 위치 서비스 활성화 상태
  bool _isLocationServiceEnabled = false;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  // 로딩 상태
  bool _isLoadingLocation = false;
  bool _isLoadingNearbyStations = false;
  bool _isLoadingAllStations = false;

  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingNearbyStations => _isLoadingNearbyStations;
  bool get isLoadingAllStations => _isLoadingAllStations;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 위치 권한 상태 초기화
  Future<void> initializeLocationStatus() async {
    try {
      _hasLocationPermission = await _locationService.checkLocationPermission();
      _isLocationServiceEnabled = await _locationService.isLocationServiceEnabled();
      notifyListeners();
    } catch (e) {
      _errorMessage = '위치 권한 상태 확인에 실패했습니다: ${e.toString()}';
      notifyListeners();
    }
  }

  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    try {
      _hasLocationPermission = await _locationService.requestLocationPermission();
      notifyListeners();
      return _hasLocationPermission;
    } catch (e) {
      _errorMessage = '위치 권한 요청에 실패했습니다: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// 현재 위치 가져오기
  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPosition = await _locationService.getCurrentPosition();
    } catch (e) {
      _errorMessage = '현재 위치를 가져오는데 실패했습니다: ${e.toString()}';
      _currentPosition = null;
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// 전체 지하철역 목록 로드 (캐시) - 현재 사용하지 않음
  Future<void> _loadAllStations() async {
    if (_allStationsLoaded) return;

    _isLoadingAllStations = true;
    notifyListeners();

    try {
      // API 서비스 없이 빈 리스트로 처리
      _allStations = [];
      _allStationsLoaded = true;
      print('전체 지하철역 로드 완료: ${_allStations.length}개');
    } catch (e) {
      _errorMessage = '지하철역 목록 로드에 실패했습니다: ${e.toString()}';
      print('전체 지하철역 로드 오류: $e');
    } finally {
      _isLoadingAllStations = false;
      notifyListeners();
    }
  }

  /// 주변 지하철역 검색
  Future<void> loadNearbyStations({int radius = 3000}) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
      if (_currentPosition == null) {
        print('현재 위치를 가져올 수 없어서 기본 위치(서울역) 사용');
        // 현재 위치를 가져올 수 없으면 서울역 기준으로 설정
        _currentPosition = Position(
          latitude: 37.5546,
          longitude: 126.9707,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    _isLoadingNearbyStations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 좌표 기반으로 주변 역 찾기
      List<Map<String, dynamic>> nearbyStationsWithDistance = [];
      
      _seoulStationCoordinates.forEach((stationName, coords) {
        final distance = _locationService.calculateDistance(
          startLatitude: _currentPosition!.latitude,
          startLongitude: _currentPosition!.longitude,
          endLatitude: coords['lat'],
          endLongitude: coords['lng'],
        );
        
        if (distance <= radius) {
          // 각 호선별로 별도 역으로 생성
          for (String line in coords['lines']) {
            nearbyStationsWithDistance.add({
              'station': SubwayStation(
                subwayStationId: 'STATION_${stationName.replaceAll('역', '')}_$line',
                subwayStationName: stationName,
                subwayRouteName: '서울 ${line}호선',
                latitude: coords['lat'],
                longitude: coords['lng'],
              ),
              'distance': distance,
            });
          }
        }
      });
      
      // 거리순으로 정렬
      nearbyStationsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));
      
      // SubwayStation 리스트로 변환 (최대 15개)
      _nearbyStations = nearbyStationsWithDistance
          .take(15)
          .map((item) => item['station'] as SubwayStation)
          .toList();

      print('실제 좌표 기반 주변 지하철역 검색 완료: ${_nearbyStations.length}개');
      print('현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      if (_nearbyStations.isNotEmpty) {
        print('가장 가까운 역: ${_nearbyStations.first.subwayStationName}');
      }

    } catch (e) {
      _errorMessage = '주변 지하철역 검색에 실패했습니다: ${e.toString()}';
      _nearbyStations = [];
      print('주변 지하철역 검색 오류: $e');
    } finally {
      _isLoadingNearbyStations = false;
      notifyListeners();
    }
  }

  /// 서울 지역 역인지 확인 (임시 구현)
  bool _isSeoulArea(SubwayStation station) {
    final seoulKeywords = [
      '서울', '강남', '홍대', '신도림', '건대', '잠실', '역삼', '선릉', '삼성',
      '압구정', '청담', '신촌', '명동', '종로', '동대문', '용산', '이태원',
      '여의도', '마포', '송파', '강서', '노원', '도봉', '성북', '중랑',
      '동작', '관악', '서초', '강동', '양천', '구로', '금천', '영등포'
    ];

    return seoulKeywords.any((keyword) => 
        station.subwayStationName.contains(keyword) || 
        station.subwayRouteName.contains('서울'));
  }

  /// 두 지점 간 거리 계산 (실제 좌표 기반)
  double? calculateDistanceToStation(SubwayStation station) {
    if (_currentPosition == null) {
      return null;
    }

    // 역에 좌표 정보가 있는 경우 실제 거리 계산
    if (station.latitude != null && station.longitude != null) {
      return _locationService.calculateDistance(
        startLatitude: _currentPosition!.latitude,
        startLongitude: _currentPosition!.longitude,
        endLatitude: station.latitude!,
        endLongitude: station.longitude!,
      );
    }

    // 좌표 정보가 없는 경우 하드코딩된 데이터에서 찾기
    for (String stationName in _seoulStationCoordinates.keys) {
      if (station.subwayStationName.contains(stationName.replaceAll('역', '')) ||
          stationName.contains(station.subwayStationName.replaceAll('역', ''))) {
        final coords = _seoulStationCoordinates[stationName]!;
        return _locationService.calculateDistance(
          startLatitude: _currentPosition!.latitude,
          startLongitude: _currentPosition!.longitude,
          endLatitude: coords['lat'],
          endLongitude: coords['lng'],
        );
      }
    }

    // 찾을 수 없는 경우 null 반환
    return null;
  }

  /// 거리를 읽기 쉬운 형태로 포맷팅
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 위치 서비스 설정으로 이동
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// 앱 설정으로 이동
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 위치 정보 새로고침
  Future<void> refreshLocation() async {
    await getCurrentLocation();
    if (_currentPosition != null) {
      await loadNearbyStations();
    }
  }

  /// 실시간 위치 추적 시작
  void startLocationTracking() {
    _locationService.getPositionStream().listen(
      (position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '위치 추적 중 오류가 발생했습니다: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  /// 특정 역명으로 주변 역 필터링
  List<SubwayStation> filterStationsByName(String query) {
    if (query.isEmpty) return _nearbyStations;
    
    return _nearbyStations
        .where((station) => 
            station.subwayStationName.contains(query) ||
            station.subwayRouteName.contains(query))
        .toList();
  }

  /// 호선별 주변 역 필터링
  List<SubwayStation> filterStationsByLine(String lineNumber) {
    return _nearbyStations
        .where((station) => station.lineNumber == lineNumber)
        .toList();
  }

  /// 주변 역 목록 강제 새로고침
  Future<void> forceRefreshNearbyStations() async {
    _allStationsLoaded = false;
    _allStations.clear();
    await loadNearbyStations();
  }
}
