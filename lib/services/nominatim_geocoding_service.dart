import 'dart:async';
import 'package:dio/dio.dart';
import '../models/subway_station.dart';
import '../utils/ksy_log.dart';
import '../utils/station_utils.dart';

/// OpenStreetMap Nominatim API를 사용한 좌표 검색 서비스
///
/// API 제한사항: 3초에 1번만 요청 가능
class NominatimGeocodingService {
  // API 기본 설정
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _searchEndpoint = '/search';
  static const Duration _requestDelay = Duration(
    seconds: 1,
  ); // API 요청 간 최소 간격 (3초로 증가)

  // 요청 제한을 위한 타이머
  DateTime? _lastRequestTime;
  final List<_GeocodingRequest> _requestQueue = [];
  bool _isProcessingQueue = false;

  /// 지하철역명으로 좌표 검색
  ///
  /// [stationName] 검색할 역명 (예: "의왕역", "강남역")
  /// [includeCountry] 국가 정보 포함 여부 (기본값: true)
  /// [limitResults] 결과 개수 제한 (기본값: 5)
  Future<List<NominatimLocation>> searchStationCoordinates({
    required String stationName,
    bool includeCountry = true,
    int limitResults = 5,
  }) async {
    final completer = Completer<List<NominatimLocation>>();

    // 요청을 큐에 추가
    _requestQueue.add(
      _GeocodingRequest(
        stationName: stationName,
        includeCountry: includeCountry,
        limitResults: limitResults,
        completer: completer,
      ),
    );

    // 큐 처리 시작
    _processQueue();

    return completer.future;
  }

  /// 지하철역 리스트의 좌표를 일괄 검색
  ///
  /// [stations] 좌표를 검색할 지하철역 리스트
  /// [onProgress] 진행률 콜백 (현재 인덱스, 전체 개수)
  /// [onStationUpdated] 개별 역 좌표 업데이트 콜백
  /// [forceUpdate] 이미 좌표가 있는 역도 강제 업데이트 여부
  Future<List<SubwayStation>> batchUpdateStationCoordinates({
    required List<SubwayStation> stations,
    Function(int current, int total)? onProgress,
    Function(SubwayStation updatedStation)? onStationUpdated,
    bool forceUpdate = false,
  }) async {
    final updatedStations = <SubwayStation>[];

    KSYLog.info(
      '🚀 좌표 업데이트 시작: 총 ${stations.length}개 역, 강제 업데이트: $forceUpdate',
    );

    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];

      // 강제 업데이트가 아니고 이미 유효한 좌표가 있는 경우 건너뛰기
      if (!forceUpdate &&
          station.latitude != null &&
          station.longitude != null &&
          station.latitude != 0.0 &&
          station.longitude != 0.0) {
        updatedStations.add(station);
        onProgress?.call(i + 1, stations.length);
        KSYLog.debug(
          '⏭️ ${station.subwayStationName}: 유효한 좌표 이미 존재 (${station.latitude}, ${station.longitude}), 건너뛰기',
        );
        continue;
      }

      try {
        KSYLog.debug('🔍 ${station.subwayStationName} 좌표 검색 시작...');

        // 역명으로 좌표 검색
        final locations = await searchStationCoordinates(
          stationName: station.subwayStationName,
          includeCountry: true,
          limitResults: 3,
        );

        if (locations.isNotEmpty) {
          // 가장 적합한 결과 선택 (첫 번째 결과 사용)
          final bestLocation = _selectBestLocation(
            locations,
            station.subwayStationName,
          );

          final updatedStation = SubwayStation(
            subwayStationId: station.subwayStationId,
            subwayStationName: station.subwayStationName,
            subwayRouteName: station.subwayRouteName,
            latitude: bestLocation.latitude,
            longitude: bestLocation.longitude,
          );

          updatedStations.add(updatedStation);
          onStationUpdated?.call(updatedStation);

          KSYLog.debug(
            '✅ ${station.subwayStationName}: ${bestLocation.latitude}, ${bestLocation.longitude}',
          );
        } else {
          // 좌표를 찾지 못한 경우 원본 유지
          updatedStations.add(station);
          KSYLog.debug('❌ ${station.subwayStationName}: 좌표를 찾을 수 없음');
        }
      } catch (e) {
        KSYLog.error('🚨 ${station.subwayStationName}: 검색 오류 - $e');

        // 타임아웃이나 네트워크 오류 시 추가 대기
        if (e.toString().contains('timeout') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection refused')) {
          KSYLog.debug('⏰ 네트워크 오류로 인한 5초 추가 대기...');
          await Future.delayed(Duration(seconds: 5));
        }

        // 오류 발생 시 원본 유지
        updatedStations.add(station);
      }

