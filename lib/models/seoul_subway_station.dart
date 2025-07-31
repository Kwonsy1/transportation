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
  
  /// 국토교통부 API용 지하철역 ID (옵션)
  final String? subwayStationId;

  const SeoulSubwayStation({
    required this.stationName,
    required this.lineName,
    required this.latitude,
    required this.longitude,
    this.stationCode,
    this.subwayTypeName,
    this.subwayStationId,
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
    final normalizedLineNumber = _normalizeLineNumber(lineName);
    final routeName = _formatRouteName(lineName);
    
    return SubwayStation(
      subwayStationId: subwayStationId ?? stationCode ?? _generateStationId(),
      subwayStationName: stationName,
      subwayRouteName: routeName,
      latitude: latitude,
      longitude: longitude,
      lineNumber: normalizedLineNumber,
    );
  }
  
  /// 호선 번호 정규화 (02 → 2, 01 → 1)
  String _normalizeLineNumber(String lineNumber) {
    // 숫자로 시작하는 호선 처리 (01호선 → 1, 02호선 → 2)
    final numberMatch = RegExp(r'^0?(\d+)').firstMatch(lineNumber);
    if (numberMatch != null) {
      return numberMatch.group(1)!;
    }
    
    // 특수 호선 처리
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
    };
    
    for (final entry in specialLines.entries) {
      if (lineNumber.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 기타 경우 원본 반환 (호선 제거)
    return lineNumber.replaceAll('호선', '').trim();
  }
  
  /// 호선명 포맷팅
  String _formatRouteName(String lineNumber) {
    // 이미 "호선"이 포함되어 있으면 그대로 사용
    if (lineNumber.contains('호선')) {
      // 02호선 → 2호선으로 정규화
      final numberMatch = RegExp(r'^0?(\d+)호선').firstMatch(lineNumber);
      if (numberMatch != null) {
        return '${numberMatch.group(1)}호선';
      }
      return lineNumber;
    }
    
    // 특수 호선들은 "선"이 이미 포함되어 있음
    final specialLines = [
      '경의중앙선', '분당선', '신분당선', '경춘선', 
      '수인분당선', '우이신설선', '서해선', '김포골드라인', '신림선'
    ];
    
    for (final specialLine in specialLines) {
      if (lineNumber.contains(specialLine.replaceAll('선', ''))) {
        return specialLine;
      }
    }
    
    // 숫자만 있는 경우 "호선" 추가
    final numberMatch = RegExp(r'^0?(\d+)$').firstMatch(lineNumber);
    if (numberMatch != null) {
      return '${numberMatch.group(1)}호선';
    }
    
    // 기타 경우 원본에 "호선" 추가
    return '${lineNumber}호선';
  }

  /// 역명과 호선을 기반으로 고유한 ID 생성
  String _generateStationId() {
    final normalizedLine = _normalizeLineNumber(lineName);
    return 'SEOUL_${stationName.hashCode.abs()}_${normalizedLine.hashCode.abs()}';
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
