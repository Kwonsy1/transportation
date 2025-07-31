import 'package:json_annotation/json_annotation.dart';
import '../utils/ksy_log.dart';

part 'subway_station.g.dart';

/// 지하철 역 정보 모델
@JsonSerializable()
class SubwayStation {
  /// 지하철역 ID (예: MTRS11133)
  final String subwayStationId;

  /// 지하철역명 (예: 서울역)
  final String subwayStationName;

  /// 노선명 (예: 서울 1호선)
  final String? subwayRouteName;

  /// 호선 번호 (예: "1", "2", "경의중앙")
  final String? lineNumber;

  /// 위도
  final double? latitude;

  /// 경도
  final double? longitude;

  /// 현재 위치로부터의 거리 (미터)
  final double? dist;

  SubwayStation({
    required this.subwayStationId,
    required this.subwayStationName,
    this.subwayRouteName,
    this.lineNumber,
    this.latitude,
    this.longitude,
    this.dist,
  });

  /// 안전한 double 파싱 헬퍼 함수
  static double _safeParseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // Factory constructor for the nearby API response (kkssyy.ipdisk.co.kr)
  factory SubwayStation.fromNearbyApiJson(Map<String, dynamic> json) {
    // 좌표 정보 추출
    final coordinates = json['coordinates'] as Map<String, dynamic>?;
    final latitude = coordinates?['latitude'] as double?;
    final longitude = coordinates?['longitude'] as double?;
    
    // subwayStationId 추출 디버깅
    final subwayStationId = json['subway_station_id']?.toString() ?? json['station_code']?.toString() ?? json['id']?.toString() ?? '';
    KSYLog.debug('🆔 SubwayStation.fromNearbyApiJson - name: ${json['name']}, subway_station_id: ${json['subway_station_id']}, station_code: ${json['station_code']}, id: ${json['id']}, final: $subwayStationId');
    
    return SubwayStation(
      subwayStationId: subwayStationId,
      subwayStationName: json['name'] as String? ?? '',
      subwayRouteName: json['line_number'] as String?,
      lineNumber: json['line_number'] as String?,
      latitude: latitude,
      longitude: longitude,
      dist: json['distance_km'] as double?,
    );
  }

  // Factory constructor for the government API response (국토교통부 API)
  factory SubwayStation.fromGovApiJson(Map<String, dynamic> json) {
    return SubwayStation(
      subwayStationId: json['STATION_CD']?.toString() ?? '',
      subwayStationName: json['STATION_NM']?.toString() ?? '',
      subwayRouteName: json['LINE_NUM']?.toString(),
      lineNumber: json['LINE_NUM']?.toString(), // LINE_NUM을 lineNumber로도 사용
      latitude: SubwayStation._safeParseDouble(json['YCOORD']), // YCOORD가 위도
      longitude: SubwayStation._safeParseDouble(json['XCOORD']), // XCOORD가 경도
      dist: null, // 국토교통부 API에는 dist 필드가 없을 수 있음
    );
  }

  Map<String, dynamic> toJson() => _$SubwayStationToJson(this);

  /// 호선 번호 (필드가 있으면 사용, 없으면 노선명에서 추출)
  String get effectiveLineNumber {
    // lineNumber 필드가 있으면 우선 사용
    if (lineNumber != null && lineNumber!.isNotEmpty) {
      return lineNumber!;
    }

    // subwayRouteName이 null이거나 비어있으면 기본값 반환
    if (subwayRouteName == null || subwayRouteName!.isEmpty) {
      return '정보없음'; // 또는 '1' 등 적절한 기본값
    }

    // 숫자 + '호선' 형식 추출 (예: '2호선' -> '2')
    final numberRegex = RegExp(r'(\d+)호선');
    final numberMatch = numberRegex.firstMatch(subwayRouteName!);
    if (numberMatch != null) {
      return numberMatch.group(1)!;
    }

    // '선'으로 끝나는 호선 처리 (예: '신분당선' -> '신분당')
    final lineSuffixRegex = RegExp(r'(.*)선$');
    final lineSuffixMatch = lineSuffixRegex.firstMatch(subwayRouteName!);
    if (lineSuffixMatch != null) {
      return lineSuffixMatch.group(1)!;
    }

    // 기타 특수 호선 처리 (정확한 이름 매칭)
    final specialLines = {
      '경의중앙선': '경의중앙',
      '분당선': '분당',
      '신분당선': '신분당',
      '경춘선': '경춘',
      '수인분당선': '수인분당',
      '우이신설선': '우이신설',
      '서해선': '서해',
      '김포골드라인': '김포',
      '신림선': '신림',
      // 필요한 경우 다른 특수 호선 추가
    };

    for (final entry in specialLines.entries) {
      if (subwayRouteName!.contains(entry.key)) { // <-- 이 부분을 contains로 변경
        return entry.value;
      }
    }

    // 위 규칙에 해당하지 않는 경우, 원본 노선명 반환
    return subwayRouteName!;
  }

  /// 단순화된 역명 (역 이름만)
  String get stationName => subwayStationName;

  /// 단순화된 노선명
  String get lineName => subwayRouteName ?? '';

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
    KSYLog.debug('SubwayExitBusRoute JSON keys: ${json.keys.toList()}');
    KSYLog.object('SubwayExitBusRoute JSON data', json);
    
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
    KSYLog.debug('SubwayExitFacility JSON keys: ${json.keys.toList()}');
    KSYLog.object('SubwayExitFacility JSON data', json);
    
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