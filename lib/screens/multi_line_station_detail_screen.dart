import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/station_group.dart';
import '../models/subway_station.dart';
import '../providers/subway_provider.dart';

/// 멀티라인 역 상세 화면
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

class _MultiLineStationDetailScreenState extends State<MultiLineStationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SubwayStation? _selectedStation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.stationGroup.stations.length,
      vsync: this,
    );
    
    _selectedStation = widget.initialStation ?? widget.stationGroup.stations.first;
    
    // 초기 역 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubwayProvider>().selectStation(_selectedStation!);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stationGroup.cleanStationName}역'),
        actions: [
          // 즐겨찾기 버튼
          Consumer<SubwayProvider>(
            builder: (context, provider, child) {
              final isFavorite = provider.isFavoriteStationGroup(widget.stationGroup);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? AppColors.error : null,
                ),
                onPressed: () async {
                  if (isFavorite) {
                    await provider.removeFavoriteStationGroup(widget.stationGroup);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    await provider.addFavoriteStationGroup(widget.stationGroup);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.stationGroup.cleanStationName}역을 즐겨찾기에 추가했습니다'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
        bottom: widget.stationGroup.stations.length > 1
            ? TabBar(
                controller: _tabController,
                tabs: widget.stationGroup.stations.map((station) {
                  return Tab(
                    text: '${station.lineNumber}호선',
                  );
                }).toList(),
                onTap: (index) {
                  setState(() {
                    _selectedStation = widget.stationGroup.stations[index];
                  });
                  context.read<SubwayProvider>().selectStation(_selectedStation!);
                },
              )
            : null,
      ),
      body: _selectedStation == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 역 정보 헤더
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: AppColors.primary.withOpacity(0.1),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getLineColor(_selectedStation!.lineNumber),
                        child: Text(
                          _selectedStation!.lineNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStation!.stationName,
                              style: AppTextStyles.heading2,
                            ),
                            Text(
                              _selectedStation!.lineName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 역 상세 정보
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // 다음 열차 정보
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '다음 열차',
                                    style: AppTextStyles.heading3,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () {
                                      context.read<SubwayProvider>().loadNextTrains();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Consumer<SubwayProvider>(
                                builder: (context, provider, child) {
                                  if (provider.isLoadingNextTrains) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(AppSpacing.md),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  
                                  if (provider.nextTrains.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      child: const Text(
                                        '다음 열차 정보가 없습니다.\n시간표 기반 정보를 사용하므로 운행 시간을 확인해주세요.',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    );
                                  }
                                  
                                  return Column(
                                    children: provider.nextTrains.take(5).map((train) {
                                      return ListTile(
                                        leading: Icon(
                                          Icons.train,
                                          color: _getLineColor(train.lineNumber),
                                        ),
                                        title: Text(train.destination),
                                        subtitle: Text(
                                          '${train.direction} • ${train.arrivalTime}',
                                        ),
                                        trailing: Text(
                                          train.arrivalStatusMessage,
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // 시간표 정보
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '시간표',
                                style: AppTextStyles.heading3,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final provider = context.read<SubwayProvider>();
                                        provider.loadSchedules(
                                          dailyTypeCode: provider.getCurrentDailyTypeCode(),
                                          upDownTypeCode: 'U', // 상행
                                        );
                                      },
                                      child: const Text('상행 시간표'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final provider = context.read<SubwayProvider>();
                                        provider.loadSchedules(
                                          dailyTypeCode: provider.getCurrentDailyTypeCode(),
                                          upDownTypeCode: 'D', // 하행
                                        );
                                      },
                                      child: const Text('하행 시간표'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Consumer<SubwayProvider>(
                                builder: (context, provider, child) {
                                  if (provider.isLoadingSchedules) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(AppSpacing.md),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  
                                  if (provider.schedules.isEmpty) {
                                    return const Text('시간표를 불러오려면 위 버튼을 눌러주세요.');
                                  }
                                  
                                  final upcomingSchedules = provider.getUpcomingSchedules();
                                  return Column(
                                    children: upcomingSchedules.take(5).map((schedule) {
                                      return ListTile(
                                        leading: const Icon(Icons.schedule),
                                        title: Text(schedule.endSubwayStationNm),
                                        subtitle: Text(schedule.directionKorean),
                                        trailing: Text(
                                          schedule.simpleArrivalTime,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // 출구 정보
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '출구 정보',
                                    style: AppTextStyles.heading3,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () {
                                      context.read<SubwayProvider>().loadExitInfo();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Consumer<SubwayProvider>(
                                builder: (context, provider, child) {
                                  if (provider.isLoadingExitInfo) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(AppSpacing.md),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  
                                  final busRoutes = provider.busRoutesByExit;
                                  final facilities = provider.facilitiesByExit;
                                  
                                  if (busRoutes.isEmpty && facilities.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      child: const Text(
                                        '출구 정보가 없습니다.\n새로고침 버튼을 눌러 다시 시도해보세요.',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    );
                                  }
                                  
                                  return Column(
                                    children: [
                                      if (busRoutes.isNotEmpty) ...[
                                        const Text('버스 노선 정보', style: AppTextStyles.bodyLarge),
                                        const SizedBox(height: AppSpacing.sm),
                                        ...busRoutes.entries.take(3).map((entry) {
                                          return ListTile(
                                            leading: CircleAvatar(
                                              child: Text(entry.key),
                                            ),
                                            title: Text('${entry.key}번 출구'),
                                            subtitle: Text(
                                              entry.value.map((route) => route.busRouteNm).join(', '),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                      if (facilities.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        const Text('주변 시설 정보', style: AppTextStyles.bodyLarge),
                                        const SizedBox(height: AppSpacing.sm),
                                        ...facilities.entries.take(3).map((entry) {
                                          return ListTile(
                                            leading: CircleAvatar(
                                              child: Text(entry.key),
                                            ),
                                            title: Text('${entry.key}번 출구'),
                                            subtitle: Text(
                                              entry.value.map((facility) => facility.cfFacilityNm).join(', '),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Color _getLineColor(String lineNumber) {
    final colors = {
      '1': AppColors.line1,
      '2': AppColors.line2,
      '3': AppColors.line3,
      '4': AppColors.line4,
      '5': AppColors.line5,
      '6': AppColors.line6,
      '7': AppColors.line7,
      '8': AppColors.line8,
      '9': AppColors.line9,
    };
    return colors[lineNumber] ?? AppColors.primary;
  }
}
