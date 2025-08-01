import '../models/subway_station.dart';
import '../models/server_api_response.dart';
import 'http_service.dart';
import '../utils/ksy_log.dart';

class NearbyStationApiService {
  final HttpService _httpService = HttpService.instance;

  /// GPS 좌표 기반으로 주변 지하철역 검색 (레거시 호환)
  ///
  /// [latitude]: 위도 (GPS 좌표)
  /// [longitude]: 경도 (GPS 좌표)
  /// [limit]: 검색 결과 제한 (개수)
  @Deprecated('Use getNearbyStationsGrouped instead for better performance')
  Future<List<SubwayStation>> getNearbyStations({
    required double latitude,
    required double longitude,
    int limit = 100,
  }) async {
    try {
      // 새로운 그룹화된 API를 사용하여 기존 인터페이스 호환성 유지
      final groupedResponse = await getNearbyStationsGrouped(
        latitude: latitude,
        longitude: longitude,
        limit: limit,
        radius: 50,
      );

      // 그룹화된 결과를 개별 SubwayStation 목록으로 변환
      final stations = <SubwayStation>[];
      for (final group in groupedResponse.stations) {
        for (final detail in group.details) {
          stations.add(
            SubwayStation(
              subwayStationId: detail.subwayStationId ?? '',
              subwayStationName: group.stationName ?? '',
              subwayRouteName: detail.lineNumber,
              lineNumber: detail.lineNumber,
              latitude: group.coordinates!.latitude,
              longitude: group.coordinates!.longitude,
              dist: group.distanceKm,
            ),
          );
        }
      }

      KSYLog.info('주변 역 검색 결과(레거시): ${stations.length}개 역 발견');
      return stations;
    } catch (e) {
      KSYLog.error('주변 역 검색 오류(레거시)', e);
      rethrow;
    }
  }

  /// GPS 좌표 기반으로 주변 지하철역 검색 (그룹화된 결과)
  ///
  /// [latitude]: 위도 (33.0 ~ 43.0)
  /// [longitude]: 경도 (124.0 ~ 132.0)
  /// [radius]: 검색 반경 (km, 기본값: 2.0, 최대: 50.0)
  /// [limit]: 최대 결과 개수 (기본값: 80, 최대: 200)
  Future<GroupedNearbyStationResponse> getNearbyStationsGrouped({
    required double latitude,
    required double longitude,
    int radius = 2,
    int limit = 80,
  }) async {
    try {
      final params = {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'limit': limit,
      };

      KSYLog.debug('API 호출: /api/stations/nearby (그룹화), params: $params');

      final response = await _httpService.getNearbyApi(
        '/api/stations/nearby',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        // API 응답은 항상 StandardApiResponse로 래핑됨
        final apiResponse = StandardApiResponse<Map<String, dynamic>>.fromJson(
          response.data,
          (json) => json as Map<String, dynamic>,
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final nearbyResponse = GroupedNearbyStationResponse.fromJson(
            apiResponse.data!,
          );
          KSYLog.info('근처 역 검색 결과(그룹화): ${nearbyResponse.totalCount}개 그룹 발견');
          return nearbyResponse;
        } else {
          throw Exception('API 오류: ${apiResponse.errorMessage}');
        }
      } else {
        throw Exception(
          'API 호출 실패: ${response.statusCode} - ${response.statusMessage}',
        );
      }
    } catch (e) {
      KSYLog.error('근처 역 검색 오류(그룹화)', e);
      rethrow;
    }
  }
}
