import 'package:hive/hive.dart';
import '../station_group.dart';
import '../subway_station.dart';
import '../../utils/station_utils.dart';
import 'seoul_subway_station_hive.dart';

part 'station_group_hive.g.dart';

/// Hive용 즐겨찾기 StationGroup 모델
@HiveType(typeId: 1)
class StationGroupHive extends HiveObject {
  @HiveField(0)
  final String stationName;

  @HiveField(1)
  final List<SeoulSubwayStationHive> stations;

  @HiveField(2)
  final double? latitude;

  @HiveField(3)
  final double? longitude;

  @HiveField(4)
  final DateTime createdAt;

  StationGroupHive({
    required this.stationName,
    required this.stations,
    this.latitude,
    this.longitude,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// StationGroup에서 변환
  factory StationGroupHive.fromStationGroup(StationGroup group) {
    return StationGroupHive(
      stationName: group.stationName,
      stations: group.stations.map((station) => 
          _subwayStationToSeoulSubwayStationHive(station)).toList(),
      latitude: group.latitude,
      longitude: group.longitude,
    );
  }

  /// SubwayStation을 SeoulSubwayStationHive로 변환하는 헬퍼 메서드
  static SeoulSubwayStationHive _subwayStationToSeoulSubwayStationHive(SubwayStation station) {
    return SeoulSubwayStationHive(
      stationName: station.subwayStationName,
      lineName: station.subwayRouteName ?? '',
      latitude: station.latitude ?? 0.0,
      longitude: station.longitude ?? 0.0,
      stationCode: station.subwayStationId,
      lastUpdated: DateTime.now(),
      hasValidCoordinates: station.latitude != null && station.longitude != null,
    );
  }

  /// StationGroup으로 변환
  StationGroup toStationGroup() {
    return StationGroup(
      stationName: stationName,
      stations: stations.map((station) => _seoulSubwayStationHiveToSubwayStation(station)).toList(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// SeoulSubwayStationHive를 SubwayStation으로 변환하는 헬퍼 메서드
  static SubwayStation _seoulSubwayStationHiveToSubwayStation(SeoulSubwayStationHive station) {
    return SubwayStation(
      subwayStationId: station.stationCode ?? '',
      subwayStationName: station.stationName,
      subwayRouteName: station.lineName.isEmpty ? null : station.lineName,
      latitude: station.latitude == 0.0 ? null : station.latitude,
      longitude: station.longitude == 0.0 ? null : station.longitude,
    );
  }

  /// 깨끗한 역명 (번호 제거)
  String get cleanStationName {
    return StationUtils.cleanStationName(stationName);
  }

  /// 포함된 호선 목록
  List<String> get availableLines {
    return stations
        .map((station) => station.lineName)
        .where((routeName) => routeName.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 대표 역 (첫 번째 역)
  SeoulSubwayStationHive get representativeStation => stations.first;

  @override
  String toString() {
    return 'StationGroupHive(name: $stationName, lines: ${availableLines.length})';
  }
}

