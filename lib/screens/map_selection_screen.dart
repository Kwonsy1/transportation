import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'map_screen.dart';
import 'enhanced_map_screen.dart';
import 'stable_map_screen.dart';
import 'debug_console_screen.dart';

/// 지도 선택 화면 - 여러 지도 옵션 제공
class MapSelectionScreen extends StatelessWidget {
  const MapSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ 지하철 지도 선택'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지도 버전을 선택하세요',
                  style: AppTextStyles.heading1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '각 지도는 서로 다른 특징과 안정성을 제공합니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 수정된 지도 (권장)
                _buildMapOption(
                  context,
                  title: '수정된 지도',
                  subtitle: '🔧 JavaScript 오류 수정 버전',
                  description:
                      '• 안정된 오류 처리\n• 향상된 로깅 시스템\n• 데이터 검증 강화\n• 권장 사용',
                  icon: Icons.verified,
                  iconColor: Colors.green,
                  isRecommended: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 향상된 지도
                _buildMapOption(
                  context,
                  title: '향상된 지도',
                  subtitle: '✨ 고급 UI/UX 버전',
                  description:
                      '• 아름다운 애니메이션\n• 인터랙티브 마커\n• 커스텀 정보창\n• 시각적 효과 강화',
                  icon: Icons.auto_awesome,
                  iconColor: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnhancedMapScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 안정적인 지도
                _buildMapOption(
                  context,
                  title: '안정적인 지도',
                  subtitle: '🛡️ 디버깅 강화 버전',
                  description: '• 상세한 로그 출력\n• 네트워크 모니터링\n• 폴백 메커니즘\n• 개발자 도구',
                  icon: Icons.bug_report,
                  iconColor: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StableMapScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 개발자 도구 섹션
                Text(
                  '개발자 도구',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 디버그 콘솔
                _buildMapOption(
                  context,
                  title: '디버그 콘솔',
                  subtitle: '🐛 실시간 로그 모니터링',
                  description:
                      '• JavaScript 오류 추적\n• 실시간 로그 출력\n• 로그 필터링 및 검색\n• 로그 내보내기',
                  icon: Icons.terminal,
                  iconColor: Colors.grey.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugConsoleScreen(),
                    ),
                  ),
                ),

                const Spacer(),

                // 하단 정보
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '문제 해결 팁',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '지도가 로딩되지 않으면 "수정된 지도"를 사용해보세요.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: isRecommended
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            gradient: isRecommended
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade50, Colors.white],
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '권장',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
