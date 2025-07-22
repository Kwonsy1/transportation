import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../providers/subway_provider.dart';
import '../models/station_group.dart';
import '../widgets/station_group_card.dart';
import 'multi_line_station_detail_screen.dart';

/// 역 검색 화면
class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({super.key});

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      context.read<SubwayProvider>().searchStations(query.trim());
    } else {
      context.read<SubwayProvider>().clearSearchResults();
    }
  }

  void _onStationGroupTap(StationGroup stationGroup) {
    // 키보드 숨기기
    _searchFocusNode.unfocus();

    // 항상 통합 상세 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MultiLineStationDetailScreen(stationGroup: stationGroup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지하철 역 검색')),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '역 이름을 입력하세요 (예: 강남)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SubwayProvider>().clearSearchResults();
                        },
                      )
                    : null,
              ),
              onChanged: _performSearch,
              onSubmitted: _performSearch,
            ),
          ),

          // 검색 결과
          Expanded(
            child: Consumer<SubwayProvider>(
              builder: (context, provider, child) {
                // 로딩 상태
                if (provider.isLoadingSearch) {
                  return const Center(
                    child: SpinKitWave(color: AppColors.primary, size: 50.0),
                  );
                }

                // 에러 상태
                if (provider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          provider.errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () {
                            provider.clearError();
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                // 검색 결과 없음
                if (provider.groupedSearchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isEmpty
                              ? Icons.search_off
                              : Icons.train_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _searchController.text.isEmpty
                              ? '검색할 역 이름을 입력해주세요'
                              : '검색 결과가 없습니다',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 그룹화된 검색 결과 전용
                return _buildGroupedResults(provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 그룹화된 검색 결과 빌드
  Widget _buildGroupedResults(SubwayProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: provider.groupedSearchResults.length,
      itemBuilder: (context, index) {
        final stationGroup = provider.groupedSearchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: StationGroupCard(
            stationGroup: stationGroup,
            onTap: () => _onStationGroupTap(stationGroup),
            showFavoriteButton: true,
          ),
        );
      },
    );
  }
}
