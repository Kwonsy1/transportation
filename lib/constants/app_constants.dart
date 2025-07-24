import 'package:flutter/material.dart';

/// 앱에서 사용하는 색상 상수들
class AppColors {
  // 지하철 노선별 색상 (서울 1-9호선)
  static const Color line1 = Color(0xFF263c96); // 1호선 - 진한 파랑
  static const Color line2 = Color(0xFF00a650); // 2호선 - 초록
  static const Color line3 = Color(0xFFef7c1c); // 3호선 - 주황
  static const Color line4 = Color(0xFF00a4e3); // 4호선 - 하늘색
  static const Color line5 = Color(0xFF996cac); // 5호선 - 보라
  static const Color line6 = Color(0xFFcd7c2f); // 6호선 - 갈색
  static const Color line7 = Color(0xFF747f00); // 7호선 - 올리브
  static const Color line8 = Color(0xFFe6186c); // 8호선 - 분홍
  static const Color line9 = Color(0xFFbdb092); // 9호선 - 베이지
  
  // 광역철도 노선별 색상
  static const Color gyeonguiJungang = Color(0xFF77C4A3); // 경의중앙선
  static const Color bundang = Color(0xFFFFD320); // 분당선
  static const Color sinbundang = Color(0xFFD31145); // 신분당선
  static const Color gyeongchun = Color(0xFF178C72); // 경춘선
  static const Color suinBundang = Color(0xFFFFD320); // 수인분당선
  static const Color uiSinseol = Color(0xFFB7C452); // 우이신설선
  static const Color seohae = Color(0xFF81A914); // 서해선
  static const Color gimpo = Color(0xFFB69240); // 김포골드라인
  static const Color sillim = Color(0xFF6789CA); // 신림선
  
  // 기본 앱 색상
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF388E3C);
  static const Color accent = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  
  // 텍스트 색상
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Colors.white;
}

/// 앱에서 사용하는 텍스트 스타일
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
}

/// 앱에서 사용하는 패딩, 마진 등의 간격 상수
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 앱에서 사용하는 테두리 반지름 상수
class AppRadius {
  static const double small = 4.0;
  static const double medium = 8.0;
  static const double large = 12.0;
  static const double extraLarge = 16.0;
}
