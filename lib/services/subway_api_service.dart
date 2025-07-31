import '../constants/api_constants.dart';
import '../models/subway_station.dart';
import '../models/subway_schedule.dart';
import '../models/next_train_info.dart';
import '../models/api_response.dart';
import 'http_service.dart';
import '../utils/ksy_log.dart';

/// 국토교통부 지하철정보 API 서비스
class SubwayApiService {
  final HttpService _httpService = HttpService.instance;

  /// 키워드기반 지하철역 목록 조회
  ///
  /// [stationName] 지하철역명 (예: '서울역')  
  /// [numOfRows] 한 페이지 결과 수 (기본값: 100)
  /// [pageNo] 페이지 번호 (기본값: 1)
  Future<List<SubwayStation>> searchStations({
    required String stationName,
    int numOfRows = 100,
    int pageNo = 1,
  }) async {
    try {
      final queryParams = {
        'serviceKey': ApiConstants.subwayApiKey,
        'numOfRows': numOfRows,
        'pageNo': pageNo,
        'subwayStationName': stationName,
        '_type': 'json',
      };

      final response = await _httpService.get(
        ApiConstants.stationSearchEndpoint,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final apiResponse = SubwayApiResponse.fromJson(response.data);

        if (!apiResponse.isSuccess) {
          throw Exception(apiResponse.errorMessage ?? '지하철역 검색에 실패했습니다.');
        }

        return apiResponse.items
            .map((item) => SubwayStation.fromGovApiJson(item))
            .toList();
      }

      return [];
    } catch (e) {
      KSYLog.error('지하철역 검색 오류: $e');
      rethrow;
    }
  }

  /// 좌표 기반 지하철역 목록 조회 (공공데이터포털 API)
  ///
  /// [tmX] TM 좌표 X (경도 변환)
  /// [tmY] TM 좌표 Y (위도 변환) 
  /// [radius] 검색 반경 (미터)
  Future<List<SubwayStation>> searchStationsByCoordinate({
    required double tmX,
    required double tmY,
    int radius = 5000,
  }) async {
    try {
      final queryParams = {
        'serviceKey': ApiConstants.subwayApiKey,
        'tmX': tmX,
        'tmY': tmY,
        'radius': radius,
        '_type': 'json',
      };

      final response = await _httpService.get(
        ApiConstants.stationSearchEndpoint,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final apiResponse = SubwayApiResponse.fromJson(response.data);

        if (!apiResponse.isSuccess) {
          throw Exception(apiResponse.errorMessage ?? '지하철역 검색에 실패했습니다.');
        }

        return apiResponse.items
            .map((item) => SubwayStation.fromGovApiJson(item))
            .toList();
      }

      return [];
    } catch (e) {
      KSYLog.error('좌표 기반 지하철역 검색 오류: $e');
      rethrow;
    }
  }

  /// 지하철역별 시간표 목록 조회
  ///
  /// [subwayStationId] 지하철역ID (예: 'MTRS11133')
  /// [dailyTypeCode] 요일구분코드 (01:평일, 02:토요일, 03:일요일)
  /// [upDownTypeCode] 상하행구분코드 (U:상행, D:하행)
  /// [numOfRows] 한 페이지 결과 수 (기본값: 300)
  /// [pageNo] 페이지 번호 (기본값: 1)
  Future<List<SubwaySchedule>> getSchedules({
    required String subwayStationId,
    required String dailyTypeCode,
    required String upDownTypeCode,
    int numOfRows = 300,
    int pageNo = 1,
  }) async {
    try {
      final queryParams = {
        'serviceKey': ApiConstants.subwayApiKey,
        'numOfRows': numOfRows,
        'pageNo': pageNo,
        'subwayStationId': subwayStationId,
        'dailyTypeCode': dailyTypeCode,
        'upDownTypeCode': upDownTypeCode,
        '_type': 'json',
      };

      final response = await _httpService.get(
        ApiConstants.scheduleEndpoint,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final apiResponse = SubwayApiResponse.fromJson(response.data);

        if (!apiResponse.isSuccess) {
          throw Exception(apiResponse.errorMessage ?? '시간표 조회에 실패했습니다.');
        }

        return apiResponse.items
            .map((item) => SubwaySchedule.fromJson(item))
            .toList();
      }

      return [];
    } catch (e) {
      KSYLog.error('시간표 조회 오류: $e');
      rethrow;
    }
  }

  /// 다음 열차 정보 조회 (시간표 기반)
  ///
  /// [subwayStationId] 지하철역ID
  /// [upDownTypeCode] 상하행구분코드 (옵션, 미지정시 상행/하행 모두 조회)
  Future<List<NextTrainInfo>> getNextTrains({
    required String subwayStationId,
    String? upDownTypeCode,
  }) async {
    try {
      final now = DateTime.now();

      // 현재 요일에 따른 요일 코드 결정
      String dailyTypeCode;
      final weekday = now.weekday;
      if (weekday == 6) {
        dailyTypeCode = ApiConstants.saturdayCode; // 토요일
      } else if (weekday == 7) {
        dailyTypeCode = ApiConstants.sundayCode; // 일요일
      } else {
        dailyTypeCode = ApiConstants.weekdayCode; // 평일
      }

      List<NextTrainInfo> nextTrains = [];

      // 상하행 모두 조회하거나 지정된 방향만 조회
      final directions = upDownTypeCode != null
          ? [upDownTypeCode]
          : [ApiConstants.upDirection, ApiConstants.downDirection];

      for (final direction in directions) {
        final schedules = await getSchedules(
          subwayStationId: subwayStationId,
          dailyTypeCode: dailyTypeCode,
          upDownTypeCode: direction,
        );

        // 현재 시간 이후의 시간표만 필터링
        final currentTimeString =
            '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';
        final upcomingSchedules = schedules
            .where(
              (schedule) => schedule.arrTime.compareTo(currentTimeString) > 0,
            )
            .take(3) // 각 방향별로 최대 3개
            .toList();

        // NextTrainInfo로 변환
        nextTrains.addAll(
          upcomingSchedules.map(
            (schedule) => NextTrainInfo.fromSchedule(schedule),
          ),
        );
      }

      // 도착 시간순으로 정렬
      nextTrains.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

      return nextTrains;
    } catch (e) {
      KSYLog.error('다음 열차 정보 조회 오류: $e');
      rethrow;
    }
  }

