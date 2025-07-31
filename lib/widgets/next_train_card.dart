import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/next_train_info.dart';
import '../utils/app_utils.dart';

/// 다음 열차 정보를 표시하는 카드 위젯
class NextTrainCard extends StatelessWidget {
  final NextTrainInfo nextTrain;

  const NextTrainCard({
    super.key,
    required this.nextTrain,
  });


  /// 도착 상태에 따른 색상 반환
  Color _getArrivalStatusColor() {
    if (nextTrain.minutesUntilArrival <= 0) {
      return AppColors.error;
    } else if (nextTrain.minutesUntilArrival <= 3) {
      return Colors.orange;
    } else {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 호선과 방향 정보
            Row(
              children: [
                // 호선 표시
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SubwayUtils.getLineColor(nextTrain.lineNumber),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nextTrain.lineNumber,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                
                // 방향 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${nextTrain.destination} 방면',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        nextTrain.direction,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 열차 종류
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    nextTrain.trainType,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // 도착 정보
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 도착 시간
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: _getArrivalStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: _getArrivalStatusColor().withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        nextTrain.arrivalTime,
                        style: AppTextStyles.heading3.copyWith(
                          color: _getArrivalStatusColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (nextTrain.formattedTimeUntilArrival.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          nextTrain.formattedTimeUntilArrival,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getArrivalStatusColor(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: AppSpacing.md),
                
                // 상세 메시지
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextTrain.arrivalStatusMessage,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '출발: ${nextTrain.departureTime}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 추가 정보 (필요시)
            if (nextTrain.minutesUntilArrival > 30) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '시간표 기준 정보입니다',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
