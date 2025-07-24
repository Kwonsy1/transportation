import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/subway_station.dart';
import '../providers/subway_provider.dart';
import '../providers/location_provider.dart';
import '../utils/app_utils.dart';

/// 지하철역 정보를 표시하는 카드 위젯 (국토교통부 API 기준)
class StationCard extends StatelessWidget {
  final SubwayStation station;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool showDistance;

  const StationCard({
    super.key,
    required this.station,
    this.onTap,
    this.showFavoriteButton = false,
    this.showDistance = false,
  });


  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // 호선 표시
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SubwayUtils.getLineColor(station.effectiveLineNumber),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    station.effectiveLineNumber.length > 3 
                        ? station.effectiveLineNumber.substring(0, 2) 
                        : station.effectiveLineNumber,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: station.effectiveLineNumber.length > 2 ? 10 : 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              
              // 역 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.subwayStationName,
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      station.subwayRouteName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: SubwayUtils.getLineColor(station.effectiveLineNumber),
                      ),
                    ),
                    
                    // 역 ID 표시 (디버그용, 옵션)
                    if (station.subwayStationId.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'ID: ${station.subwayStationId}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    
                    // 거리 정보 (옵션)
                    if (showDistance) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Consumer<LocationProvider>(
                        builder: (context, locationProvider, child) {
                          final distance = locationProvider.calculateDistanceToStation(station);
                          if (distance != null) {
                            return Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  locationProvider.formatDistance(distance),
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              // 즐겨찾기 버튼 (옵션)
              if (showFavoriteButton)
                Consumer<SubwayProvider>(
                  builder: (context, provider, child) {
                    final isFavorite = provider.isFavoriteStation(station);
                    return IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.error : AppColors.textSecondary,
                      ),
                      onPressed: () {
                        if (isFavorite) {
                          provider.removeFavoriteStation(station);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${station.subwayStationName}역을 즐겨찾기에서 제거했습니다'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          provider.addFavoriteStation(station);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${station.subwayStationName}역을 즐겨찾기에 추가했습니다'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
