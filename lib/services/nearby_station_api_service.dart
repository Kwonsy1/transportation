import '../models/subway_station.dart';
import 'http_service.dart';
import '../constants/api_constants.dart';
import '../utils/ksy_log.dart';

class NearbyStationApiService {
  final HttpService _httpService = HttpService.instance;

  /// GPS 좌표 기반으로 주변 지하철역 검색
  ///
  /// [latitude]: 위도 (GPS 좌표)
  /// [longitude]: 경도 (GPS 좌표)
  /// [limit]: 검색 결과 제한 (개수)
  Future<List<SubwayStation>> getNearbyStations({
    required double latitude,
    required double longitude,
    int limit = 100, // 기본값 100으로 설정
  }) async {
    try {
      final params = {
        'latitude': latitude,
        'longitude': longitude,
        'limit': limit,
        'radius': 50,
      };

      KSYLog.debug('API 호출: /api/stations/nearby, params: $params');

      final response = await _httpService.getNearbyApi(
        '/api/stations/nearby',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        // API 응답 구조 검증
        if (response.data == null) {
          throw Exception('API 응답 데이터가 null입니다');
        }

        final dynamic responseData = response.data;
        List<dynamic> stationsData;

        // 새로운 API 응답 구조에 맞춰 데이터 추출
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data')) {
          final dataSection = responseData['data'];
          if (dataSection is Map<String, dynamic> &&
              dataSection.containsKey('stations')) {
            stationsData = dataSection['stations'] as List<dynamic>;
          } else if (dataSection is List<dynamic>) {
            // data가 바로 리스트인 경우
            stationsData = dataSection;
          } else {
            throw Exception(
              'API 응답에서 stations 배열을 찾을 수 없습니다. data: $dataSection',
            );
          }
        } else if (responseData is List<dynamic>) {
          stationsData = responseData;
        } else {
          throw Exception('예상치 못한 API 응답 구조입니다. 응답: $responseData');
        }

        KSYLog.info('주변 역 검색 결과: ${stationsData.length}개 역 발견');

        // 첫 번째 항목의 구조를 확인
        if (stationsData.isNotEmpty) {
          KSYLog.debug('🔍 첫 번째 역 데이터 구조: ${stationsData.first}');
        }

        final stations = stationsData
            .map(
              (item) =>
                  SubwayStation.fromNearbyApiJson(item as Map<String, dynamic>),
            )
            .where(
              (station) =>
                  station.latitude != null && station.longitude != null,
            ) // 좌표가 유효한 역만 필터링
            .toList();

        return stations;
      } else {
        throw Exception(
          'API 호출 실패: ${response.statusCode} - ${response.statusMessage}',
        );
      }
    } catch (e) {
      KSYLog.error('주변 역 검색 오류', e);
      rethrow;
    }
  }
}
