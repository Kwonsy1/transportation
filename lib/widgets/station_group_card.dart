import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/station_group.dart';
import '../providers/subway_provider.dart';

/// 역 그룹 카드 위젯
class StationGroupCard extends StatelessWidget {
  final StationGroup stationGroup;
  final VoidCallback? onTap;
  final bool showFavoriteButton;

  const StationGroupCard({
    super.key,
    required this.stationGroup,
    this.onTap,
    this.showFavoriteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Consumer<SubwayProvider>(
        builder: (context, provider, child) {
          final isFavorite = provider.isFavoriteStationGroup(stationGroup);
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                '${stationGroup.stations.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              stationGroup.cleanStationName,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              stationGroup.lineNamesText,
              style: AppTextStyles.bodySmall,
            ),
            trailing: showFavoriteButton
                ? IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? AppColors.error : null,
                    ),
                    onPressed: () async {
                      if (isFavorite) {
                        await provider.removeFavoriteStationGroup(stationGroup);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        await provider.addFavoriteStationGroup(stationGroup);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${stationGroup.cleanStationName}역을 즐겨찾기에 추가했습니다'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  )
                : const Icon(Icons.chevron_right),
            onTap: onTap,
          );
        },
      ),
    );
  }
}
