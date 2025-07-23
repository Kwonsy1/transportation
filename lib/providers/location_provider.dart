import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../services/location_service.dart';
import '../providers/seoul_subway_provider.dart';
import '../utils/ksy_log.dart';

/// 위치 정보 상태 관리 Provider (Hive 데이터 기반)
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService.instance;
  SeoulSubwayProvider? _seoulSubwayProvider;

  // 현재 위치
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // 현재 화면에 표시할 역 목록 (동적)
  List<SeoulSubwayStation> _visibleStations = [];
  List<SeoulSubwayStation> get visibleStations => _visibleStations;

  // 주변 역 목록 (하위 호환성을 위해 유지)
  List<SubwayStation> get nearbyStations =>
      _visibleStations.map((station) => station.toSubwayStation()).toList();

  // 현재 지도 영역 정보
  double _currentCenterLat = 37.5665; // 서울시청 기본값
  double _currentCenterLng = 126.9780;
  double _currentZoomLevel = 15.0;

  double get currentCenterLat => _currentCenterLat;
  double get currentCenterLng => _currentCenterLng;
  double get currentZoomLevel => _currentZoomLevel;

  // 위치 권한 상태
  bool _hasLocationPermission = false;
  bool get hasLocationPermission => _hasLocationPermission;

  // 위치 서비스 활성화 상태
  bool _isLocationServiceEnabled = false;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  // 로딩 상태
  bool _isLoadingLocation = false;
  bool _isLoadingVisibleStations = false;

  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingNearbyStations => _isLoadingVisibleStations; // 하위 호환성
  bool get isLoadingVisibleStations => _isLoadingVisibleStations;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// SeoulSubwayProvider 설정
  void setSeoulSubwayProvider(SeoulSubwayProvider provider) {
    _seoulSubwayProvider = provider;
  }

  /// 위치 권한 상태 초기화
  Future<void> initializeLocationStatus() async {
    try {
      _hasLocationPermission = await _locationService.checkLocationPermission();
      _isLocationServiceEnabled = await _locationService
          .isLocationServiceEnabled();
      notifyListeners();
    } catch (e) {
      _errorMessage = '위치 권한 상태 확인에 실패했습니다: ${e.toString()}';
      notifyListeners();
    }
  }

  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    try {
      _hasLocationPermission = await _locationService
          .requestLocationPermission();
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
      if (_currentPosition != null) {
        // 현재 위치로 지도 중심 이동
        _currentCenterLat = _currentPosition!.latitude;
        _currentCenterLng = _currentPosition!.longitude;
      }
    } catch (e) {
      _errorMessage = '현재 위치를 가져오는데 실패했습니다: ${e.toString()}';
      _currentPosition = null;
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// 지도 영역 업데이트 (카메라 이동 시 호출)
  void updateMapBounds(double centerLat, double centerLng, double zoomLevel) {
    _currentCenterLat = centerLat;
    _currentCenterLng = centerLng;
    _currentZoomLevel = zoomLevel;

    loadVisibleStations();
  }

  /// 현재 화면에 보이는 역들만 로드 (동적)
  Future<void> loadVisibleStations({double? radiusKm}) async {
    if (_seoulSubwayProvider == null) {
      KSYLog.warning('⚠️ SeoulSubwayProvider가 설정되지 않음');
      return;
    }

    _isLoadingVisibleStations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 줄 레벨에 따른 반지름 계산
      final double radius =
          radiusKm ?? _calculateRadiusFromZoom(_currentZoomLevel);

      // Hive에서 좌표가 있는 모든 역 가져오기
      final allStations = _seoulSubwayProvider!.allStations
          .where(
            (station) => station.latitude != 0.0 && station.longitude != 0.0,
          )
          .toList();

      KSYLog.debug('📍 좌표가 있는 역: ${allStations.length}개');

      // 현재 지도 영역 내의 역들만 필터링
      final visibleStations = <SeoulSubwayStation>[];

      for (final station in allStations) {
        final distance = _locationService.calculateDistance(
          startLatitude: _currentCenterLat,
          startLongitude: _currentCenterLng,
          endLatitude: station.latitude,
          endLongitude: station.longitude,
        );

        if (distance <= radius * 1000) {
          // km를 m로 변환
          visibleStations.add(station);
        }
      }

      // 거리순으로 정렬 후 제한 (성능 최적화)
      visibleStations.sort((a, b) {
        final distanceA = _locationService.calculateDistance(
          startLatitude: _currentCenterLat,
          startLongitude: _currentCenterLng,
          endLatitude: a.latitude,
          endLongitude: a.longitude,
        );
        final distanceB = _locationService.calculateDistance(
          startLatitude: _currentCenterLat,
          startLongitude: _currentCenterLng,
          endLatitude: b.latitude,
          endLongitude: b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      // 성능을 위해 최대 100개로 제한
      _visibleStations = visibleStations.take(100).toList();

      KSYLog.info('🗺️ 화면 내 역 로드 완료: ${_visibleStations.length}개');
      KSYLog.location('화면 중심', _currentCenterLat, _currentCenterLng);
      KSYLog.debug('🔍 반지름: ${radius.toStringAsFixed(1)}km');

      if (_visibleStations.isNotEmpty) {
        KSYLog.debug('🚇 가장 가까운 역: ${_visibleStations.first.stationName}');
      }
    } catch (e) {
      _errorMessage = '화면 내 역 검색에 실패했습니다: ${e.toString()}';
      _visibleStations = [];
      KSYLog.error('❌ 화면 내 역 로드 오류', e);
    } finally {
      _isLoadingVisibleStations = false;
      notifyListeners();
    }
  }

  /// 줄 레벨에 따른 검색 반지름 계산
  double _calculateRadiusFromZoom(double zoomLevel) {
    // 줄 레벨이 높을수록 더 세밀한 영역 표시
    if (zoomLevel >= 18) return 0.5; // 500m
    if (zoomLevel >= 16) return 1.0; // 1km
    if (zoomLevel >= 14) return 2.0; // 2km
    if (zoomLevel >= 12) return 5.0; // 5km
    if (zoomLevel >= 10) return 10.0; // 10km
    return 20.0; // 20km
  }

  /// 두 지점 간 거리 계산 (실제 좌표 기반)
  double? calculateDistanceToStation(SubwayStation station) {
    // 현재 위치가 없으면 지도 중심 사용
    final baseLat = _currentPosition?.latitude ?? _currentCenterLat;
    final baseLng = _currentPosition?.longitude ?? _currentCenterLng;

    // 역에 좌표 정보가 있는 경우 실제 거리 계산
    if (station.latitude != null && station.longitude != null) {
      return _locationService.calculateDistance(
        startLatitude: baseLat,
        startLongitude: baseLng,
        endLatitude: station.latitude!,
        endLongitude: station.longitude!,
      );
    }

    // 좌표 정보가 없는 경우 null 반환
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
      await loadVisibleStations();
    }
  }

  /// 주변 역 목록 새로고침 (하위 호환성)
  Future<void> loadNearbyStations({int radius = 3000}) async {
    final radiusKm = radius / 1000.0;
    await loadVisibleStations(radiusKm: radiusKm);
  }

  /// 실시간 위치 추적 시작
  void startLocationTracking() {
    _locationService.getPositionStream().listen(
      (position) {
        _currentPosition = position;
        // 현재 위치가 업데이트되면 지도 중심도 업데이트
        _currentCenterLat = position.latitude;
        _currentCenterLng = position.longitude;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '위치 추적 중 오류가 발생했습니다: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  /// 특정 역명으로 화면 내 역 필터링
  List<SeoulSubwayStation> filterStationsByName(String query) {
    if (query.isEmpty) return _visibleStations;

    return _visibleStations
        .where(
          (station) =>
              station.stationName.contains(query) ||
              station.lineName.contains(query),
        )
        .toList();
  }

  /// 호선별 화면 내 역 필터링
  List<SeoulSubwayStation> filterStationsByLine(String lineName) {
    return _visibleStations
        .where((station) => station.lineName.contains(lineName))
        .toList();
  }

  /// 화면 내 역 목록 강제 새로고침
  Future<void> forceRefreshVisibleStations() async {
    await loadVisibleStations();
  }

  /// 하위 호환성을 위한 메서드
  Future<void> forceRefreshNearbyStations() async {
    await forceRefreshVisibleStations();
  }

  /// 리소스 정리
  @override
  void dispose() {
    super.dispose();
  }
}
