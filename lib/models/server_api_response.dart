import 'package:json_annotation/json_annotation.dart';

part 'server_api_response.g.dart';

/// 커스텀 서버 API 표준 응답 모델
@JsonSerializable(genericArgumentFactories: true)
class StandardApiResponse<T> {
  /// 응답 상태 (success/error)
  final String status;

  /// HTTP 상태 코드
  final int code;

  /// 응답 메시지
  final String message;

  /// 응답 데이터
  final T? data;

  /// 리스트 데이터인 경우 총 개수
  final int? totalCount;

  /// 오류 상세 정보
  final String? error;

  /// 타임스탬프
  final String? timestamp;

  const StandardApiResponse({
    required this.status,
    required this.code,
    required this.message,
    this.data,
    this.totalCount,
    this.error,
    this.timestamp,
  });

  factory StandardApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$StandardApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$StandardApiResponseToJson(this, toJsonT);

  /// 성공 여부 확인
  bool get isSuccess => status == 'success' && code == 200;

  /// 에러 메시지 반환
  String? get errorMessage => error ?? message;
}

/// 그룹화된 역 응답 모델
@JsonSerializable()
class GroupedStationResponse {
  /// 역명
  final String stationName;

  /// 호선 목록
  final List<String> lines;

  /// 대표 위도
  final double? representativeLatitude;

  /// 대표 경도
  final double? representativeLongitude;

  /// 대표 주소
  final String? representativeAddress;

  /// 역 상세 정보 목록
  final List<StationDetail> details;

  /// 역 개수
  final int stationCount;

  /// 지역
  final String? region;

  const GroupedStationResponse({
    required this.stationName,
    required this.lines,
    this.representativeLatitude,
    this.representativeLongitude,
    this.representativeAddress,
    required this.details,
    required this.stationCount,
    this.region,
  });

  factory GroupedStationResponse.fromJson(Map<String, dynamic> json) =>
      _$GroupedStationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GroupedStationResponseToJson(this);
}

/// 역 상세 정보 모델
@JsonSerializable()
class StationDetail {
  /// 역 ID
  final int id;

  /// 호선 번호
  final String? lineNumber;

  /// 역 코드
  final String? stationCode;

  /// 위도
  final double? latitude;

  /// 경도
  final double? longitude;

  /// 주소
  final String? address;

  /// 지하철역 ID
  final String? subwayStationId;

  /// 데이터 소스
  final String? dataSource;

  const StationDetail({
    required this.id,
    required this.lineNumber,
    this.stationCode,
    this.latitude,
    this.longitude,
    this.address,
    this.subwayStationId,
    this.dataSource,
  });

  factory StationDetail.fromJson(Map<String, dynamic> json) =>
      _$StationDetailFromJson(json);

  Map<String, dynamic> toJson() => _$StationDetailToJson(this);
}

/// 좌표 정보 모델
@JsonSerializable()
class Coordinates {
  /// 위도
  final double latitude;

  /// 경도
  final double longitude;

  const Coordinates({required this.latitude, required this.longitude});

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      _$CoordinatesFromJson(json);

  Map<String, dynamic> toJson() => _$CoordinatesToJson(this);
}

/// 근처 역 그룹화 응답 모델
@JsonSerializable()
class GroupedNearbyStationResponse {
  /// 검색 반경 (km) - API가 camelCase로 변경됨
  final double searchRadiusKm;

  /// 역 목록
  final List<GroupedNearbyStation> stations;

  /// 총 개수 - API가 camelCase로 변경됨
  final int totalCount;

  /// 중심 좌표 - API가 camelCase로 변경됨
  final SearchCenter centerCoordinates;

  const GroupedNearbyStationResponse({
    required this.searchRadiusKm,
    required this.stations,
    required this.totalCount,
    required this.centerCoordinates,
  });

  factory GroupedNearbyStationResponse.fromJson(Map<String, dynamic> json) =>
      _$GroupedNearbyStationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GroupedNearbyStationResponseToJson(this);
}

/// 그룹화된 근처 역 정보
@JsonSerializable()
class GroupedNearbyStation {
  /// 역명 (API가 camelCase로 변경됨)
  final String? stationName;

  /// 좌표
  final Coordinates? coordinates;

  /// 거리 (km)
  final double distanceKm;

  /// 주소
  final String? address;

  /// 지역
  final String? region;

  /// 역 개수
  final int stationCount;

  /// 상세 정보 (진실의 원천)
  @JsonKey(defaultValue: [])
  final List<StationDetail> details;

  const GroupedNearbyStation({
    this.stationName,
    this.coordinates,
    required this.distanceKm,
    this.address,
    this.region,
    required this.stationCount,
    required this.details,
  });

  factory GroupedNearbyStation.fromJson(Map<String, dynamic> json) =>
      _$GroupedNearbyStationFromJson(json);

  Map<String, dynamic> toJson() => _$GroupedNearbyStationToJson(this);
}

/// 검색 중심 좌표
@JsonSerializable()
class SearchCenter {
  /// 위도
  final double latitude;

  /// 경도
  final double longitude;

  const SearchCenter({required this.latitude, required this.longitude});

  factory SearchCenter.fromJson(Map<String, dynamic> json) =>
      _$SearchCenterFromJson(json);

  Map<String, dynamic> toJson() => _$SearchCenterToJson(this);
}

/// 좌표 통계 모델
@JsonSerializable()
class CoordinateStatistics {
  /// 전체 역 수
  final int total;

  /// 좌표 있는 역 수
  final int hasCoordinates;

  /// 좌표 없는 역 수
  final int missingCoordinates;

  /// 완성도 (0.0 ~ 1.0)
  final double completionRate;

  const CoordinateStatistics({
    required this.total,
    required this.hasCoordinates,
    required this.missingCoordinates,
    required this.completionRate,
  });

  factory CoordinateStatistics.fromJson(Map<String, dynamic> json) =>
      _$CoordinateStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$CoordinateStatisticsToJson(this);
}
