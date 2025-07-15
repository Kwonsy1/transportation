import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// 디버그 콘솔 화면 - JavaScript 로그 모니터링
class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';
  LogLevel _filterLevel = LogLevel.all;

  @override
  void initState() {
    super.initState();
    _addInitialLog();
    DebugConsole.setInstance(this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addInitialLog() {
    _addLog(LogLevel.info, '🔧 디버그 콘솔이 시작되었습니다');
    _addLog(LogLevel.info, '📱 JavaScript 로그를 실시간으로 모니터링합니다');
  }

  void addLog(LogLevel level, String message) {
    if (mounted) {
      setState(() {
        _addLog(level, message);
      });
    }
  }

  void _addLog(LogLevel level, String message) {
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
    );
    
    _logs.add(entry);
    
    // 최대 로그 수 제한
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    
    // 자동 스크롤
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  List<LogEntry> get _filteredLogs {
    return _logs.where((log) {
      // 레벨 필터
      if (_filterLevel != LogLevel.all && log.level != _filterLevel) {
        return false;
      }
      
      // 텍스트 필터
      if (_filter.isNotEmpty && 
          !log.message.toLowerCase().contains(_filter.toLowerCase())) {
        return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 디버그 콘솔'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 필터 버튼
          PopupMenuButton<LogLevel>(
            icon: Icon(
              Icons.filter_list,
              color: _filterLevel != LogLevel.all ? Colors.yellow : Colors.white,
            ),
            onSelected: (level) {
              setState(() {
                _filterLevel = level;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: LogLevel.all,
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('모든 로그'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LogLevel.error,
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('오류만'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LogLevel.warning,
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('경고만'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LogLevel.info,
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('정보만'),
                  ],
                ),
              ),
            ],
          ),
          
          // 자동 스크롤 토글
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: _autoScroll ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: '자동 스크롤 ${_autoScroll ? '끄기' : '켜기'}',
          ),
          
          // 로그 지우기
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _logs.clear();
                _addInitialLog();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그가 지워졌습니다')),
              );
            },
            tooltip: '로그 지우기',
          ),
          
          // 로그 복사
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final logText = filteredLogs.map((log) => 
                '[${log.formattedTime}] ${log.levelName}: ${log.message}'
              ).join('\n');
              
              Clipboard.setData(ClipboardData(text: logText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그가 클립보드에 복사되었습니다')),
              );
            },
            tooltip: '로그 복사',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade900,
        child: Column(
          children: [
            // 검색 필터
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '로그 검색...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade700,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 통계 정보
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filteredLogs.length}/${_logs.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 로그 목록
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter.isNotEmpty 
                                ? '검색 결과가 없습니다'
                                : '로그가 없습니다',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildLogEntry(log);
                      },
                    ),
            ),
          ],
        ),
      ),
      
      // 하단 액션 버튼
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          border: Border(
            top: BorderSide(color: Colors.grey.shade700),
          ),
        ),
        child: Row(
          children: [
            // 로그 레벨 통계
            Expanded(
              child: Row(
                children: [
                  _buildLogCount(LogLevel.error, Colors.red),
                  const SizedBox(width: 8),
                  _buildLogCount(LogLevel.warning, Colors.orange),
                  const SizedBox(width: 8),
                  _buildLogCount(LogLevel.info, Colors.blue),
                ],
              ),
            ),
            
            // 최신 로그로 이동
            if (!_autoScroll)
              IconButton(
                icon: const Icon(Icons.vertical_align_bottom),
                color: Colors.white,
                onPressed: () {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                },
                tooltip: '최신 로그로 이동',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로그 레벨 아이콘
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: log.levelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              log.levelIcon,
              color: log.levelColor,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          
          // 시간
          Text(
            log.formattedTime,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          
          // 메시지
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                color: Colors.grey.shade100,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCount(LogLevel level, Color color) {
    final count = _logs.where((log) => log.level == level).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getLogIcon(level),
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.all:
        return Icons.all_inclusive;
    }
  }
}

// 로그 엔트리 클래스
class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  String get levelName {
    switch (level) {
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.all:
        return 'ALL';
    }
  }

  Color get levelColor {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.all:
        return Colors.grey;
    }
  }

  IconData get levelIcon {
    switch (level) {
      case LogLevel.error:
        return Icons.error;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.all:
        return Icons.all_inclusive;
    }
  }
}

// 로그 레벨 열거형
enum LogLevel {
  all,
  error,
  warning,
  info,
}

// 전역 디버그 콘솔 인스턴스
class DebugConsole {
  static _DebugConsoleScreenState? _instance;

  static void setInstance(_DebugConsoleScreenState instance) {
    _instance = instance;
  }

  static void log(LogLevel level, String message) {
    _instance?.addLog(level, message);
    print('[${level.name.toUpperCase()}] $message');
  }

  static void error(String message) => log(LogLevel.error, message);
  static void warning(String message) => log(LogLevel.warning, message);
  static void info(String message) => log(LogLevel.info, message);
}
