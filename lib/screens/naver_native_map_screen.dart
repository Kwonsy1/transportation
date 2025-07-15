import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';

/// 네이버 지도 네이티브 화면 (flutter_naver_map 사용)
class NaverNativeMapScreen extends StatefulWidget {
  const NaverNativeMapScreen({super.key});

  @override
  State<NaverNativeMapScreen> createState() => _NaverNativeMapScreenState();
}

class _NaverNativeMapScreenState extends State<NaverNativeMapScreen> {
  NaverMapController? _mapController;
  bool _isLoading = false; // 초기화 제거로 기본값 false
  String? _errorMessage;
  final List<NMarker> _markers = [];
  NMarker? _currentLocationMarker;

  @override
  void initState() {
    super.initState();
    // main.dart에서 이미 전역 초기화가 완료되었으므로 추가 초기화 불필요
    print('네이버 지도 화면 준비 완료 (이미 초기화됨)');
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    print('네이버 지도 준비 완료');
    
    // 현재 위치가 있으면 지도에 표시
    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.currentPosition != null) {
      await _addCurrentLocationMarker(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );
      
      // 주변 지하철역 마커 추가
      if (locationProvider.nearbyStations.isNotEmpty) {
        await _addSubwayStationMarkers();
      }
    }
  }

  Future<void> _addCurrentLocationMarker(double lat, double lng) async {
    if (_mapController == null) return;

    try {
      // 기존 현재 위치 마커 제거
      if (_currentLocationMarker != null) {
        await _mapController!.deleteOverlay(_currentLocationMarker!.info);
      }

      // 마커 아이콘 비동기 생성
      final markerIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF4285F4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        size: const Size(20, 20),
        context: context, // Context 추가
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

      // 정보창 설정
      final infoWindow = NInfoWindow.onMarker(
        id: _currentLocationMarker!.info.id,
        text: '현재 위치',
      );
      _currentLocationMarker!.openInfoWindow(infoWindow);

      print('현재 위치 마커 추가 완료: $lat, $lng');
    } catch (e) {
      print('현재 위치 마커 추가 오류: $e');
    }
  }

  Future<void> _addSubwayStationMarkers() async {
    if (_mapController == null) return;

    try {
      // 기존 지하철역 마커들 제거
      await _clearSubwayMarkers();

      final locationProvider = context.read<LocationProvider>();
      final stations = locationProvider.nearbyStations;

      for (int i = 0; i < stations.length; i++) {
        final station = stations[i];
        if (station.latitude != null && station.longitude != null) {
          // 마커 아이콘 비동기 생성
          final markerIcon = await _buildStationMarkerIcon(station.lineNumber, context);
          
          final marker = NMarker(
            id: 'station_$i',
            position: NLatLng(station.latitude!, station.longitude!),
            icon: markerIcon,
            anchor: const NPoint(0.5, 0.5),
          );

          // 마커 클릭 이벤트
          marker.setOnTapListener((overlay) {
            final infoWindow = NInfoWindow.onMarker(
              id: marker.info.id,
              text: '${station.stationName}\n${station.lineName}',
            );
            marker.openInfoWindow(infoWindow);
          });

          await _mapController!.addOverlay(marker);
          _markers.add(marker);
        }
      }

      print('지하철역 마커 ${stations.length}개 추가 완료');
    } catch (e) {
      print('지하철역 마커 추가 오류: $e');
    }
  }

  /// 지하철역 마커 아이콘 비동기 생성
  Future<NOverlayImage> _buildStationMarkerIcon(String lineNumber, BuildContext context) async {
    final color = _getLineColor(lineNumber);
    return await NOverlayImage.fromWidget(
      widget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          lineNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      size: const Size(40, 30),
      context: context, // Context 추가
    );
  }

  Color _getLineColor(String lineNumber) {
    final colors = {
      '1': const Color(0xFF263c96),
      '2': const Color(0xFF00a650),
      '3': const Color(0xFFef7c1c),
      '4': const Color(0xFF00a4e3),
      '5': const Color(0xFF996cac),
      '6': const Color(0xFFcd7c2f),
      '7': const Color(0xFF747f00),
      '8': const Color(0xFFe6186c),
      '9': const Color(0xFFbdb092),
    };
    return colors[lineNumber] ?? const Color(0xFF757575);
  }

  Future<void> _clearSubwayMarkers() async {
    if (_mapController == null) return;

    try {
      for (final marker in _markers) {
        await _mapController!.deleteOverlay(marker.info);
      }
      _markers.clear();
      print('지하철역 마커 제거 완료');
    } catch (e) {
      print('지하철역 마커 제거 오류: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final locationProvider = context.read<LocationProvider>();

      // 위치 권한 확인
      if (!locationProvider.hasLocationPermission) {
        final granted = await locationProvider.requestLocationPermission();
        if (!granted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '위치 권한이 필요합니다.';
          });
          return;
        }
      }

      // 현재 위치 가져오기
      await locationProvider.getCurrentLocation();
      
      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;

        // 지도 카메라 이동
        if (_mapController != null) {
          final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(lat, lng),
            zoom: 15,
          );
          await _mapController!.updateCamera(cameraUpdate);
        }

        // 현재 위치 마커 추가
        await _addCurrentLocationMarker(lat, lng);

        // 주변 지하철역 로드
        await locationProvider.loadNearbyStations();
        if (locationProvider.nearbyStations.isNotEmpty) {
          await _addSubwayStationMarkers();
        }
      } else {
        setState(() {
          _errorMessage = '위치를 가져올 수 없습니다.';
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('위치 가져오기 오류: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '위치를 가져오는데 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지하철 지도 (네이버 네이티브)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  setState(() {
                    _isLoading = true;
                  });
                  await _clearSubwayMarkers();
                  await _getCurrentLocation();
                  setState(() {
                    _isLoading = false;
                  });
                  break;
                case 'clear':
                  await _clearSubwayMarkers();
                  if (_currentLocationMarker != null && _mapController != null) {
                    await _mapController!.deleteOverlay(_currentLocationMarker!.info);
                    _currentLocationMarker = null;
                  }
                  break;
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
          // 네이버 지도 (main.dart에서 이미 초기화 완료)
          NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(37.5665, 126.9780), // 서울시청
                  zoom: 10,
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
              onMapTapped: (point, coord) {
                print('지도 클릭: ${coord.latitude}, ${coord.longitude}');
              },
            ),

          // 에러 메시지
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Card(
                color: AppColors.error.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                          ),
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
                    SpinKitWave(
                      color: AppColors.primary,
                      size: 50.0,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      '위치 정보를 불러오고 있습니다...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // 하단 정보 패널
      bottomSheet: Consumer2<LocationProvider, SubwayProvider>(
        builder: (context, locationProvider, subwayProvider, child) {
          if (locationProvider.nearbyStations.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            height: 100,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.train,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '주변 지하철역 ${locationProvider.nearbyStations.length}개',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: locationProvider.nearbyStations.length,
                    itemBuilder: (context, index) {
                      final station = locationProvider.nearbyStations[index];
                      final distance = locationProvider.calculateDistanceToStation(station);

                      return Container(
                        margin: const EdgeInsets.only(right: AppSpacing.md),
                        child: InkWell(
                          onTap: () async {
                            if (station.latitude != null && 
                                station.longitude != null && 
                                _mapController != null) {
                              try {
                                final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
                                  target: NLatLng(station.latitude!, station.longitude!),
                                  zoom: 17,
                                );
                                await _mapController!.updateCamera(cameraUpdate);
                              } catch (e) {
                                print('지도 이동 오류: $e');
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station.stationName,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (distance != null)
                                  Text(
                                    locationProvider.formatDistance(distance),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
