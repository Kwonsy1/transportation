import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 로그 레벨 정의
enum LogLevel {
  /// 디버그 정보 (개발 시에만 표시)
  debug(0, '🔍', 'DEBUG'),
  
  /// 일반 정보 (앱 흐름 추적)
  info(1, 'ℹ️', 'INFO'),
  
  /// 경고 (주의가 필요한 상황)
  warning(2, '⚠️', 'WARNING'),
  
  /// 에러 (오류 발생)
  error(3, '❌', 'ERROR'),
  
  /// 치명적 오류 (앱 종료 가능)
  fatal(4, '💀', 'FATAL');

  const LogLevel(this.level, this.emoji, this.name);
  
  final int level;
  final String emoji;
  final String name;
}

/// 로그 설정
class LogConfig {
  /// 최소 로그 레벨 (이 레벨 이상만 출력)
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  
  /// 타임스탬프 표시 여부
  static bool showTimestamp = true;
  
  /// 파일명 표시 여부
  static bool showFileName = true;
  
  /// 함수명 표시 여부
  static bool showFunctionName = true;
  
  /// 라인 번호 표시 여부
  static bool showLineNumber = true;
  
  /// 스택 트레이스 표시 여부 (에러 로그만)
  static bool showStackTrace = true;
  
  /// 최대 로그 라인 길이
  static int maxLineLength = 1000;
  
  /// 컬러 출력 여부
  static bool useColors = true;
}

/// 메인 로그 클래스
class KSYLog {
  static const String _separator = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  
  /// 현재 스택 트레이스에서 호출자 정보 추출
  static Map<String, String> _getCallerInfo() {
    final stackTrace = StackTrace.current;
    final lines = stackTrace.toString().split('\n');
    
    // 3번째 라인이 실제 호출자 (0: current, 1: _log, 2: debug/info/etc, 3: 실제 호출자)
    if (lines.length > 3) {
      final callerLine = lines[3];
      
      // 파일명 추출
      final fileMatch = RegExp(r'(\w+\.dart):(\d+):(\d+)').firstMatch(callerLine);
      if (fileMatch != null) {
        final fileName = fileMatch.group(1) ?? 'unknown.dart';
        final lineNumber = fileMatch.group(2) ?? '0';
        
        // 함수명 추출 시도
        final functionMatch = RegExp(r'#\d+\s+(\w+\.)?(\w+)\s+').firstMatch(callerLine);
        final functionName = functionMatch?.group(2) ?? 'unknown';
        
        return {
          'fileName': fileName,
          'lineNumber': lineNumber,
          'functionName': functionName,
        };
      }
    }
    
    return {
      'fileName': 'unknown.dart',
      'lineNumber': '0',
      'functionName': 'unknown',
    };
  }
  
