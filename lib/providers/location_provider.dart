import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/subway_station.dart';
import '../services/location_service.dart';
import '../services/nearby_station_api_service.dart';
import '../utils/ksy_log.dart';

/// 위치 정보 상태 관리 Provider
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService.instance;
  final NearbyStationApiService _nearbyStationApiService = NearbyStationApiService();

  // 현재 위치
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // 주변 역 목록
  List<SubwayStation> _nearbyStations = [];
  List<SubwayStation> get nearbyStations => _nearbyStations;

  // 위치 권한 상태
  bool _hasLocationPermission = false;
  bool get hasLocationPermission => _hasLocationPermission;

  // 로딩 상태
  bool _isLoadingLocation = false;
  bool _isLoadingNearbyStations = false;

  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingNearbyStations => _isLoadingNearbyStations;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  /// 주변 역 목록 불러오기
  Future<void> loadNearbyStations({int limit = 100}) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
    }

    if (_currentPosition == null) {
      _errorMessage = '현재 위치를 알 수 없어 주변 역을 검색할 수 없습니다.';
      notifyListeners();
      return;
    }

    _isLoadingNearbyStations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _nearbyStations = await _nearbyStationApiService.getNearbyStations(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        limit: limit,
      );
    } catch (e) {
      _errorMessage = '주변 역 정보를 불러오는데 실패했습니다: ${e.toString()}';
      _nearbyStations = [];
    } finally {
      _isLoadingNearbyStations = false;
      notifyListeners();
    }
  }

  /// 위치 정보 새로고침
  Future<void> refreshLocation() async {
    await loadNearbyStations();
  }

  /// 앱 설정으로 이동
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// 두 지점 간 거리 계산 (실제 좌표 기반)
  double? calculateDistanceToStation(SubwayStation station) {
    // 현재 위치가 없으면 null 반환
    if (_currentPosition == null) return null;

    // 역에 좌표 정보가 있는 경우 실제 거리 계산
    if (station.latitude != null && station.longitude != null) {
      return _locationService.calculateDistance(
        startLatitude: _currentPosition!.latitude,
        startLongitude: _currentPosition!.longitude,
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
