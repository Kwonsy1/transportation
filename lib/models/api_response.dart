import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

/// 안전한 정수 파싱 헬퍼 함수
int _safeParseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  if (value is double) return value.toInt();
  return defaultValue;
}

/// 국토교통부 지하철정보 API 응답 모델
@JsonSerializable()
class SubwayApiResponse {
  /// 응답 헤더
  final ApiHeader? header;
  
  /// 응답 바디
  final ApiBody? body;

  const SubwayApiResponse({
    this.header,
    this.body,
  });

  // 커스텀 fromJson - API 응답 구조에 맞춤
  factory SubwayApiResponse.fromJson(Map<String, dynamic> json) {
    // 'response' 키로 감싸져 있는 경우 처리
    final responseData = json['response'] ?? json;
    
    return SubwayApiResponse(
      header: responseData['header'] != null 
          ? ApiHeader.fromJson(responseData['header']) 
          : null,
      body: responseData['body'] != null 
          ? ApiBody.fromJson(responseData['body']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => _$SubwayApiResponseToJson(this);

  /// 성공 여부 확인
  bool get isSuccess => header?.resultCode == '00';

  /// 에러 메시지 반환
  String? get errorMessage => header?.resultMsg;

  /// 데이터 목록 반환
  List<Map<String, dynamic>> get items => body?.items ?? [];

  @override
  String toString() {
    return 'SubwayApiResponse(resultCode: ${header?.resultCode}, resultMsg: ${header?.resultMsg}, totalCount: ${body?.totalCount})';
  }
}

/// API 응답 헤더
@JsonSerializable()
class ApiHeader {
  /// 결과 코드 ('00': 정상)
  final String resultCode;
  
  /// 결과 메시지
  final String resultMsg;

  const ApiHeader({
    required this.resultCode,
    required this.resultMsg,
  });

  factory ApiHeader.fromJson(Map<String, dynamic> json) {
    return ApiHeader(
      resultCode: json['resultCode']?.toString() ?? '',
      resultMsg: json['resultMsg']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => _$ApiHeaderToJson(this);

  @override
  String toString() {
    return 'ApiHeader(resultCode: $resultCode, resultMsg: $resultMsg)';
  }
}

/// API 응답 바디
@JsonSerializable()
class ApiBody {
  /// 데이터 항목들
  final List<Map<String, dynamic>> items;
  
  /// 한 페이지당 표출 데이터 수
  final int numOfRows;
  
  /// 페이지 번호
  final int pageNo;
  
  /// 데이터 총 개수
  final int totalCount;

  const ApiBody({
    required this.items,
    required this.numOfRows,
    required this.pageNo,
    required this.totalCount,
  });

  // 커스텀 fromJson - 복잡한 items 구조 처리
  factory ApiBody.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> itemsList = [];
    
    // items 처리
    if (json['items'] != null) {
      final itemsData = json['items'];
      
      if (itemsData is List) {
        // 이미 리스트인 경우
        itemsList = itemsData.cast<Map<String, dynamic>>();
      } else if (itemsData is Map) {
        // items가 객체인 경우, item 키 확인
        if (itemsData['item'] != null) {
          final itemData = itemsData['item'];
          if (itemData is List) {
            itemsList = itemData.cast<Map<String, dynamic>>();
          } else if (itemData is Map) {
            itemsList = [itemData.cast<String, dynamic>()];
          }
        }
      }
    }

    return ApiBody(
      items: itemsList,
      numOfRows: _safeParseInt(json['numOfRows']),
      pageNo: _safeParseInt(json['pageNo'], 1),
      totalCount: _safeParseInt(json['totalCount']),
    );
  }

  Map<String, dynamic> toJson() => _$ApiBodyToJson(this);

  @override
  String toString() {
    return 'ApiBody(totalCount: $totalCount, numOfRows: $numOfRows, pageNo: $pageNo, itemsCount: ${items.length})';
  }
}

/// 공공데이터포털 에러 응답 모델
@JsonSerializable()
class OpenApiErrorResponse {
  /// 에러 메시지
  final String errMsg;
  
  /// 인증 메시지
  final String returnAuthMsg;
  
  /// 에러 코드
  final String returnReasonCode;

  const OpenApiErrorResponse({
    required this.errMsg,
    required this.returnAuthMsg,
    required this.returnReasonCode,
  });

  factory OpenApiErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$OpenApiErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OpenApiErrorResponseToJson(this);

  @override
  String toString() {
    return 'OpenApiErrorResponse(errMsg: $errMsg, returnAuthMsg: $returnAuthMsg, returnReasonCode: $returnReasonCode)';
  }
}
