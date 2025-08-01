import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import '../services/nearby_station_api_service.dart';
import '../models/server_api_response.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';
import '../utils/ksy_log.dart';
import '../utils/app_utils.dart';

/// 네이버 지도 네이티브 화면 (API 연동 마커 로딩)
class NaverNativeMapScreen extends StatefulWidget {
  const NaverNativeMapScreen({super.key});

  @override
  State<NaverNativeMapScreen> createState() => _NaverNativeMapScreenState();
}

class _NaverNativeMapScreenState extends State<NaverNativeMapScreen> {
  NaverMapController? _mapController;
  bool _isLoading = false;
  String? _errorMessage;
  final List<NMarker> _stationMarkers = [];
  NMarker? _currentLocationMarker;

  // 현재 지도 상태
  NCameraPosition? _currentCameraPosition;

  // API 서비스
  final NearbyStationApiService _nearbyApiService = NearbyStationApiService();

  // 디바운스 타이머
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    KSYLog.lifecycle('🗺️ 네이티브 지도 화면 시작 (API 연동)');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    _stationMarkers.clear();
    _currentLocationMarker = null;
    super.dispose();
  }

  /// 지도 준비 완료 콜백
  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    KSYLog.info('🗺️ 네이버 지도 준비 완료');

    final locationProvider = context.read<LocationProvider>();

    // 현재 위치가 있으면 표시
    if (locationProvider.currentPosition != null) {
      final lat = locationProvider.currentPosition!.latitude;
      final lng = locationProvider.currentPosition!.longitude;
      await _addCurrentLocationMarker(lat, lng);

      // 현재 위치로 카메라 이동
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(lat, lng),
        zoom: 15,
      );
      await _mapController!.updateCamera(cameraUpdate);
    }
    // 초기 로딩
    _loadVisibleStations();
  }

  /// 카메라 변경 콜백 (지도 이동 시)
  void _onCameraChange(NCameraUpdateReason reason, bool isAnimated) {
    // 디바운스로 과도한 호출 방지
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadVisibleStations();
      }
    });
  }

  /// 카메라 변경 완료 콜백
  void _onCameraIdle() {
    _debounceTimer?.cancel(); // 기존 타이머 취소
    _loadVisibleStations();
  }

  /// 현재 화면에 보이는 역들 로드 (API 호출)
  Future<void> _loadVisibleStations() async {
    if (_mapController == null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cameraPosition = await _mapController!.getCameraPosition();
      _currentCameraPosition = cameraPosition;

      final center = cameraPosition.target;
      final zoom = cameraPosition.zoom;

      KSYLog.debug('지도 중심: ${center.latitude}, ${center.longitude}, 줌: $zoom');

      // 줌 레벨에 따른 검색 결과 제한 (개수)
      int limit;
      if (zoom >= 16) {
        limit = 30; // 매우 높은 줌: 30개
      } else if (zoom >= 14) {
        limit = 50; // 높은 줌: 50개
      } else if (zoom >= 12) {
        limit = 80; // 중간 줌: 80개
      } else {
        limit = 100; // 낮은 줌: 100개
      }

      // 줌 레벨에 따른 검색 반경 설정 (km)
      int radius;
      if (zoom >= 16) {
        radius = 1; // 매우 높은 줌: 1km 반경
      } else if (zoom >= 14) {
        radius = 5; // 높은 줌: 5km 반경
      } else if (zoom >= 12) {
        radius = 10; // 중간 줌: 10km 반경
      } else {
        radius = 20; // 낮은 줌: 20km 반경
      }

      // API 호출하여 주변 역 정보 가져오기 (새로운 그룹화된 API 사용)
      var groupedResponse = await _nearbyApiService.getNearbyStationsGrouped(
        latitude: center.latitude,
        longitude: center.longitude,
        radius: radius,
        limit: limit,
      );

      KSYLog.info('API로부터 ${groupedResponse.totalCount}개 역 그룹 수신');

      // 역 이름이 null인 경우, details 정보로 복원 시도
      final subwayProvider = context.read<SubwayProvider>();
      final restoredStations = <GroupedNearbyStation>[];

      for (final group in groupedResponse.stations) {
        if (group.stationName == null || group.stationName!.isEmpty) {
          KSYLog.warning('⚠️ 역 이름이 비어있음. 복원을 시도합니다.');
          if (group.details.isNotEmpty &&
              group.details.first.subwayStationId != null) {
            final firstDetail = group.details.first;
            try {
              final stationInfo = await subwayProvider
                  .getStationDetailsBySubwayStationId(
                    subwayStationId: firstDetail.subwayStationId!,
                    stationName: '임시 역명', // 임시 역명 사용
                  );

              if (stationInfo != null) {
                KSYLog.info('✅ 역 이름 복원 성공: ${stationInfo.stationName}');
                // 복원된 정보로 새로운 GroupedNearbyStation 객체 생성
                restoredStations.add(
                  GroupedNearbyStation(
                    stationName: stationInfo.stationName,
                    coordinates: group.coordinates,
                    distanceKm: group.distanceKm,
                    address: group.address,
                    region: group.region,
                    stationCount: group.stationCount,
                    details: group.details,
                  ),
                );
              } else {
                KSYLog.error('❌ 역 이름 복원 실패: ${firstDetail.subwayStationId}');
              }
            } catch (e) {
              KSYLog.error('❌ 역 이름 복원 중 오류 발생', e);
            }
          } else {
            KSYLog.warning('⚠️ 복원에 필요한 정보(subwayStationId)가 없습니다.');
          }
        } else {
          restoredStations.add(group);
        }
      }

      // 그룹화된 결과를 개별 SubwayStation 목록으로 변환
      final stations = <SubwayStation>[];
      for (final group in restoredStations) {
        // 좌표 정보가 없는 그룹은 건너뜀
        if (group.coordinates == null) {
          KSYLog.warning('⚠️ 좌표 정보가 없는 역 그룹: ${group.stationName}');
          continue;
        }

        for (final detail in group.details) {
          stations.add(
            SubwayStation(
              subwayStationId: detail.subwayStationId ?? '',
              subwayStationName: group.stationName ?? '이름 없음', // null일 경우 기본값 제공
              subwayRouteName: detail.lineNumber ?? '미분류',
              lineNumber: detail.lineNumber ?? '미분류',
              latitude: group.coordinates!.latitude,
              longitude: group.coordinates!.longitude,
              dist: group.distanceKm,
            ),
          );
        }
      }

      KSYLog.info('변환된 ${stations.length}개 개별 역 정보');

      // SubwayStation -> SeoulSubwayStation 모델로 변환
      final seoulStations = stations
          .map((s) {
            // API 응답에 호선 정보가 없을 경우 기본값 처리
            final lineName = s.subwayRouteName ?? '미분류';

            // 좌표가 유효한지 확인
            final lat = s.latitude ?? 0.0;
            final lng = s.longitude ?? 0.0;

            KSYLog.debug(
              '역 변환: ${s.subwayStationName}, 호선: $lineName, 좌표: ($lat, $lng), subwayStationId: ${s.subwayStationId}',
            );

            return SeoulSubwayStation(
              stationName: s.subwayStationName,
              lineName: lineName,
              latitude: lat,
              longitude: lng,
              stationCode: s.subwayStationId,
              subwayStationId: s.subwayStationId, // 국토교통부 API용 ID
            );
          })
          .where(
            (station) => station.latitude != 0.0 && station.longitude != 0.0,
          )
          .toList();

      // 마커 업데이트
      await _updateStationMarkers(seoulStations);
    } catch (e) {
      KSYLog.error('❌ 화면 내 역 로드 오류', e);
      if (mounted) {
        setState(() {
          _errorMessage = '주변 역 정보를 불러오는데 실패했습니다.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 역 마커 업데이트
  Future<void> _updateStationMarkers(List<SeoulSubwayStation> stations) async {
    if (_mapController == null || _currentCameraPosition == null) {
      KSYLog.warning('⚠️ 지도 컨트롤러 또는 카메라 위치 없음');
      return;
    }

    try {
      KSYLog.info('🔄 마커 업데이트 시작: ${stations.length}개 역');

      // 기존 역 마커들 제거
      await _clearStationMarkers();

      if (stations.isEmpty) {
        KSYLog.warning('⚠️ 표시할 역이 없음');
        return;
      }

      // 지도 중심점 가져오기
      final center = _currentCameraPosition!.target;
      KSYLog.debug('📍 지도 중심: (${center.latitude}, ${center.longitude})');

      int successCount = 0;
      int failCount = 0;

      // 마커 업데이트
      for (int i = 0; i < stations.length; i++) {
        final station = stations[i];

        try {
          // 마커 생성
          final marker = await _createStationMarker(station, i);

          // 마커 클릭 이벤트
          marker.setOnTapListener((overlay) {
            KSYLog.ui('🔘 마커 클릭: ${station.stationName}');
            _showStationInfo(station);
          });

          // 지도에 추가
          await _mapController!.addOverlay(marker);
          _stationMarkers.add(marker);
          successCount++;

          KSYLog.debug(
            '📍 마커 추가 완료: ${station.stationName} ($successCount/${stations.length})',
          );
        } catch (e) {
          failCount++;
          KSYLog.error(
            '❌ 마커 추가 실패: ${station.stationName} ($failCount번째 실패)',
            e,
          );
          // 개별 마커 실패는 무시하고 계속
        }
      }

      KSYLog.info('✅ 마커 업데이트 완료: 성공 $successCount개, 실패 $failCount개');

      if (successCount == 0) {
        KSYLog.error('❌ 모든 마커 생성 실패');
        if (mounted) {
          setState(() {
            _errorMessage = '지도 마커를 표시할 수 없습니다.';
          });
        }
      }
    } catch (e) {
      KSYLog.error('❌ 마커 업데이트 오류', e);
      if (mounted) {
        setState(() {
          _errorMessage = '지도 마커 업데이트 중 오류가 발생했습니다.';
        });
      }
    }
  }

  /// 역 마커 생성
  Future<NMarker> _createStationMarker(
    SeoulSubwayStation station,
    int index,
  ) async {
    try {
      KSYLog.debug(
        '🎯 마커 생성 시도: ${station.stationName} (${station.lineName}) at (${station.latitude}, ${station.longitude})',
      );

      if (!mounted) {
        KSYLog.warning('⚠️ Widget이 마운트되지 않음: ${station.stationName}');
        throw Exception('Widget is not mounted');
      }

      // 좌표 유효성 검사
      if (station.latitude == 0.0 || station.longitude == 0.0) {
        KSYLog.warning(
          '⚠️ 잘못된 좌표: ${station.stationName} (${station.latitude}, ${station.longitude})',
        );
        throw Exception('Invalid coordinates');
      }

      final lineColor = SubwayUtils.getLineColor(station.lineName);
      final shortName = SubwayUtils.getLineShortName(station.lineName);

      KSYLog.debug(
        '🎨 마커 스타일: 색상=${lineColor.toARGB32().toRadixString(16)}, 텍스트=$shortName',
      );

      final markerIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: lineColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              shortName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        size: const Size(30, 30),
        context: context,
      );

      final marker = NMarker(
        id: 'station_${index}_${station.stationName}',
        position: NLatLng(station.latitude, station.longitude),
        icon: markerIcon,
        anchor: const NPoint(0.5, 0.5),
      );

      KSYLog.debug(
        '✅ 마커 생성 성공: ${station.stationName} (${station.latitude}, ${station.longitude})',
      );
      return marker;
    } catch (e) {
      KSYLog.error('❌ 마커 생성 실패: ${station.stationName}', e);
      rethrow;
    }
  }

  /// 역 마커들 제거
  Future<void> _clearStationMarkers() async {
    if (_mapController == null) return;

    try {
      for (final marker in _stationMarkers) {
        await _mapController!.deleteOverlay(marker.info);
      }
      _stationMarkers.clear();
    } catch (e) {
      KSYLog.error('❌ 마커 제거 오류', e);
    }
  }

  /// 현재 위치 마커 추가
  Future<void> _addCurrentLocationMarker(double lat, double lng) async {
    if (_mapController == null) return;

    try {
      // 기존 현재 위치 마커 제거
      if (_currentLocationMarker != null) {
        await _mapController!.deleteOverlay(_currentLocationMarker!.info);
      }

      if (!mounted) return;

      // 현재 위치 마커 아이콘 생성
      final markerIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
        size: const Size(24, 24),
        context: context,
      );

      // 새로운 현재 위치 마커 생성
      _currentLocationMarker = NMarker(
        id: 'current_location',
        position: NLatLng(lat, lng),
        icon: markerIcon,
        anchor: const NPoint(0.5, 0.5),
      );

      // 마커를 지도에 추가
      await _mapController!.addOverlay(_currentLocationMarker!);

      KSYLog.location('현재 위치 마커 추가', lat, lng);
    } catch (e) {
      KSYLog.error('❌ 현재 위치 마커 추가 오류', e);
    }
  }

  /// 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final locationProvider = context.read<LocationProvider>();

      // 위치 권한 처리
      if (!locationProvider.hasLocationPermission) {
        final granted = await locationProvider.requestLocationPermission();
        if (!granted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
          });
          return;
        }
      }

      // 현재 위치 가져오기
      await locationProvider.getCurrentLocation();

      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;

        KSYLog.location('현재 위치 획득', lat, lng);

        // 지도 중심 이동
        if (_mapController != null) {
          final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(lat, lng),
            zoom: 16,
          );
          await _mapController!.updateCamera(cameraUpdate);
        }

        // 현재 위치 마커 추가
        await _addCurrentLocationMarker(lat, lng);

        // 성공 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('현재 위치로 이동했습니다'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = '위치를 가져올 수 없습니다. GPS가 켜져 있는지 확인해주세요.';
        });
      }
    } catch (e) {
      KSYLog.error('❌ 위치 가져오기 오류', e);
      setState(() {
        _errorMessage = '위치를 가져오는데 실패했습니다: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 역 정보 표시
  void _showStationInfo(SeoulSubwayStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 역명과 호선
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SubwayUtils.getLineColor(station.lineName),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      SubwayUtils.getLineShortName(station.lineName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(station.stationName, style: AppTextStyles.heading2),
                      Text(
                        station.lineName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 상세 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.location_on,
                      '위치',
                      '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
                    ),
                    if (station.stationCode != null)
                      _buildInfoRow(
                        Icons.confirmation_number,
                        '역코드',
                        station.stationCode!,
                      ),
                    if (station.subwayTypeName != null)
                      _buildInfoRow(
                        Icons.train,
                        '지하철구분',
                        station.subwayTypeName!,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToStationDetail(station);
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('상세 정보'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _moveToStation(station);
                    },
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('지도 중심'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// 역 상세 페이지로 이동 (캐싱 활용 API 연동)
  Future<void> _navigateToStationDetail(SeoulSubwayStation seoulStation) async {
    final subwayProvider = context.read<SubwayProvider>();

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      StationGroup? stationGroup;

      // 1. subwayStationId가 있으면 우선 사용
      KSYLog.debug(
        '📋 상세페이지 이동 - 역명: ${seoulStation.stationName}, subwayStationId: ${seoulStation.subwayStationId}',
      );

      if (seoulStation.subwayStationId != null &&
          seoulStation.subwayStationId!.isNotEmpty) {
        KSYLog.info('🆔 subwayStationId 사용: ${seoulStation.subwayStationId}');
        stationGroup = await subwayProvider.getStationDetailsBySubwayStationId(
          subwayStationId: seoulStation.subwayStationId!,
          stationName: seoulStation.stationName,
        );
      } else {
        KSYLog.warning(
          '⚠️ subwayStationId가 없음 또는 비어있음: ${seoulStation.subwayStationId}',
        );
      }

      // 2. subwayStationId 실패 시 기존 방식 사용
      if (stationGroup == null) {
        KSYLog.info('🔍 기존 역명 검색 방식 사용: ${seoulStation.stationName}');
        stationGroup = await subwayProvider.getStationGroupByName(
          seoulStation.stationName,
        );
      }

      // 로딩 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (stationGroup == null) {
        // 검색 실패 시 기본 데이터로 폴백
        KSYLog.warning('⚠️ API 검색 실패, 기본 데이터 사용: ${seoulStation.stationName}');
        final fallbackStation = seoulStation.toSubwayStation();
        final fallbackGroup = StationGroup(
          stationName: fallbackStation.subwayStationName,
          stations: [fallbackStation],
        );

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MultiLineStationDetailScreen(
                stationGroup: fallbackGroup,
                initialStation: fallbackStation,
              ),
            ),
          );
        }
        return;
      }

      // 2. 클릭한 호선과 가장 유사한 역 찾기
      final clickedLineNumber = seoulStation
          .toSubwayStation()
          .effectiveLineNumber;
      SubwayStation? initialStation;

      // 정확한 호선 매칭 시도
      final validStationGroup = stationGroup;
      initialStation = validStationGroup.stations.firstWhere(
        (station) => station.effectiveLineNumber == clickedLineNumber,
        orElse: () => validStationGroup.stations.first,
      );

      KSYLog.info(
        '✅ 지도 연동 성공: ${validStationGroup.stationName} (호선 ${validStationGroup.stations.length}개, 초기 선택: ${initialStation.effectiveLineNumber})',
      );

      // 3. 상세 페이지로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultiLineStationDetailScreen(
              stationGroup: validStationGroup,
              initialStation: initialStation,
            ),
          ),
        );
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      KSYLog.error('❌ 지도 연동 오류', e);

      // 오류 시 기본 데이터로 폴백
      final fallbackStation = seoulStation.toSubwayStation();
      final fallbackGroup = StationGroup(
        stationName: fallbackStation.subwayStationName,
        stations: [fallbackStation],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('역 정보를 불러오는데 시간이 걸립니다. 기본 정보를 표시합니다.'),
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultiLineStationDetailScreen(
              stationGroup: fallbackGroup,
              initialStation: fallbackStation,
            ),
          ),
        );
      }
    }
  }

  /// 지도를 해당 역 중심으로 이동
  Future<void> _moveToStation(SeoulSubwayStation station) async {
    if (_mapController != null) {
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(station.latitude, station.longitude),
        zoom: 17,
      );
      await _mapController!.updateCamera(cameraUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${station.stationName}으로 이동'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지하철 지도'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _isLoading ? null : _getCurrentLocation,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              try {
                switch (value) {
                  case 'refresh':
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    await _clearStationMarkers();
                    await _loadVisibleStations();
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 'clear':
                    await _clearStationMarkers();
                    if (_currentLocationMarker != null &&
                        _mapController != null) {
                      await _mapController!.deleteOverlay(
                        _currentLocationMarker!.info,
                      );
                      _currentLocationMarker = null;
                    }
                    break;
                }
              } catch (e) {
                KSYLog.error('메뉴 액션 오류', e);
                setState(() {
                  _isLoading = false;
                  _errorMessage = '작업을 수행하는데 실패했습니다.';
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('새로고침'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear),
                    SizedBox(width: 8),
                    Text('마커 지우기'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // 네이버 지도
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 서울시청
                zoom: 12,
                bearing: 0,
                tilt: 0,
              ),
              indoorEnable: true,
              locationButtonEnable: false,
              consumeSymbolTapEvents: false,
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
            ),
            onMapReady: _onMapReady,
            onCameraChange: _onCameraChange,
            onCameraIdle: _onCameraIdle,
            onMapTapped: (point, coord) {
              KSYLog.ui('🗺️ 지도 클릭', '${coord.latitude}, ${coord.longitude}');
            },
          ),

          // 에러 메시지
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.withValues(alpha: 0.9),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitWave(color: AppColors.primary, size: 50.0),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      '지하철 정보를 불러오고 있습니다...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
