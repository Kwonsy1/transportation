import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';

/// 지하철 관련 유틸리티 함수들 (국토교통부 API 기준)
class SubwayUtils {
  /// 호선명을 표준 형태로 정규화 (컬러 매칭용)
  static String normalizeLineNameForColor(String lineName) {
    // 숫자로 시작하는 호선 처리 (01 → 1, 02 → 2, 01호선 → 1)
    final numberMatch = RegExp(r'^0?(\d+)').firstMatch(lineName);
    if (numberMatch != null) {
      return numberMatch.group(1)!;
    }

    // 특수 호선명 처리 (정확한 매칭 우선, 긴 이름부터)
    // 신분당선이 분당선보다 먼저 와야 함
    if (lineName.contains('신분당')) {
      return '신분당';
    }
    if (lineName.contains('수인분당')) {
      return '수인분당';
    }
    if (lineName.contains('분당')) {
      return '분당';
    }
    if (lineName.contains('경의중앙')) {
      return '경의중앙';
    }
    if (lineName.contains('우이신설')) {
      return '우이신설';
    }
    if (lineName.contains('경춘')) {
      return '경춘';
    }
    if (lineName.contains('서해')) {
      return '서해';
    }
    if (lineName.contains('김포')) {
      return '김포';
    }
    if (lineName.contains('신림')) {
      return '신림';
    }

    // 매칭되지 않으면 원본 반환 (호선 제거)
    return lineName.replaceAll('호선', '').trim();
  }

  /// 호선 번호/이름으로 색상 반환
  static Color getLineColor(String lineNumber) {
    // 입력값을 정규화
    final normalizedLine = normalizeLineNameForColor(lineNumber);

    switch (normalizedLine) {
      // 서울 지하철 1-9호선
      case '1':
        return AppColors.line1;
      case '2':
        return AppColors.line2;
      case '3':
        return AppColors.line3;
      case '4':
        return AppColors.line4;
      case '5':
        return AppColors.line5;
      case '6':
        return AppColors.line6;
      case '7':
        return AppColors.line7;
      case '8':
        return AppColors.line8;
      case '9':
        return AppColors.line9;

      // 광역철도 노선들
      case '경의중앙':
      case '경의중앙선':
        return AppColors.gyeonguiJungang;
      case '신분당':
      case '신분당선':
        return AppColors.sinbundang;
      case '수인분당':
      case '수인분당선':
        return AppColors.suinBundang;
      case '분당':
      case '분당선':
        return AppColors.bundang;
      case '경춘':
      case '경춘선':
        return AppColors.gyeongchun;
      case '우이신설':
      case '우이신설선':
        return AppColors.uiSinseol;
      case '서해':
      case '서해선':
        return AppColors.seohae;
      case '김포':
      case '김포골드라인':
        return AppColors.gimpo;
      case '신림':
      case '신림선':
        return AppColors.sillim;

      default:
        return AppColors.textSecondary;
    }
  }

  /// 지하철 노선 ID에서 호선 번호 추출
  static String extractLineNumber(String subwayRouteId) {
    // MTRS11 -> 1호선
    if (subwayRouteId.contains('MTRS1')) {
      if (subwayRouteId.contains('MTRS11')) return '1';
      if (subwayRouteId.contains('MTRS12')) return '2';
      if (subwayRouteId.contains('MTRS13')) return '3';
      if (subwayRouteId.contains('MTRS14')) return '4';
      if (subwayRouteId.contains('MTRS15')) return '5';
      if (subwayRouteId.contains('MTRS16')) return '6';
      if (subwayRouteId.contains('MTRS17')) return '7';
      if (subwayRouteId.contains('MTRS18')) return '8';
      if (subwayRouteId.contains('MTRS19')) return '9';
    }
    return '1'; // 기본값
  }

