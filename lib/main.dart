import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'constants/app_constants.dart';
import 'constants/api_constants.dart';
import 'providers/subway_provider.dart';
import 'providers/location_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 네이버 맵 SDK 초기화
  await _initializeNaverMap();
  
  runApp(const TransportationApp());
}

/// 네이버 맵 SDK 초기화 (새로운 1.4.0 API)
Future<void> _initializeNaverMap() async {
  try {
    await FlutterNaverMap().init(
      clientId: ApiConstants.naverMapClientId,
      onAuthFailed: (ex) => switch (ex) {
        NQuotaExceededException(:final message) => 
          print('네이버맵 사용량 초과: $message'),
        NUnauthorizedClientException() => 
          print('네이버맵 인증되지 않은 클라이언트'),
        NClientUnspecifiedException() => 
          print('네이버맵 클라이언트 미지정'),
        NAnotherAuthFailedException() => 
          print('네이버맵 기타 인증 실패'),
      },
    );
    print('네이버 맵 SDK 1.4.0 초기화 성공');
  } catch (e) {
    print('네이버 맵 SDK 초기화 오류: $e');
    // 오류 발생 시 대체 맵 서비스 사용 가능
  }
}

/// 앱 시작 시 전역 위치 초기화
Future<void> _initializeLocation(LocationProvider locationProvider) async {
  try {
    print('전역 위치 초기화 시작');
    
    // 위치 서비스 상태 초기화
    await locationProvider.initializeLocationStatus();
    
    // 위치 권한이 있으면 현재 위치 가져오기
    if (locationProvider.hasLocationPermission) {
      await locationProvider.getCurrentLocation();
      print('전역 위치 초기화 완료: ${locationProvider.currentPosition}');
      
      // 주변 역 미리 로드
      if (locationProvider.currentPosition != null) {
        await locationProvider.loadNearbyStations();
        print('주변 역 로드 완료: ${locationProvider.nearbyStations.length}개');
      }
    } else {
      print('위치 권한 없음 - 나중에 요청 할 예정');
    }
  } catch (e) {
    print('전역 위치 초기화 오류: $e');
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
            final locationProvider = LocationProvider();
            // 앱 시작 시 위치 초기화
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeLocation(locationProvider);
            });
            return locationProvider;
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
