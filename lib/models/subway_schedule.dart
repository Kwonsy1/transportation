import 'package:json_annotation/json_annotation.dart';

part 'subway_schedule.g.dart';

/// 지하철 시간표 정보 모델 (국토교통부 API 기준)
@JsonSerializable()
class SubwaySchedule {
  /// 지하철노선ID
  final String subwayRouteId;
  
  /// 지하철역ID
  final String subwayStationId;
  
  /// 지하철역명
  final String subwayStationNm;
  
  /// 요일구분코드 (01:평일, 02:토요일, 03:일요일)
  final String dailyTypeCode;
  
  /// 상하행구분코드 (U:상행, D:하행)
  final String upDownTypeCode;
  
  /// 출발시간 (HHMISS 형식)
  final String depTime;
  
  /// 도착시간 (HHMISS 형식)
  final String arrTime;
  
  /// 종점지하철역ID
  final String endSubwayStationId;
  
  /// 종점지하철역명
  final String endSubwayStationNm;

  const SubwaySchedule({
    required this.subwayRouteId,
    required this.subwayStationId,
    required this.subwayStationNm,
    required this.dailyTypeCode,
    required this.upDownTypeCode,
    required this.depTime,
    required this.arrTime,
    required this.endSubwayStationId,
    required this.endSubwayStationNm,
  });

  factory SubwaySchedule.fromJson(Map<String, dynamic> json) {
    return SubwaySchedule(
      subwayRouteId: json['subwayRouteId']?.toString() ?? '',
      subwayStationId: json['subwayStationId']?.toString() ?? '',
      subwayStationNm: json['subwayStationNm']?.toString() ?? '',
      dailyTypeCode: json['dailyTypeCode']?.toString() ?? '',
      upDownTypeCode: json['upDownTypeCode']?.toString() ?? '',
      depTime: json['depTime']?.toString() ?? '',
      arrTime: json['arrTime']?.toString() ?? '',
      endSubwayStationId: json['endSubwayStationId']?.toString() ?? '',
      endSubwayStationNm: json['endSubwayStationNm']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => _$SubwayScheduleToJson(this);

  /// 도착시간을 HH:MM:SS 형태로 포맷팅
  String get formattedArrivalTime {
    if (arrTime.length >= 6) {
      final hour = arrTime.substring(0, 2);
      final minute = arrTime.substring(2, 4);
      final second = arrTime.substring(4, 6);
      return '$hour:$minute:$second';
    } else if (arrTime.length >= 4) {
      final hour = arrTime.substring(0, 2);
      final minute = arrTime.substring(2, 4);
      return '$hour:$minute';
    }
    return arrTime;
  }

  /// 출발시간을 HH:MM:SS 형태로 포맷팅
  String get formattedDepartureTime {
    if (depTime.length >= 6) {
      final hour = depTime.substring(0, 2);
      final minute = depTime.substring(2, 4);
      final second = depTime.substring(4, 6);
      return '$hour:$minute:$second';
    } else if (depTime.length >= 4) {
      final hour = depTime.substring(0, 2);
      final minute = depTime.substring(2, 4);
      return '$hour:$minute';
    }
    return depTime;
  }

  /// 간단한 도착시간 (HH:MM 형태)
  String get simpleArrivalTime {
    if (arrTime.length >= 4) {
      final hour = arrTime.substring(0, 2);
      final minute = arrTime.substring(2, 4);
      return '$hour:$minute';
    }
    return arrTime;
  }

  /// 간단한 출발시간 (HH:MM 형태)
  String get simpleDepartureTime {
    if (depTime.length >= 4) {
      final hour = depTime.substring(0, 2);
      final minute = depTime.substring(2, 4);
      return '$hour:$minute';
    }
    return depTime;
  }

  /// 상하행을 한글로 변환
  String get directionKorean {
    switch (upDownTypeCode) {
      case 'U':
        return '상행';
      case 'D':
        return '하행';
      default:
        return upDownTypeCode;
    }
  }

  /// 요일 구분을 한글로 변환
  String get weekdayKorean {
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

  /// 종점역 방향 정보
  String get trainLineNm => endSubwayStationNm;

  /// 호선 번호 추출
  String get lineNumber {
    // subwayRouteId에서 호선 정보 추출 (예: MTRS11 -> 1호선)
    if (subwayRouteId.contains('MTRS1')) {
      return '1';
    } else if (subwayRouteId.contains('MTRS2')) {
      return '2';
    }
    // 기본값
    return '1';
  }

  /// 현재 시간 기준으로 다음 열차 여부 확인
  bool get isUpcoming {
    final now = DateTime.now();
    final currentTimeString = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00';
    return arrTime.compareTo(currentTimeString) > 0;
  }

  /// 남은 시간 계산
  String get timeUntilArrival {
    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;
    
    final arrivalHour = int.tryParse(arrTime.substring(0, 2)) ?? 0;
    final arrivalMinute = int.tryParse(arrTime.substring(2, 4)) ?? 0;
    final arrivalTimeInMinutes = arrivalHour * 60 + arrivalMinute;
    
    final diff = arrivalTimeInMinutes - currentTime;
    
    if (diff <= 0) {
      return '';
    } else if (diff < 60) {
      return '${diff}분 후';
    } else {
      final hours = diff ~/ 60;
      final minutes = diff % 60;
      return '${hours}시간 ${minutes}분 후';
    }
  }

  @override
  String toString() {
    return 'SubwaySchedule(subwayStationNm: $subwayStationNm, arrTime: $formattedArrivalTime, endSubwayStationNm: $endSubwayStationNm)';
  }
}
