import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/api_constants.dart';
import '../models/subway_station.dart';
import '../models/station_group.dart';
import '../providers/subway_provider.dart';
import '../providers/location_provider.dart';
import '../utils/ksy_log.dart';
import '../utils/app_utils.dart';

/// 멀티 호선 지원 역 상세 정보 화면
class MultiLineStationDetailScreen extends StatefulWidget {
  final StationGroup stationGroup;
  final SubwayStation? initialStation;

  const MultiLineStationDetailScreen({
    super.key,
    required this.stationGroup,
    this.initialStation,
  });

  @override
  State<MultiLineStationDetailScreen> createState() =>
      _MultiLineStationDetailScreenState();
}

class _MultiLineStationDetailScreenState
    extends State<MultiLineStationDetailScreen> {
  late SubwayStation _selectedStation;

  @override
  void initState() {
    super.initState();
    _selectedStation =
        widget.initialStation ?? widget.stationGroup.stations.first;

    // 역 그룹 구조 디버깅
    KSYLog.info('=== 역 그룹 구조 디버깅 ===');
    KSYLog.info('총 역 개수: ${widget.stationGroup.stations.length}');
    for (int i = 0; i < widget.stationGroup.stations.length; i++) {
      final station = widget.stationGroup.stations[i];
      KSYLog.info('역 $i: ${station.subwayStationName} (${station.effectiveLineNumber}) - ID: ${station.subwayStationId}');
    }
    KSYLog.info('초기 선택된 역: ${_selectedStation.subwayStationName} (${_selectedStation.effectiveLineNumber}) - ID: ${_selectedStation.subwayStationId}');
    KSYLog.info('=== 역 그룹 구조 디버깅 완료 ===');

    // 선택된 역의 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStationData();
    });
  }

  Future<void> _loadStationData() async {
    final provider = context.read<SubwayProvider>();
    provider.selectStation(_selectedStation);
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    final provider = context.read<SubwayProvider>();
    KSYLog.info('데이터 로드 시작: ${_selectedStation.subwayStationName} (${_selectedStation.effectiveLineNumber})');

    try {
      // 모든 데이터를 병렬로 로드
      await Future.wait([
        provider.loadNextTrains(),
        provider.loadExitInfo(),
        _loadScheduleData(),
      ]);
      KSYLog.info('데이터 로드 완료');
    } catch (e) {
      KSYLog.error('데이터 로드 실패', e);
    }
  }

  Future<void> _loadScheduleData() async {
    final provider = context.read<SubwayProvider>();
    final dailyTypeCode = provider.getCurrentDailyTypeCode();

    KSYLog.debug(
      '시간표 로드: ${_selectedStation.subwayStationId}, 요일: $dailyTypeCode, 호선: ${_selectedStation.effectiveLineNumber}',
    );
    
    await provider.loadSchedules(
      dailyTypeCode: dailyTypeCode,
      upDownTypeCode: ApiConstants.upDirection, // 상행 방향으로 로드
    );
    
    KSYLog.debug('시간표 로드 완료: ${provider.schedules.length}개');
  }

  /// 호선 번호를 표시용으로 변환
  String _getDisplayLineNumber(String lineNumber) {
    // 숫자만 있는 경우 (1, 2, 3 등)
    if (RegExp(r'^\d+$').hasMatch(lineNumber)) {
      return '${lineNumber}호선';
    }
    
    // 이미 "선"으로 끝나는 경우 그대로 반환
    if (lineNumber.endsWith('선')) {
      return lineNumber;
    }
    
    // 기타 특수 호선의 경우 "선" 추가
    return '${lineNumber}선';
  }

  void _onLineSelected(SubwayStation station) {
    KSYLog.info('호선 탭 클릭: ${station.effectiveLineNumber} (ID: ${station.subwayStationId})');
    KSYLog.debug('현재 선택된 역: ${_selectedStation.effectiveLineNumber} (ID: ${_selectedStation.subwayStationId})');
    
    // 호선 번호로 비교 (같은 역의 다른 호선이므로 effectiveLineNumber로 비교)
    if (_selectedStation.effectiveLineNumber != station.effectiveLineNumber) {
      KSYLog.info('호선 변경: ${_selectedStation.effectiveLineNumber} → ${station.effectiveLineNumber}');
      
      // setState를 먼저 호출하여 UI 업데이트
      setState(() {
        _selectedStation = station;
        KSYLog.debug('setState 완료: 새로운 선택된 역 = ${_selectedStation.effectiveLineNumber}');
      });
      
      // provider의 선택된 역을 업데이트
      final provider = context.read<SubwayProvider>();
      provider.selectStation(_selectedStation);
      
      // 비동기적으로 데이터 로드
      _loadAllData().then((_) {
        KSYLog.info('데이터 로드 및 UI 업데이트 완료');
      });
    } else {
      KSYLog.warning('동일한 호선 선택됨: ${station.effectiveLineNumber}');
    }
  }


  /// 시간 포맷 헬퍼 (범위 체크 포함)
  String _formatTime(String timeString) {
    if (timeString.length < 4) {
      return timeString; // 너무 짧으면 그대로 반환
    }

    try {
      if (timeString.length >= 6) {
        // HHMMSS 형식
        return '${timeString.substring(0, 2)}:${timeString.substring(2, 4)}';
      } else if (timeString.length >= 4) {
        // HHMM 형식
        return '${timeString.substring(0, 2)}:${timeString.substring(2, 4)}';
      } else {
        return timeString;
      }
    } catch (e) {
      KSYLog.error('시간 포맷 오류: $timeString', e);
      return timeString; // 오류 시 원본 문자열 반환
    }
  }

  @override
  Widget build(BuildContext context) {
    KSYLog.debug('Build 호출: 현재 선택된 역 = ${_selectedStation.effectiveLineNumber}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          '${widget.stationGroup.cleanStationName}역',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 역 정보 헤더 (Consumer로 감싸서 상태 변화 감지)
              _buildStationHeader(),

              const SizedBox(height: 16),

              // 호선 선택 탭 (Consumer로 감싸서 선택 상태 업데이트)
              _buildLineSelectionTabs(),

              const SizedBox(height: 20),

              // 즐겨찾기 및 기타 액션
              _buildSecondaryActions(),

              const SizedBox(height: 24),

              // 실시간 열차 정보
              _buildRealtimeInfo(),

              const SizedBox(height: 24),

              // 시간표 정보
              _buildScheduleInfo(),

              const SizedBox(height: 24),

              // 출구 정보
              _buildExitInfo(),

              // 하단 여백 추가
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationHeader() {
    return Consumer<SubwayProvider>(
      builder: (context, provider, child) {
        // 로컬 _selectedStation을 우선 사용 (즉시성을 위해)
        final currentStation = _selectedStation;
        KSYLog.debug('UI: 헤더 빌드 - ${currentStation.subwayStationName} (${currentStation.effectiveLineNumber})');
        KSYLog.debug('Provider 헤더 역 = ${provider.selectedStation?.effectiveLineNumber ?? 'null'}');
    
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // 현재 선택된 노선 정보
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: SubwayUtils.getLineColor(currentStation.effectiveLineNumber),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: SubwayUtils.getLineColor(currentStation.effectiveLineNumber),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    currentStation.effectiveLineNumber.length > 3
                        ? currentStation.effectiveLineNumber.substring(0, 2)
                        : currentStation.effectiveLineNumber,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: currentStation.effectiveLineNumber.length > 2
                          ? 8
                          : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getDisplayLineNumber(currentStation.effectiveLineNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 거리 정보
        Consumer<LocationProvider>(
          builder: (context, locationProvider, child) {
            if (locationProvider.currentPosition != null) {
              final distance = locationProvider.calculateDistanceToStation(
                currentStation,
              );
              if (distance != null) {
                return Text(
                  '현재 위치에서 ${locationProvider.formatDistance(distance)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                );
              }
            }
            return const SizedBox.shrink();
          },
        ),
          ],
        );
      },
    );
  }

  Widget _buildLineSelectionTabs() {
    if (widget.stationGroup.stations.length <= 1) {
      return const SizedBox.shrink();
    }
    
    // Consumer 내부에서 호출되므로 provider에 접근 가능
    return Consumer<SubwayProvider>(
      builder: (context, provider, child) {
        // 로컬 _selectedStation을 우선 사용 (즉시성을 위해)
        final currentSelectedStation = _selectedStation;
        KSYLog.debug('탭 빌드: 현재 선택된 역 = ${currentSelectedStation.effectiveLineNumber} (ID: ${currentSelectedStation.subwayStationId})');
        KSYLog.debug('Provider 선택된 역 = ${provider.selectedStation?.effectiveLineNumber ?? 'null'}');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '호선을 선택해주세요',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 호선 탭들
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.stationGroup.stations.map((station) {
              final isSelected =
                  currentSelectedStation.effectiveLineNumber == station.effectiveLineNumber;
              final lineNumber = station.effectiveLineNumber;
              final lineColor = SubwayUtils.getLineColor(lineNumber);
              
              KSYLog.debug('버튼 렌더링: ${station.effectiveLineNumber} (ID: ${station.subwayStationId}) - 선택됨: $isSelected');
              KSYLog.debug('  - 현재 선택: "${currentSelectedStation.effectiveLineNumber}" vs 버튼: "${station.effectiveLineNumber}"');

              return GestureDetector(
                onTap: () => _onLineSelected(station),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? lineColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: lineColor, width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: lineColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : lineColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            lineNumber.length > 3
                                ? lineNumber.substring(0, 2)
                                : lineNumber,
                            style: TextStyle(
                              color: isSelected ? lineColor : Colors.white,
                              fontSize: lineNumber.length > 2 ? 8 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getDisplayLineNumber(station.effectiveLineNumber),
                        style: TextStyle(
                          color: isSelected ? Colors.white : lineColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        // 즐겨찾기 버튼
        Consumer<SubwayProvider>(
          builder: (context, provider, child) {
            final isFavorite = provider.isFavoriteStationGroup(
              widget.stationGroup,
            );
            return OutlinedButton.icon(
              onPressed: () {
                if (isFavorite) {
                  provider.removeFavoriteStationGroup(widget.stationGroup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다',
                      ),
                    ),
                  );
                } else {
                  provider.addFavoriteStationGroup(widget.stationGroup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.stationGroup.cleanStationName}역을 즐겨찾기에 추가했습니다',
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.orange : Colors.grey,
              ),
              label: Text(
                '즐겨찾기',
                style: TextStyle(
                  color: isFavorite ? Colors.orange : Colors.grey,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isFavorite ? Colors.orange : Colors.grey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 12),

        // 공유 버튼
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('공유 기능은 추후 구현됩니다')));
          },
          icon: const Icon(Icons.share, color: Colors.grey),
          label: const Text('공유', style: TextStyle(color: Colors.grey)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimeInfo() {
    return Consumer<SubwayProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '실시간',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '오후 ${DateTime.now().hour % 12}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    KSYLog.info('실시간 정보 새로고침 버튼 클릭');
                    provider.refreshNextTrains();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (provider.isLoadingNextTrains)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SpinKitWave(color: Colors.blue, size: 30),
                ),
              )
            else if (provider.nextTrains.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '실시간 정보를 불러올 수 없습니다\n(시간표를 확인해주세요)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: [
                  // 상행선
                  if (provider.upwardNextTrains.isNotEmpty) ...[
                    _buildDirectionInfo(
                      '상행선',
                      provider.upwardNextTrains.first.destination,
                      provider.upwardNextTrains,
                      true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 하행선
                  if (provider.downwardNextTrains.isNotEmpty)
                    _buildDirectionInfo(
                      '하행선',
                      provider.downwardNextTrains.first.destination,
                      provider.downwardNextTrains,
                      false,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildDirectionInfo(
    String direction,
    String destination,
    List nextTrains,
    bool isUpward,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isUpward ? Colors.blue : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$direction $destination 방면',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (nextTrains.isNotEmpty)
            Row(
              children: [
                // 첫 번째 열차
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextTrains[0].formattedTimeUntilArrival.isEmpty
                            ? nextTrains[0].arrivalStatusMessage
                            : nextTrains[0].formattedTimeUntilArrival,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        nextTrains[0].arrivalStatusMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // 두 번째 열차 (있는 경우)
                if (nextTrains.length > 1)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextTrains[1].formattedTimeUntilArrival.isEmpty
                              ? nextTrains[1].arrivalStatusMessage
                              : nextTrains[1].formattedTimeUntilArrival,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          nextTrains[1].arrivalStatusMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo() {
    return Consumer<SubwayProvider>(
      builder: (context, provider, child) {
        final upcomingSchedules = provider.getUpcomingSchedules();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  '전체 시간표',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (provider.isLoadingSchedules)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SpinKitWave(color: Colors.blue, size: 30),
                ),
              )
            else if (upcomingSchedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '시간표 정보가 없습니다',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingSchedules.take(6).length,
                  itemBuilder: (context, index) {
                    final schedule = upcomingSchedules.elementAt(index);
                    final isLast =
                        index == upcomingSchedules.take(6).length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 0.5,
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _formatTime(schedule.depTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '${schedule.endSubwayStationNm} 방면',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(schedule.arrTime),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExitInfo() {
    return Consumer<SubwayProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingExitInfo) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SpinKitWave(color: Colors.blue, size: 30),
            ),
          );
        }

        final exits = <String>{};
        for (var route in provider.exitBusRoutes) {
          exits.add(route.exitNo);
        }
        for (var facility in provider.exitFacilities) {
          exits.add(facility.exitNo);
        }

        if (exits.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  '출구 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exits.map((exitNo) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    '$exitNo번 출구',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
