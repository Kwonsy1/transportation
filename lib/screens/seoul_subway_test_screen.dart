import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/seoul_subway_provider.dart';

/// 서울 지하철 API 테스트 화면
class SeoulSubwayTestScreen extends StatefulWidget {
  const SeoulSubwayTestScreen({super.key});

  @override
  State<SeoulSubwayTestScreen> createState() => _SeoulSubwayTestScreenState();
}

class _SeoulSubwayTestScreenState extends State<SeoulSubwayTestScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서울 지하철 API 테스트')),
      body: Consumer<SeoulSubwayProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 데이터 상태 정보
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('데이터 상태', style: AppTextStyles.heading3),
                      const SizedBox(height: AppSpacing.md),
                      Text('전체 역 수: ${provider.allStations.length}개'),
                      Text('검색 결과: ${provider.searchResults.length}개'),
                      Text('주변 역: ${provider.nearbyStations.length}개'),
                      const SizedBox(height: AppSpacing.sm),

                      // 좌표 통계 정보
                      const Text('좌표 정보', style: AppTextStyles.bodyLarge),
                      const SizedBox(height: AppSpacing.sm),
                      if (provider.allStations.isNotEmpty) ...[
                        () {
                          final stats = provider.getCoordinateStatistics();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('좌표 있음: ${stats['hasCoordinates']}개'),
                              Text('좌표 없음: ${stats['missingCoordinates']}개'),
                              Text(
                                '완성도: ${((stats['hasCoordinates']! / stats['total']!) * 100).toStringAsFixed(1)}%',
                              ),
                            ],
                          );
                        }(),
                      ],

                      const SizedBox(height: AppSpacing.sm),
                      if (provider.isLoading)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('로딩 중...'),
                          ],
                        ),
                      if (provider.errorMessage != null)
                        Text(
                          '에러: ${provider.errorMessage}',
                          style: const TextStyle(color: AppColors.error),
                        ),

                      // 좌표 업데이트 상태
                      if (provider.isUpdatingCoordinates) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          '좌표 업데이트 중...',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: provider.updateProgressPercent / 100,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '진행률: ${provider.coordinateUpdateProgress}/${provider.totalStationsToUpdate}',
                        ),
                        if (provider.currentUpdatingStation != null)
                          Text('현재: ${provider.currentUpdatingStation}'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 검색 테스트
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('역 검색 테스트', style: AppTextStyles.heading3),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '역명을 입력하세요 (예: 강남)',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            provider.searchStations(value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: provider.isLoading
                            ? null
                            : () {
                                if (_searchController.text.isNotEmpty) {
                                  provider.searchStations(
                                    _searchController.text,
                                  );
                                }
                              },
                        child: const Text('검색'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 테스트 버튼들
              Card(
                // child: Padding(padding: EdgeInsets.all(AppSpacing.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('테스트 액션', style: AppTextStyles.heading3),
                    const SizedBox(height: AppSpacing.md),

                    // 기본 액션들
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.initialize(),
                          child: const Text('데이터 초기화'),
                        ),
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.refresh(),
                          child: const Text('스마트 새로고침'),
                        ),
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.searchStations('강남'),
                          child: const Text('강남역 검색'),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 좌표 업데이트 액션들
                    const Text('좌표 업데이트 (개발용)', style: AppTextStyles.bodyLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '⚠️ 좌표 업데이트는 시간이 오래 걸립니다.\n네트워크 상태가 좋을 때 사용하세요.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ElevatedButton(
                          onPressed:
                              (provider.isLoading ||
                                  provider.isUpdatingCoordinates)
                              ? null
                              : () => provider.updateMissingCoordinatesOnly(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('누락된 좌표만 업데이트'),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 캐시 관리
                    const Text('캐시 관리', style: AppTextStyles.bodyLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.clearCache(
                                  preserveCoordinates: true,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('캐시 초기화 (좌표 보존)'),
                        ),
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => provider.clearCache(
                                  preserveCoordinates: false,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('전체 캐시 삭제'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              if (provider.searchResults.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '검색 결과 (${provider.searchResults.length}개)',
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...provider.searchResults.take(10).map((station) {
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              child: Text(
                                station.lineName,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            title: Text(station.stationName),
                            subtitle: Text(
                              '${station.lineName}호선 • ${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
                              style: AppTextStyles.caption,
                            ),
                            trailing:
                                station.latitude != 0.0 &&
                                    station.longitude != 0.0
                                ? const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 16,
                                  )
                                : const Icon(
                                    Icons.location_off,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                          );
                        }),
                        if (provider.searchResults.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              '... 외 ${provider.searchResults.length - 10}개 더',
                              style: AppTextStyles.caption,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
