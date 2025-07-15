import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';
import '../models/subway_station.dart';
import 'station_detail_screen.dart';

/// 향상된 네이버 지도 화면 (개선된 UI/UX)
class EnhancedMapScreen extends StatefulWidget {
  const EnhancedMapScreen({super.key});

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedLine = 'all';
  bool _showStationSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _loadMapWithCurrentLocation();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = '지도를 불러오는데 실패했습니다: ${error.description}';
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'StationClick',
        onMessageReceived: (JavaScriptMessage message) {
          _handleStationClick(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ShowToast',
        onMessageReceived: (JavaScriptMessage message) {
          _showToast(message.message);
        },
      )
      ..loadHtmlString(_getEnhancedMapHtml());
  }

  void _handleStationClick(String stationData) {
    try {
      final parts = stationData.split('|');
      if (parts.length >= 4) {
        final stationName = parts[0];
        final lineName = parts[1];
        final lineNumber = parts[2];
        final stationId = parts[3];

        final station = SubwayStation(
          subwayStationId: stationId,
          subwayStationName: stationName,
          subwayRouteName: lineName,
          latitude: parts.length > 4 ? double.tryParse(parts[4]) : null,
          longitude: parts.length > 5 ? double.tryParse(parts[5]) : null,
        );

        // 선택 피드백 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚇 $stationName으로 이동합니다'),
            duration: const Duration(milliseconds: 1000),
            backgroundColor: _getLineColor(lineNumber),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StationDetailScreen(station: station),
          ),
        );
      }
    } catch (e) {
      print('역 클릭 이벤트 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('역 정보를 불러오는데 실패했습니다.')),
      );
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  String _getEnhancedMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no">
    <title>향상된 지하철 지도</title>
    <script type="text/javascript" src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpClientId=${ApiConstants.naverMapClientId}"></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { 
            margin: 0; 
            padding: 0; 
            font-family: 'Noto Sans KR', 'Apple SD Gothic Neo', sans-serif; 
            overflow: hidden;
        }
        #map { width: 100%; height: 100vh; position: relative; }
        
        /* 로딩 스피너 */
        .loading { 
            position: absolute; 
            top: 50%; 
            left: 50%; 
            transform: translate(-50%, -50%);
            text-align: center;
            z-index: 1000;
            background: rgba(255,255,255,0.98);
            padding: 30px;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
            min-width: 200px;
        }
        
        .loading-spinner {
            width: 40px;
            height: 40px;
            border: 4px solid #f0f0f0;
            border-top: 4px solid #4285F4;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        /* 역 마커 스타일 */
        .station-marker {
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            z-index: 100;
        }
        
        .station-marker:hover {
            transform: scale(1.2);
            z-index: 1000 !important;
        }
        
        .station-marker.selected {
            transform: scale(1.3);
            z-index: 1001 !important;
        }
        
        /* 펄스 애니메이션 */
        @keyframes pulse {
            0% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.1); }
            100% { opacity: 1; transform: scale(1); }
        }
        
        .pulse {
            animation: pulse 2s infinite;
        }
        
        /* 네이버 지도 커스텀 InfoWindow */
        .custom-info-window {
            background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
            border: none;
            border-radius: 16px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
            padding: 0;
            font-family: 'Noto Sans KR', sans-serif;
            max-width: 320px;
            overflow: hidden;
        }
        
        .info-content {
            padding: 20px;
            position: relative;
        }
        
        .station-header {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .line-badge {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 14px;
            margin-right: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        
        .station-info {
            flex: 1;
        }
        
        .station-name {
            font-size: 20px;
            font-weight: bold;
            color: #1a202c;
            margin-bottom: 3px;
        }
        
        .line-name {
            font-size: 14px;
            font-weight: 600;
            opacity: 0.8;
        }
        
        .features-section {
            background: linear-gradient(90deg, rgba(66, 133, 244, 0.1), rgba(66, 133, 244, 0.05));
            padding: 15px;
            border-radius: 12px;
            border-left: 4px solid;
            margin-bottom: 15px;
        }
        
        .feature-item {
            display: flex;
            align-items: center;
            font-size: 13px;
            color: #4a5568;
            margin-bottom: 8px;
        }
        
        .feature-item:last-child {
            margin-bottom: 0;
        }
        
        .feature-icon {
            margin-right: 8px;
            font-size: 16px;
        }
        
        .action-button {
            width: 100%;
            background: linear-gradient(135deg, #4285F4 0%, #34A853 100%);
            color: white;
            padding: 12px 20px;
            border: none;
            border-radius: 25px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(66, 133, 244, 0.3);
            transition: all 0.2s ease;
            margin-top: 10px;
        }
        
        .action-button:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 16px rgba(66, 133, 244, 0.4);
        }
        
        .close-btn {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(0,0,0,0.1);
            border: none;
            border-radius: 50%;
            width: 24px;
            height: 24px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
            transition: all 0.2s ease;
        }
        
        .close-btn:hover {
            background: rgba(0,0,0,0.2);
            color: #333;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div id="loading" class="loading">
        <div class="loading-spinner"></div>
        <div id="loading-text">향상된 지도를 로드하고 있습니다...</div>
    </div>
    
    <script>
        var map;
        var markers = [];
        var infoWindows = [];
        var isMapReady = false;
        var currentLocationMarker = null;
        var selectedStationMarker = null;
        
        function showToast(message) {
            if (window.ShowToast && window.ShowToast.postMessage) {
                window.ShowToast.postMessage(message);
            }
        }
        
        function updateLoadingText(text) {
            var loadingTextDiv = document.getElementById('loading-text');
            if (loadingTextDiv) {
                loadingTextDiv.textContent = text;
            }
        }
        
        function hideLoading() {
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) {
                loadingDiv.style.transition = 'opacity 0.5s ease';
                loadingDiv.style.opacity = '0';
                setTimeout(function() {
                    loadingDiv.style.display = 'none';
                }, 500);
            }
        }
        
        function waitForNaverMaps(callback) {
            if (typeof naver !== 'undefined' && naver.maps && naver.maps.Map) {
                callback();
            } else {
                setTimeout(function() {
                    waitForNaverMaps(callback);
                }, 100);
            }
        }
        
        function initMap(lat, lng) {
            try {
                updateLoadingText('지도 인터페이스를 구성하고 있습니다...');
                
                var center = new naver.maps.LatLng(lat || 37.5665, lng || 126.9780);
                
                var mapOptions = {
                    center: center,
                    zoom: 15,
                    mapTypeControl: true,
                    mapTypeControlOptions: {
                        style: naver.maps.MapTypeControlStyle.BUTTON,
                        position: naver.maps.Position.TOP_RIGHT
                    },
                    zoomControl: true,
                    zoomControlOptions: {
                        style: naver.maps.ZoomControlStyle.LARGE,
                        position: naver.maps.Position.TOP_LEFT
                    },
                    scaleControl: false,
                    logoControl: false,
                    mapDataControl: false
                };
                
                map = new naver.maps.Map('map', mapOptions);
                isMapReady = true;
                
                // 현재 위치 마커 추가
                if (lat && lng) {
                    addCurrentLocationMarker(lat, lng);
                }
                
                hideLoading();
                showToast('🗺️ 지도 로드 완료! 지하철역을 클릭해보세요');
                console.log('향상된 지도 초기화 완료');
                
            } catch (error) {
                console.error('지도 초기화 오류:', error);
                updateLoadingText('지도 로드에 실패했습니다');
            }
        }
        
        function addCurrentLocationMarker(lat, lng) {
            try {
                if (!isMapReady || !map) return;
                
                if (currentLocationMarker) {
                    currentLocationMarker.setMap(null);
                }
                
                currentLocationMarker = new naver.maps.Marker({
                    position: new naver.maps.LatLng(lat, lng),
                    map: map,
                    icon: {
                        content: '<div style="background: linear-gradient(135deg, #4285F4, #34A853); width: 24px; height: 24px; border-radius: 50%; border: 3px solid white; box-shadow: 0 4px 12px rgba(66,133,244,0.4); position: relative; animation: pulse 2s infinite;"><div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: white; font-size: 10px; font-weight: bold;">📍</div></div>',
                        anchor: new naver.maps.Point(12, 12)
                    }
                });
                
                var currentLocationInfo = new naver.maps.InfoWindow({
                    content: '<div style="padding: 12px; font-size: 14px; font-weight: 600; color: #4285F4;">📍 현재 위치</div>',
                    borderColor: '#4285F4',
                    borderWidth: 2,
                    anchorSize: new naver.maps.Size(10, 10)
                });
                
                naver.maps.Event.addListener(currentLocationMarker, 'click', function() {
                    closeAllInfoWindows();
                    currentLocationInfo.open(map, currentLocationMarker);
                });
                
                console.log('현재 위치 마커 추가 완료');
            } catch (error) {
                console.error('현재 위치 마커 추가 오류:', error);
            }
        }
        
        function addSubwayStations(stations, filterLine) {
            try {
                if (!isMapReady || !map) return;
                
                clearSubwayMarkers();
                
                if (!stations || !Array.isArray(stations)) return;
                
                var filteredStations = stations;
                if (filterLine && filterLine !== 'all') {
                    filteredStations = stations.filter(function(station) {
                        return station.lineNumber === filterLine;
                    });
                }
                
                filteredStations.forEach(function(station, index) {
                    if (station.latitude && station.longitude) {
                        setTimeout(function() {
                            createEnhancedStationMarker(station);
                        }, index * 50); // 순차적 애니메이션
                    }
                });
                
                showToast('🚇 ' + filteredStations.length + '개 지하철역을 표시했습니다');
                console.log('향상된 지하철역 마커 추가 완료:', filteredStations.length, '개');
                
            } catch (error) {
                console.error('지하철역 마커 추가 오류:', error);
            }
        }
        
        function createEnhancedStationMarker(station) {
            var color = getLineColor(station.lineNumber);
            var textColor = getTextColor(station.lineNumber);
            
            var marker = new naver.maps.Marker({
                position: new naver.maps.LatLng(station.latitude, station.longitude),
                map: map,
                icon: {
                    content: '<div class="station-marker" style="background: linear-gradient(135deg, ' + color + ', ' + darkenColor(color, 0.15) + '); color: ' + textColor + '; padding: 8px 12px; border-radius: 25px; font-size: 13px; font-weight: bold; box-shadow: 0 4px 15px rgba(0,0,0,0.3); border: 3px solid white; min-width: 32px; text-align: center; position: relative;"><div style="position: absolute; top: -3px; right: -3px; width: 10px; height: 10px; background: #10b981; border-radius: 50%; border: 2px solid white;" class="pulse"></div>' + station.lineNumber + '</div>',
                    anchor: new naver.maps.Point(20, 20)
                }
            });
            
            var infoWindow = createEnhancedInfoWindow(station, color);
            
            // 마커 클릭 이벤트
            naver.maps.Event.addListener(marker, 'click', function() {
                // 이전 선택 마커 스타일 제거
                if (selectedStationMarker) {
                    selectedStationMarker.getElement().classList.remove('selected');
                }
                
                // 현재 마커 선택 스타일 적용
                marker.getElement().classList.add('selected');
                selectedStationMarker = marker;
                
                closeAllInfoWindows();
                infoWindow.open(map, marker);
                
                // 맵 중심을 마커로 이동
                map.panTo(marker.getPosition());
            });
            
            // 마커 호버 효과
            naver.maps.Event.addListener(marker, 'mouseover', function() {
                if (selectedStationMarker !== marker) {
                    marker.getElement().style.transform = 'scale(1.15)';
                    marker.getElement().style.zIndex = '500';
                }
            });
            
            naver.maps.Event.addListener(marker, 'mouseout', function() {
                if (selectedStationMarker !== marker) {
                    marker.getElement().style.transform = 'scale(1)';
                    marker.getElement().style.zIndex = '100';
                }
            });
            
            markers.push(marker);
            infoWindows.push(infoWindow);
        }
        
        function createEnhancedInfoWindow(station, color) {
            var content = 
                '<div class="custom-info-window">' +
                    '<div class="info-content">' +
                        '<button class="close-btn" onclick="closeAllInfoWindows()">×</button>' +
                        '<div class="station-header">' +
                            '<div class="line-badge" style="background: linear-gradient(135deg, ' + color + ', ' + darkenColor(color, 0.2) + ');">' + station.lineNumber + '</div>' +
                            '<div class="station-info">' +
                                '<div class="station-name">' + station.stationName + '</div>' +
                                '<div class="line-name" style="color: ' + color + ';">' + station.lineName + '</div>' +
                            '</div>' +
                        '</div>' +
                        '<div class="features-section" style="border-left-color: ' + color + ';">' +
                            '<div class="feature-item">' +
                                '<span class="feature-icon">🚇</span>' +
                                '<strong>실시간 도착정보</strong> 및 시간표' +
                            '</div>' +
                            '<div class="feature-item">' +
                                '<span class="feature-icon">🗺️</span>' +
                                '출구정보 및 주변시설 안내' +
                            '</div>' +
                            '<div class="feature-item">' +
                                '<span class="feature-icon">🚌</span>' +
                                '환승 및 연계교통 정보' +
                            '</div>' +
                        '</div>' +
                        '<button class="action-button" onclick="goToStationDetail(\'' + 
                            station.stationName + '|' + station.lineName + '|' + station.lineNumber + '|' + 
                            'STATION_' + station.stationName.replace('역', '') + '_' + station.lineNumber + '|' +
                            station.latitude + '|' + station.longitude + '\')">' +
                            '✨ 상세정보 보기' +
                        '</button>' +
                    '</div>' +
                '</div>';
            
            return new naver.maps.InfoWindow({
                content: content,
                borderWidth: 0,
                anchorSize: new naver.maps.Size(15, 15),
                pixelOffset: new naver.maps.Point(0, -10)
            });
        }
        
        function goToStationDetail(stationData) {
            if (window.StationClick && window.StationClick.postMessage) {
                window.StationClick.postMessage(stationData);
            }
            closeAllInfoWindows();
        }
        
        function getLineColor(lineNumber) {
            var colors = {
                '1': '#263c96', '2': '#00a650', '3': '#ef7c1c', '4': '#00a4e3',
                '5': '#996cac', '6': '#cd7c2f', '7': '#747f00', '8': '#e6186c',
                '9': '#bdb092', '공항철도': '#0d9488', '경의중앙': '#06b6d4',
                '분당': '#f59e0b', '신분당': '#dc2626'
            };
            return colors[lineNumber] || '#6b7280';
        }
        
        function getTextColor(lineNumber) {
            return '#ffffff';
        }
        
        function darkenColor(color, factor) {
            var f = parseInt(color.slice(1), 16);
            var R = f >> 16, G = f >> 8 & 0x00FF, B = f & 0x0000FF;
            return "#" + (0x1000000 + (Math.round((1 - factor) * R) << 16) + 
                         (Math.round((1 - factor) * G) << 8) + 
                         Math.round((1 - factor) * B)).toString(16).slice(1);
        }
        
        function clearSubwayMarkers() {
            markers.forEach(function(marker) {
                if (marker && marker.setMap) {
                    marker.setMap(null);
                }
            });
            markers = [];
            closeAllInfoWindows();
            selectedStationMarker = null;
        }
        
        function closeAllInfoWindows() {
            infoWindows.forEach(function(infoWindow) {
                if (infoWindow && infoWindow.close) {
                    infoWindow.close();
                }
            });
            
            // 선택된 마커 스타일 제거
            if (selectedStationMarker) {
                selectedStationMarker.getElement().classList.remove('selected');
                selectedStationMarker = null;
            }
        }
        
        function moveToLocation(lat, lng, zoom) {
            if (!isMapReady || !map) return;
            map.setCenter(new naver.maps.LatLng(lat, lng));
            if (zoom) map.setZoom(zoom);
            addCurrentLocationMarker(lat, lng);
        }
        
        function refreshMap() {
            clearSubwayMarkers();
            if (map) map.refresh();
            showToast('🔄 지도를 새로고침했습니다');
        }
        
        // 지도 초기화
        waitForNaverMaps(function() {
            console.log('향상된 네이버 지도 API 로드 완료');
            initMap();
        });
    </script>
</body>
</html>
    ''';
  }

  Future<void> _loadMapWithCurrentLocation() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;
        
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap($lat, $lng); }'
        );
        
        await _loadEnhancedSubwayStations();
      } else {
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap(37.5665, 126.9780); }'
        );
        
        await _loadEnhancedSubwayStations();
      }
    } catch (e) {
      print('지도 로드 오류: $e');
      setState(() {
        _errorMessage = '지도를 불러오는데 실패했습니다.';
      });
    }
  }

  Future<void> _loadEnhancedSubwayStations() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      
      await locationProvider.loadEnhancedStations();
      
      final stations = locationProvider.allEnhancedStations;
      
      if (stations.isNotEmpty) {
        final stationsJson = stations.map((station) => {
          'stationName': station.stationName,
          'lineName': station.lineName,
          'lineNumber': station.lineNumber,
          'latitude': station.latitude,
          'longitude': station.longitude,
        }).toList();
        
        final stationsJsonString = stationsJson.toString()
            .replaceAll("'", '"')
            .replaceAll('null', 'null');
        
        await _webViewController.runJavaScript(
          'if (typeof addSubwayStations === "function") { addSubwayStations($stationsJsonString, "$_selectedLine"); }'
        );
      }
    } catch (e) {
      print('확장된 지하철역 마커 로드 오류: $e');
    }
  }

  Future<void> _filterStationsByLine(String line) async {
    setState(() {
      _selectedLine = line;
    });
    
    await _webViewController.runJavaScript(
      'if (typeof addSubwayStations === "function") { '
      'var stations = JSON.parse(\'${await _getStationsJsonString()}\'); '
      'addSubwayStations(stations, "$line"); }'
    );
  }

  Future<String> _getStationsJsonString() async {
    final locationProvider = context.read<LocationProvider>();
    final stations = locationProvider.allEnhancedStations;
    
    final stationsJson = stations.map((station) => {
      'stationName': station.stationName,
      'lineName': station.lineName,
      'lineNumber': station.lineNumber,
      'latitude': station.latitude,
      'longitude': station.longitude,
    }).toList();
    
    return stationsJson.toString()
        .replaceAll("'", '"')
        .replaceAll('null', 'null');
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final locationProvider = context.read<LocationProvider>();
      
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
      
      await locationProvider.getCurrentLocation();
      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;
        
        await _webViewController.runJavaScript(
          'if (typeof moveToLocation === "function") { moveToLocation($lat, $lng, 16); }'
        );
        
        await locationProvider.loadNearbyStations();
        await _loadEnhancedSubwayStations();
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

  Widget _buildEnhancedLineFilter() {
    final lines = ['all', '1', '2', '3', '4', '5', '6', '7', '8', '9', '공항철도', '경의중앙', '분당', '신분당'];
    final lineNames = {
      'all': '전체', '1': '1호선', '2': '2호선', '3': '3호선', '4': '4호선',
      '5': '5호선', '6': '6호선', '7': '7호선', '8': '8호선', '9': '9호선',
      '공항철도': '공항철도', '경의중앙': '경의중앙', '분당': '분당선', '신분당': '신분당선',
    };
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isSelected = _selectedLine == line;
          
          return Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () => _filterStationsByLine(line),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: isSelected ? _getLineColor(line) : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected ? _getLineColor(line) : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (line != 'all') ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : _getLineColor(line),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              line == '공항철도' ? 'A' : 
                              line == '경의중앙' ? 'K' :
                              line == '분당' ? 'B' :
                              line == '신분당' ? 'S' : line,
                              style: TextStyle(
                                color: isSelected ? _getLineColor(line) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        lineNames[line] ?? line,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getLineColor(String line) {
    switch (line) {
      case '1': return const Color(0xFF263c96);
      case '2': return const Color(0xFF00a650);
      case '3': return const Color(0xFFef7c1c);
      case '4': return const Color(0xFF00a4e3);
      case '5': return const Color(0xFF996cac);
      case '6': return const Color(0xFFcd7c2f);
      case '7': return const Color(0xFF747f00);
      case '8': return const Color(0xFFe6186c);
      case '9': return const Color(0xFFbdb092);
      case '공항철도': return const Color(0xFF0d9488);
      case '경의중앙': return const Color(0xFF06b6d4);
      case '분당': return const Color(0xFFf59e0b);
      case '신분당': return const Color(0xFFdc2626);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚇 네이버 지하철 지도'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showStationSearch ? Icons.close : Icons.search),
            tooltip: '역 검색',
            onPressed: () {
              setState(() {
                _showStationSearch = !_showStationSearch;
                if (!_showStationSearch) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: '내 위치',
            onPressed: _getCurrentLocation,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              try {
                switch (value) {
                  case 'refresh':
                    setState(() { _isLoading = true; });
                    await _webViewController.runJavaScript(
                      'if (typeof refreshMap === "function") { refreshMap(); }'
                    );
                    await _loadEnhancedSubwayStations();
                    setState(() { _isLoading = false; });
                    break;
                  case 'clear':
                    await _webViewController.runJavaScript(
                      'if (typeof clearSubwayMarkers === "function") { clearSubwayMarkers(); }'
                    );
                    break;
                  case 'show_all':
                    _filterStationsByLine('all');
                    break;
                }
              } catch (e) {
                print('메뉴 액션 오류: $e');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('새로고침'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'show_all',
                child: Row(
                  children: [
                    Icon(Icons.train, color: Colors.green),
                    SizedBox(width: 8),
                    Text('모든 역 표시'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear, color: Colors.red),
                    SizedBox(width: 8),
                    Text('역 마커 지우기'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 개선된 검색창
          if (_showStationSearch)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '🔍 지하철역을 검색하세요...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) => setState(() {}),
                onSubmitted: (value) => _searchStation(value),
              ),
            ),
          
          // 향상된 노선 필터
          _buildEnhancedLineFilter(),
          
          // 지도
          Expanded(
            child: Stack(
              children: [
                if (_errorMessage == null)
                  WebViewWidget(controller: _webViewController),
                
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 64,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton.icon(
                            onPressed: () async {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _initializeWebView();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                if (_isLoading)
                  Container(
                    color: Colors.white,
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
                            '🗺️ 향상된 지도를 불러오고 있습니다...',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      
      // 향상된 하단 정보 패널
      bottomSheet: Consumer2<LocationProvider, SubwayProvider>(
        builder: (context, locationProvider, subwayProvider, child) {
          final stations = locationProvider.allEnhancedStations;
          final filteredStations = _selectedLine == 'all' 
              ? stations 
              : stations.where((s) => s.lineNumber == _selectedLine).toList();
          
          if (filteredStations.isEmpty) {
            return const SizedBox.shrink();
          }
          
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getLineColor(_selectedLine).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.train,
                        color: _getLineColor(_selectedLine),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLine == 'all' 
                                ? '전체 지하철역'
                                : _getLineName(_selectedLine),
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '총 ${filteredStations.length}개 역 표시 중',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_getLineColor(_selectedLine), _getLineColor(_selectedLine).withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✨ 역 클릭하기',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLineName(String line) {
    switch (line) {
      case '1': return '1호선';
      case '2': return '2호선';
      case '3': return '3호선';
      case '4': return '4호선';
      case '5': return '5호선';
      case '6': return '6호선';
      case '7': return '7호선';
      case '8': return '8호선';
      case '9': return '9호선';
      case '공항철도': return '공항철도';
      case '경의중앙': return '경의중앙선';
      case '분당': return '분당선';
      case '신분당': return '신분당선';
      default: return line;
    }
  }

  void _searchStation(String query) {
    print('역 검색: $query');
    // TODO: 실제 검색 로직 구현
  }
}
