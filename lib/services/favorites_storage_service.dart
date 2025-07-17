import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station_group.dart';
import '../models/subway_station.dart';

/// 즐겨찾기 데이터 로컬 저장 서비스
class FavoritesStorageService {
  static const String _favoritesKey = 'favorite_station_groups';
  static const String _legacyFavoritesKey = 'favorite_stations'; // 기존 즐겨찾기 호환성

  /// 즐겨찾기 스테이션 그룹 저장
  static Future<void> saveFavoriteStationGroups(List<StationGroup> stationGroups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 저장 전 디버깅
      print('=== 즐겨찾기 저장 시작 ===');
      print('저장할 그룹 개수: ${stationGroups.length}');
      for (int i = 0; i < stationGroups.length; i++) {
        final group = stationGroups[i];
        print('그룹 $i: ${group.stationName} (역 개수: ${group.stations.length})');
        for (int j = 0; j < group.stations.length; j++) {
          final station = group.stations[j];
          print('  역 $j: ${station.subwayStationName} (${station.subwayRouteName})');
        }
      }
      
      // StationGroup을 JSON으로 변환
      final jsonList = stationGroups.map((group) {
        try {
          final json = group.toJson();
          print('그룹 ${group.stationName} JSON 변환 성공: $json');
          return json;
        } catch (e) {
          print('그룹 ${group.stationName} JSON 변환 실패: $e');
          rethrow;
        }
      }).toList();
      
      final jsonString = jsonEncode(jsonList);
      print('최종 JSON 문자열 길이: ${jsonString.length}');
      print('최종 JSON 문자열 (처음 200자): ${jsonString.length > 200 ? jsonString.substring(0, 200) + '...' : jsonString}');
      
      final success = await prefs.setString(_favoritesKey, jsonString);
      print('SharedPreferences 저장 결과: $success');
      
      // 저장 후 바로 확인
      final savedData = prefs.getString(_favoritesKey);
      print('저장 후 확인 - 데이터 존재: ${savedData != null}');
      print('저장 후 확인 - 데이터 길이: ${savedData?.length ?? 0}');
      
      print('즐겨찾기 ${stationGroups.length}개 저장 완료');
    } catch (e) {
      print('즐겨찾기 저장 오류: $e');
      print('오류 스택 트레이스: ${StackTrace.current}');
      throw Exception('즐겨찾기 저장에 실패했습니다: $e');
    }
  }

  /// 즐겨찾기 스테이션 그룹 로드
  static Future<List<StationGroup>> loadFavoriteStationGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('=== 즐겨찾기 로드 시작 ===');
      
      // 새로운 형식 먼저 시도
      final jsonString = prefs.getString(_favoritesKey);
      print('저장된 데이터 존재: ${jsonString != null}');
      print('저장된 데이터 길이: ${jsonString?.length ?? 0}');
      
      if (jsonString != null && jsonString.isNotEmpty) {
        print('저장된 JSON 데이터 (처음 200자): ${jsonString.length > 200 ? jsonString.substring(0, 200) + '...' : jsonString}');
        
        try {
          final jsonList = jsonDecode(jsonString) as List<dynamic>;
          print('전체 JSON 리스트 개수: ${jsonList.length}');
          
          final stationGroups = <StationGroup>[];
          for (int i = 0; i < jsonList.length; i++) {
            try {
              final json = jsonList[i] as Map<String, dynamic>;
              print('그룹 $i JSON: $json');
              
              final stationGroup = StationGroup.fromJson(json);
              stationGroups.add(stationGroup);
              print('그룹 $i 변환 성공: ${stationGroup.stationName}');
            } catch (e) {
              print('그룹 $i 변환 실패: $e');
              // 개별 그룹 실패시 건너뛰고 계속
            }
          }
          
          print('즐겨찾기 ${stationGroups.length}개 로드 완료');
          return stationGroups;
        } catch (e) {
          print('JSON 파싱 오류: $e');
          // JSON 파싱 실패 시 기존 데이터 마이그레이션 시도
        }
      }

      // 기존 형식 마이그레이션 시도
      print('기존 데이터 마이그레이션 시도');
      final legacyStationGroups = await _migrateLegacyFavorites();
      if (legacyStationGroups.isNotEmpty) {
        print('기존 데이터 ${legacyStationGroups.length}개 발견 - 마이그레이션 실행');
        // 마이그레이션된 데이터를 새 형식으로 저장
        await saveFavoriteStationGroups(legacyStationGroups);
        return legacyStationGroups;
      }

      print('저장된 즐겨찾기 없음');
      return [];
    } catch (e) {
      print('즐겨찾기 로드 오류: $e');
      print('오류 스택 트레이스: ${StackTrace.current}');
      // 에러 발생시 빈 리스트 반환
      return [];
    }
  }

  /// 특정 즐겨찾기 스테이션 그룹 추가
  static Future<void> addFavoriteStationGroup(StationGroup stationGroup) async {
    try {
      final currentFavorites = await loadFavoriteStationGroups();
      
      // 중복 확인
      final isDuplicate = currentFavorites.any(
        (group) => group.stationName == stationGroup.stationName,
      );
      
      if (!isDuplicate) {
        currentFavorites.add(stationGroup);
        await saveFavoriteStationGroups(currentFavorites);
        print('즐겨찾기에 ${stationGroup.cleanStationName} 추가');
      } else {
        print('이미 즐겨찾기에 있는 역: ${stationGroup.cleanStationName}');
      }
    } catch (e) {
      print('즐겨찾기 추가 오류: $e');
      throw Exception('즐겨찾기 추가에 실패했습니다: $e');
    }
  }

  /// 특정 즐겨찾기 스테이션 그룹 제거
  static Future<void> removeFavoriteStationGroup(StationGroup stationGroup) async {
    try {
      final currentFavorites = await loadFavoriteStationGroups();
      
      currentFavorites.removeWhere(
        (group) => group.stationName == stationGroup.stationName,
      );
      
      await saveFavoriteStationGroups(currentFavorites);
      print('즐겨찾기에서 ${stationGroup.cleanStationName} 제거');
    } catch (e) {
      print('즐겨찾기 제거 오류: $e');
      throw Exception('즐겨찾기 제거에 실패했습니다: $e');
    }
  }

  /// 모든 즐겨찾기 제거
  static Future<void> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      await prefs.remove(_legacyFavoritesKey); // 기존 데이터도 제거
      print('모든 즐겨찾기 제거 완료');
    } catch (e) {
      print('즐겨찾기 전체 제거 오류: $e');
      throw Exception('즐겨찾기 전체 제거에 실패했습니다: $e');
    }
  }

  /// 특정 역명이 즐겨찾기에 있는지 확인
  static Future<bool> isFavoriteStation(String stationName) async {
    try {
      final favorites = await loadFavoriteStationGroups();
      final cleanName = stationName.replaceAll('역', '').trim();
      
      return favorites.any(
        (group) => group.cleanStationName == cleanName,
      );
    } catch (e) {
      print('즐겨찾기 확인 오류: $e');
      return false;
    }
  }

  /// 즐겨찾기 개수 반환
  static Future<int> getFavoritesCount() async {
    try {
      final favorites = await loadFavoriteStationGroups();
      return favorites.length;
    } catch (e) {
      print('즐겨찾기 개수 확인 오류: $e');
      return 0;
    }
  }

  /// 기존 즐겨찾기 데이터 마이그레이션 (하위 호환성)
  static Future<List<StationGroup>> _migrateLegacyFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyJsonString = prefs.getString(_legacyFavoritesKey);
      
      if (legacyJsonString == null || legacyJsonString.isEmpty) {
        return [];
      }

      final legacyJsonList = jsonDecode(legacyJsonString) as List<dynamic>;
      final legacyStations = legacyJsonList
          .map((json) => SubwayStation.fromJson(json as Map<String, dynamic>))
          .toList();

      // 기존 역들을 그룹화
      final Map<String, List<SubwayStation>> groupedMap = {};
      for (final station in legacyStations) {
        final cleanName = station.subwayStationName.replaceAll('역', '').trim();
        if (!groupedMap.containsKey(cleanName)) {
          groupedMap[cleanName] = [];
        }
        groupedMap[cleanName]!.add(station);
      }

      // StationGroup으로 변환
      final stationGroups = groupedMap.entries.map((entry) {
        return StationGroup(
          stationName: entry.key,
          stations: entry.value,
          latitude: entry.value.first.latitude,
          longitude: entry.value.first.longitude,
        );
      }).toList();

      print('기존 즐겨찾기 ${stationGroups.length}개 마이그레이션 완료');
      return stationGroups;
    } catch (e) {
      print('기존 즐겨찾기 마이그레이션 오류: $e');
      return [];
    }
  }

  /// 저장소 초기화 (디버그용)
  static Future<void> resetStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('즐겨찾기 저장소 초기화 완료');
    } catch (e) {
      print('저장소 초기화 오류: $e');
    }
  }

  /// 저장소 상태 확인 (디버그용)
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesData = prefs.getString(_favoritesKey);
      final legacyData = prefs.getString(_legacyFavoritesKey);
      
      return {
        'has_favorites': favoritesData != null,
        'has_legacy_favorites': legacyData != null,
        'favorites_size': favoritesData?.length ?? 0,
        'legacy_size': legacyData?.length ?? 0,
      };
    } catch (e) {
      print('저장소 정보 확인 오류: $e');
      return {};
    }
  }
}