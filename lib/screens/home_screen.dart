import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import 'station_search_screen.dart';
import 'favorites_screen.dart';
import 'naver_native_map_screen.dart'; // 네이버 네이티브 맵 사용
import 'google_map_screen.dart'; // OpenStreetMap 사용 (대체용)

/// 메인 홈 화면 (하단 네비게이션 포함)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const NaverNativeMapScreen(), // 네이버 네이티브 지도
    const StationSearchScreen(), // 역검색
    const FavoritesScreen(), // 즐겨찾기
  ];

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 위치 권한 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().initializeLocationStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '역검색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: '즐겨찾기',
          ),
        ],
      ),
    );
  }
}
