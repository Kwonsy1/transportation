import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'constants/app_constants.dart';
import 'constants/api_constants.dart';
import 'providers/subway_provider.dart';
import 'providers/location_provider.dart';
import 'providers/seoul_subway_provider.dart';
import 'services/hive_subway_service.dart';
import 'services/favorites_storage_service.dart';
import 'screens/home_screen.dart';
import 'utils/ksy_log.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KSY 로그 시스템 초기화
  KSYLog.initialize();
  KSYLog.lifecycle('App starting');

  // Hive 초기화
  await _initializeHive();

  // 네이버 맵 SDK 초기화
  await _initializeNaverMap();

  runApp(const TransportationApp());
}

/// Hive 데이터베이스 초기화
Future<void> _initializeHive() async {
  try {
    // 지하철 정보 Hive 초기화
    await HiveSubwayService.instance.initialize();

    // 즐겨찾기 Hive 초기화
    await FavoritesStorageService.initialize();

    KSYLog.database('Initialize', 'Hive', null);
  } catch (e) {
    KSYLog.error('Hive 초기화 오류', e);
    // Hive 초기화 실패 시 SharedPreferences 사용
  }
}

/// 네이버 맵 SDK 초기화 (새로운 1.4.0 API)
Future<void> _initializeNaverMap() async {
  try {
    await FlutterNaverMap().init(
      clientId: ApiConstants.naverMapClientId,
      onAuthFailed: (ex) => switch (ex) {
        NQuotaExceededException(:final message) => KSYLog.warning(
        '네이버맵 사용량 초과: $message',
        ),
        NUnauthorizedClientException() => KSYLog.error('네이버맵 인증되지 않은 클라이언트'),
        NClientUnspecifiedException() => KSYLog.error('네이버맵 클라이언트 미지정'),
        NAnotherAuthFailedException() => KSYLog.error('네이버맵 기타 인증 실패'),
      },
    );
    KSYLog.info('네이버 맵 SDK 1.4.0 초기화 성공');
  } catch (e) {
    KSYLog.error('네이버 맵 SDK 초기화 오류', e);
    // 오류 발생 시 대체 맵 서비스 사용 가능
  }
}

class TransportationApp extends StatelessWidget {
  const TransportationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final subwayProvider = SubwayProvider();
            // 앱 시작 시 즐겨찾기 로드
            WidgetsBinding.instance.addPostFrameCallback((_) {
              subwayProvider.loadFavoritesFromLocal();
            });
            return subwayProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            return LocationProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final seoulSubwayProvider = SeoulSubwayProvider();
            // 앱 시작 시 서울 지하철 데이터 초기화
            WidgetsBinding.instance.addPostFrameCallback((_) {
              seoulSubwayProvider.initialize();
            });
            return seoulSubwayProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: '지하철 정보 앱',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'NotoSans',

          // AppBar 테마
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),

          // Card 테마
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),

          // ElevatedButton 테마
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
          ),

          // TextButton 테마
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),

          // InputDecoration 테마
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),

          // BottomNavigationBar 테마
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),

          // ListTile 테마
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
