import 'package:json_annotation/json_annotation.dart';

part 'naver_place.g.dart';

/// 네이버 지역 검색 API 응답 모델
@JsonSerializable()
class NaverPlace {
  final String title;
  final String link;
  final String category;
  final String description;
  final String telephone;
  final String address;
  final String roadAddress;
  final String mapx; // String으로 변경
  final String mapy; // String으로 변경

  NaverPlace({
    required this.title,
    required this.link,
    required this.category,
    required this.description,
    required this.telephone,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
  });

  factory NaverPlace.fromJson(Map<String, dynamic> json) => _$NaverPlaceFromJson(json);
  Map<String, dynamic> toJson() => _$NaverPlaceToJson(this);

  /// HTML 태그 제거된 제목
  String get cleanTitle => title.replaceAll(RegExp(r'<[^>]*>'), '');

  /// 경도 (longitude)
  double get longitude {
    try {
      final x = double.tryParse(mapx) ?? 0;
      return x / 10000000.0;
    } catch (e) {
      print('경도 파싱 오류: $mapx, $e');
      return 0.0;
    }
  }

  /// 위도 (latitude)  
  double get latitude {
    try {
      final y = double.tryParse(mapy) ?? 0;
      return y / 10000000.0;
    } catch (e) {
      print('위도 파싱 오류: $mapy, $e');
      return 0.0;
    }
  }

  /// 지하철역 여부 확인
  bool get isSubwayStation {
    final cleanText = cleanTitle.toLowerCase();
    final cleanCategory = category.toLowerCase();
    final cleanDescription = description.toLowerCase();
    
    final subwayKeywords = [
      '지하철', '전철', '역', 'subway', 'metro', 'station',
      '1호선', '2호선', '3호선', '4호선', '5호선', '6호선', '7호선', '8호선', '9호선',
    ];
    
    return subwayKeywords.any((keyword) => 
        cleanText.contains(keyword) || 
        cleanCategory.contains(keyword) ||
        cleanDescription.contains(keyword));
  }

  /// 호선 정보 추출
  String get lineInfo {
    final text = '$cleanTitle $category $description'.toLowerCase();
    
    final linePatterns = {
      '1호선': '1',
      '2호선': '2', 
      '3호선': '3',
      '4호선': '4',
      '5호선': '5',
      '6호선': '6',
      '7호선': '7',
      '8호선': '8',
      '9호선': '9',
      '중앙선': '중앙',
      '경의': '경의',
      '분당': '분당',
      '신분당': '신분당',
      '경춘': '경춘',
      '수인': '수인',
      '경강': '경강',
    };
    
    for (final entry in linePatterns.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return '기타';
  }

  @override
  String toString() {
    return 'NaverPlace(title: $cleanTitle, lat: $latitude, lng: $longitude, line: $lineInfo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NaverPlace &&
        other.cleanTitle == cleanTitle &&
        (other.latitude - latitude).abs() < 0.001 &&
        (other.longitude - longitude).abs() < 0.001;
  }

  @override
  int get hashCode => Object.hash(cleanTitle, latitude.round(), longitude.round());
}
