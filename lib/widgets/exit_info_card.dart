import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/subway_station.dart';

/// 출구 정보를 표시하는 카드 위젯
class ExitInfoCard extends StatelessWidget {
  final Map<String, List<SubwayExitBusRoute>> busRoutesByExit;
  final Map<String, List<SubwayExitFacility>> facilitiesByExit;

  const ExitInfoCard({
    super.key,
    required this.busRoutesByExit,
    required this.facilitiesByExit,
  });

  @override
  Widget build(BuildContext context) {
    // 디버깅 정보
    print('ExitInfoCard build:');
    print('busRoutesByExit keys: ${busRoutesByExit.keys.toList()}');
    print('facilitiesByExit keys: ${facilitiesByExit.keys.toList()}');
    print('busRoutesByExit: $busRoutesByExit');
    print('facilitiesByExit: $facilitiesByExit');
    
    // 모든 출구 번호 수집
    final allExitNumbers = <String>{};
    allExitNumbers.addAll(busRoutesByExit.keys);
    allExitNumbers.addAll(facilitiesByExit.keys);
    
    // 출구 번호 정렬
    final sortedExitNumbers = allExitNumbers.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a) ?? 0;
        final bNum = int.tryParse(b) ?? 0;
        return aNum.compareTo(bNum);
      });

    if (sortedExitNumbers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '출구 정보가 없습니다',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sortedExitNumbers.length,
      itemBuilder: (context, index) {
        final exitNo = sortedExitNumbers[index];
        final busRoutes = busRoutesByExit[exitNo] ?? [];
        final facilities = facilitiesByExit[exitNo] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 출구 번호 헤더
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Center(
                        child: Text(
                          exitNo.isNotEmpty ? exitNo : '?',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${exitNo.isNotEmpty ? exitNo : '?'}번 출구',
                      style: AppTextStyles.heading3,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // 버스 노선 정보
                if (busRoutes.where((route) => route.busRouteNm.isNotEmpty).isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '버스 노선',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: busRoutes.where((route) => route.busRouteNm.isNotEmpty).map((route) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          route.busRouteNm,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                // 주변 시설 정보
                if (facilities.where((facility) => facility.cfFacilityNm.isNotEmpty).isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '주변 시설',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...facilities.where((facility) => facility.cfFacilityNm.isNotEmpty).map((facility) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(
                              top: 8,
                              right: AppSpacing.sm,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              facility.cfFacilityNm,
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                
                // 정보가 없는 경우
                if (busRoutes.where((route) => route.busRouteNm.isNotEmpty).isEmpty && 
                    facilities.where((facility) => facility.cfFacilityNm.isNotEmpty).isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Text(
                      '이 출구에 대한 상세 정보가 없습니다',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
