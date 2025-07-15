import 'package:json_annotation/json_annotation.dart';
import 'subway_schedule.dart';

part 'next_train_info.g.dart';

/// 다음 열차 정보 모델 (시간표 기반)
@JsonSerializable()
class NextTrainInfo {
  /// 역명
  final String stationName;
  
  /// 방향 (종점역명)
  final String destination;
  
  /// 상하행 구분
  final String direction;
  
  /// 도착 예정 시간
  final String arrivalTime;
  
  /// 출발 시간
  final String departureTime;
  
  /// 남은 시간 (분)
  final int minutesUntilArrival;
  
  /// 호선 정보
  final String lineNumber;

  const NextTrainInfo({
    required this.stationName,
    required this.destination,
    required this.direction,
    required this.arrivalTime,
    required this.departureTime,
    required this.minutesUntilArrival,
    required this.lineNumber,
  });

  /// 시간표에서 다음 열차 정보 생성
  factory NextTrainInfo.fromSchedule(SubwaySchedule schedule) {
    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;
    
    final arrivalHour = int.tryParse(schedule.arrTime.substring(0, 2)) ?? 0;
    final arrivalMinute = int.tryParse(schedule.arrTime.substring(2, 4)) ?? 0;
    final arrivalTimeInMinutes = arrivalHour * 60 + arrivalMinute;
    
    final minutesUntil = arrivalTimeInMinutes - currentTime;

    return NextTrainInfo(
      stationName: schedule.subwayStationNm,
      destination: schedule.endSubwayStationNm,
      direction: schedule.directionKorean,
      arrivalTime: schedule.simpleArrivalTime,
      departureTime: schedule.simpleDepartureTime,
      minutesUntilArrival: minutesUntil > 0 ? minutesUntil : 0,
      lineNumber: schedule.lineNumber,
    );
  }

  factory NextTrainInfo.fromJson(Map<String, dynamic> json) {
    return NextTrainInfo(
      stationName: json['stationName']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      arrivalTime: json['arrivalTime']?.toString() ?? '',
      departureTime: json['departureTime']?.toString() ?? '',
      minutesUntilArrival: json['minutesUntilArrival'] is int
          ? json['minutesUntilArrival']
          : int.tryParse(json['minutesUntilArrival']?.toString() ?? '0') ?? 0,
      lineNumber: json['lineNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => _$NextTrainInfoToJson(this);

  /// 도착 상태 메시지
  String get arrivalStatusMessage {
    if (minutesUntilArrival <= 0) {
      return '출발';
    } else if (minutesUntilArrival <= 1) {
      return '잠시 후 도착';
    } else if (minutesUntilArrival <= 5) {
      return '${minutesUntilArrival}분 후 도착';
    } else {
      return '${minutesUntilArrival}분 후';
    }
  }

  /// 포맷된 남은 시간
  String get formattedTimeUntilArrival {
    if (minutesUntilArrival <= 0) {
      return '';
    } else if (minutesUntilArrival < 60) {
      return '${minutesUntilArrival}분 후';
    } else {
      final hours = minutesUntilArrival ~/ 60;
      final minutes = minutesUntilArrival % 60;
      return '${hours}시간 ${minutes}분 후';
    }
  }

  /// 열차 종류 (일반으로 고정, API에서 제공하지 않음)
  String get trainType => '일반';

  @override
  String toString() {
    return 'NextTrainInfo(stationName: $stationName, destination: $destination, arrivalTime: $arrivalTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NextTrainInfo &&
        other.stationName == stationName &&
        other.arrivalTime == arrivalTime &&
        other.direction == direction;
  }

  @override
  int get hashCode => stationName.hashCode ^ arrivalTime.hashCode ^ direction.hashCode;
}
