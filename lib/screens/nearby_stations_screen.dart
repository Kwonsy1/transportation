import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../models/subway_station.dart';
import '../widgets/station_card.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';

/// 주변 지하철역 화면
class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadData();
    });
  }

  Future<void> _checkAndLoadData() async {
    final provider = context.read<LocationProvider>();
    
    print('주변역 화면 - 현재 상태 확인');
    print('위치 권한: ${provider.hasLocationPermission}');
    print('현재 위치: ${provider.currentPosition}');
    print('주변 역 개수: ${provider.nearbyStations.length}');
    
    // 이미 주변 역 데이터가 있으면 추가 로드 생략
    if (provider.nearbyStations.isNotEmpty) {
      print('이미 주변 역 데이터가 있음 - 새로고침 생략');
      return;
    }
    
    // 주변 역 데이터가 없으면 로드
    await _loadNearbyStations();
  }

  Future<void> _loadNearbyStations() async {
    final provider = context.read<LocationProvider>();
    
    // 위치 권한 확인
    if (!provider.hasLocationPermission) {
      final granted = await provider.requestLocationPermission();
      if (!granted) return;
    }
    
    // 현재 위치 가져오기 및 주변 역 검색
    await provider.getCurrentLocation();
    if (provider.currentPosition != null) {
      await provider.loadNearbyStations();
    }
  }

  Future<void> _refreshData() async {
    await context.read<LocationProvider>().refreshLocation();
  }

  void _onStationTap(SubwayStation station) {
    // 선택한 역에 해당하는 StationGroup을 생성
    final stationGroup = StationGroup(
      stationName: station.stationName,
      stations: [station],
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiLineStationDetailScreen(
          stationGroup: stationGroup,
          initialStation: station,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주변 지하철역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Consumer<LocationProvider>(
        builder: (context, provider, child) {
          // 위치 권한이 없는 경우
          if (!provider.hasLocationPermission) {
            return _buildPermissionRequestWidget(provider);
          }

          // 로딩 상태
          if (provider.isLoadingLocation || provider.isLoadingNearbyStations) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitWave(
                    color: AppColors.primary,
                    size: 50.0,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '주변 지하철역을 검색하고 있습니다...',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
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
                      _loadNearbyStations();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 주변 역이 없는 경우
          if (provider.nearbyStations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '주변에 지하철역이 없습니다',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _refreshData,
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }

          // 주변 역 목록
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: Column(
              children: [
                // 현재 위치 정보
                if (provider.currentPosition != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: AppColors.primary.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '현재 위치',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${provider.currentPosition!.latitude.toStringAsFixed(6)}, ${provider.currentPosition!.longitude.toStringAsFixed(6)}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${provider.nearbyStations.length}개 역 발견',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // 역 목록
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: provider.nearbyStations.length,
                    itemBuilder: (context, index) {
                      final station = provider.nearbyStations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: StationCard(
                          station: station,
                          onTap: () => _onStationTap(station),
                          showFavoriteButton: true,
                          showDistance: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionRequestWidget(LocationProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_disabled,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '위치 권한이 필요합니다',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '주변 지하철역을 찾기 위해서는 위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () async {
                final granted = await provider.requestLocationPermission();
                if (granted) {
                  _loadNearbyStations();
                }
              },
              child: const Text('위치 권한 허용'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: provider.openAppSettings,
              child: const Text('설정으로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
