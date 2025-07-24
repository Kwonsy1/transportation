import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/station_group.dart';
import '../providers/subway_provider.dart';
import '../utils/app_utils.dart';

/// 역 그룹을 표시하는 카드 위젯
class StationGroupCard extends StatelessWidget {
  final StationGroup stationGroup;
  final VoidCallback onTap;
  final bool showFavoriteButton;

  const StationGroupCard({
    super.key,
    required this.stationGroup,
    required this.onTap,
    this.showFavoriteButton = false,
  });


  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 역명
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stationGroup.cleanStationName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stationGroup.availableLines.length}개 호선',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 즐겨찾기 버튼 (옵션)
                  if (showFavoriteButton)
                    Consumer<SubwayProvider>(
                      builder: (context, provider, child) {
                        final isFavorite = provider.isFavoriteStationGroup(
                          stationGroup,
                        );
                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite
                                ? Colors.orange
                                : AppColors.textSecondary,
                          ),
                          onPressed: () async {
                            if (isFavorite) {
                              await provider.removeFavoriteStationGroup(
                                stationGroup,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              await provider.addFavoriteStationGroup(
                                stationGroup,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${stationGroup.cleanStationName}역을 즐겨찾기에 추가했습니다',
                                  ),
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

              const SizedBox(height: AppSpacing.sm),

              // 호선 태그들
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: stationGroup.stations.map((station) {
                  final lineNumber = station.effectiveLineNumber;
                  final lineColor = SubwayUtils.getLineColor(lineNumber);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: lineColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              lineNumber.length > 3 ? lineNumber.substring(0, 2) : lineNumber,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: lineNumber.length > 2 ? 6 : 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          station.subwayRouteName
                              .replaceAll('서울 ', '')
                              .replaceAll('호선', ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
