import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:math';
import '../constants/api_constants.dart';
import '../models/naver_place.dart';

/// 네이버 지도 검색 API 서비스
class NaverSearchService {
  late final Dio _dio;

  NaverSearchService() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://openapi.naver.com/v1/search';
    _dio.options.headers = {
      'X-Naver-Client-Id': ApiConstants.naverAPIClientId,
      'X-Naver-Client-Secret': ApiConstants.naverAPIClientSecret,
      'Content-Type': 'application/json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    print('네이버 검색 서비스 초기화');
    print('Client ID: ${ApiConstants.naverAPIClientId}');
    print(
      'Client Secret: ${ApiConstants.naverAPIClientSecret.substring(0, 10)}...',
    );
  }

  /// 지하철역 검색
  Future<List<NaverPlace>> searchSubwayStations({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      print(
        '네이버 API로 지하철역 검색 시작: lat=$latitude, lng=$longitude, radius=${radiusKm}km',
      );

      // 여러 검색어로 지하철역 검색
      final searchQueries = ['서울역', '신도림'];

      final allPlaces = <NaverPlace>[];

      for (final query in searchQueries) {
        try {
          final places = await _searchPlaces(
            query: query,
            latitude: latitude,
            longitude: longitude,
          );

          // 중복 제거하면서 추가
          for (final place in places) {
            if (!allPlaces.any(
              (existing) =>
                  existing.title == place.title &&
                  (existing.latitude - place.latitude).abs() < 0.001 &&
                  (existing.longitude - place.longitude).abs() < 0.001,
            )) {
              allPlaces.add(place);
            }
          }

          // API 호출 간격
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('검색어 "$query" 오류: $e');
          continue;
        }
      }

      // 거리 기준으로 필터링
      final filteredPlaces = allPlaces.where((place) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          place.latitude,
          place.longitude,
        );
        return distance <= radiusKm;
      }).toList();

      // 거리순으로 정렬
      filteredPlaces.sort((a, b) {
        final distA = _calculateDistance(
          latitude,
          longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          latitude,
          longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });

      print('네이버 API 검색 완료: 총 ${filteredPlaces.length}개 지하철역 발견');
      return filteredPlaces;
    } catch (e) {
      print('네이버 지하철역 검색 오류: $e');
      return [];
    }
  }

  /// 네이버 지역 검색 API 호출
  Future<List<NaverPlace>> _searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get(
        '/local.json',
        queryParameters: {
          'query': query,
          'display': 5, // 최대 5개로 제한
          'start': 1,
          'sort': 'comment', // 리뷰 많은 순으로 정렬
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final items = data['items'] as List<dynamic>? ?? [];

        final places = <NaverPlace>[];
        for (final item in items) {
          try {
            // 안전한 파싱을 위한 로그
            print('아이템 파싱 시도: $item');

            final place = NaverPlace.fromJson(item as Map<String, dynamic>);
            // 지하철 관련 키워드가 포함된 경우만 추가
            if (_isSubwayRelated(place.title) ||
                _isSubwayRelated(place.category)) {
              places.add(place);
              print('지하철역 발견: ${place.cleanTitle}');
            }
          } catch (e, stackTrace) {
            print('장소 파싱 오류: $e');
            print('스택 트레이스: $stackTrace');
            print('문제 데이터: $item');
            continue;
          }
        }

        return places;
      } else {
        throw Exception('네이버 API 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('네이버 지역 검색 오류: $e');
      rethrow;
    }
  }

  /// 지하철 관련 키워드 확인
  bool _isSubwayRelated(String text) {
    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '').toLowerCase();
    final subwayKeywords = [
      '지하철',
      '전철',
      '역',
      '메트로',
      'subway',
      'metro',
      'station',
      '1호선',
      '2호선',
      '3호선',
      '4호선',
      '5호선',
      '6호선',
      '7호선',
      '8호선',
      '9호선',
      '중앙선',
      '경의',
      '분당',
      '신분당',
      '경춘',
      '수인',
      '경강',
    ];

    return subwayKeywords.any((keyword) => cleanText.contains(keyword));
  }

  /// 두 좌표 간의 거리 계산 (km)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            pow(sin(dLon / 2), 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
