import '../models/subway_station.dart';

/// 서울 열린데이터 광장 지하철역 정보 모델
class SeoulSubwayStation {
  /// 역명
  final String stationName;
  
  /// 호선명
  final String lineName;
  
  /// 위도
  final double latitude;
  
  /// 경도
  final double longitude;
  
  /// 역코드 (옵션)
  final String? stationCode;
  
  /// 지하철구분명 (옵션)
  final String? subwayTypeName;

  const SeoulSubwayStation({
    required this.stationName,
    required this.lineName,
    required this.latitude,
    required this.longitude,
    this.stationCode,
    this.subwayTypeName,
  });

  factory SeoulSubwayStation.fromJson(Map<String, dynamic> json) {
    return SeoulSubwayStation(
      stationName: json['STATION_NM']?.toString() ?? '',
      lineName: json['LINE_NUM']?.toString() ?? '',
      latitude: _parseDouble(json['YCOORD']),  // YCOORD가 위도
      longitude: _parseDouble(json['XCOORD']), // XCOORD가 경도
      stationCode: json['STATION_CD']?.toString(),
      subwayTypeName: json['SUBWAY_NM']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'STATION_NM': stationName,
      'LINE_NUM': lineName,
      'YCOORD': latitude,  // YCOORD가 위도
      'XCOORD': longitude, // XCOORD가 경도
      'STATION_CD': stationCode,
      'SUBWAY_NM': subwayTypeName,
    };
  }

  /// 기존 SubwayStation 모델로 변환
  SubwayStation toSubwayStation() {
    return SubwayStation(
      subwayStationId: stationCode ?? _generateStationId(),
      subwayStationName: stationName,
      subwayRouteName: '${lineName}호선',
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 역명과 호선을 기반으로 고유한 ID 생성
  String _generateStationId() {
    return 'SEOUL_${stationName.hashCode.abs()}_${lineName.hashCode.abs()}';
  }

  /// 안전한 double 파싱
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  String toString() {
    return 'SeoulSubwayStation(stationName: $stationName, lineName: $lineName, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeoulSubwayStation &&
        other.stationName == stationName &&
        other.lineName == lineName;
  }

  @override
  int get hashCode => stationName.hashCode ^ lineName.hashCode;
}
