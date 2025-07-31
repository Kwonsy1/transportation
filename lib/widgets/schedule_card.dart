import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/subway_schedule.dart';
import '../utils/app_utils.dart';

/// 시간표 정보를 표시하는 카드 위젯 (국토교통부 API 기준)
class ScheduleCard extends StatelessWidget {
  final SubwaySchedule schedule;

  const ScheduleCard({
    super.key,
    required this.schedule,
  });


  @override
  Widget build(BuildContext context) {
    final isUpcoming = schedule.isUpcoming;
    final timeUntilArrival = schedule.timeUntilArrival;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: isUpcoming
              ? Border.all(color: SubwayUtils.getLineColor(schedule.lineNumber).withValues(alpha: 0.3))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // 호선 표시
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SubwayUtils.getLineColor(schedule.lineNumber),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    schedule.lineNumber,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              
              // 시간 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 도착 시간
                        Text(
                          schedule.simpleArrivalTime,
                          style: AppTextStyles.heading3.copyWith(
                            color: isUpcoming 
                                ? SubwayUtils.getLineColor(schedule.lineNumber)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        // 출발 시간 (도착시간과 다른 경우)
                        if (schedule.simpleDepartureTime != schedule.simpleArrivalTime) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '→ ${schedule.simpleDepartureTime}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        
                        // 남은 시간 표시
                        if (timeUntilArrival.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.small),
                            ),
                            child: Text(
                              timeUntilArrival,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    
                    // 종점 정보
                    Text(
                      '${schedule.endSubwayStationNm} 방면',
                      style: AppTextStyles.bodyMedium,
                    ),
                    
                    // 추가 정보
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        // 요일 정보
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(
                            schedule.weekdayKorean,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: AppSpacing.sm),
                        
                        // 방향 정보
                        Text(
                          schedule.directionKorean,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 상태 아이콘
              if (isUpcoming)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: SubwayUtils.getLineColor(schedule.lineNumber).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: SubwayUtils.getLineColor(schedule.lineNumber),
                    size: 20,
                  ),
                )
              else
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
