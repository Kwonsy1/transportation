import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../models/subway_station.dart';
import '../providers/subway_provider.dart';
import '../widgets/next_train_card.dart';
import '../widgets/schedule_card.dart';
import '../widgets/exit_info_card.dart';

/// 역 상세 정보 화면 (국토교통부 API 기준)
class StationDetailScreen extends StatefulWidget {
  final SubwayStation station;

  const StationDetailScreen({
    super.key,
    required this.station,
  });

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // 역 선택 및 다음 열차 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SubwayProvider>();
      provider.selectStation(widget.station);
      provider.loadNextTrains();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final provider = context.read<SubwayProvider>();
    
    switch (_tabController.index) {
      case 0:
        // 다음 열차 정보 새로고침
        await provider.refreshNextTrains();
        break;
      case 1:
        // 시간표 정보 새로고침
        await Future.delayed(Duration.zero);
        _loadScheduleData();
        break;
      case 2:
        // 출구 정보 새로고침
        await provider.loadExitInfo();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.station.subwayStationName),
        actions: [
          Consumer<SubwayProvider>(
            builder: (context, provider, child) {
              final isFavorite = provider.isFavoriteStation(widget.station);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? AppColors.error : AppColors.textLight,
                ),
                onPressed: () {
                  if (isFavorite) {
                    provider.removeFavoriteStation(widget.station);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.station.subwayStationName}역을 즐겨찾기에서 제거했습니다'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    provider.addFavoriteStation(widget.station);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.station.subwayStationName}역을 즐겨찾기에 추가했습니다'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textLight,
          labelColor: AppColors.textLight,
          unselectedLabelColor: AppColors.textLight.withOpacity(0.7),
          tabs: const [
            Tab(text: '다음 열차'),
            Tab(text: '시간표'),
            Tab(text: '출구 정보'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 다음 열차 정보 탭
          _buildNextTrainsTab(),
          
          // 시간표 탭
          _buildScheduleTab(),
          
          // 출구 정보 탭
          _buildExitInfoTab(),
        ],
      ),
    );
  }

  Widget _buildNextTrainsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Consumer<SubwayProvider>(
        builder: (context, provider, child) {
          // 로딩 상태
          if (provider.isLoadingNextTrains) {
            return const Center(
              child: SpinKitWave(
                color: AppColors.primary,
                size: 50.0,
              ),
            );
          }

          // 에러 상태
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    provider.errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadNextTrains();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 데이터 없음
          if (provider.nextTrains.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.train_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '다음 열차 정보가 없습니다',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => provider.loadNextTrains(),
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }

          // 다음 열차 정보 목록
          return CustomScrollView(
            slivers: [
              // 상행 열차
              if (provider.upwardNextTrains.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      '상행 (${provider.upwardNextTrains.first.destination} 방면)',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final nextTrain = provider.upwardNextTrains[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: NextTrainCard(nextTrain: nextTrain),
                      );
                    },
                    childCount: provider.upwardNextTrains.length,
                  ),
                ),
              ],
              
              // 하행 열차
              if (provider.downwardNextTrains.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      '하행 (${provider.downwardNextTrains.first.destination} 방면)',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final nextTrain = provider.downwardNextTrains[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: NextTrainCard(nextTrain: nextTrain),
                      );
                    },
                    childCount: provider.downwardNextTrains.length,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Consumer<SubwayProvider>(
        builder: (context, provider, child) {
          // 로딩 상태
          if (provider.isLoadingSchedules) {
            return const Center(
              child: SpinKitWave(
                color: AppColors.primary,
                size: 50.0,
              ),
            );
          }

          // 에러 상태
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    provider.errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _loadScheduleData();
                      });
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 시간표 데이터 로드 (빌드 후에 실행)
          if (provider.schedules.isEmpty && !provider.isLoadingSchedules) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadScheduleData();
            });
            return const Center(
              child: SpinKitWave(
                color: AppColors.primary,
                size: 50.0,
              ),
            );
          }

          // 시간표 목록
          final upcomingSchedules = provider.getUpcomingSchedules();
          
          if (upcomingSchedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '시간표 정보가 없습니다',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _loadScheduleData();
                      });
                    },
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: upcomingSchedules.length,
            itemBuilder: (context, index) {
              final schedule = upcomingSchedules[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ScheduleCard(schedule: schedule),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExitInfoTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Consumer<SubwayProvider>(
        builder: (context, provider, child) {
          // 출구 정보가 로드되지 않았으면 로드 (빌드 후에 실행)
          if (provider.exitBusRoutes.isEmpty && provider.exitFacilities.isEmpty && !provider.isLoadingExitInfo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              provider.loadExitInfo();
            });
          }

          // 로딩 상태
          if (provider.isLoadingExitInfo) {
            return const Center(
              child: SpinKitWave(
                color: AppColors.primary,
                size: 50.0,
              ),
            );
          }

          // 에러 상태
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    provider.errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadExitInfo();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 출구 정보 표시
          print('busRoutesByExit: ${provider.busRoutesByExit}');
          print('facilitiesByExit: ${provider.facilitiesByExit}');
          print('exitBusRoutes length: ${provider.exitBusRoutes.length}');
          print('exitFacilities length: ${provider.exitFacilities.length}');
          
          return ExitInfoCard(
            busRoutesByExit: provider.busRoutesByExit,
            facilitiesByExit: provider.facilitiesByExit,
          );
        },
      ),
    );
  }

  void _loadScheduleData() {
    final provider = context.read<SubwayProvider>();
    final dailyTypeCode = provider.getCurrentDailyTypeCode();
    
    provider.loadSchedules(
      dailyTypeCode: dailyTypeCode,
      upDownTypeCode: ApiConstants.upDirection, // 상행 기준으로 로드
    );
  }
}
