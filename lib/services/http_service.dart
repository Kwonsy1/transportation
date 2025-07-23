import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../utils/ksy_log.dart';

/// HTTP 클라이언트 관리 서비스
class HttpService {
  static HttpService? _instance;
  late Dio _dio;

  HttpService._internal() {
    _dio = Dio();
    _setupInterceptors();
  }

  static HttpService get instance {
    _instance ??= HttpService._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  /// Dio 인터셉터 설정
  void _setupInterceptors() {
    _dio.options.connectTimeout = Duration(
      seconds: ApiConstants.connectTimeoutSeconds,
    );
    _dio.options.receiveTimeout = Duration(
      seconds: ApiConstants.receiveTimeoutSeconds,
    );

    // 요청/응답 로깅 인터셉터 (디버그 모드에서만)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: true,
      ),
    );

    // 에러 처리 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // 여기서 공통 에러 처리 로직을 추가할 수 있습니다
          KSYLog.error('HTTP Error: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// GET 요청
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST 요청
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Dio 에러를 앱 에러로 변환
  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('연결 시간이 초과되었습니다.');
      case DioExceptionType.sendTimeout:
        return Exception('요청 전송 시간이 초과되었습니다.');
      case DioExceptionType.receiveTimeout:
        return Exception('응답 수신 시간이 초과되었습니다.');
      case DioExceptionType.badResponse:
        return Exception('서버 응답 오류: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('요청이 취소되었습니다.');
      case DioExceptionType.connectionError:
        return Exception('네트워크 연결에 실패했습니다.');
      default:
        return Exception('알 수 없는 오류가 발생했습니다: ${error.message}');
    }
  }
}
