import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../providers/location_provider.dart';
import '../providers/seoul_subway_provider.dart';
import '../models/subway_station.dart';
import '../models/seoul_subway_station.dart';
import '../models/station_group.dart';
import '../services/seoul_subway_api_service.dart';
import 'multi_line_station_detail_screen.dart';

/// 네이버 지도 네이티브 화면 (서울 지하철 API 사용)
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
  List<SeoulSubwayStation> _displayedStations = [];

  @override
  void initState() {
    super.initState();
    print('서울 지하철 지도 화면 시작');
    
    // 앱 시작 시 지하철역 마커 자동 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeoulSubwayStations();
    });
  }

  /// 서울 지하철 API 데이터로 역 로드
  Future<void> _loadSeoulSubwayStations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final seoulSubwayProvider = context.read<SeoulSubwayProvider>();
      
      // 데이터가 없으면 초기화
      if (!seoulSubwayProvider.hasStations) {
        await seoulSubwayProvider.initialize();
      }

      // 모든 서울 지하철역 가져오기
      final allStations = seoulSubwayProvider.allStations;
      
      // 좌표가 있는 역들만 필터링
      final stationsWithCoordinates = allStations
          .where((station) => station.latitude != 0.0 && station.longitude != 0.0)
          .toList();

      setState(() {
        _displayedStations = stationsWithCoordinates;
        _isLoading = false;
      });

      print('서울 지하철역 로드 완료: 전체 ${allStations.length}개, 좌표 있음 ${stationsWithCoordinates.length}개');

      // 지도가 준비되었으면 마커 추가
      if (_mapController != null) {
        await _addSeoulSubwayStationMarkers();
      }

    } catch (e) {
      print('서울 지하철역 로드 오류: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '지하철역 정보를 불러오는데 실패했습니다: $e';
      });
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
    
    // 서울 지하철역 마커 추가
    if (_displayedStations.isNotEmpty) {
      await _addSeoulSubwayStationMarkers();
    } else {
      // 없으면 새로 로드
      await _loadSeoulSubwayStations();
    }
  }

  /// 서울 지하철 API 데이터로 마커 추가
  Future<void> _addSeoulSubwayStationMarkers() async {
    if (_mapController == null || _displayedStations.isEmpty) return;

    try {
      print('서울 지하철역 마커 추가 시작: ${_displayedStations.length}개');

      // 기존 지하철역 마커들 제거
      await _clearSubwayMarkers();

      // 마커 표시 개수 제한 (성능을 위해 200개로 제한)
      final maxMarkers = 200;
      final stationsToShow = _displayedStations.length > maxMarkers 
          ? _displayedStations.take(maxMarkers).toList()
          : _displayedStations;

      for (int i = 0; i < stationsToShow.length; i++) {
        final station = stationsToShow[i];
        
        // 마커 아이콘 생성
        final markerIcon = await _buildStationMarkerIcon(station.lineName, context);
        
        final marker = NMarker(
          id: 'seoul_station_$i',
          position: NLatLng(station.latitude, station.longitude),
          icon: markerIcon,
          anchor: const NPoint(0.5, 0.5),
        );

        // 마커 클릭 이벤트 - 역 정보 표시
        marker.setOnTapListener((overlay) {
          print('${station.stationName} 마커 클릭됨');
          _showSeoulStationInfo(station);
        });

        await _mapController!.addOverlay(marker);
        _markers.add(marker);
      }

      print('서울 지하철역 마커 ${_markers.length}개 추가 완료');
      setState(() {});
      
    } catch (e) {
      print('서울 지하철역 마커 추가 오류: $e');
    }
  }

  /// 서울 지하철역 정보 표시
  void _showSeoulStationInfo(SeoulSubwayStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
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
                CircleAvatar(
                  backgroundColor: _getLineColor(station.lineName),
                  radius: 16,
                  child: Text(
                    station.lineName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.stationName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${station.lineName}호선',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 상세 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.location_on, '위치', 
                        '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}'),
                    if (station.stationCode != null)
                      _buildInfoRow(Icons.confirmation_number, '역코드', station.stationCode!),
                    if (station.subwayTypeName != null)
                      _buildInfoRow(Icons.train, '지하철구분', station.subwayTypeName!),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
            
            const SizedBox(height: 8),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 정보 행 빌더
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// 역 상세 페이지로 이동
  void _navigateToStationDetail(SeoulSubwayStation seoulStation) {
    // SeoulSubwayStation을 SubwayStation으로 변환
    final station = seoulStation.toSubwayStation();
    
    // StationGroup 생성
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

  /// 지도를 해당 역 중심으로 이동
  Future<void> _moveToStation(SeoulSubwayStation station) async {
    if (_mapController != null) {
      final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(station.latitude, station.longitude),
        zoom: 16,
      );
      await _mapController!.updateCamera(cameraUpdate);
    }
  }

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

  /// 지하철역 마커 아이콘 생성
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
        child: Center(
          child: Text(
            lineNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
        title: const Text('서울 지하철 지도'),
        actions: [
          // 서울 지하철역 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadSeoulSubwayStations();
            },
            tooltip: '지하철역 새로고침',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh_all':
                  setState(() {
                    _isLoading = true;
                  });
                  await _clearSubwayMarkers();
                  await _loadSeoulSubwayStations();
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
                  setState(() {
                    _displayedStations = [];
                  });
                  break;
                case 'seoul_only':
                  // 서울 지역만 필터링
                  final seoulStations = _displayedStations
                      .where((station) => 
                          station.latitude >= 37.4 && 
                          station.latitude <= 37.7 &&
                          station.longitude >= 126.7 && 
                          station.longitude <= 127.3)
                      .toList();
                  setState(() {
                    _displayedStations = seoulStations;
                  });
                  await _addSeoulSubwayStationMarkers();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh_all',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('전체 새로고침'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'seoul_only',
                child: Row(
                  children: [
                    Icon(Icons.location_city),
                    SizedBox(width: 8),
                    Text('서울 지역만'),
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
                      '서울 지하철 정보를 불러오고 있습니다...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 역 개수 표시
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
                    '서울 지하철: ${_displayedStations.length}개',
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
