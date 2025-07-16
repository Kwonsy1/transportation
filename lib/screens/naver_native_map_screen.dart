import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';
import '../models/subway_station.dart';
import 'station_detail_screen.dart';

/// 네이버 지도 네이티브 화면 (flutter_naver_map 사용)
class NaverNativeMapScreen extends StatefulWidget {
  const NaverNativeMapScreen({super.key});

  @override
  State<NaverNativeMapScreen> createState() => _NaverNativeMapScreenState();
}

class _NaverNativeMapScreenState extends State<NaverNativeMapScreen> {
  NaverMapController? _mapController;
  bool _isLoading = false;
  String? _errorMessage;
  final List<NMarker> _markers = [];
  NMarker? _currentLocationMarker;

  @override
  void initState() {
    super.initState();
    print('네이버 지도 화면 시작');
    
    // 앱 시작 시 지하철역 마커 자동 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialStations();
    });
  }

  /// 앱 시작 시 기본 지하철역들을 로드
  Future<void> _loadInitialStations() async {
    final locationProvider = context.read<LocationProvider>();
    
    print('초기 역 로드 시작');
    
    // 현재 위치가 없으면 기본값으로 로드
    if (locationProvider.currentPosition == null) {
      await locationProvider.loadNearbyStations();
    }
    
    print('현재 주변 역 수: ${locationProvider.nearbyStations.length}');
    
    // 지도가 준비되었고 주변 역이 있으면 마커 추가
    if (_mapController != null && locationProvider.nearbyStations.isNotEmpty) {
      await _addSubwayStationMarkers();
    }
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    print('네이버 지도 준비 완료');
    
    final locationProvider = context.read<LocationProvider>();
    
    // 현재 위치가 있으면 지도에 표시
    if (locationProvider.currentPosition != null) {
      await _addCurrentLocationMarker(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );
    }
    
    // 주변 지하철역이 있으면 마커 추가
    if (locationProvider.nearbyStations.isNotEmpty) {
      await _addSubwayStationMarkers();
    } else {
      // 없으면 새로 로드
      await _loadInitialStations();
    }
    
    // 수동으로 몇 개 마커 추가 (테스트용)
    await _addDebugMarkers();
  }

  /// 디버깅용 고정 마커 추가
  Future<void> _addDebugMarkers() async {
    if (_mapController == null) return;

    try {
      print('디버깅 마커 추가 시작');
      
      // 서울시 주요 역들 정확한 좌표로 수정
      final debugStations = [
        {
          'name': '강남역',
          'lat': 37.497952,
          'lng': 127.027619,
          'line': '2',
          'id': 'GANGNAM_STATION',
          'routeName': '서울 2호선'
        },
        {
          'name': '서울역',
          'lat': 37.554648,
          'lng': 126.970880,
          'line': '1',
          'id': 'SEOUL_STATION',
          'routeName': '서울 1호선'
        },
        {
          'name': '홍대입구역',
          'lat': 37.556798,
          'lng': 126.924370,
          'line': '2',
          'id': 'HONGIK_UNIV_STATION',
          'routeName': '서울 2호선'
        },
        {
          'name': '여의도역',
          'lat': 37.521931,
          'lng': 126.924477,
          'line': '5',
          'id': 'YEOUIDO_STATION',
          'routeName': '서울 5호선'
        },
        {
          'name': '종로3가역',
          'lat': 37.570607,
          'lng': 126.991806,
          'line': '3',
          'id': 'JONGNO_3GA_STATION',
          'routeName': '서울 3호선'
        },
        {
          'name': '잠실역',
          'lat': 37.513188,
          'lng': 127.100052,
          'line': '2',
          'id': 'JAMSIL_STATION',
          'routeName': '서울 2호선'
        },
        {
          'name': '신도림역',
          'lat': 37.508728,
          'lng': 126.891242,
          'line': '1',
          'id': 'SINDORIM_STATION',
          'routeName': '서울 1호선'
        },
        {
          'name': '건대입구역',
          'lat': 37.540126,
          'lng': 127.069684,
          'line': '2',
          'id': 'KONKUK_UNIV_STATION',
          'routeName': '서울 2호선'
        },
      ];
      
      for (int i = 0; i < debugStations.length; i++) {
        final stationData = debugStations[i];
        
        // SubwayStation 객체 생성 (상세 페이지용)
        final station = SubwayStation(
          subwayStationId: stationData['id'] as String,
          subwayStationName: stationData['name'] as String,
          subwayRouteName: stationData['routeName'] as String,
          latitude: stationData['lat'] as double,
          longitude: stationData['lng'] as double,
        );
        
        // 마커 아이콘 생성
        final markerIcon = await _buildStationMarkerIcon(stationData['line'] as String, context);
        
        final marker = NMarker(
          id: 'debug_station_$i',
          position: NLatLng(stationData['lat'] as double, stationData['lng'] as double),
          icon: markerIcon,
          anchor: const NPoint(0.5, 0.5),
        );
        
        // 마커 클릭 이벤트 - 실제 상세 페이지로 이동
        marker.setOnTapListener((overlay) {
          print('${stationData['name']} 마커 클릭됨');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StationDetailScreen(station: station),
            ),
          );
        });
        
        await _mapController!.addOverlay(marker);
        _markers.add(marker);
        
        print('마커 추가: ${stationData['name']} at ${stationData['lat']}, ${stationData['lng']}');
      }
      
      print('총 ${debugStations.length}개 마커 추가 완료');
      setState(() {});
      
    } catch (e) {
      print('마커 추가 오류: $e');
    }
  }

  Future<void> _addCurrentLocationMarker(double lat, double lng) async {
    if (_mapController == null) return;

    try {
      // 기존 현재 위치 마커 제거
      if (_currentLocationMarker != null) {
        await _mapController!.deleteOverlay(_currentLocationMarker!.info);
      }

      // 현재 위치 마커 아이콘 비동기 생성
      final markerIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0xFF4285F4),
                blurRadius: 12,
                spreadRadius: -3,
                offset: Offset(0, 0),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
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

          // 마커 클릭 이벤트 - 상세 페이지로 이동
          marker.setOnTapListener((overlay) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StationDetailScreen(station: station),
              ),
            );
          });

          await _mapController!.addOverlay(marker);
          _markers.add(marker);
        }
      }

      print('지하철역 마커 ${_markers.length}개 추가 완료');
      
      // 마커 추가 후 UI 업데이트
      setState(() {});
    } catch (e) {
      print('지하철역 마커 추가 오류: $e');
    }
  }

  /// 지하철역 마커 아이콘 비동기 생성 (현재 위치 스타일)
  Future<NOverlayImage> _buildStationMarkerIcon(String lineNumber, BuildContext context) async {
    final color = _getLineColor(lineNumber);
    return await NOverlayImage.fromWidget(
      widget: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.train,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      size: const Size(28, 28),
      context: context,
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
          // 디버깅용 마커 추가 버튼
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: () async {
              await _addDebugMarkers();
            },
            tooltip: '마커 추가',
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
            onMapTapped: (point, coord) {
              print('지도 클릭: ${coord.latitude}, ${coord.longitude}');
            },
          ),

          // 내 위치 버튼 (우측 하단)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
              onPressed: _isLoading ? null : _getCurrentLocation,
              backgroundColor: _isLoading 
                  ? Colors.green.withOpacity(0.6) 
                  : Colors.green,
              foregroundColor: Colors.white,
              elevation: 4,
              heroTag: 'location_button',
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      size: 20,
                    ),
            ),
          ),

          // 에러 메시지
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
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
                      color: Colors.green,
                      size: 50.0,
                    ),
                    SizedBox(height: 16),
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

          // 마커 개수 및 상태 표시
          Positioned(
            top: 100,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.train,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '마커: ${_markers.length}개',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
