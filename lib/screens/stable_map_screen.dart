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

/// 안정적인 네이버 지도 화면 (디버깅 강화)
class StableMapScreen extends StatefulWidget {
  const StableMapScreen({super.key});

  @override
  State<StableMapScreen> createState() => _StableMapScreenState();
}

class _StableMapScreenState extends State<StableMapScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedLine = 'all';
  bool _showStationSearch = false;
  final TextEditingController _searchController = TextEditingController();
  bool _useNaverMap = true; // 네이버 지도 사용 여부
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 2;

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
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            print('🌐 페이지 로딩 시작: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            print('✅ 페이지 로딩 완료: $url');
            _loadMapWithCurrentLocation();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView 리소스 오류: ${error.description}');
            print('   오류 코드: ${error.errorCode}');
            print('   오류 타입: ${error.errorType}');
            
            _loadAttempts++;
            if (_loadAttempts >= _maxLoadAttempts && _useNaverMap) {
              print('🔄 네이버 지도 로딩 실패, OpenStreetMap으로 전환');
              setState(() {
                _useNaverMap = false;
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeWebView();
              return;
            }
            
            setState(() {
              _isLoading = false;
              _errorMessage = _useNaverMap 
                  ? '네이버 지도를 불러오는데 실패했습니다. OpenStreetMap으로 전환하겠습니다.'
                  : '지도를 불러오는데 실패했습니다: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔗 네비게이션 요청: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'StationClick',
        onMessageReceived: (JavaScriptMessage message) {
          print('🚇 역 클릭: ${message.message}');
          _handleStationClick(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ConsoleLog',
        onMessageReceived: (JavaScriptMessage message) {
          print('📝 지도 로그: ${message.message}');
        },
      )
      ..loadHtmlString(_getMapHtml());
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚇 $stationName 상세정보로 이동합니다'),
            duration: const Duration(milliseconds: 1500),
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
      print('❌ 역 클릭 이벤트 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('역 정보를 불러오는데 실패했습니다.')),
      );
    }
  }

  String _getMapHtml() {
    if (_useNaverMap) {
      return _getNaverMapHtml();
    } else {
      return _getOpenStreetMapHtml();
    }
  }

  String _getNaverMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no">
    <meta http-equiv="Content-Security-Policy" content="default-src * 'unsafe-inline' 'unsafe-eval'; script-src * 'unsafe-inline' 'unsafe-eval'; connect-src * 'unsafe-inline'; img-src * data: blob: 'unsafe-inline'; frame-src *; style-src * 'unsafe-inline';">
    <title>네이버 지하철 지도</title>
    <script type="text/javascript" src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpClientId=${ApiConstants.naverMapClientId}" 
        onerror="console.log('❌ 네이버 지도 API 스크립트 로드 실패'); if(window.ConsoleLog) window.ConsoleLog.postMessage('❌ 네이버 지도 API 스크립트 로드 실패 - Origin: ' + window.location.origin);"
        onload="console.log('✅ 네이버 지도 API 스크립트 로드 성공'); if(window.ConsoleLog) window.ConsoleLog.postMessage('✅ 네이버 지도 API 스크립트 로드 성공');"></script>
    <style>
        body { margin: 0; padding: 0; font-family: 'Noto Sans KR', Arial, sans-serif; }
        #map { width: 100%; height: 100vh; }
        .loading { 
            position: absolute; top: 50%; left: 50%; 
            transform: translate(-50%, -50%); text-align: center; z-index: 1000;
            background: rgba(255,255,255,0.95); padding: 25px; border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .station-marker { cursor: pointer; transition: transform 0.2s ease; }
        .station-marker:hover { transform: scale(1.1); }
    </style>
</head>
<body>
    <div id="map"></div>
    <div id="loading" class="loading">
        <div>네이버 지도를 로드하고 있습니다...</div>
    </div>
    
    <script>
        // 네트워크 요청 모니터링
        window.addEventListener('error', function(e) {
            console.error('페이지 에러:', e.error);
            if (window.ConsoleLog) {
                window.ConsoleLog.postMessage('페이지 에러: ' + e.error);
            }
        });
        
        // XMLHttpRequest 모니터링
        const originalXHR = window.XMLHttpRequest;
        window.XMLHttpRequest = function() {
            const xhr = new originalXHR();
            const originalOpen = xhr.open;
            xhr.open = function(method, url) {
                console.log('🌐 XHR 요청:', method, url);
                if (window.ConsoleLog) {
                    window.ConsoleLog.postMessage('🌐 XHR 요청: ' + method + ' ' + url);
                }
                return originalOpen.apply(this, arguments);
            };
            return xhr;
        };
        
        // Fetch 모니터링
        const originalFetch = window.fetch;
        window.fetch = function(url, options) {
            console.log('🌐 Fetch 요청:', url);
            if (window.ConsoleLog) {
                window.ConsoleLog.postMessage('🌐 Fetch 요청: ' + url);
            }
            return originalFetch.apply(this, arguments).catch(function(error) {
                console.error('🌐 Fetch 에러:', error);
                if (window.ConsoleLog) {
                    window.ConsoleLog.postMessage('🌐 Fetch 에러: ' + error.message);
                }
                throw error;
            });
        };
        
        var map, markers = [], infoWindows = [], isMapReady = false, currentLocationMarker = null;
        
        function log(message) {
            console.log(message);
            if (window.ConsoleLog && window.ConsoleLog.postMessage) {
                window.ConsoleLog.postMessage(message);
            }
        }
        
        function hideLoading() {
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) {
                loadingDiv.style.display = 'none';
            }
        }
        
        function waitForNaverMaps(callback, attempts = 0) {
            // 현재 페이지 정보 로그
            log('🌐 현재 Origin: ' + window.location.origin);
            log('🌐 현재 URL: ' + window.location.href);
            log('🌐 현재 Protocol: ' + window.location.protocol);
            log('🌐 현재 Host: ' + window.location.host);
            
            if (attempts > 50) { // 5초 타임아웃
                log('❌ 네이버 지도 API 로드 타임아웃');
                document.body.innerHTML = '<div style="padding: 50px; text-align: center;"><h3>네이버 지도 로드에 실패했습니다</h3><p>현재 Origin: ' + window.location.origin + '</p><p>OpenStreetMap으로 전환하겠습니다.</p></div>';
                return;
            }
            
            if (typeof naver !== 'undefined' && naver.maps && naver.maps.Map) {
                log('✅ 네이버 지도 API 로드 완료');
                callback();
            } else {
                log('⏳ 네이버 지도 API 로딩 중... (' + attempts + '/50)');
                setTimeout(function() {
                    waitForNaverMaps(callback, attempts + 1);
                }, 100);
            }
        }
        
        function initMap(lat, lng) {
            try {
                log('🗺️ 네이버 지도 초기화 시작');
                hideLoading();
                
                var mapOptions = {
                    center: new naver.maps.LatLng(lat || 37.5665, lng || 126.9780),
                    zoom: 15,
                    mapTypeControl: true,
                    zoomControl: true,
                    scaleControl: false,
                    logoControl: false,
                    mapDataControl: false
                };
                
                map = new naver.maps.Map('map', mapOptions);
                isMapReady = true;
                
                if (lat && lng) {
                    addCurrentLocationMarker(lat, lng);
                }
                
                log('✅ 네이버 지도 초기화 완료');
            } catch (error) {
                log('❌ 네이버 지도 초기화 오류: ' + error.message);
                document.body.innerHTML = '<div style="padding: 50px; text-align: center;"><h3>지도 초기화 실패</h3><p>' + error.message + '</p></div>';
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
                        content: '<div style="background-color: #4285F4; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>',
                        anchor: new naver.maps.Point(10, 10)
                    }
                });
                
                log('📍 현재 위치 마커 추가: ' + lat + ', ' + lng);
            } catch (error) {
                log('❌ 현재 위치 마커 추가 오류: ' + error.message);
            }
        }
        
        function addSubwayStations(stations, filterLine) {
            try {
                if (!isMapReady || !map) {
                    log('⚠️ 지도가 준비되지 않음');
                    return;
                }
                
                clearSubwayMarkers();
                
                if (!stations || !Array.isArray(stations)) {
                    log('⚠️ 역 데이터가 유효하지 않음');
                    return;
                }
                
                var filteredStations = stations;
                if (filterLine && filterLine !== 'all') {
                    filteredStations = stations.filter(function(station) {
                        return station.lineNumber === filterLine;
                    });
                }
                
                filteredStations.forEach(function(station) {
                    if (station.latitude && station.longitude) {
                        var color = getLineColor(station.lineNumber);
                        
                        var marker = new naver.maps.Marker({
                            position: new naver.maps.LatLng(station.latitude, station.longitude),
                            map: map,
                            icon: {
                                content: '<div class="station-marker" style="background: ' + color + '; color: white; padding: 6px 10px; border-radius: 20px; font-size: 12px; font-weight: bold; box-shadow: 0 3px 8px rgba(0,0,0,0.3); border: 2px solid white; min-width: 24px; text-align: center;">' + station.lineNumber + '</div>',
                                anchor: new naver.maps.Point(20, 15)
                            }
                        });
                        
                        var infoWindow = new naver.maps.InfoWindow({
                            content: '<div style="padding: 15px; min-width: 150px;"><div style="font-size: 16px; font-weight: bold; margin-bottom: 5px;">' + station.stationName + '</div><div style="color: ' + color + '; font-weight: 600; margin-bottom: 8px;">' + station.lineName + '</div><div style="font-size: 12px; color: #666;">🚇 클릭하여 상세정보 보기</div></div>'
                        });
                        
                        naver.maps.Event.addListener(marker, 'click', function() {
                            closeAllInfoWindows();
                            infoWindow.open(map, marker);
                            
                            var stationData = station.stationName + '|' + station.lineName + '|' + station.lineNumber + '|' + 'STATION_' + station.stationName.replace('역', '') + '_' + station.lineNumber + '|' + station.latitude + '|' + station.longitude;
                            
                            if (window.StationClick && window.StationClick.postMessage) {
                                window.StationClick.postMessage(stationData);
                            }
                        });
                        
                        markers.push(marker);
                        infoWindows.push(infoWindow);
                    }
                });
                
                log('🚇 지하철역 마커 추가 완료: ' + filteredStations.length + '개');
            } catch (error) {
                log('❌ 지하철역 마커 추가 오류: ' + error.message);
            }
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
        
        function clearSubwayMarkers() {
            markers.forEach(function(marker) {
                if (marker && marker.setMap) {
                    marker.setMap(null);
                }
            });
            markers = [];
            closeAllInfoWindows();
        }
        
        function closeAllInfoWindows() {
            infoWindows.forEach(function(infoWindow) {
                if (infoWindow && infoWindow.close) {
                    infoWindow.close();
                }
            });
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
        }
        
        // 초기화
        waitForNaverMaps(function() {
            initMap();
        });
    </script>
</body>
</html>
    ''';
  }

  String _getOpenStreetMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>지하철 지도 (OpenStreetMap)</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
        #map { width: 100%; height: 100vh; }
        .loading { 
            position: absolute; top: 50%; left: 50%; 
            transform: translate(-50%, -50%); text-align: center; z-index: 1000;
            background: rgba(255,255,255,0.95); padding: 25px; border-radius: 12px;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div id="loading" class="loading">
        <div>OpenStreetMap을 로드하고 있습니다...</div>
    </div>
    
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        var map, markers = [], currentLocationMarker = null;
        
        function log(message) {
            console.log(message);
            if (window.ConsoleLog && window.ConsoleLog.postMessage) {
                window.ConsoleLog.postMessage(message);
            }
        }
        
        function hideLoading() {
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) loadingDiv.style.display = 'none';
        }
        
        function initMap(lat, lng) {
            try {
                log('🗺️ OpenStreetMap 초기화 시작');
                
                var center = [lat || 37.5665, lng || 126.9780];
                map = L.map('map').setView(center, 15);
                
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 19
                }).addTo(map);
                
                if (lat && lng) {
                    addCurrentLocationMarker(lat, lng);
                }
                
                hideLoading();
                log('✅ OpenStreetMap 초기화 완료');
            } catch (error) {
                log('❌ OpenStreetMap 초기화 오류: ' + error.message);
            }
        }
        
        function addCurrentLocationMarker(lat, lng) {
            try {
                if (currentLocationMarker) {
                    map.removeLayer(currentLocationMarker);
                }
                
                var blueIcon = L.divIcon({
                    className: 'current-location-marker',
                    html: '<div style="background-color: #4285F4; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>',
                    iconSize: [20, 20],
                    iconAnchor: [10, 10]
                });
                
                currentLocationMarker = L.marker([lat, lng], {icon: blueIcon}).addTo(map);
                currentLocationMarker.bindPopup('📍 현재 위치').openPopup();
                
                log('📍 현재 위치 마커 추가: ' + lat + ', ' + lng);
            } catch (error) {
                log('❌ 현재 위치 마커 추가 오류: ' + error.message);
            }
        }
        
        function addSubwayStations(stations, filterLine) {
            try {
                clearSubwayMarkers();
                
                if (!stations || !Array.isArray(stations)) return;
                
                var filteredStations = stations;
                if (filterLine && filterLine !== 'all') {
                    filteredStations = stations.filter(function(station) {
                        return station.lineNumber === filterLine;
                    });
                }
                
                filteredStations.forEach(function(station) {
                    if (station.latitude && station.longitude) {
                        var color = getLineColor(station.lineNumber);
                        
                        var stationIcon = L.divIcon({
                            className: 'subway-station-marker',
                            html: '<div style="background-color: ' + color + '; color: white; padding: 5px 8px; border-radius: 15px; font-size: 12px; font-weight: bold; box-shadow: 0 2px 4px rgba(0,0,0,0.3); cursor: pointer;">' + station.lineNumber + '</div>',
                            iconSize: [40, 30],
                            iconAnchor: [20, 15]
                        });
                        
                        var marker = L.marker([station.latitude, station.longitude], {icon: stationIcon}).addTo(map);
                        
                        var popupContent = '<div style="padding: 10px;"><strong>' + station.stationName + '</strong><br><span style="color: ' + color + ';">' + station.lineName + '</span><br><small>클릭하여 상세정보 보기</small></div>';
                        marker.bindPopup(popupContent);
                        
                        marker.on('click', function() {
                            var stationData = station.stationName + '|' + station.lineName + '|' + station.lineNumber + '|' + 'STATION_' + station.stationName.replace('역', '') + '_' + station.lineNumber + '|' + station.latitude + '|' + station.longitude;
                            
                            if (window.StationClick && window.StationClick.postMessage) {
                                window.StationClick.postMessage(stationData);
                            }
                        });
                        
                        markers.push(marker);
                    }
                });
                
                log('🚇 지하철역 마커 추가 완료: ' + filteredStations.length + '개');
            } catch (error) {
                log('❌ 지하철역 마커 추가 오류: ' + error.message);
            }
        }
        
        function getLineColor(lineNumber) {
            var colors = {
                '1': '#263c96', '2': '#00a650', '3': '#ef7c1c', '4': '#00a4e3',
                '5': '#996cac', '6': '#cd7c2f', '7': '#747f00', '8': '#e6186c',
                '9': '#bdb092', '공항철도': '#0d9488', '경의중앙': '#06b6d4',
                '분당': '#f59e0b', '신분당': '#dc2626'
            };
            return colors[lineNumber] || '#757575';
        }
        
        function clearSubwayMarkers() {
            markers.forEach(function(marker) {
                if (marker && map) {
                    map.removeLayer(marker);
                }
            });
            markers = [];
        }
        
        function moveToLocation(lat, lng, zoom) {
            if (map) {
                map.setView([lat, lng], zoom || 15);
                addCurrentLocationMarker(lat, lng);
            }
        }
        
        function refreshMap() {
            clearSubwayMarkers();
        }
        
        // 초기화
        document.addEventListener('DOMContentLoaded', function() {
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
        
        print('📍 현재 위치로 지도 로드: $lat, $lng');
        
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap($lat, $lng); }'
        );
        
        await _loadEnhancedSubwayStations();
      } else {
        print('📍 기본 위치로 지도 로드: 서울시청');
        
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap(37.5665, 126.9780); }'
        );
        
        await _loadEnhancedSubwayStations();
      }
    } catch (e) {
      print('❌ 지도 로드 오류: $e');
      setState(() {
        _errorMessage = '지도를 불러오는데 실패했습니다: $e';
      });
    }
  }

  Future<void> _loadEnhancedSubwayStations() async {
    try {
      // 서울 전체 지하철역 데이터 하드코딩
      final stations = _getSeoulSubwayStations();
      
      if (stations.isNotEmpty) {
        final stationsJson = stations.map((station) => {
          'stationName': station['name'],
          'lineName': '서울 ${station['line']}호선',
          'lineNumber': station['line'],
          'latitude': station['lat'],
          'longitude': station['lng'],
        }).toList();
        
        final stationsJsonString = stationsJson.toString()
            .replaceAll("'", '"')
            .replaceAll('null', 'null');
        
        print('🚇 서울 지하철역 데이터 로드: ${stations.length}개');
        
        await _webViewController.runJavaScript(
          'if (typeof addSubwayStations === "function") { addSubwayStations($stationsJsonString, "$_selectedLine"); }'
        );
      }
    } catch (e) {
      print('❌ 지하철역 마커 로드 오류: $e');
    }
  }
  
  /// 서울 전체 지하철역 데이터 반환
  List<Map<String, dynamic>> _getSeoulSubwayStations() {
    final Map<String, Map<String, dynamic>> seoulStations = {
      // 1호선
      '서울역': {'lat': 37.5546, 'lng': 126.9707, 'lines': ['1', '4', '경의중앙', '공항철도']},
      '시청역': {'lat': 37.5657, 'lng': 126.9769, 'lines': ['1', '2']},
      '종각역': {'lat': 37.5703, 'lng': 126.9826, 'lines': ['1']},
      '종로3가역': {'lat': 37.5706, 'lng': 126.9915, 'lines': ['1', '3', '5']},
      '동대문역': {'lat': 37.5717, 'lng': 127.0092, 'lines': ['1', '4']},
      '신설동역': {'lat': 37.5750, 'lng': 127.0253, 'lines': ['1', '2']},
      '청량리역': {'lat': 37.5800, 'lng': 127.0478, 'lines': ['1', '경의중앙']},
      '용산역': {'lat': 37.5299, 'lng': 126.9648, 'lines': ['1', '경의중앙']},
      '신도림역': {'lat': 37.5087, 'lng': 126.8913, 'lines': ['1', '2']},
      '가산디지털단지역': {'lat': 37.4817, 'lng': 126.8827, 'lines': ['1', '7']},
      
      // 2호선
      '강남역': {'lat': 37.4979, 'lng': 127.0276, 'lines': ['2', '신분당']},
      '역삼역': {'lat': 37.5000, 'lng': 127.0364, 'lines': ['2']},
      '선릉역': {'lat': 37.5044, 'lng': 127.0489, 'lines': ['2', '분당']},
      '삼성역': {'lat': 37.5090, 'lng': 127.0633, 'lines': ['2']},
      '종합운동장역': {'lat': 37.5115, 'lng': 127.0734, 'lines': ['2', '9']},
      '잠실역': {'lat': 37.5132, 'lng': 127.1000, 'lines': ['2', '8']},
      '건대입구역': {'lat': 37.5401, 'lng': 127.0699, 'lines': ['2', '7']},
      '신촌역': {'lat': 37.5561, 'lng': 126.9364, 'lines': ['2']},
      '이대역': {'lat': 37.5569, 'lng': 126.9456, 'lines': ['2']},
      '을지로입구역': {'lat': 37.5660, 'lng': 126.9822, 'lines': ['2']},
      '을지로3가역': {'lat': 37.5665, 'lng': 126.9915, 'lines': ['2', '3']},
      '동대문역사문화공원역': {'lat': 37.5665, 'lng': 127.0079, 'lines': ['2', '4', '5']},
      '신당역': {'lat': 37.5656, 'lng': 127.0180, 'lines': ['2', '6']},
      '왕십리역': {'lat': 37.5610, 'lng': 127.0379, 'lines': ['2', '5', '경의중앙', '분당']},
      '성수역': {'lat': 37.5445, 'lng': 127.0557, 'lines': ['2']},
      '홀대입구역': {'lat': 37.5563, 'lng': 126.9243, 'lines': ['2', '6', '공항철도', '경의중앙']},
      '합정역': {'lat': 37.5497, 'lng': 126.9138, 'lines': ['2', '6']},
      '당산역': {'lat': 37.5345, 'lng': 126.9025, 'lines': ['2', '9']},
      '대림역': {'lat': 37.4930, 'lng': 126.8958, 'lines': ['2', '7']},
      '사당역': {'lat': 37.4767, 'lng': 126.9816, 'lines': ['2', '4']},
      '교대역': {'lat': 37.4928, 'lng': 127.0143, 'lines': ['2', '3']},
      
      // 3호선
      '압구정역': {'lat': 37.5273, 'lng': 127.0287, 'lines': ['3']},
      '신사역': {'lat': 37.5164, 'lng': 127.0206, 'lines': ['3']},
      '고속터미널역': {'lat': 37.5048, 'lng': 127.0051, 'lines': ['3', '7', '9']},
      '양재역': {'lat': 37.4674, 'lng': 127.0347, 'lines': ['3', '신분당']},
      '도곳역': {'lat': 37.4914, 'lng': 127.0516, 'lines': ['3']},
      '대치역': {'lat': 37.4951, 'lng': 127.0627, 'lines': ['3']},
      '수서역': {'lat': 37.4874, 'lng': 127.1008, 'lines': ['3', '분당']},
      '가락시장역': {'lat': 37.4924, 'lng': 127.1179, 'lines': ['3', '8']},
      '오금역': {'lat': 37.5026, 'lng': 127.1283, 'lines': ['3', '5']},
      '충무로역': {'lat': 37.5615, 'lng': 126.9946, 'lines': ['3', '4']},
      '동대입구역': {'lat': 37.5583, 'lng': 126.9754, 'lines': ['3', '6']},
      '약수역': {'lat': 37.5544, 'lng': 127.0096, 'lines': ['3', '6']},
      '옥수역': {'lat': 37.5404, 'lng': 127.0172, 'lines': ['3']},
      '안국역': {'lat': 37.5763, 'lng': 126.9850, 'lines': ['3']},
      '경복궁역': {'lat': 37.5759, 'lng': 126.9732, 'lines': ['3']},
      '독립문역': {'lat': 37.5747, 'lng': 126.9558, 'lines': ['3']},
      '불광역': {'lat': 37.6108, 'lng': 126.9298, 'lines': ['3', '6']},
      '연신내역': {'lat': 37.6191, 'lng': 126.9212, 'lines': ['3', '6']},
      
      // 4호선
      '명동역': {'lat': 37.5636, 'lng': 126.9866, 'lines': ['4']},
      '회현역': {'lat': 37.5591, 'lng': 126.9785, 'lines': ['4']},
      '숙대입구역': {'lat': 37.5446, 'lng': 126.9689, 'lines': ['4']},
      '삼각지역': {'lat': 37.5347, 'lng': 126.9729, 'lines': ['4', '6']},
      '이촌역': {'lat': 37.5219, 'lng': 126.9758, 'lines': ['4']},
      '동작역': {'lat': 37.5127, 'lng': 126.9797, 'lines': ['4', '9']},
      '총신대입구역': {'lat': 37.5016, 'lng': 126.9853, 'lines': ['4', '7']},
      '혜화역': {'lat': 37.5821, 'lng': 127.0021, 'lines': ['4']},
      '성신여대입구역': {'lat': 37.5924, 'lng': 127.0167, 'lines': ['4']},
      '길음역': {'lat': 37.6025, 'lng': 127.0258, 'lines': ['4']},
      '미아역': {'lat': 37.6136, 'lng': 127.0306, 'lines': ['4']},
      '수유역': {'lat': 37.6376, 'lng': 127.0254, 'lines': ['4']},
      '창동역': {'lat': 37.6536, 'lng': 127.0470, 'lines': ['4']},
      '노원역': {'lat': 37.6541, 'lng': 127.0618, 'lines': ['4', '7']},
      
      // 5호선
      '방화역': {'lat': 37.5784, 'lng': 126.8126, 'lines': ['5']},
      '김포공항역': {'lat': 37.5623, 'lng': 126.8014, 'lines': ['5', '9', '공항철도']},
      '여의도역': {'lat': 37.5219, 'lng': 126.9245, 'lines': ['5', '9']},
      '공덕역': {'lat': 37.5448, 'lng': 126.9516, 'lines': ['5', '6', '경의중앙', '공항철도']},
      '광화문역': {'lat': 37.5720, 'lng': 126.9762, 'lines': ['5']},
      '청구역': {'lat': 37.5601, 'lng': 127.0153, 'lines': ['5', '6']},
      '군자역': {'lat': 37.5574, 'lng': 127.0794, 'lines': ['5', '7']},
      '천호역': {'lat': 37.5387, 'lng': 127.1236, 'lines': ['5', '8']},
      '강동역': {'lat': 37.5269, 'lng': 127.1265, 'lines': ['5']},
      '명일역': {'lat': 37.5511, 'lng': 127.1472, 'lines': ['5']},
      '마천역': {'lat': 37.4942, 'lng': 127.1477, 'lines': ['5']},
      
      // 6호선
      '응암역': {'lat': 37.6022, 'lng': 126.9134, 'lines': ['6']},
      '디지털미디어시티역': {'lat': 37.5768, 'lng': 126.9003, 'lines': ['6', '공항철도', '경의중앙']},
      '월드컵경기장역': {'lat': 37.5679, 'lng': 126.9003, 'lines': ['6']},
      '망원역': {'lat': 37.5555, 'lng': 126.9104, 'lines': ['6']},
      '상수역': {'lat': 37.5479, 'lng': 126.9227, 'lines': ['6']},
      '이태원역': {'lat': 37.5346, 'lng': 126.9946, 'lines': ['6']},
      '버티고개역': {'lat': 37.5408, 'lng': 127.0079, 'lines': ['6']},
      '안암역': {'lat': 37.5858, 'lng': 127.0297, 'lines': ['6']},
      '고려대역': {'lat': 37.5890, 'lng': 127.0326, 'lines': ['6']},
      '태릉입구역': {'lat': 37.6240, 'lng': 127.0567, 'lines': ['6', '7']},
      
      // 7호선
      '장암역': {'lat': 37.6458, 'lng': 126.8345, 'lines': ['7']},
      '어린이대공원역': {'lat': 37.5480, 'lng': 127.0742, 'lines': ['7']},
      '강남구청역': {'lat': 37.5173, 'lng': 127.0417, 'lines': ['7']},
      '논현역': {'lat': 37.5104, 'lng': 127.0221, 'lines': ['7']},
      '반포역': {'lat': 37.5048, 'lng': 127.0051, 'lines': ['7']},
      '이수역': {'lat': 37.4863, 'lng': 126.9820, 'lines': ['7']},
      '상도역': {'lat': 37.5016, 'lng': 126.9477, 'lines': ['7']},
      '대림역': {'lat': 37.4930, 'lng': 126.8958, 'lines': ['2', '7']},
      '남구로역': {'lat': 37.4860, 'lng': 126.8874, 'lines': ['7']},
      '부평구청역': {'lat': 37.5070, 'lng': 126.7229, 'lines': ['7']},
      
      // 8호선
      '암사역': {'lat': 37.5527, 'lng': 127.1281, 'lines': ['8']},
      '강동구청역': {'lat': 37.5301, 'lng': 127.1264, 'lines': ['8']},
      '몽촌토성역': {'lat': 37.5185, 'lng': 127.1222, 'lines': ['8']},
      '석촌역': {'lat': 37.5052, 'lng': 127.1062, 'lines': ['8']},
      '송파역': {'lat': 37.5048, 'lng': 127.1116, 'lines': ['8']},
      '문정역': {'lat': 37.4848, 'lng': 127.1221, 'lines': ['8']},
      '장지역': {'lat': 37.4781, 'lng': 127.1261, 'lines': ['8']},
      '복정역': {'lat': 37.4705, 'lng': 127.1263, 'lines': ['8', '분당']},
      '모란역': {'lat': 37.3932, 'lng': 127.1279, 'lines': ['8', '분당']},
      
      // 9호선
      '개화역': {'lat': 37.5784, 'lng': 126.7955, 'lines': ['9']},
      '염창역': {'lat': 37.5467, 'lng': 126.8745, 'lines': ['9']},
      '국회의사당역': {'lat': 37.5293, 'lng': 126.9179, 'lines': ['9']},
      '흑석역': {'lat': 37.5080, 'lng': 126.9616, 'lines': ['9']},
      '신논현역': {'lat': 37.4941, 'lng': 127.0251, 'lines': ['9']},
      '언주역': {'lat': 37.4849, 'lng': 127.0378, 'lines': ['9']},
      '선정릉역': {'lat': 37.5044, 'lng': 127.0489, 'lines': ['9', '분당']},
      '석촌고분역': {'lat': 37.5014, 'lng': 127.0915, 'lines': ['9']},
      '송파나루역': {'lat': 37.5152, 'lng': 127.1103, 'lines': ['9']},
      '올림픽공원역': {'lat': 37.5218, 'lng': 127.1242, 'lines': ['9']},
      '둘촌오륜역': {'lat': 37.5272, 'lng': 127.1364, 'lines': ['9']},
      
      // 공항철도
      '계양역': {'lat': 37.5373, 'lng': 126.7375, 'lines': ['공항철도']},
      
      // 분당선
      '야탑역': {'lat': 37.4114, 'lng': 127.1278, 'lines': ['분당']},
      '이매역': {'lat': 37.4020, 'lng': 127.1278, 'lines': ['분당']},
      '서현역': {'lat': 37.3856, 'lng': 127.1232, 'lines': ['분당']},
      '수내역': {'lat': 37.3836, 'lng': 127.1022, 'lines': ['분당']},
      '정자역': {'lat': 37.3653, 'lng': 127.1067, 'lines': ['분당']},
      '미금역': {'lat': 37.3499, 'lng': 127.1089, 'lines': ['분당']},
      '죽전역': {'lat': 37.3246, 'lng': 127.1067, 'lines': ['분당']},
      '기흥역': {'lat': 37.2758, 'lng': 127.1159, 'lines': ['분당']},
      '수원역': {'lat': 37.2661, 'lng': 127.0016, 'lines': ['분당']},
      
      // 신분당선
      '판교역': {'lat': 37.3951, 'lng': 127.1116, 'lines': ['신분당']},
      '수지구청역': {'lat': 37.3234, 'lng': 127.1260, 'lines': ['신분당']},
      '상현역': {'lat': 37.2576, 'lng': 127.1359, 'lines': ['신분당']},
      '광교역': {'lat': 37.2847, 'lng': 127.0448, 'lines': ['신분당']},
    };
    
    List<Map<String, dynamic>> stations = [];
    
    seoulStations.forEach((stationName, coords) {
      for (String line in coords['lines']) {
        stations.add({
          'name': stationName,
          'line': line,
          'lat': coords['lat'],
          'lng': coords['lng'],
        });
      }
    });
    
    return stations;
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
    final stations = _getSeoulSubwayStations();
    
    final stationsJson = stations.map((station) => {
      'stationName': station['name'],
      'lineName': '서울 ${station['line']}호선',
      'lineNumber': station['line'],
      'latitude': station['lat'],
      'longitude': station['lng'],
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 현재 위치로 이동했습니다')),
        );
      } else {
        setState(() {
          _errorMessage = '위치를 가져올 수 없습니다.';
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 위치 가져오기 오류: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '위치를 가져오는데 실패했습니다: $e';
      });
    }
  }

  Widget _buildLineFilter() {
    final lines = ['all', '1', '2', '3', '4', '5', '6', '7', '8', '9', '공항철도', '경의중앙', '분당', '신분당'];
    final lineNames = {
      'all': '전체', '1': '1호선', '2': '2호선', '3': '3호선', '4': '4호선',
      '5': '5호선', '6': '6호선', '7': '7호선', '8': '8호선', '9': '9호선',
      '공항철도': '공항철도', '경의중앙': '경의중앙', '분당': '분당선', '신분당': '신분당선',
    };
    
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isSelected = _selectedLine == line;
          
          return Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(lineNames[line] ?? line),
              selected: isSelected,
              onSelected: (selected) {
                _filterStationsByLine(line);
              },
              selectedColor: _getLineColor(line).withOpacity(0.2),
              checkmarkColor: _getLineColor(line),
              labelStyle: TextStyle(
                color: isSelected ? _getLineColor(line) : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        title: Text(_useNaverMap ? '🚇 네이버 지하철 지도' : '🚇 지하철 지도 (OpenStreetMap)'),
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
                  case 'switch_map':
                    setState(() {
                      _useNaverMap = !_useNaverMap;
                      _loadAttempts = 0;
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initializeWebView();
                    break;
                }
              } catch (e) {
                print('❌ 메뉴 액션 오류: $e');
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
              PopupMenuItem(
                value: 'switch_map',
                child: Row(
                  children: [
                    Icon(Icons.map, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(_useNaverMap ? 'OpenStreetMap으로 전환' : '네이버 지도로 전환'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          if (_showStationSearch)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.surface,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '🔍 지하철역을 검색하세요...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (value) {
                  print('🔍 역 검색: $value');
                },
              ),
            ),
          
          // 노선 필터
          _buildLineFilter(),
          
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
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 64,
                              color: Colors.orange.shade400,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    _useNaverMap = !_useNaverMap;
                                    _loadAttempts = 0;
                                    _errorMessage = null;
                                    _isLoading = true;
                                  });
                                  _initializeWebView();
                                },
                                icon: const Icon(Icons.swap_horiz),
                                label: Text(_useNaverMap ? 'OpenStreetMap' : '네이버 지도'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SpinKitWave(
                            color: AppColors.primary,
                            size: 50.0,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _useNaverMap 
                                ? '🗺️ 네이버 지도를 불러오고 있습니다...'
                                : '🗺️ OpenStreetMap을 불러오고 있습니다...',
                            style: AppTextStyles.bodyMedium,
                          ),
                          if (_loadAttempts > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '시도 횟수: $_loadAttempts/$_maxLoadAttempts',
                                style: AppTextStyles.caption,
                              ),
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
    );
  }
}
