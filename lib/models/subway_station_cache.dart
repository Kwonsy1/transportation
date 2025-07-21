import 'package:json_annotation/json_annotation.dart';
import 'subway_station.dart';

part 'subway_station_cache.g.dart';

/// 지하철역 캐시 데이터 모델
@JsonSerializable()
class SubwayStationCache {
  /// 역 ID
  final String stationId;
  
  /// 역명
  final String stationName;
  
  /// 호선명
  final String lineName;
  
  /// 호선 번호
  final String lineNumber;
  
  /// 위도
  final double? latitude;
  
  /// 경도
  final double? longitude;
  
  /// 주소
  final String? address;
  
  /// 마지막 업데이트 시간
  final DateTime lastUpdated;

  const SubwayStationCache({
    required this.stationId,
    required this.stationName,
    required this.lineName,
    required this.lineNumber,
    this.latitude,
    this.longitude,
    this.address,
    required this.lastUpdated,
  });

  factory SubwayStationCache.fromJson(Map<String, dynamic> json) => 
      _$SubwayStationCacheFromJson(json);

  Map<String, dynamic> toJson() => _$SubwayStationCacheToJson(this);

  /// SubwayStation에서 SubwayStationCache로 변환
  factory SubwayStationCache.fromSubwayStation(SubwayStation station) {
    return SubwayStationCache(
      stationId: station.subwayStationId,
      stationName: station.subwayStationName,
      lineName: station.subwayRouteName,
      lineNumber: station.lineNumber,
      latitude: station.latitude,
      longitude: station.longitude,
      address: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// SubwayStationCache에서 SubwayStation으로 변환
  SubwayStation toSubwayStation() {
    return SubwayStation(
      subwayStationId: stationId,
      subwayStationName: stationName,
      subwayRouteName: lineName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 좌표가 있는지 확인
  bool get hasCoordinates => latitude != null && longitude != null;

  /// 캐시가 유효한지 확인 (7일 이내)
  bool get isValid {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inDays < 7;
  }

  @override
  String toString() {
    return 'SubwayStationCache(stationId: $stationId, stationName: $stationName, lineName: $lineName, hasCoordinates: $hasCoordinates)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubwayStationCache && other.stationId == stationId;
  }

  @override
  int get hashCode => stationId.hashCode;
}
