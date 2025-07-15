import 'package:json_annotation/json_annotation.dart';

part 'subway_station.g.dart';

/// 지하철 역 정보 모델 (국토교통부 API 기준)
@JsonSerializable()
class SubwayStation {
  /// 지하철역 ID (예: MTRS11133)
  final String subwayStationId;

  /// 지하철역명 (예: 서울역)
  final String subwayStationName;

  /// 노선명 (예: 서울 1호선)
  final String subwayRouteName;

  /// 위도 (API에서 제공하지 않으므로 옵션)
  final double? latitude;

  /// 경도 (API에서 제공하지 않으므로 옵션)
  final double? longitude;

  const SubwayStation({
    required this.subwayStationId,
    required this.subwayStationName,
    required this.subwayRouteName,
    this.latitude,
    this.longitude,
  });

  factory SubwayStation.fromJson(Map<String, dynamic> json) {
    return SubwayStation(
      subwayStationId: json['subwayStationId']?.toString() ?? '',
      subwayStationName: json['subwayStationName']?.toString() ?? '',
      subwayRouteName: json['subwayRouteName']?.toString() ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => _$SubwayStationToJson(this);

  /// 호선 번호 추출 (노선명에서 추출)
  String get lineNumber {
    final regex = RegExp(r'(\d+)호선');
    final match = regex.firstMatch(subwayRouteName);
    return match?.group(1) ?? '1';
  }

  /// 단순화된 역명 (역 이름만)
  String get stationName => subwayStationName;

  /// 단순화된 노선명
  String get lineName => subwayRouteName;

  @override
  String toString() {
    return 'SubwayStation(subwayStationId: $subwayStationId, subwayStationName: $subwayStationName, subwayRouteName: $subwayRouteName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubwayStation && other.subwayStationId == subwayStationId;
  }

  @override
  int get hashCode => subwayStationId.hashCode;
}

/// 지하철역 출구별 버스노선 정보
@JsonSerializable()
class SubwayExitBusRoute {
  /// 지하철역 ID
  final String subwayStationId;

  /// 지하철역명
  final String subwayStationName;

  /// 출구번호
  final String exitNo;

  /// 버스노선명
  final String busRouteNm;

  /// 구간 여부 (Y/N)
  final String sectionYn;

  /// 기점 정류장명
  final String startSttnNm;

  /// 종점 정류장명
  final String endSttnNm;

  const SubwayExitBusRoute({
    required this.subwayStationId,
    required this.subwayStationName,
    required this.exitNo,
    required this.busRouteNm,
    required this.sectionYn,
    required this.startSttnNm,
    required this.endSttnNm,
  });

  factory SubwayExitBusRoute.fromJson(Map<String, dynamic> json) {
    // API 응답 필드명 디버깅
    print('SubwayExitBusRoute JSON keys: ${json.keys.toList()}');
    print('SubwayExitBusRoute JSON data: $json');
    
    return SubwayExitBusRoute(
      subwayStationId: json['subwayStationId']?.toString() ?? '',
      subwayStationName: json['subwayStationName']?.toString() ?? json['subwayStationNm']?.toString() ?? '',
      exitNo: json['exitNo']?.toString() ?? json['subwayExitNo']?.toString() ?? json['exitNumber']?.toString() ?? '',
      // 실제 API 필드명에 맞게 수정
      busRouteNm: json['busRouteNm']?.toString() ?? json['busRouteName']?.toString() ?? json['routeName']?.toString() ?? json['dirDesc']?.toString() ?? '',
      sectionYn: json['sectionYn']?.toString() ?? 'N',
      startSttnNm: json['startSttnNm']?.toString() ?? json['startStationNm']?.toString() ?? '',
      endSttnNm: json['endSttnNm']?.toString() ?? json['endStationNm']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subwayStationId': subwayStationId,
      'subwayStationName': subwayStationName,
      'exitNo': exitNo,
      'busRouteNm': busRouteNm,
      'sectionYn': sectionYn,
      'startSttnNm': startSttnNm,
      'endSttnNm': endSttnNm,
    };
  }
}

/// 지하철역 출구별 주변시설 정보
@JsonSerializable()
class SubwayExitFacility {
  /// 지하철역 ID
  final String subwayStationId;

  /// 지하철역명
  final String subwayStationName;

  /// 출구번호
  final String exitNo;

  /// 시설명
  final String cfFacilityNm;

  /// 시설 구분
  final String cfFacilityClss;

  /// 이용 시간
  final String useTime;

  /// 전화번호
  final String phoneNumber;

  const SubwayExitFacility({
    required this.subwayStationId,
    required this.subwayStationName,
    required this.exitNo,
    required this.cfFacilityNm,
    required this.cfFacilityClss,
    required this.useTime,
    required this.phoneNumber,
  });

  factory SubwayExitFacility.fromJson(Map<String, dynamic> json) {
    // API 응답 필드명 디버깅
    print('SubwayExitFacility JSON keys: ${json.keys.toList()}');
    print('SubwayExitFacility JSON data: $json');
    
    return SubwayExitFacility(
      subwayStationId: json['subwayStationId']?.toString() ?? '',
      subwayStationName: json['subwayStationName']?.toString() ?? json['subwayStationNm']?.toString() ?? '',
      exitNo: json['exitNo']?.toString() ?? json['subwayExitNo']?.toString() ?? json['exitNumber']?.toString() ?? '',
      // dirDesc가 실제 시설명인 것 같습니다
      cfFacilityNm: json['dirDesc']?.toString() ?? json['cfFacilityNm']?.toString() ?? json['facilityName']?.toString() ?? '',
      cfFacilityClss: json['cfFacilityClss']?.toString() ?? json['facilityClass']?.toString() ?? json['category']?.toString() ?? '시설',
      useTime: json['useTime']?.toString() ?? json['operatingTime']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? json['phoneNo']?.toString() ?? json['telNo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subwayStationId': subwayStationId,
      'subwayStationName': subwayStationName,
      'exitNo': exitNo,
      'cfFacilityNm': cfFacilityNm,
      'cfFacilityClss': cfFacilityClss,
      'useTime': useTime,
      'phoneNumber': phoneNumber,
    };
  }
}
