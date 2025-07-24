import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/seoul_subway_provider.dart';
import '../models/seoul_subway_station.dart';
import '../utils/app_utils.dart';

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

  /// 좌표가 없는 역 목록을 보여주는 다이얼로그
  void _showMissingCoordinatesDialog(
    BuildContext context,
    SeoulSubwayProvider provider,
  ) {
    // 좌표가 없는 역들 필터링
    final missingStations = provider.allStations
        .where((station) => station.latitude == 0.0 || station.longitude == 0.0)
        .toList();

    // 노선별로 그룹화
    final Map<String, List<SeoulSubwayStation>> stationsByLine = {};
    for (final station in missingStations) {
      if (!stationsByLine.containsKey(station.lineName)) {
        stationsByLine[station.lineName] = [];
      }
      stationsByLine[station.lineName]!.add(station);
    }

    // 각 노선별로 정렬
    stationsByLine.forEach((lineName, stations) {
      stations.sort((a, b) => a.stationName.compareTo(b.stationName));
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '좌표가 없는 역 목록',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '총 ${missingStations.length}개 역 (${stationsByLine.length}개 노선)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.md),

                // 통계 정보
                if (missingStations.isNotEmpty) ...[
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '좌표 정보 부족',
                                  style: AppTextStyles.bodyLarge,
                                ),
                                Text(
                                  '전체 ${provider.allStations.length}개 역 중 ${missingStations.length}개 역의 좌표가 누락되었습니다.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 목록
                Expanded(
                  child: missingStations.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                '모든 역에 좌표가 설정되어 있습니다!',
                                style: AppTextStyles.heading3,
                              ),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                '지도에서 모든 역을 표시할 수 있습니다.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: stationsByLine.length,
                          itemBuilder: (context, index) {
                            final lineName = stationsByLine.keys.elementAt(index);
                            final stations = stationsByLine[lineName]!;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: SubwayUtils.getLineColor(lineName),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      SubwayUtils.getLineShortName(lineName),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  lineName,
                                  style: AppTextStyles.bodyLarge,
                                ),
                                subtitle: Text(
                                  '${stations.length}개 역',
                                  style: AppTextStyles.bodySmall,
                                ),
                                children: stations.map((station) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.location_off,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    title: Text(
                                      station.stationName,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    subtitle: Text(
                                      'ID: ${station.stationCode}',
                                      style: AppTextStyles.caption,
                                    ),
                                    trailing: Text(
                                      '(${station.latitude}, ${station.longitude})',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),

                // 하단 액션 버튼
                if (missingStations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            provider.updateMissingCoordinatesOnly();
                          },
                          icon: const Icon(Icons.update),
                          label: const Text('좌표 업데이트 시작'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                        ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => _showMissingCoordinatesDialog(context, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('좌표 없는 역 목록 보기'),
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
                              backgroundColor: SubwayUtils.getLineColor(station.lineName),
                              child: Text(
                                SubwayUtils.getLineShortName(station.lineName),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(station.stationName),
                            subtitle: Text(
                              '${station.lineName} • ${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
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