  /// 타임스탬프 생성
  static String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}:'
           '${now.second.toString().padLeft(2, '0')}.'
           '${now.millisecond.toString().padLeft(3, '0')}';
  }
  
  /// 로그 메시지 포맷팅
  static String _formatMessage(
    LogLevel level,
    String message,
    Map<String, String> callerInfo,
  ) {
    final buffer = StringBuffer();
    
    // 타임스탬프
    if (LogConfig.showTimestamp) {
      buffer.write('[${_getTimestamp()}] ');
    }
    
    // 로그 레벨
    buffer.write('${level.emoji} ${level.name} ');
    
    // 파일 정보
    final locationParts = <String>[];
    if (LogConfig.showFileName) {
      locationParts.add(callerInfo['fileName']!);
    }
    if (LogConfig.showLineNumber) {
      locationParts.add('L${callerInfo['lineNumber']}');
    }
    if (LogConfig.showFunctionName) {
      locationParts.add('${callerInfo['functionName']}()');
    }
    
    if (locationParts.isNotEmpty) {
      buffer.write('[${locationParts.join(':')}] ');
    }
    
    // 메시지
    buffer.write(message);
    
    // 길이 제한
    final result = buffer.toString();
    if (result.length > LogConfig.maxLineLength) {
      return '${result.substring(0, LogConfig.maxLineLength - 3)}...';
    }
    
    return result;
  }
  
  /// 내부 로그 출력 메서드
  static void _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    // 레벨 필터링
    if (level.level < LogConfig.minLevel.level) {
      return;
    }
    
    final callerInfo = _getCallerInfo();
    final formattedMessage = _formatMessage(level, message, callerInfo);
    
    // Flutter의 developer.log 사용 (성능상 이점)
    developer.log(
      formattedMessage,
      name: 'KSYLog',
      level: level.level * 100,
      error: error,
      stackTrace: stackTrace,
    );
    
    // 디버그 모드에서는 print도 함께 사용
    if (kDebugMode) {
      print(formattedMessage);
      
      // 에러 레벨 이상이고 스택 트레이스가 있으면 출력
      if (level.level >= LogLevel.error.level && LogConfig.showStackTrace) {
        if (error != null) {
          print('  └─ Error: $error');
        }
        if (stackTrace != null) {
          final lines = stackTrace.toString().split('\n').take(5); // 상위 5줄만
          for (final line in lines) {
            print('  └─ $line');
          }
        }
      }
    }
  }
  
  /// 디버그 로그
  static void debug(String message) {
    _log(LogLevel.debug, message);
  }
  
  /// 정보 로그
  static void info(String message) {
    _log(LogLevel.info, message);
  }
  
  /// 경고 로그
  static void warning(String message) {
    _log(LogLevel.warning, message);
  }
  
  /// 에러 로그
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }
  
  /// 치명적 오류 로그
  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error, stackTrace);
  }
  
  /// 구분선 출력
  static void separator([String? title]) {
    if (LogLevel.debug.level >= LogConfig.minLevel.level) {
      if (title != null) {
        final titleLine = '━━━━━━━━ $title ━━━━━━━━';
        _log(LogLevel.debug, titleLine);
      } else {
        _log(LogLevel.debug, _separator);
      }
    }
  }
  
  /// 객체 정보 로그 (JSON 형태)
  static void object(String name, Object? obj) {
    if (LogLevel.debug.level >= LogConfig.minLevel.level) {
      try {
        _log(LogLevel.debug, '$name: ${obj.toString()}');
      } catch (e) {
        _log(LogLevel.debug, '$name: [변환 실패: $e]');
      }
    }
  }
  
  /// 성능 측정용 로그
  static void performance(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    final emoji = ms < 100 ? '⚡' : ms < 500 ? '🐌' : '🐢';
    _log(LogLevel.info, '$emoji Performance: $operation took ${ms}ms');
  }
  
  /// 네트워크 요청 로그
  static void network(String method, String url, [int? statusCode, Duration? duration]) {
    final buffer = StringBuffer();
    buffer.write('🌐 $method $url');
    
    if (statusCode != null) {
      final statusEmoji = statusCode < 300 ? '✅' : statusCode < 400 ? '📍' : '❌';
      buffer.write(' $statusEmoji$statusCode');
    }
    
    if (duration != null) {
      buffer.write(' (${duration.inMilliseconds}ms)');
    }
    
    _log(LogLevel.info, buffer.toString());
  }
  
  /// 데이터베이스 작업 로그
  static void database(String operation, String table, [int? affectedRows]) {
    final buffer = StringBuffer();
    buffer.write('🗄️ DB: $operation on $table');
    
    if (affectedRows != null) {
      buffer.write(' ($affectedRows rows)');
    }
    
    _log(LogLevel.info, buffer.toString());
  }
  
  /// 위치 정보 로그
  static void location(String action, double? latitude, double? longitude) {
    if (latitude != null && longitude != null) {
      _log(LogLevel.info, '📍 Location: $action at ($latitude, $longitude)');
    } else {
      _log(LogLevel.info, '📍 Location: $action (coordinates unavailable)');
    }
  }
  
  /// UI 이벤트 로그
  static void ui(String event, [String? details]) {
    final message = details != null ? '🎨 UI: $event - $details' : '🎨 UI: $event';
    _log(LogLevel.debug, message);
  }
  
  /// 권한 관련 로그
  static void permission(String permission, bool granted) {
    final emoji = granted ? '✅' : '❌';
    _log(LogLevel.info, '$emoji Permission: $permission ${granted ? 'granted' : 'denied'}');
  }
  
  /// API 응답 로그
  static void apiResponse(String endpoint, bool success, [String? message]) {
    final emoji = success ? '✅' : '❌';
    final logMessage = message != null 
        ? '$emoji API: $endpoint - $message'
        : '$emoji API: $endpoint ${success ? 'success' : 'failed'}';
    _log(success ? LogLevel.info : LogLevel.error, logMessage);
  }
  
  /// 캐시 작업 로그
  static void cache(String operation, String key, [bool? hit]) {
    final buffer = StringBuffer();
    buffer.write('💾 Cache: $operation $key');
    
    if (hit != null) {
      buffer.write(hit ? ' ✅ HIT' : ' ❌ MISS');
    }
    
    _log(LogLevel.debug, buffer.toString());
  }
  
  /// 설정 변경 로그
  static void config(String setting, Object oldValue, Object newValue) {
    _log(LogLevel.info, '⚙️ Config: $setting changed from $oldValue to $newValue');
  }
  
  /// 앱 생명주기 로그
  static void lifecycle(String event) {
    _log(LogLevel.info, '🔄 Lifecycle: $event');
  }
  
  /// 로그 설정 초기화 (앱 시작 시 호출)
  static void initialize({
    LogLevel? minLevel,
    bool? showTimestamp,
    bool? showFileName,
    bool? showFunctionName,
    bool? showLineNumber,
    bool? showStackTrace,
    int? maxLineLength,
  }) {
    if (minLevel != null) LogConfig.minLevel = minLevel;
    if (showTimestamp != null) LogConfig.showTimestamp = showTimestamp;
    if (showFileName != null) LogConfig.showFileName = showFileName;
    if (showFunctionName != null) LogConfig.showFunctionName = showFunctionName;
    if (showLineNumber != null) LogConfig.showLineNumber = showLineNumber;
    if (showStackTrace != null) LogConfig.showStackTrace = showStackTrace;
    if (maxLineLength != null) LogConfig.maxLineLength = maxLineLength;
    
    info('KSY Log system initialized with minLevel: ${LogConfig.minLevel.name}');
  }
}

/// 편의를 위한 전역 함수들 (선택적 사용)
void logDebug(String message) => KSYLog.debug(message);
void logInfo(String message) => KSYLog.info(message);
void logWarning(String message) => KSYLog.warning(message);
void logError(String message, [Object? error, StackTrace? stackTrace]) => 
    KSYLog.error(message, error, stackTrace);
void logFatal(String message, [Object? error, StackTrace? stackTrace]) => 
    KSYLog.fatal(message, error, stackTrace);