  /// 호선명을 축약된 형태로 변환 (지도 마커용)
  /// 
  /// 예: "1호선" → "1", "경의중앙선" → "경의", "신분당선" → "신분"
  static String getLineShortName(String lineName) {
    // 숫자가 있으면 숫자만 반환
    final numberRegex = RegExp(r'(\d+)');
    final match = numberRegex.firstMatch(lineName);
    if (match != null) {
      final number = match.group(1) ?? '';
      // 한 자리 숫자만 표시 (예: 01 -> 1, 02 -> 2)
      return int.tryParse(number)?.toString() ?? number;
    }

    // 특별한 노선들의 축약명
    final Map<String, String> specialLines = {
      '경의중앙선': '경의',
      '분당선': '분당',
      '신분당선': '신분',
      '경춘선': '경춘',
      '수인분당선': '수인',
      '우이신설선': '우이',
      '서해선': '서해',
      '김포골드라인': '김포',
      '신림선': '신림',
    };

    for (final entry in specialLines.entries) {
      if (lineName.contains(entry.key)) {
        return entry.value;
      }
    }

    // 기본값: 앞 2글자
    return lineName.length >= 2 ? lineName.substring(0, 2) : lineName;
  }

  /// 노선명에서 호선 번호 추출
  static String extractLineNumberFromRouteName(String routeName) {
    final regex = RegExp(r'(\d+)호선');
    final match = regex.firstMatch(routeName);
    return match?.group(1) ?? '1';
  }

  /// 요일 코드를 한글로 변환
  static String getDailyTypeKorean(String dailyTypeCode) {
    switch (dailyTypeCode) {
      case '01':
        return '평일';
      case '02':
        return '토요일';
      case '03':
        return '일요일/공휴일';
      default:
        return dailyTypeCode;
    }
  }

  /// 상하행 코드를 한글로 변환
  static String getDirectionKorean(String upDownTypeCode) {
    switch (upDownTypeCode) {
      case 'U':
        return '상행';
      case 'D':
        return '하행';
      default:
        return upDownTypeCode;
    }
  }

