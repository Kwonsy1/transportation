/// API 관련 상수들
class ApiConstants {
  // 커스텀 근처 역 검색 API (kkssyy 서버)
  static const String nearbyApiBaseUrl = 'http://kkssyy.ipdisk.co.kr:5300';
  
  // 국토교통부 지하철정보 API (공공데이터포털)
  static const String subwayApiBaseUrl = 'http://apis.data.go.kr/1613000/SubwayInfoService';
  static const String subwayApiKey =
      '0cBM8RCAiOxxIyQbKRTdya4Z5LZzmDImKCctKA18eaK3EgZqZXm6kuSWKLkBha49jhqB+/qkhBjt5G6X1A/XjA=='; // 실제 API 키

  // 네이버 지도 API
  static const String naverMapClientId = 'jpj5i2bvdl'; // 실제 클라이언트 ID로 교체 완료
  static const String naverMapClientSecret =
      'N4mEolnK5KGBQvcQDWqFzofQsp82uk7hLP36uZPQ'; // 실제 클라이언트 시크릿으로 교체 완료

  // 지하철정보 API 엔드포인트 (국토교통부 표준)
  static const String stationSearchEndpoint = '/getKwrdFndSubwaySttnList';
  static const String exitBusRouteEndpoint = '/getSubwaySttnExitAcctoBusRouteList';
  static const String exitFacilityEndpoint = '/getSubwaySttnExitAcctoCfrFcltyList';
  static const String scheduleEndpoint = '/getSubwaySttnAcctoSchdulList';

  // 요일 구분 코드
  static const String weekdayCode = '01'; // 평일
  static const String saturdayCode = '02'; // 토요일
  static const String sundayCode = '03'; // 일요일/공휴일

  // 상하행 구분 코드
  static const String upDirection = 'U'; // 상행
  static const String downDirection = 'D'; // 하행

  // HTTP 요청 타임아웃 (초)
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 10;

  // 기본 페이징 설정
  static const int defaultPageSize = 100;
}
