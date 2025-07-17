import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/favorites_storage_service.dart';
import '../providers/subway_provider.dart';
import '../constants/app_constants.dart';

/// 즐겨찾기 디버깅 화면
class FavoritesDebugScreen extends StatefulWidget {
  const FavoritesDebugScreen({super.key});

  @override
  State<FavoritesDebugScreen> createState() => _FavoritesDebugScreenState();
}

class _FavoritesDebugScreenState extends State<FavoritesDebugScreen> {
  Map<String, dynamic> _storageInfo = {};
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    final info = await FavoritesStorageService.getStorageInfo();
    final logs = <String>[];
    
    try {
      final favorites = await FavoritesStorageService.loadFavoriteStationGroups();
      logs.add('로드된 즐겨찾기 개수: ${favorites.length}');
      for (int i = 0; i < favorites.length; i++) {
        final group = favorites[i];
        logs.add('즐겨찾기 $i: ${group.stationName} (${group.stations.length}개 노선)');
      }
    } catch (e) {
      logs.add('즐겨찾기 로드 실패: $e');
    }
    
    setState(() {
      _storageInfo = info;
      _debugLogs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기 디버그'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 저장소 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '저장소 정보',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('즐겨찾기 데이터 존재: ${_storageInfo['has_favorites'] ?? false}'),
                    Text('기존 데이터 존재: ${_storageInfo['has_legacy_favorites'] ?? false}'),
                    Text('즐겨찾기 데이터 크기: ${_storageInfo['favorites_size'] ?? 0} bytes'),
                    Text('기존 데이터 크기: ${_storageInfo['legacy_size'] ?? 0} bytes'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // 디버그 로그
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '디버그 로그',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._debugLogs.map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(log, style: AppTextStyles.bodySmall),
                    )),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // 현재 Provider 상태
            Consumer<SubwayProvider>(
              builder: (context, provider, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Provider 상태',
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Provider 즐겨찾기 개수: ${provider.favoriteStationGroups.length}'),
                        ...provider.favoriteStationGroups.map((group) => 
                          Text('  - ${group.stationName} (${group.stations.length}개 노선)', 
                               style: AppTextStyles.bodySmall)
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // 테스트 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await FavoritesStorageService.resetStorage();
                      await _refreshInfo();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('저장소 초기화 완료')),
                      );
                    },
                    child: const Text('저장소 초기화'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await context.read<SubwayProvider>().loadFavoritesFromLocal();
                      await _refreshInfo();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('즐겨찾기 다시 로드 완료')),
                      );
                    },
                    child: const Text('다시 로드'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}