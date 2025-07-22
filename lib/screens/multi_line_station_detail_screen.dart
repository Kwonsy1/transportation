import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../models/subway_station.dart';
import '../models/station_group.dart';
import '../providers/subway_provider.dart';
import '../providers/location_provider.dart';

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
  State<MultiLineStationDetailScreen> createState() => _MultiLineStationDetailScreenState();
}

class _MultiLineStationDetailScreenState extends State<MultiLineStationDetailScreen> {
  late SubwayStation _selectedStation;

  @override
  void initState() {
    super.initState();
    _selectedStation = widget.initialStation ?? widget.stationGroup.stations.first;
    
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

    // 모든 데이터를 병렬로 로드
    await Future.wait([
      provider.loadNextTrains(),
      provider.loadExitInfo(),
      _loadScheduleData(),
    ]);
  }

  Future<void> _loadScheduleData() async {
    final provider = context.read<SubwayProvider>();
    final dailyTypeCode = provider.getCurrentDailyTypeCode();

    await provider.loadSchedules(
      dailyTypeCode: dailyTypeCode,
      upDownTypeCode: ApiConstants.upDirection,
    );
  }

  void _onLineSelected(SubwayStation station) {
    if (_selectedStation.subwayStationId != station.subwayStationId) {
      setState(() {
        _selectedStation = station;
      });
      _loadStationData();
    }
  }

  Color _getLineColor(String lineNumber) {
    final colors = {
      '1': const Color(0xFF263c96),
      '2': const Color(0xFF00a650),
      '3': const Color(0xFFef7c1c),
      '4': const Color(0xFF00a4e3),
      '5': const Color(0xFF996cac),
      '6': const Color(0xFFcd7c2f),
      '7': const Color(0xFF747f00),
      '8': const Color(0xFFe6186c),
      '9': const Color(0xFFbdb092),
    };
    return colors[lineNumber] ?? const Color(0xFF757575);
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
      print('시간 포맷 오류: $timeString, $e');
      return timeString; // 오류 시 원본 문자열 반환
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // 역 정보 헤더
              _buildStationHeader(),

              const SizedBox(height: 16),

              // 호선 선택 탭
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 선택된 노선 정보
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getLineColor(_selectedStation.lineNumber),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getLineColor(_selectedStation.lineNumber),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    _selectedStation.lineNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedStation.subwayRouteName,
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
                _selectedStation,
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
  }

  Widget _buildLineSelectionTabs() {
    if (widget.stationGroup.stations.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 20,
              ),
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
              final isSelected = _selectedStation.subwayStationId == station.subwayStationId;
              final lineColor = _getLineColor(station.lineNumber);
              
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
                    border: Border.all(
                      color: lineColor,
                      width: 2,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: lineColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
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
                            station.lineNumber,
                            style: TextStyle(
                              color: isSelected ? lineColor : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        station.subwayRouteName
                            .replaceAll('서울 ', '')
                            .replaceAll('호선', ''),
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
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        // 즐겨찾기 버튼
        Consumer<SubwayProvider>(
          builder: (context, provider, child) {
            final isFavorite = provider.isFavoriteStationGroup(widget.stationGroup);
            return OutlinedButton.icon(
              onPressed: () {
                if (isFavorite) {
                  provider.removeFavoriteStationGroup(widget.stationGroup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다')),
                  );
                } else {
                  provider.addFavoriteStationGroup(widget.stationGroup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.stationGroup.cleanStationName}역을 즐겨찾기에 추가했습니다')),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('공유 기능은 추후 구현됩니다')),
            );
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
                  onPressed: () => provider.refreshNextTrains(),
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
                constraints: const BoxConstraints(
                  maxHeight: 300,
                ),
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
                    final isLast = index == upcomingSchedules.take(6).length - 1;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: isLast ? null : Border(
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
