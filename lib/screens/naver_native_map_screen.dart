import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import '../utils/location_utils.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../providers/seoul_subway_provider.dart';
import '../providers/subway_provider.dart';
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';
import '../utils/ksy_log.dart';
import '../utils/app_utils.dart';

/// 네이버 지도 네이티브 화면 (동적 마커 로딩)
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

  // 디바운스 타이머
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    KSYLog.lifecycle('🗺️ 네이티브 지도 화면 시작');

    // LocationProvider 변경 리스너
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      final seoulSubwayProvider = context.read<SeoulSubwayProvider>();

      // LocationProvider에 SeoulSubwayProvider 설정
      locationProvider.setSeoulSubwayProvider(seoulSubwayProvider);

      // 데이터 초기화
      _initializeData();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// 데이터 초기화
  Future<void> _initializeData() async {
    final seoulSubwayProvider = context.read<SeoulSubwayProvider>();

    // SeoulSubwayProvider 데이터가 없으면 초기화
    if (!seoulSubwayProvider.hasStations && !seoulSubwayProvider.isLoading) {
      KSYLog.info('🚇 SeoulSubwayProvider 데이터 초기화 시작...');
      await seoulSubwayProvider.initialize();
      KSYLog.info(
        '🚇 SeoulSubwayProvider 데이터 초기화 완료: ${seoulSubwayProvider.hasStations}',
      );
    } else if (seoulSubwayProvider.isLoading) {
      // 이미 로딩 중이면 완료될 때까지 대기
      KSYLog.info('🚇 SeoulSubwayProvider 로딩 중, 대기...');
      while (seoulSubwayProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      KSYLog.info(
        '🚇 SeoulSubwayProvider 로딩 완료: ${seoulSubwayProvider.hasStations}',
      );
    }
  }

  /// 지도 준비 완료 콜백
  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    KSYLog.info('🗺️ 네이버 지도 준비 완료');

    final locationProvider = context.read<LocationProvider>();
    final seoulSubwayProvider = context.read<SeoulSubwayProvider>();

    // 데이터 초기화가 완료될 때까지 대기
    if (!seoulSubwayProvider.hasStations) {
      KSYLog.info('🚇 SeoulSubwayProvider 데이터 초기화 대기 중...');
      await _initializeData();
    }

    // 현재 위치가 있으면 표시
    if (locationProvider.currentPosition != null) {
      await _addCurrentLocationMarker(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );

      // 현재 위치로 카메라 이동
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
        ),
        zoom: 15,
      );
      await _mapController!.updateCamera(cameraUpdate);
    }
  }

  /// 카메라 변경 콜백 (지도 이동 시)
  void _onCameraChange(NCameraUpdateReason reason, bool isAnimated) {
    // 디바운스로 과도한 호출 방지
    // _debounceTimer?.cancel();
    // _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    //   if (mounted) {
    //     _loadVisibleStations();
    //   }
    // });
  }

  /// 카메라 변경 완료 콜백
  void _onCameraIdle() {
    _loadVisibleStations();
  }

  /// 현재 화면에 보이는 역들 로드
  Future<void> _loadVisibleStations() async {
    if (_mapController == null) return;

    try {
      // 현재 카메라 위치 가져오기
      final cameraPosition = await _mapController!.getCameraPosition();
      _currentCameraPosition = cameraPosition;

      final center = cameraPosition.target;
      final zoomLevel = cameraPosition.zoom;

      KSYLog.debug(
        '📍 지도 중심: ${center.latitude}, ${center.longitude}, 줌: $zoomLevel',
      );

      // LocationProvider 업데이트
      final locationProvider = context.read<LocationProvider>();
      locationProvider.updateMapBounds(
        center.latitude,
        center.longitude,
        zoomLevel,
      );

      // 화면 내 역 가져오기
      final stations = locationProvider.visibleStations;

      if (stations.isEmpty) {
        KSYLog.debug('🚇 표시할 역이 없음');
        return;
      }

      // 마커 업데이트
      await _updateStationMarkers(stations);
    } catch (e) {
      KSYLog.error('❌ 화면 내 역 로드 오류', e);
    }
  }

  /// 역 마커 업데이트
  Future<void> _updateStationMarkers(List<SeoulSubwayStation> stations) async {
    if (_mapController == null || _currentCameraPosition == null) return;

    try {
      // 기존 역 마커들 제거
      await _clearStationMarkers();

      // 지도 중심점 가져오기
      final center = _currentCameraPosition!.target;

      // 지도 중심점으로부터 거리순으로 정렬
      final stationsWithDistance = stations.map((station) {
        final distance = LocationUtils.calculateDistanceM(
          center.latitude,
          center.longitude,
          station.latitude,
          station.longitude,
        );
        return {'station': station, 'distance': distance};
      }).toList();

      // 거리순으로 정렬
      stationsWithDistance.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      // 가장 가까운 60개만 선택
      final stationsToShow = stationsWithDistance
          .take(60)
          .map((item) => item['station'] as SeoulSubwayStation)
          .toList();

      KSYLog.info(
        '🚇 지도 중심(${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)})에서 가장 가까운 ${stationsToShow.length}개 마커 추가',
      );

      for (int i = 0; i < stationsToShow.length; i++) {
        final station = stationsToShow[i];

        try {
          // 마커 생성
          final marker = await _createStationMarker(station, i);

          // 마커 클릭 이벤트
          marker.setOnTapListener((overlay) {
            _showStationInfo(station);
          });

          // 지도에 추가
          await _mapController!.addOverlay(marker);
          _stationMarkers.add(marker);

          KSYLog.debug(
            '📍 마커 추가 완료: ${station.stationName} (총 ${_stationMarkers.length}개)',
          );
        } catch (e) {
          KSYLog.error('❌ 마커 추가 실패: ${station.stationName}', e);
          // 개별 마커 실패는 무시하고 계속
        }
      }

      KSYLog.info('✅ 마커 ${_stationMarkers.length}개 추가 완료');
    } catch (e) {
      KSYLog.error('❌ 마커 업데이트 오류', e);
    }
  }

  /// 역 마커 생성
  Future<NMarker> _createStationMarker(
    SeoulSubwayStation station,
    int index,
  ) async {
    try {
      KSYLog.debug('🎯 마커 생성 시도: ${station.stationName} (${station.lineName})');

      final markerIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: SubwayUtils.getLineColor(station.lineName),
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
              SubwayUtils.getLineShortName(station.lineName),
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
        id: 'station_$index',
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
        await locationProvider.initializeLocationStatus();

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
      // 1. 캐싱을 활용한 API 검색
      final stationGroup = await subwayProvider.getStationGroupByName(
        seoulStation.stationName,
      );

      // 로딩 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (stationGroup == null) {
        // 검색 실패 시 기본 데이터로 폴백
        KSYLog.warning('⚠️ API 검색 실패, 기본 데이터 사용: ${seoulStation.stationName}');
        final fallbackStation = seoulStation.toSubwayStation();
        final fallbackGroup = StationGroup(
          stationName: fallbackStation.stationName,
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
      initialStation = stationGroup.stations.firstWhere(
        (station) => station.effectiveLineNumber == clickedLineNumber,
        orElse: () => stationGroup.stations.first,
      );

      KSYLog.info(
        '✅ 지도 연동 성공: ${stationGroup.stationName} (호선 ${stationGroup.stations.length}개, 초기 선택: ${initialStation.effectiveLineNumber})',
      );

      // 3. 상세 페이지로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultiLineStationDetailScreen(
              stationGroup: stationGroup,
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
        stationName: fallbackStation.stationName,
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
                color: Colors.red.withOpacity(0.9),
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
