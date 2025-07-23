import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/subway_provider.dart';
import '../widgets/station_group_card.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';

/// 즐겨찾기 화면
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _onStationGroupTap(BuildContext context, StationGroup stationGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MultiLineStationDetailScreen(stationGroup: stationGroup),
      ),
    );
  }

  void _showRemoveConfirmDialog(
    BuildContext context,
    StationGroup stationGroup,
    SubwayProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('즐겨찾기 제거'),
          content: Text('${stationGroup.cleanStationName}역을 즐겨찾기에서 제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await provider.removeFavoriteStationGroup(stationGroup);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('제거', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기'),
        actions: [
          Consumer<SubwayProvider>(
            builder: (context, provider, child) {
              if (provider.favoriteStationGroups.isNotEmpty) {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear_all') {
                      _showClearAllConfirmDialog(context, provider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('모두 제거'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<SubwayProvider>(
        builder: (context, provider, child) {
          // 즐겨찾기가 비어있는 경우
          if (provider.favoriteStationGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('즐겨찾기한 역이 없습니다', style: AppTextStyles.heading3),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '자주 이용하는 지하철역을 즐겨찾기에 추가해보세요',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // 즐겨찾기 목록
          return Column(
            children: [
              // 상단 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.primary.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '즐겨찾기 ${provider.favoriteStationGroups.length}개',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '길게 누르면 제거됩니다',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // 즐겨찾기 역 그룹 목록
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: provider.favoriteStationGroups.length,
                  itemBuilder: (context, index) {
                    final stationGroup = provider.favoriteStationGroups[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Dismissible(
                        key: Key(stationGroup.stationName),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white, size: 24),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                '제거',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('즐겨찾기 제거'),
                                content: Text(
                                  '${stationGroup.cleanStationName}역을 즐겨찾기에서 제거하시겠습니까?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      '제거',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          await provider.removeFavoriteStationGroup(
                            stationGroup,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${stationGroup.cleanStationName}역을 즐겨찾기에서 제거했습니다',
                              ),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: '취소',
                                onPressed: () async {
                                  await provider.addFavoriteStationGroup(
                                    stationGroup,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        child: InkWell(
                          onTap: () =>
                              _onStationGroupTap(context, stationGroup),
                          onLongPress: () => _showRemoveConfirmDialog(
                            context,
                            stationGroup,
                            provider,
                          ),
                          child: StationGroupCard(
                            stationGroup: stationGroup,
                            onTap: () =>
                                _onStationGroupTap(context, stationGroup),
                            showFavoriteButton: false,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearAllConfirmDialog(
    BuildContext context,
    SubwayProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('모든 즐겨찾기 제거'),
          content: const Text('모든 즐겨찾기 역을 제거하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await provider.clearAllFavorites();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('모든 즐겨찾기를 제거했습니다'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text(
                '모두 제거',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