  /// 지하철역출구별 버스노선 목록 조회
  ///
  /// [subwayStationId] 지하철역ID
  Future<List<SubwayExitBusRoute>> getExitBusRoutes({
    required String subwayStationId,
    int numOfRows = 100,
    int pageNo = 1,
  }) async {
    try {
      final queryParams = {
        'serviceKey': ApiConstants.subwayApiKey,
        'numOfRows': numOfRows,
        'pageNo': pageNo,
        'subwayStationId': subwayStationId,
        '_type': 'json',
      };

      final response = await _httpService.get(
        ApiConstants.exitBusRouteEndpoint,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final apiResponse = SubwayApiResponse.fromJson(response.data);

        KSYLog.info('Exit Bus Routes API Response:');
        KSYLog.debug('Success: ${apiResponse.isSuccess}');
        KSYLog.debug('Items count: ${apiResponse.items.length}');
        KSYLog.debug('Sample items: ${apiResponse.items.take(2).toList()}');

        if (!apiResponse.isSuccess) {
          throw Exception(apiResponse.errorMessage ?? '출구별 버스노선 조회에 실패했습니다.');
        }

        final busRoutes = apiResponse.items.map((item) {
          KSYLog.debug('Parsing bus route item: $item');
          return SubwayExitBusRoute.fromJson(item);
        }).toList();

        KSYLog.info('Parsed bus routes: ${busRoutes.length}');
        return busRoutes;
      }

      return [];
    } catch (e) {
      KSYLog.error('출구별 버스노선 조회 오류: $e');
      rethrow;
    }
  }

  /// 지하철역출구별 주변 시설 목록 조회
  ///
  /// [subwayStationId] 지하철역ID
  Future<List<SubwayExitFacility>> getExitFacilities({
    required String subwayStationId,
    int numOfRows = 100,
    int pageNo = 1,
  }) async {
    try {
      final queryParams = {
        'serviceKey': ApiConstants.subwayApiKey,
        'numOfRows': numOfRows,
        'pageNo': pageNo,
        'subwayStationId': subwayStationId,
        '_type': 'json',
      };

      final response = await _httpService.get(
        ApiConstants.exitFacilityEndpoint,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final apiResponse = SubwayApiResponse.fromJson(response.data);

        KSYLog.info('Exit Facilities API Response:');
        KSYLog.debug('Success: ${apiResponse.isSuccess}');
        KSYLog.debug('Items count: ${apiResponse.items.length}');
        KSYLog.debug('Sample items: ${apiResponse.items.take(2).toList()}');

        if (!apiResponse.isSuccess) {
          throw Exception(apiResponse.errorMessage ?? '출구별 주변시설 조회에 실패했습니다.');
        }

        final facilities = apiResponse.items.map((item) {
          KSYLog.debug('Parsing facility item: $item');
          return SubwayExitFacility.fromJson(item);
        }).toList();

        KSYLog.info('Parsed facilities: ${facilities.length}');
        return facilities;
      }

      return [];
    } catch (e) {
      KSYLog.error('출구별 주변시설 조회 오류: $e');
      rethrow;
    }
  }

  /// 모든 지하철역 목록 조회 (주변 역 검색용)
  ///
  /// 참고: 이 API는 키워드 기반이므로 일반적인 역명으로 검색
  Future<List<SubwayStation>> getAllStations() async {
    try {
      final commonStationNames = [
        '역',
        '신도림',
        '강남',
        '홍대',
        '서울',
        '부산',
        '대구',
        '인천',
        '광주',
        '대전',
        '수원',
        '안양',
        '의정부',
        '고양',
        '성남',
        '용인',
        '부천',
        '안산',
        '남양주',
        '화성',
      ];

      List<SubwayStation> allStations = [];

      for (final keyword in commonStationNames) {
        try {
          final stations = await searchStations(stationName: keyword);
          allStations.addAll(stations);
        } catch (e) {
          KSYLog.error('$keyword 검색 중 오류: $e');
          // 개별 검색 실패는 무시하고 계속 진행
        }
      }

      // 중복 제거 (subwayStationId 기준)
      final uniqueStations = <String, SubwayStation>{};
      for (final station in allStations) {
        uniqueStations[station.subwayStationId] = station;
      }

      return uniqueStations.values.toList();
    } catch (e) {
      KSYLog.error('전체 지하철역 목록 조회 오류', e);
      rethrow;
    }
  }

  /// 현재 요일에 따른 요일 코드 반환
  String getCurrentDailyTypeCode() {
    final now = DateTime.now();
    final weekday = now.weekday;

    if (weekday == 6) {
      return ApiConstants.saturdayCode; // 토요일
    } else if (weekday == 7) {
      return ApiConstants.sundayCode; // 일요일
    } else {
      return ApiConstants.weekdayCode; // 평일
    }
  }
}
