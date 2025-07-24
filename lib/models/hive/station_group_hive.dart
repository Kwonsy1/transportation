import 'package:hive/hive.dart';
import '../station_group.dart';
import '../subway_station.dart';
import '../../utils/station_utils.dart';

part 'station_group_hive.g.dart';

/// Hive용 즐겨찾기 StationGroup 모델
@HiveType(typeId: 1)
class StationGroupHive extends HiveObject {
  @HiveField(0)
  final String stationName;

  @HiveField(1)
  final List<SubwayStationHive> stations;

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
          SubwayStationHive.fromSubwayStation(station)).toList(),
      latitude: group.latitude,
      longitude: group.longitude,
    );
  }

  /// StationGroup으로 변환
  StationGroup toStationGroup() {
    return StationGroup(
      stationName: stationName,
      stations: stations.map((station) => station.toSubwayStation()).toList(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 깨끗한 역명 (번호 제거)
  String get cleanStationName {
    return StationUtils.cleanStationName(stationName);
  }

  /// 포함된 호선 목록
  List<String> get availableLines {
    return stations.map((station) => station.subwayRouteName).toSet().toList()
      ..sort();
  }

  /// 대표 역 (첫 번째 역)
  SubwayStationHive get representativeStation => stations.first;

  @override
  String toString() {
    return 'StationGroupHive(name: $stationName, lines: ${availableLines.length})';
  }
}

/// Hive용 SubwayStation 모델
@HiveType(typeId: 2)
class SubwayStationHive extends HiveObject {
  @HiveField(0)
  final String subwayStationId;

  @HiveField(1)
  final String subwayStationName;

  @HiveField(2)
  final String subwayRouteName;

  @HiveField(3)
  final double? latitude;

  @HiveField(4)
  final double? longitude;

  @HiveField(5)
  final String? lineNumber;

  SubwayStationHive({
    required this.subwayStationId,
    required this.subwayStationName,
    required this.subwayRouteName,
    this.latitude,
    this.longitude,
    this.lineNumber,
  });

  /// SubwayStation에서 변환
  factory SubwayStationHive.fromSubwayStation(SubwayStation station) {
    return SubwayStationHive(
      subwayStationId: station.subwayStationId,
      subwayStationName: station.subwayStationName,
      subwayRouteName: station.subwayRouteName,
      latitude: station.latitude,
      longitude: station.longitude,
      lineNumber: station.lineNumber, // getter 사용
    );
  }

  /// SubwayStation으로 변환
  SubwayStation toSubwayStation() {
    return SubwayStation(
      subwayStationId: subwayStationId,
      subwayStationName: subwayStationName,
      subwayRouteName: subwayRouteName,
      latitude: latitude,
      longitude: longitude,
      // lineNumber는 getter이므로 생성자에서 제외
    );
  }

  @override
  String toString() {
    return 'SubwayStationHive(name: $subwayStationName, line: $subwayRouteName)';
  }
}
