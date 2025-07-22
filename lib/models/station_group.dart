import 'package:json_annotation/json_annotation.dart';
import 'subway_station.dart';

part 'station_group.g.dart';

/// 동일한 역명의 여러 호선을 그룹화하는 모델
@JsonSerializable()
class StationGroup {
  final String stationName;
  final List<SubwayStation> stations;
  final double? latitude;
  final double? longitude;

  StationGroup({
    required this.stationName,
    required this.stations,
    this.latitude,
    this.longitude,
  });

  factory StationGroup.fromJson(Map<String, dynamic> json) =>
      _$StationGroupFromJson(json);
  Map<String, dynamic> toJson() => _$StationGroupToJson(this);

  /// 깨끗한 역명 (마지막 "역"만 제거)
  String get cleanStationName {
    // 마지막이 "역"으로 끝나는 경우에만 제거
    if (stationName.endsWith('역')) {
      return stationName.substring(0, stationName.length - 1);
    }
    return stationName
        .replaceAll(RegExp(r'\d+호선'), '')
        .trim();
  }

  /// 포함된 호선 목록
  List<String> get availableLines {
    return stations.map((station) => station.subwayRouteName).toSet().toList()
      ..sort();
  }

  /// 대표 역 (첫 번째 역)
  SubwayStation get representativeStation => stations.first;

  /// 특정 호선의 역 찾기
  SubwayStation? getStationByLine(String lineName) {
    try {
      return stations.firstWhere(
        (station) => station.subwayRouteName == lineName,
      );
    } catch (e) {
      return null;
    }
  }

  /// 호선 번호로 역 찾기
  SubwayStation? getStationByLineNumber(String lineNumber) {
    try {
      return stations.firstWhere(
        (station) => station.effectiveLineNumber == lineNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// 거리 정보 (현재는 지원하지 않음)
  double? get distance => null;

  /// 호선명 텍스트 (UI 표시용)
  String get lineNamesText {
    final lines = stations
        .map((station) => station.effectiveLineNumber)
        .toSet()
        .toList();
    lines.sort((a, b) {
      final numA = int.tryParse(a) ?? 999;
      final numB = int.tryParse(b) ?? 999;
      return numA.compareTo(numB);
    });
    return lines
        .map((line) {
          // 숫자만 있는 경우 "호선" 추가, 특수 호선은 "선" 추가
          if (RegExp(r'^\d+$').hasMatch(line)) {
            return '$line호선';
          } else {
            return line.endsWith('선') ? line : '$line선';
          }
        })
        .join(', ');
  }

  /// 호선 개수
  int get lineCount => stations.length;

  @override
  String toString() {
    return 'StationGroup(name: $stationName, lines: ${availableLines.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StationGroup && other.stationName == stationName;
  }

  @override
  int get hashCode => stationName.hashCode;
}

/// 역 목록을 그룹화하는 유틸리티 클래스
class StationGrouper {
  /// 역 목록을 역명으로 그룹화
  static List<StationGroup> groupStations(List<SubwayStation> stations) {
    final Map<String, List<SubwayStation>> groupedMap = {};

    for (final station in stations) {
      final cleanName = _getCleanStationName(station.subwayStationName);

      if (!groupedMap.containsKey(cleanName)) {
        groupedMap[cleanName] = [];
      }
      groupedMap[cleanName]!.add(station);
    }

    return groupedMap.entries.map((entry) {
      final stationName = entry.key;
      final stationList = entry.value;

      // 좌표는 첫 번째 역의 좌표 사용
      final firstStation = stationList.first;

      return StationGroup(
        stationName: stationName,
        stations: stationList,
        latitude: firstStation.latitude,
        longitude: firstStation.longitude,
      );
    }).toList();
  }

  /// 역명에서 불필요한 부분 제거
  static String _getCleanStationName(String stationName) {
    return stationName
        .replaceAll(RegExp(r'역$'), '') // 마지막 "역"만 제거
        .replaceAll(RegExp(r'\(\w+\)'), '') // 괄호 안 내용 제거
        .trim();
  }
}
