import '../models/server_api_response.dart';
import '../models/subway_station.dart';
import 'http_service.dart';
import '../utils/ksy_log.dart';

/// 커스텀 서버 API 서비스 클래스
class ServerApiService {
  final HttpService _httpService = HttpService.instance;

  /// 스마트 역명 검색 (개별 역 반환)
  /// 
  /// [stationName]: 검색할 역명
  /// 
  /// 정확한 매칭을 우선시하는 스마트 검색
  /// '강남' 검색 시 '강남역'만 반환하고 '강남구청역'은 제외
  Future<List<SubwayStation>> searchStationsSmart(String stationName) async {
    try {
      KSYLog.debug('API 호출: /api/subway/stations/search-smart, stationName: $stationName');

      final response = await _httpService.getNearbyApi(
        '/api/subway/stations/search-smart',
        queryParameters: {'stationName': stationName},
      );

      if (response.statusCode == 200) {
        final apiResponse = StandardApiResponse<List<dynamic>>.fromJson(
          response.data,
          (json) => json as List<dynamic>,
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final stations = apiResponse.data!
              .map((item) => SubwayStation.fromServerApiJson(item as Map<String, dynamic>))
              .where((station) => station.latitude != null && station.longitude != null)
              .toList();

          KSYLog.info('스마트 역명 검색 결과: ${stations.length}개 역 발견');
          return stations;
        } else {
          throw Exception('API 오류: ${apiResponse.errorMessage}');
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('스마트 역명 검색 오류', e);
      rethrow;
    }
  }

  /// 역명 검색 (스마트 그룹화된 결과)
  /// 
  /// [stationName]: 검색할 역명
  /// 
  /// 역명으로 지하철역 정보 검색 후 정확한 매칭을 우선시하여 그룹화
  /// '강남' 검색 시 '강남역'만 반환하고 '강남구청역'은 제외
  Future<List<GroupedStationResponse>> searchStationsGrouped(String stationName) async {
    try {
      KSYLog.debug('API 호출: /api/subway/stations/search-grouped, stationName: $stationName');

      final response = await _httpService.getNearbyApi(
        '/api/subway/stations/search-grouped',
        queryParameters: {'stationName': stationName},
      );

      KSYLog.debug('API 응답 상태 코드: ${response.statusCode}');
      KSYLog.debug('API 응답 데이터: ${response.data}');
      
      if (response.statusCode == 200) {
        try {
          final apiResponse = StandardApiResponse<List<dynamic>>.fromJson(
            response.data,
            (json) => json as List<dynamic>,
          );

          KSYLog.debug('API 응답 파싱 성공 - status: ${apiResponse.status}, code: ${apiResponse.code}');

          if (apiResponse.isSuccess && apiResponse.data != null) {
            final groupedStations = apiResponse.data!
                .map((item) => GroupedStationResponse.fromJson(item as Map<String, dynamic>))
                .toList();

            KSYLog.info('그룹화된 역명 검색 결과: ${groupedStations.length}개 그룹 발견');
            return groupedStations;
          } else {
            KSYLog.warning('API 응답 실패 - message: ${apiResponse.message}, error: ${apiResponse.error}');
            throw Exception('API 오류: ${apiResponse.errorMessage}');
          }
        } catch (parseError) {
          KSYLog.error('JSON 파싱 오류', parseError);
          KSYLog.debug('원시 응답 데이터: ${response.data}');
          rethrow;
        }
      } else {
        KSYLog.warning('API 호출 실패 - statusCode: ${response.statusCode}, statusMessage: ${response.statusMessage}');
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('그룹화된 역명 검색 오류: $stationName', e);
      KSYLog.debug('스택 트레이스: ${StackTrace.current}');
      rethrow;
    }
  }

  /// 노선별 역 목록 조회 (로컬 DB)
  /// 
  /// [lineNumber]: 노선번호 (예: 01호선, 02호선, 경의선)
  /// 
  /// 특정 노선의 모든 역 목록 조회 (로컬 데이터베이스 사용)
  Future<List<SubwayStation>> getStationsByLine(String lineNumber) async {
    try {
      KSYLog.debug('API 호출: /api/subway/lines/$lineNumber/stations');

      final response = await _httpService.getNearbyApi(
        '/api/subway/lines/$lineNumber/stations',
      );

      if (response.statusCode == 200) {
        final apiResponse = StandardApiResponse<List<dynamic>>.fromJson(
          response.data,
          (json) => json as List<dynamic>,
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final stations = apiResponse.data!
              .map((item) => SubwayStation.fromServerApiJson(item as Map<String, dynamic>))
              .where((station) => station.latitude != null && station.longitude != null)
              .toList();

          KSYLog.info('$lineNumber 노선 역 목록: ${stations.length}개 역 발견');
          return stations;
        } else {
          throw Exception('API 오류: ${apiResponse.errorMessage}');
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('노선별 역 목록 조회 오류', e);
      rethrow;
    }
  }

  /// 가장 가까운 지하철역 조회 (그룹화된 결과)
  /// 
  /// [latitude]: 위도
  /// [longitude]: 경도
  /// 
  /// 주어진 좌표에서 가장 가까운 지하철역 그룹 1개를 조회
  /// 같은 역명의 여러 노선이 있을 경우 하나로 그룹화
  Future<GroupedNearbyStation?> getNearestStation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final params = {
        'latitude': latitude,
        'longitude': longitude,
      };

      KSYLog.debug('API 호출: /api/stations/nearest, params: $params');

      final response = await _httpService.getNearbyApi(
        '/api/stations/nearest',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final apiResponse = StandardApiResponse<Map<String, dynamic>>.fromJson(
          response.data,
          (json) => json as Map<String, dynamic>,
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final nearestStation = GroupedNearbyStation.fromJson(apiResponse.data!);
          KSYLog.info('가장 가까운 역: ${nearestStation.stationName} (거리: ${nearestStation.distanceKm}km)');
          return nearestStation;
        } else {
          throw Exception('API 오류: ${apiResponse.errorMessage}');
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('가장 가까운 역 조회 오류', e);
      rethrow;
    }
  }

  /// 근처 지하철역 조회 (그룹화된 결과)
  /// 
  /// [latitude]: 위도 (33.0 ~ 43.0)
  /// [longitude]: 경도 (124.0 ~ 132.0)
  /// [radius]: 검색 반경 (km, 기본값: 2.0, 최대: 50.0)
  /// [limit]: 최대 결과 개수 (기본값: 80, 최대: 200)
  /// 
  /// 주어진 좌표를 중심으로 지정된 반경 내의 지하철역을 그룹화하여 거리순으로 조회
  /// 같은 역명이고 5km 이내에 있는 역들을 하나로 그룹화하여 반환
  Future<GroupedNearbyStationResponse> getNearbyStationsGrouped({
    required double latitude,
    required double longitude,
    double radius = 2.0,
    int limit = 80,
  }) async {
    try {
      final params = {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'limit': limit,
      };

      KSYLog.debug('API 호출: /api/stations/nearby, params: $params');

      final response = await _httpService.getNearbyApi(
        '/api/stations/nearby',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        // 응답이 StandardApiResponse로 래핑되지 않고 직접 GroupedNearbyStationResponse인 경우
        if (response.data is Map<String, dynamic> && 
            response.data.containsKey('stations')) {
          final nearbyResponse = GroupedNearbyStationResponse.fromJson(response.data);
          KSYLog.info('근처 역 검색 결과: ${nearbyResponse.totalCount}개 그룹 발견');
          return nearbyResponse;
        } 
        // StandardApiResponse로 래핑된 경우
        else {
          final apiResponse = StandardApiResponse<Map<String, dynamic>>.fromJson(
            response.data,
            (json) => json as Map<String, dynamic>,
          );

          if (apiResponse.isSuccess && apiResponse.data != null) {
            final nearbyResponse = GroupedNearbyStationResponse.fromJson(apiResponse.data!);
            KSYLog.info('근처 역 검색 결과: ${nearbyResponse.totalCount}개 그룹 발견');
            return nearbyResponse;
          } else {
            throw Exception('API 오류: ${apiResponse.errorMessage}');
          }
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('근처 역 검색 오류', e);
      rethrow;
    }
  }

  /// 좌표 완성도 통계 조회
  /// 
  /// 전체 역 대비 좌표 보유 현황 통계를 조회
  Future<CoordinateStatistics> getCoordinateStatistics() async {
    try {
      KSYLog.debug('API 호출: /api/subway/coordinates/statistics');

      final response = await _httpService.getNearbyApi(
        '/api/subway/coordinates/statistics',
      );

      if (response.statusCode == 200) {
        final apiResponse = StandardApiResponse<Map<String, dynamic>>.fromJson(
          response.data,
          (json) => json as Map<String, dynamic>,
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final statistics = CoordinateStatistics.fromJson(apiResponse.data!);
          KSYLog.info('좌표 통계: 전체 ${statistics.total}개 역 중 ${statistics.hasCoordinates}개 역 좌표 보유 (완성도: ${(statistics.completionRate * 100).toStringAsFixed(1)}%)');
          return statistics;
        } else {
          throw Exception('API 오류: ${apiResponse.errorMessage}');
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('좌표 통계 조회 오류', e);
      rethrow;
    }
  }

  /// 헬스체크 (간단한 서버 상태 확인)
  /// 
  /// 서버의 기본적인 동작 상태를 확인
  Future<String> healthCheck() async {
    try {
      KSYLog.debug('API 호출: /api/health');

      final response = await _httpService.getNearbyApi('/api/health');

      if (response.statusCode == 200) {
        final result = response.data?.toString() ?? '서버 정상';
        KSYLog.info('헬스체크 결과: $result');
        return result;
      } else {
        throw Exception('헬스체크 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('헬스체크 오류', e);
      rethrow;
    }
  }

  /// API 기본 정보 조회
  /// 
  /// Transportation Server API의 기본 상태를 반환
  Future<String> getApiInfo() async {
    try {
      KSYLog.debug('API 호출: /api/');

      final response = await _httpService.getNearbyApi('/api/');

      if (response.statusCode == 200) {
        final result = response.data?.toString() ?? 'API 정상 동작';
        KSYLog.info('API 기본 정보: $result');
        return result;
      } else {
        throw Exception('API 기본 정보 조회 실패: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      KSYLog.error('API 기본 정보 조회 오류', e);
      rethrow;
    }
  }
}