import 'package:hive/hive.dart';
import '../subway_station.dart';
import '../seoul_subway_station.dart';

part 'seoul_subway_station_hive.g.dart';

/// Hive용 서울 지하철역 정보 모델
@HiveType(typeId: 0)
class SeoulSubwayStationHive extends HiveObject {
  /// 역명
  @HiveField(0)
  final String stationName;

  /// 호선명
  @HiveField(1)
  final String lineName;

  /// 위도
  @HiveField(2)
  final double latitude;

  /// 경도
  @HiveField(3)
  final double longitude;

  /// 역코드 (옵션)
  @HiveField(4)
  final String? stationCode;

  /// 지하철구분명 (옵션)
  @HiveField(5)
  final String? subwayTypeName;

  /// 마지막 업데이트 시간
  @HiveField(6)
  final DateTime lastUpdated;

  /// 좌표 업데이트 완료 여부
  @HiveField(7)
  final bool hasValidCoordinates;

  SeoulSubwayStationHive({
    required this.stationName,
    required this.lineName,
    required this.latitude,
    required this.longitude,
    this.stationCode,
    this.subwayTypeName,
    required this.lastUpdated,
    required this.hasValidCoordinates,
  });

  /// SeoulSubwayStation에서 변환
  factory SeoulSubwayStationHive.fromSeoulSubwayStation(
    SeoulSubwayStation station, {
    DateTime? lastUpdated,
  }) {
    final now = lastUpdated ?? DateTime.now();
    final hasValidCoords = station.latitude != 0.0 && station.longitude != 0.0;

    return SeoulSubwayStationHive(
      stationName: station.stationName,
      lineName: station.lineName,
      latitude: station.latitude,
      longitude: station.longitude,
      stationCode: station.stationCode,
      subwayTypeName: station.subwayTypeName,
      lastUpdated: now,
      hasValidCoordinates: hasValidCoords,
    );
  }

  /// SeoulSubwayStation으로 변환
  SeoulSubwayStation toSeoulSubwayStation() {
    return SeoulSubwayStation(
      stationName: stationName,
      lineName: lineName,
      latitude: latitude,
      longitude: longitude,
      stationCode: stationCode,
      subwayTypeName: subwayTypeName,
    );
  }

  /// SubwayStation으로 변환
  SubwayStation toSubwayStation() {
    return SubwayStation(
      subwayStationId: stationCode ?? _generateStationId(),
      subwayStationName: stationName,
      subwayRouteName: '$lineName호선',
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 역명과 호선을 기반으로 고유한 ID 생성
  String _generateStationId() {
    return 'SEOUL_${stationName.hashCode.abs()}_${lineName.hashCode.abs()}';
  }

  /// 좌표 업데이트
  SeoulSubwayStationHive updateCoordinates(
    double newLatitude,
    double newLongitude,
  ) {
    return SeoulSubwayStationHive(
      stationName: stationName,
      lineName: lineName,
      latitude: newLatitude,
      longitude: newLongitude,
      stationCode: stationCode,
      subwayTypeName: subwayTypeName,
      lastUpdated: DateTime.now(),
      hasValidCoordinates: newLatitude != 0.0 && newLongitude != 0.0,
    );
  }

  /// 좌표가 유효한지 확인
  bool get isCoordinateValid =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  /// 좌표가 비어있는지 확인
  bool get isCoordinateEmpty => latitude == 0.0 || longitude == 0.0;

  @override
  String toString() {
    return 'SeoulSubwayStationHive('
        'stationName: $stationName, '
        'lineName: $lineName, '
        'lat: $latitude, '
        'lng: $longitude, '
        'hasValidCoords: $hasValidCoordinates'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeoulSubwayStationHive &&
        other.stationName == stationName &&
        other.lineName == lineName;
  }

  @override
  int get hashCode => stationName.hashCode ^ lineName.hashCode;
}
