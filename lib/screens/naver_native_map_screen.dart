import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'dart:math';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../providers/seoul_subway_provider.dart';
import '../models/seoul_subway_station.dart';
import '../models/station_group.dart';
import 'multi_line_station_detail_screen.dart';

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
  List<SeoulSubwayStation> _visibleStations = [];

  // 디바운스 타이머
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    print('🗺️ 네이티브 지도 화면 시작');

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
      print('🚇 SeoulSubwayProvider 데이터 초기화 시작...');
      await seoulSubwayProvider.initialize();
    }
  }

  /// 지도 준비 완료 콜백
  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    print('🗺️ 네이버 지도 준비 완료');

    final locationProvider = context.read<LocationProvider>();

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

    // 초기 화면의 역 로드
    await _loadVisibleStations();
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

      print('📍 지도 중심: ${center.latitude}, ${center.longitude}, 줌: $zoomLevel');

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
        print('🚇 표시할 역이 없음');
        return;
      }

      setState(() {
        _visibleStations = stations;
      });

      // 마커 업데이트
      await _updateStationMarkers(stations);
    } catch (e) {
      print('❌ 화면 내 역 로드 오류: $e');
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
        final distance = _calculateDistance(
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

      print(
        '🚇 지도 중심(${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)})에서 가장 가까운 ${stationsToShow.length}개 마커 추가',
      );

      for (int i = 0; i < stationsToShow.length; i++) {
        final station = stationsToShow[i];

        // 마커 생성
        final marker = await _createStationMarker(station, i);

        // 마커 클릭 이벤트
        marker.setOnTapListener((overlay) {
          _showStationInfo(station);
        });

        // 지도에 추가
        await _mapController!.addOverlay(marker);
        _stationMarkers.add(marker);
      }

      print('✅ 마커 ${_stationMarkers.length}개 추가 완료');
    } catch (e) {
      print('❌ 마커 업데이트 오류: $e');
    }
  }

  /// 역 마커 생성
  Future<NMarker> _createStationMarker(
    SeoulSubwayStation station,
    int index,
  ) async {
    final markerIcon = await NOverlayImage.fromWidget(
      widget: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _getLineColor(station.lineName),
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
            _getLineShortName(station.lineName),
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

    return NMarker(
      id: 'station_$index',
      position: NLatLng(station.latitude, station.longitude),
      icon: markerIcon,
      anchor: const NPoint(0.5, 0.5),
    );
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
      print('❌ 마커 제거 오류: $e');
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

      print('📍 현재 위치 마커 추가: $lat, $lng');
    } catch (e) {
      print('❌ 현재 위치 마커 추가 오류: $e');
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

        print('📍 현재 위치: $lat, $lng');

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
      print('❌ 위치 가져오기 오류: $e');
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
                    color: _getLineColor(station.lineName),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _getLineShortName(station.lineName),
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

  /// 역 상세 페이지로 이동
  void _navigateToStationDetail(SeoulSubwayStation seoulStation) {
    final station = seoulStation.toSubwayStation();
    final stationGroup = StationGroup(
      stationName: station.stationName,
      stations: [station],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiLineStationDetailScreen(
          stationGroup: stationGroup,
          initialStation: station,
        ),
      ),
    );
  }

  /// 두 지점 간의 거리 계산 (Haversine 공식)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
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

  /// 노선별 색상
  Color _getLineColor(String lineName) {
    final Map<String, Color> lineColors = {
      '1호선': const Color(0xFF0052A4),
      '2호선': const Color(0xFF00A84D),
      '3호선': const Color(0xFFEF7C1C),
      '4호선': const Color(0xFF00A5DE),
      '5호선': const Color(0xFF996CAC),
      '6호선': const Color(0xFFCD7C2F),
      '7호선': const Color(0xFF747F00),
      '8호선': const Color(0xFFE6186C),
      '9호선': const Color(0xFFBB8336),
      '경의중앙선': const Color(0xFF77C4A3),
      '분당선': const Color(0xFFFFD320),
      '신분당선': const Color(0xFFD31145),
      '경춘선': const Color(0xFF178C72),
      '수인분당선': const Color(0xFFFFD320),
      '우이신설선': const Color(0xFFB7C452),
      '서해선': const Color(0xFF81A914),
      '김포골드라인': const Color(0xFFB69240),
      '신림선': const Color(0xFF6789CA),
    };

    for (final entry in lineColors.entries) {
      if (lineName.contains(entry.key) || entry.key.contains(lineName)) {
        return entry.value;
      }
    }

    return Colors.grey[600] ?? Colors.grey;
  }

  /// 노선 이름 축약
  String _getLineShortName(String lineName) {
    final numberRegex = RegExp(r'(\d+)');
    final match = numberRegex.firstMatch(lineName);
    if (match != null) {
      final number = match.group(1) ?? '';
      // 한 자리 숫자만 표시 (예: 01 -> 1, 02 -> 2)
      return int.tryParse(number)?.toString() ?? number;
    }

    final Map<String, String> specialLines = {
      '경의중앙선': '경의',
      '분당선': '분당',
      '신분당선': '신분',
      '경춘선': '경춘',
      '수인분당선': '수인',
      '우이신설선': '우이',
      '서해선': '서해',
      '김포골드라인': '김포',
      '신림선': '신림',
    };

    for (final entry in specialLines.entries) {
      if (lineName.contains(entry.key)) {
        return entry.value;
      }
    }

    return lineName.length >= 2 ? lineName.substring(0, 2) : lineName;
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
                print('메뉴 액션 오류: $e');
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
              print('🗺️ 지도 클릭: ${coord.latitude}, ${coord.longitude}');
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
