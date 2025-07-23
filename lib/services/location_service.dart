import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/ksy_log.dart';

/// 위치 서비스 관리 클래스
class LocationService {
  static LocationService? _instance;
  
  LocationService._internal();
  
  static LocationService get instance {
    _instance ??= LocationService._internal();
    return _instance!;
  }

  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      KSYLog.error('위치 권한 요청 오류', e);
      return false;
    }
  }

  /// 위치 권한 상태 확인
  Future<bool> checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      KSYLog.error('위치 권한 확인 오류', e);
      return false;
    }
  }

  /// 위치 서비스 활성화 상태 확인
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      KSYLog.error('위치 서비스 상태 확인 오류', e);
      return false;
    }
  }

  /// 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      KSYLog.debug('LocationService: 현재 위치 가져오기 시작');
      
      // 위치 서비스 활성화 확인
      final serviceEnabled = await isLocationServiceEnabled();
      KSYLog.debug('LocationService: 위치 서비스 활성화: $serviceEnabled');
      
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 비활성화되어 있습니다.');
      }

      // 위치 권한 확인
      final hasPermission = await checkLocationPermission();
      KSYLog.debug('LocationService: 위치 권한: $hasPermission');
      
      if (!hasPermission) {
        final granted = await requestLocationPermission();
        KSYLog.debug('LocationService: 권한 요청 결과: $granted');
        
        if (!granted) {
          throw Exception('위치 권한이 필요합니다.');
        }
      }

      // 현재 위치 가져오기
      KSYLog.debug('LocationService: Geolocator로 위치 가져오기 시작');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // 타임아웃 늘림
      );
      
      KSYLog.location('위치 가져오기 성공', position.latitude, position.longitude);
      return position;
      
    } catch (e) {
      KSYLog.error('LocationService: 현재 위치 가져오기 오류', e);
      rethrow;
    }
  }

  /// 위치 스트림 가져오기 (실시간 위치 추적)
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터 이동시마다 업데이트
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// 두 지점 간의 거리 계산 (미터)
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 두 지점 간의 방향 계산 (도)
  double calculateBearing({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 설정 앱으로 이동
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      KSYLog.error('LocationService: 위치 설정 열기 오류', e);
    }
  }

  /// 앱 설정으로 이동
  Future<void> openAppSettings() async {
    try {
      await Permission.location.request().then((status) {
        if (status.isDenied || status.isPermanentlyDenied) {
          Permission.location.request();
        }
      });
    } catch (e) {
      KSYLog.error('LocationService: 앱 설정 열기 오류', e);
    }
  }
}
