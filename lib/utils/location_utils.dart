import 'dart:math';

/// 위치 관련 유틸리티 함수들
class LocationUtils {
  LocationUtils._(); // 인스턴스 생성 방지

  /// 지구 반지름 (km)
  static const double _earthRadiusKm = 6371.0;
  
  /// 지구 반지름 (m) 
  static const double _earthRadiusM = 6371000.0;

  /// 두 지점 간의 거리 계산 (Haversine formula)
  /// 
  /// [lat1] 첫 번째 지점의 위도
  /// [lon1] 첫 번째 지점의 경도  
  /// [lat2] 두 번째 지점의 위도
  /// [lon2] 두 번째 지점의 경도
  /// [unit] 거리 단위 ('km' 또는 'm')
  /// 
  /// 반환값: 거리 (지정된 단위)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    String unit = 'km',
  }) {
    // 동일한 지점인 경우
    if (lat1 == lat2 && lon1 == lon2) return 0.0;
    
    final earthRadius = unit == 'km' ? _earthRadiusKm : _earthRadiusM;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// 두 지점 간의 거리 계산 (km 단위)
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2, unit: 'km');
  }

  /// 두 지점 간의 거리 계산 (m 단위)
  static double calculateDistanceM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2, unit: 'm');
  }

  /// 도를 라디안으로 변환
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 거리를 사용자 친화적인 문자열로 포맷
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 중심점으로부터 반지름 내에 있는 지점들 필터링
  static List<T> filterByRadius<T>(
    List<T> items,
    double centerLat,
    double centerLon,
    double radiusKm,
    double Function(T) getLatitude,
    double Function(T) getLongitude,
  ) {
    return items.where((item) {
      final distance = calculateDistanceKm(
        centerLat,
        centerLon,
        getLatitude(item),
        getLongitude(item),
      );
      return distance <= radiusKm;
    }).toList();
  }

  /// 거리순으로 정렬
  static List<T> sortByDistance<T>(
    List<T> items,
    double baseLat,
    double baseLon,
    double Function(T) getLatitude,
    double Function(T) getLongitude,
  ) {
    final itemsWithDistance = items.map((item) {
      final distance = calculateDistanceKm(
        baseLat,
        baseLon,
        getLatitude(item),
        getLongitude(item),
      );
      return _ItemWithDistance<T>(item, distance);
    }).toList();

    itemsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
    
    return itemsWithDistance.map((item) => item.data).toList();
  }
}

/// 거리 정보와 함께 아이템을 저장하는 내부 클래스
class _ItemWithDistance<T> {
  final T data;
  final double distance;

  _ItemWithDistance(this.data, this.distance);
}