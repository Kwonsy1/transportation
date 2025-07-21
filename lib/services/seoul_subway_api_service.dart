import 'dart:convert';
import 'dart:math' as math;
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../models/api_response.dart';
import 'http_service.dart';

/// 서울 열린데이터 광장 지하철 API 서비스
class SeoulSubwayApiService {
  final HttpService _httpService = HttpService.instance;
  
  // 서울 열린데이터 광장 지하철역명 검색 API
  static const String _baseUrl = 'http://openAPI.seoul.go.kr:8088';
  static const String _apiKey = '7045586a4268756e3531464a796d4b'; // 실제 API 키
  static const String _serviceName = 'SearchInfoBySubwayNameService';

  /// 모든 지하철역 목록 조회
  ///
  /// [startIndex] 요청 시작 위치 (기본값: 1)
  /// [endIndex] 요청 종료 위치 (기본값: 1000)
  Future<List<SeoulSubwayStation>> getAllStations({
    int startIndex = 1,
    int endIndex = 1000,
  }) async {
    try {
      final url = '$_baseUrl/$_apiKey/json/$_serviceName/$startIndex/$endIndex/';
      
      print('서울 지하철 API 요청 URL: $url');
      
      final response = await _httpService.get(url);
      
      if (response.data != null) {
        print('서울 지하철 API 응답: ${response.data}');
        
        final responseData = response.data as Map<String, dynamic>;
        
        // 응답 구조 확인
        if (responseData.containsKey(_serviceName)) {
          final serviceData = responseData[_serviceName] as Map<String, dynamic>;
          
          // 에러 체크
          if (serviceData.containsKey('RESULT')) {
            final result = serviceData['RESULT'] as Map<String, dynamic>;
            final code = result['CODE'] as String;
            final message = result['MESSAGE'] as String;
            
            if (code != 'INFO-000') {
              throw Exception('API 오류: $message (코드: $code)');
            }
          }
          
          // 데이터 파싱
          if (serviceData.containsKey('row')) {
            final rows = serviceData['row'] as List<dynamic>;
            
            return rows.map((row) {
              final data = row as Map<String, dynamic>;
              return SeoulSubwayStation.fromJson(data);
            }).toList();
          }
        }
      }
      
      return [];
    } catch (e) {
      print('서울 지하철역 목록 조회 오류: $e');
      rethrow;
    }
  }

  /// 지하철역명으로 검색
  ///
  /// [stationName] 검색할 역명
  Future<List<SeoulSubwayStation>> searchStationsByName(String stationName) async {
    try {
      // 전체 목록을 가져온 후 필터링
      final allStations = await getAllStations();
      
      // 역명으로 필터링 (부분 일치)
      return allStations.where((station) {
        return station.stationName.contains(stationName) ||
               station.stationName.replaceAll('역', '').contains(stationName.replaceAll('역', ''));
      }).toList();
    } catch (e) {
      print('지하철역 검색 오류: $e');
      rethrow;
    }
  }

  /// 위도, 경도를 이용한 주변 역 검색
  ///
  /// [latitude] 위도
  /// [longitude] 경도
  /// [radiusKm] 검색 반경 (km, 기본값: 2km)
  Future<List<SeoulSubwayStation>> searchNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
  }) async {
    try {
      final allStations = await getAllStations();
      
      // 거리 계산을 통한 필터링
      final nearbyStations = <SeoulSubwayStation>[];
      
      for (final station in allStations) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          station.latitude,
          station.longitude,
        );
        
        if (distance <= radiusKm) {
          nearbyStations.add(station);
        }
      }
      
      // 거리순으로 정렬
      nearbyStations.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      
      return nearbyStations;
    } catch (e) {
      print('주변 지하철역 검색 오류: $e');
      rethrow;
    }
  }

  /// 두 지점 간의 거리 계산 (Haversine formula)
  ///
  /// [lat1] 첫 번째 지점의 위도
  /// [lon1] 첫 번째 지점의 경도
  /// [lat2] 두 번째 지점의 위도
  /// [lon2] 두 번째 지점의 경도
  /// 반환값: 거리 (km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// 도를 라디안으로 변환
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