      // 진행률 업데이트
      onProgress?.call(i + 1, stations.length);
    }

    KSYLog.info('🏁 좌표 업데이트 완료: 총 ${updatedStations.length}개 역 처리 완료');
    return updatedStations;
  }

  /// 큐 처리 (3초 간격으로 요청 실행)
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) return;

    _isProcessingQueue = true;

    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeAt(0);

      try {
        // 이전 요청으로부터 3초 대기
        await _waitForRateLimit();

        // API 요청 실행
        final results = await _executeGeocodingRequest(request);
        request.completer.complete(results);
      } catch (e) {
        KSYLog.error('🚨 큐 처리 오류: $e');
        request.completer.completeError(e);
      }
    }

    _isProcessingQueue = false;
  }

  /// API 요청 간격 제한 대기
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _requestDelay) {
        final waitTime = _requestDelay - elapsed;
        KSYLog.debug(
          '⏰ API 요청 제한으로 ${waitTime.inSeconds}초 대기... (남은 큐: ${_requestQueue.length}개)',
        );
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
    KSYLog.debug('🚀 API 요청 실행 시작');
  }

  /// 실제 Geocoding API 요청 실행
  Future<List<NominatimLocation>> _executeGeocodingRequest(
    _GeocodingRequest request,
  ) async {
    try {
      // 검색 쿼리 구성
      String query = request.stationName;
      if (request.includeCountry) {
        query += ', South Korea';
      }

      // API 요청 파라미터
      final queryParams = {
        'q': query,
        'format': 'json',
        'limit': request.limitResults.toString(),
        'addressdetails': '1',
        'extratags': '1',
        'namedetails': '1',
      };

      KSYLog.debug('🔍 Nominatim 검색: $query (타임아웃: 20초)');

      // Nominatim API를 위한 더 긴 타임아웃 설정
      final customDio = Dio();
      customDio.options.connectTimeout = Duration(seconds: 15);
      customDio.options.receiveTimeout = Duration(seconds: 20);

      final response = await customDio.get(
        '$_baseUrl$_searchEndpoint',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'User-Agent':
                'TransportationApp/1.0 (Flutter; Seoul Subway Coordinate Updater; contact: developer@transportationapp.com)',
            'Accept': 'application/json',
            'Accept-Language': 'ko,en;q=0.9',
          },
        ),
      );

      if (response.data != null && response.data is List) {
        final results = (response.data as List)
            .map((json) => NominatimLocation.fromJson(json))
            .toList();

        KSYLog.debug('📍 검색 결과: ${results.length}개');
        return results;
      }

      return [];
    } catch (e) {
      KSYLog.error('🚨 Nominatim API 오류: $e');
      rethrow;
    }
  }

  /// 가장 적합한 위치 결과 선택
  NominatimLocation _selectBestLocation(
    List<NominatimLocation> locations,
    String stationName,
  ) {
    // 역명과 정확히 일치하는 결과 우선
    for (final location in locations) {
      if (_isExactStationMatch(location, stationName)) {
        return location;
      }
    }

    // 지하철역/기차역 타입 우선
    for (final location in locations) {
      if (_isTransportationRelated(location)) {
        return location;
      }
    }

    // 첫 번째 결과 반환 (일반적으로 가장 관련성 높음)
    return locations.first;
  }

  /// 역명과 정확히 일치하는지 확인
  bool _isExactStationMatch(NominatimLocation location, String stationName) {
    final displayName = location.displayName.toLowerCase();
    final cleanStationName = StationUtils.cleanForSearch(stationName).toLowerCase();

    return displayName.contains('$cleanStationName station') ||
        displayName.contains('$cleanStationName subway') ||
        displayName.contains(cleanStationName);
  }

  /// 교통 관련 시설인지 확인
  bool _isTransportationRelated(NominatimLocation location) {
    final category = location.category?.toLowerCase() ?? '';
    final type = location.type?.toLowerCase() ?? '';
    final displayName = location.displayName.toLowerCase();

    return category == 'railway' ||
        type == 'station' ||
        type == 'subway' ||
        displayName.contains('station') ||
        displayName.contains('subway');
  }

  /// 큐 상태 확인
  bool get isProcessing => _isProcessingQueue;
  int get queueLength => _requestQueue.length;
}

/// Geocoding 요청 데이터 클래스
class _GeocodingRequest {
  final String stationName;
  final bool includeCountry;
  final int limitResults;
  final Completer<List<NominatimLocation>> completer;

  _GeocodingRequest({
    required this.stationName,
    required this.includeCountry,
    required this.limitResults,
    required this.completer,
  });
}

/// Nominatim API 응답 위치 정보 모델
class NominatimLocation {
  final double latitude;
  final double longitude;
  final String displayName;
  final String? category;
  final String? type;
  final String? importance;
  final Map<String, dynamic>? address;

  const NominatimLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.category,
    this.type,
    this.importance,
    this.address,
  });

  factory NominatimLocation.fromJson(Map<String, dynamic> json) {
    return NominatimLocation(
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      displayName: json['display_name']?.toString() ?? '',
      category: json['category']?.toString(),
      type: json['type']?.toString(),
      importance: json['importance']?.toString(),
      address: json['address'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'display_name': displayName,
      'category': category,
      'type': type,
      'importance': importance,
      'address': address,
    };
  }

  @override
  String toString() {
    return 'NominatimLocation(lat: $latitude, lon: $longitude, name: $displayName, type: $type)';
  }
}
