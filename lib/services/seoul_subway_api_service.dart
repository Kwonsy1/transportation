import '../models/seoul_subway_station.dart';
import 'http_service.dart';
import '../utils/ksy_log.dart';
import '../utils/location_utils.dart';
import '../utils/station_utils.dart';

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
      final url =
          '$_baseUrl/$_apiKey/json/$_serviceName/$startIndex/$endIndex/';

      KSYLog.info('서울 지하철 API 요청 URL: $url');

      final response = await _httpService.get(url);

      if (response.data != null) {
        KSYLog.debug('서울 지하철 API 응답: ${response.data}');

        final responseData = response.data as Map<String, dynamic>;

        // 응답 구조 확인
        if (responseData.containsKey(_serviceName)) {
          final serviceData =
              responseData[_serviceName] as Map<String, dynamic>;

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
      KSYLog.error('서울 지하철역 목록 조회 오류', e);
      rethrow;
    }
  }

  /// 지하철역명으로 검색
  ///
  /// [stationName] 검색할 역명
  Future<List<SeoulSubwayStation>> searchStationsByName(
    String stationName,
  ) async {
    try {
      // 전체 목록을 가져온 후 필터링
      final allStations = await getAllStations();

      // 역명으로 필터링 (부분 일치)
      return StationUtils.searchStations(
        allStations,
        stationName,
        (station) => station.stationName,
      );
    } catch (e) {
      KSYLog.error('지하철역 검색 오류', e);
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
        final distance = LocationUtils.calculateDistanceKm(
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
        final distanceA = LocationUtils.calculateDistanceKm(
          latitude,
          longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = LocationUtils.calculateDistanceKm(
          latitude,
          longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyStations;
    } catch (e) {
      KSYLog.error('주변 지하철역 검색 오류', e);
      rethrow;
    }
  }

}
