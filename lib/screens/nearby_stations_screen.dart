import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../models/subway_station.dart';
import '../widgets/station_card.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';
import '../utils/ksy_log.dart';

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
      _loadNearbyStations();
    });
  }

  Future<void> _loadNearbyStations() async {
    final provider = context.read<LocationProvider>();
    await provider.loadNearbyStations();
  }

  Future<void> _refreshData() async {
    await context.read<LocationProvider>().refreshLocation();
  }

  void _onStationTap(SubwayStation station) {
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Consumer<LocationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingLocation || provider.isLoadingNearbyStations) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitWave(color: AppColors.primary, size: 50.0),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '주변 지하철역을 검색하고 있습니다...',
                  ),
                ],
              ),
            );
          }

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

          if (provider.nearbyStations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('주변에 지하철역이 없습니다'),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _refreshData,
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
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
                    distance: station.dist,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
