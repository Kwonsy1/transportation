/// 지하철역 관련 유틸리티 함수들
class StationUtils {
  StationUtils._(); // 인스턴스 생성 방지

  /// 역명을 정규화 (검색 및 비교용)
  /// 
  /// - "역" 제거
  /// - 공백 제거 
  /// - 소문자 변환
  /// 
  /// 예: "강남역" → "강남", "서울 역" → "서울"
  static String normalizeStationName(String stationName) {
    return stationName
        .replaceAll('역', '')
        .replaceAll(' ', '')
        .toLowerCase()
        .trim();
  }

  /// 역명을 정리 (표시용)
  /// 
  /// - 마지막 "역"만 제거
  /// - 괄호 안 내용 제거 
  /// - 호선 번호 제거
  /// - 앞뒤 공백 제거
  /// 
  /// 예: "강남역(2호선)" → "강남", "서울역(1호선)" → "서울"
  static String cleanStationName(String stationName) {
    return stationName
        .replaceAll(RegExp(r'역$'), '') // 마지막 "역"만 제거
        .replaceAll(RegExp(r'\(.*?\)'), '') // 괄호 제거
        .replaceAll(RegExp(r'\d+호선'), '') // 호선 번호 제거
        .trim();
  }

  /// 역명을 검색용으로 정리 (부분 일치 검색용)
  /// 
  /// - "역" 제거만 수행
  /// - 대소문자는 유지
  /// 
  /// 예: "강남역" → "강남"
  static String cleanForSearch(String stationName) {
    return stationName.replaceAll('역', '').trim();
  }

  /// 두 역명이 같은 역인지 확인
  /// 
  /// 정규화 후 비교하여 "강남역"과 "강남"을 같은 역으로 인식
  static bool isSameStation(String stationName1, String stationName2) {
    final normalized1 = normalizeStationName(stationName1);
    final normalized2 = normalizeStationName(stationName2);
    return normalized1 == normalized2;
  }

  /// 역명 목록에서 특정 역명과 일치하는 항목 찾기
  static List<T> findMatchingStations<T>(
    List<T> stations,
    String searchName,
    String Function(T) getStationName,
  ) {
    final normalizedSearch = normalizeStationName(searchName);
    
    return stations.where((station) {
      final stationName = getStationName(station);
      final normalizedStation = normalizeStationName(stationName);
      return normalizedStation == normalizedSearch;
    }).toList();
  }

  /// 역명 목록에서 부분 일치하는 항목 찾기 (검색용)
  static List<T> searchStations<T>(
    List<T> stations,
    String query,
    String Function(T) getStationName,
  ) {
    final searchQuery = query.toLowerCase();
    
    return stations.where((station) {
      final stationName = getStationName(station).toLowerCase();
      return stationName.contains(searchQuery) ||
          cleanForSearch(stationName).contains(cleanForSearch(searchQuery));
    }).toList();
  }

  /// 즐겨찾기 키 생성 (일관된 키 형식)
  static String generateFavoriteKey(String stationName) {
    return cleanStationName(stationName);
  }

  /// 좌표 업데이트를 위한 역명 매칭 (유연한 매칭)
  static bool canUpdateCoordinates(String stationName1, String stationName2) {
    final clean1 = cleanForSearch(stationName1);
    final clean2 = cleanForSearch(stationName2);
    
    // 정확한 일치
    if (clean1 == clean2) return true;
    
    // 포함 관계 확인 (한쪽이 다른 쪽을 포함)
    return clean1.contains(clean2) || clean2.contains(clean1);
  }
}