  /// 현재 요일에 따른 요일 코드 반환
  static String getCurrentDailyTypeCode() {
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

  /// 시간 문자열을 HH:MM 형태로 포맷팅
  static String formatTime(String timeString) {
    if (timeString.length >= 4) {
      final hour = timeString.substring(0, 2);
      final minute = timeString.substring(2, 4);
      return '$hour:$minute';
    }
    return timeString;
  }

  /// 시간 문자열을 HH:MM:SS 형태로 포맷팅
  static String formatTimeWithSeconds(String timeString) {
    if (timeString.length >= 6) {
      final hour = timeString.substring(0, 2);
      final minute = timeString.substring(2, 4);
      final second = timeString.substring(4, 6);
      return '$hour:$minute:$second';
    } else if (timeString.length >= 4) {
      return formatTime(timeString);
    }
    return timeString;
  }

  /// 현재 시간 기준으로 다음 열차 여부 확인
  static bool isUpcomingTrain(String arrivalTime) {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';
    return arrivalTime.compareTo(currentTime) > 0;
  }

  /// 도착 예정 시간까지 남은 시간 계산 (분 단위)
  static int calculateMinutesUntilArrival(String arrivalTime) {
    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    final arrivalHour = int.tryParse(arrivalTime.substring(0, 2)) ?? 0;
    final arrivalMinute = int.tryParse(arrivalTime.substring(2, 4)) ?? 0;
    final arrivalTimeInMinutes = arrivalHour * 60 + arrivalMinute;

    final diff = arrivalTimeInMinutes - currentTime;
    return diff > 0 ? diff : 0;
  }

  /// 도착 예정 시간까지 남은 시간을 읽기 쉬운 형태로 포맷팅
  static String formatTimeUntilArrival(String arrivalTime) {
    final minutes = calculateMinutesUntilArrival(arrivalTime);

    if (minutes <= 0) {
      return '';
    } else if (minutes < 60) {
      return '$minutes분 후';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours시간 $remainingMinutes분 후';
    }
  }

  /// 도착 상태 메시지 생성
  static String getArrivalStatusMessage(String arrivalTime) {
    final minutes = calculateMinutesUntilArrival(arrivalTime);

    if (minutes <= 0) {
      return '출발';
    } else if (minutes <= 1) {
      return '잠시 후 도착';
    } else if (minutes <= 5) {
      return '$minutes분 후 도착';
    } else {
      return '$minutes분 후';
    }
  }

  /// 역 ID가 유효한지 확인
  static bool isValidStationId(String stationId) {
    return stationId.isNotEmpty && stationId.startsWith('MTRS');
  }

  /// 노선 ID가 유효한지 확인
  static bool isValidRouteId(String routeId) {
    return routeId.isNotEmpty && routeId.startsWith('MTRS');
  }

  /// 시간 범위 내에 있는 시간표 필터링
  static List<T> filterSchedulesByTimeRange<T>(
    List<T> schedules,
    String Function(T) getTimeFunction,
    String startTime,
    String endTime,
  ) {
    return schedules.where((schedule) {
      final time = getTimeFunction(schedule);
      return time.compareTo(startTime) >= 0 && time.compareTo(endTime) <= 0;
    }).toList();
  }

  /// 현재 시간 이후의 시간표만 필터링
  static List<T> filterUpcomingSchedules<T>(
    List<T> schedules,
    String Function(T) getTimeFunction,
  ) {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';

    return schedules.where((schedule) {
      final time = getTimeFunction(schedule);
      return time.compareTo(currentTime) > 0;
    }).toList();
  }
}

/// 일반적인 유틸리티 함수들
class AppUtils {
  /// 거리를 읽기 쉬운 형태로 포맷팅
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 시간 차이를 읽기 쉬운 형태로 포맷팅
  static String formatTimeDifference(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  /// 에러 메시지를 사용자 친화적으로 변환
  static String getFriendlyErrorMessage(String error) {
    if (error.contains('timeout') || error.contains('시간')) {
      return '서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    } else if (error.contains('network') || error.contains('인터넷')) {
      return '인터넷 연결을 확인해주세요.';
    } else if (error.contains('permission') || error.contains('권한')) {
      return '앱 권한을 확인해주세요.';
    } else if (error.contains('location') || error.contains('위치')) {
      return '위치 서비스를 활성화해주세요.';
    } else if (error.contains('SERVICE_KEY') || error.contains('API')) {
      return 'API 서비스에 문제가 있습니다. 잠시 후 다시 시도해주세요.';
    } else if (error.contains('INVALID_REQUEST_PARAMETER')) {
      return '잘못된 요청입니다. 다른 검색어로 시도해주세요.';
    } else {
      return '오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
  }

  /// API 응답 코드에 따른 에러 메시지
  static String getApiErrorMessage(String resultCode, String? resultMsg) {
    switch (resultCode) {
      case '00':
        return ''; // 정상
      case '01':
        return '어플리케이션 에러가 발생했습니다.';
      case '04':
        return 'HTTP 에러가 발생했습니다.';
      case '12':
        return '해당 오픈API 서비스가 없거나 폐기되었습니다.';
      case '20':
        return '서비스 접근이 거부되었습니다.';
      case '22':
        return '서비스 요청 제한횟수를 초과했습니다.';
      case '30':
        return '등록되지 않은 서비스키입니다.';
      case '31':
        return '활용기간이 만료되었습니다.';
      case '32':
        return '등록되지 않은 IP입니다.';
      case '99':
        return resultMsg ?? '알 수 없는 오류가 발생했습니다.';
      default:
        return resultMsg ?? '서버에서 오류가 발생했습니다.';
    }
  }

  /// 현재 시간을 API 형식으로 변환
  static String getCurrentTimeForApi() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  /// 리스트가 비어있는지 확인하고 기본값 반환
  static List<T> ensureList<T>(List<T>? list) {
    return list ?? <T>[];
  }

  /// null 또는 빈 문자열을 기본값으로 대체
  static String ensureString(String? value, [String defaultValue = '']) {
    return value?.isNotEmpty == true ? value! : defaultValue;
  }

  /// 안전한 정수 파싱
  static int safeParseInt(String? value, [int defaultValue = 0]) {
    if (value == null || value.isEmpty) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// 안전한 더블 파싱
  static double safeParseDouble(String? value, [double defaultValue = 0.0]) {
    if (value == null || value.isEmpty) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }
}
