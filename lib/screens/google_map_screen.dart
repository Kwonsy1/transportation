import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Google Map 화면 (대체용)
class GoogleMapScreen extends StatelessWidget {
  const GoogleMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map (대체용)'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Google Map 기능',
              style: AppTextStyles.heading2,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '현재 네이버 지도를 사용하고 있습니다.\n이 화면은 대체용으로 준비된 화면입니다.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            Card(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      '사용 가능한 지도',
                      style: AppTextStyles.heading3,
                    ),
                    SizedBox(height: AppSpacing.md),
                    ListTile(
                      leading: Icon(Icons.map, color: AppColors.primary),
                      title: Text('네이버 네이티브 지도'),
                      subtitle: Text('서울 지하철 정보와 함께 제공'),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                    ),
                    ListTile(
                      leading: Icon(Icons.web, color: AppColors.textSecondary),
                      title: Text('네이버 웹뷰 지도'),
                      subtitle: Text('기본 지하철 정보와 함께 제공'),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                    ),
                    ListTile(
                      leading: Icon(Icons.map_outlined, color: AppColors.textSecondary),
                      title: Text('Google Maps'),
                      subtitle: Text('향후 지원 예정'),
                      trailing: Icon(Icons.schedule, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
