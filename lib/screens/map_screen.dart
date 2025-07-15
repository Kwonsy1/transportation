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
import 'debug_console_screen.dart';

/// 통합 네이버 지도 화면 (향상된 지하철역 표시)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedLine = 'all'; // 선택된 노선 (all, 1, 2, 3, ...)
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
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🌐 페이지 로딩 시작: $url');
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            print('✅ 페이지 로딩 완료: $url');
            setState(() {
              _isLoading = false;
            });
            // 지도 준비 대기 후 로드
            Future.delayed(const Duration(milliseconds: 2000), () {
              _loadMapWithCurrentLocation();
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView 리소스 오류: ${error.description}');
            setState(() {
              _isLoading = false;
              _errorMessage = '지도를 불러오는데 실패했습니다: ${error.description}';
            });
          },
        ),
      )
      // JavaScript 채널 추가 - 역 클릭 이벤트 수신
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
          DebugConsole.info('🔍 [MAP] ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'ErrorLog',
        onMessageReceived: (JavaScriptMessage message) {
          print('❌ 지하철역 마커 로드 오류: ${message.message}');
          DebugConsole.error('🚨 [MAP ERROR] ${message.message}');
        },
      )
      ..loadHtmlString(_getMapHtml());
  }

  /// 역 클릭 이벤트 처리
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

  String _getMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no">
    <title>지하철 지도</title>
    <script type="text/javascript" src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpClientId=${ApiConstants.naverMapClientId}"></script>
    <style>
        body { margin: 0; padding: 0; font-family: 'Noto Sans KR', Arial, sans-serif; }
        #map { width: 100%; height: 100vh; }
        .loading { 
            position: absolute; 
            top: 50%; 
            left: 50%; 
            transform: translate(-50%, -50%);
            text-align: center;
            z-index: 1000;
            background: rgba(255,255,255,0.95);
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .station-marker {
            cursor: pointer;
            transition: transform 0.2s ease;
        }
        .station-marker:hover {
            transform: scale(1.1);
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div id="loading" class="loading">
        <div>지도를 로드하고 있습니다...</div>
    </div>
    <script>
        var map;
        var markers = [];
        var infoWindows = [];
        var isMapReady = false;
        var currentLocationMarker = null;
        
        // 네이버 지도 API 로드 대기
        function waitForNaverMaps(callback) {
            if (typeof naver !== 'undefined' && naver.maps && naver.maps.Map) {
                callback();
            } else {
                setTimeout(function() {
                    waitForNaverMaps(callback);
                }, 100);
            }
        }
        
        // 지도 초기화
        function initMap(lat, lng) {
            try {
                var loadingDiv = document.getElementById('loading');
                if (loadingDiv) {
                    loadingDiv.style.display = 'none';
                }
                
                var mapOptions = {
                    center: new naver.maps.LatLng(lat || 37.5665, lng || 126.9780),
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
                
                console.log('지도 초기화 완료');
            } catch (error) {
                console.error('지도 초기화 오류:', error);
                var loadingDiv = document.getElementById('loading');
                if (loadingDiv) {
                    loadingDiv.innerHTML = '<div>지도 로드에 실패했습니다.</div>';
                }
            }
        }
        
        // 현재 위치 마커 추가
        function addCurrentLocationMarker(lat, lng) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                // 기존 현재 위치 마커 제거
                if (currentLocationMarker) {
                    currentLocationMarker.setMap(null);
                }
                
                currentLocationMarker = new naver.maps.Marker({
                    position: new naver.maps.LatLng(lat, lng),
                    map: map,
                    icon: {
                        content: '<div style="background-color: #4285F4; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); animation: pulse 2s infinite;"></div><style>@keyframes pulse { 0% { transform: scale(1); } 50% { transform: scale(1.2); } 100% { transform: scale(1); } }</style>',
                        anchor: new naver.maps.Point(10, 10)
                    }
                });
                
                var infoWindow = new naver.maps.InfoWindow({
                    content: '<div style="padding: 10px; font-size: 12px;">📍 현재 위치</div>'
                });
                
                naver.maps.Event.addListener(currentLocationMarker, 'click', function() {
                    if (infoWindow.getMap()) {
                        infoWindow.close();
                    } else {
                        infoWindow.open(map, currentLocationMarker);
                    }
                });
                
                console.log('현재 위치 마커 추가 완료');
            } catch (error) {
                console.error('현재 위치 마커 추가 오류:', error);
            }
        }
        
        // 지하철역 마커 추가 (개선된 오류 처리)
        function addSubwayStations(stationsData, filterLine) {
            try {
                if (!isMapReady || !map) {
                    log('지도가 준비되지 않아 지하철역 마커 추가 불가');
                    return;
                }
                
                log('지하철역 마커 추가 시작');
                
                // 기존 지하철 마커만 제거 (현재 위치 마커는 유지)
                clearSubwayMarkers();
                
                // 데이터 유효성 검증
                var stations;
                if (typeof stationsData === 'string') {
                    try {
                        stations = JSON.parse(stationsData);
                    } catch (parseError) {
                        logError('JSON 파싱 오류: ' + parseError.message);
                        return;
                    }
                } else if (Array.isArray(stationsData)) {
                    stations = stationsData;
                } else {
                    logError('유효하지 않은 역 데이터 형식');
                    return;
                }
                
                if (!Array.isArray(stations) || stations.length === 0) {
                    log('유효한 역 데이터가 없음');
                    return;
                }
                
                // 노선 필터링
                var filteredStations = stations;
                if (filterLine && filterLine !== 'all') {
                    filteredStations = stations.filter(function(station) {
                        return station && station.lineNumber === filterLine;
                    });
                }
                
                log('필터된 역 수: ' + filteredStations.length);
                
                var successCount = 0;
                var errorCount = 0;
                
                // 역 마커 생성
                filteredStations.forEach(function(station, index) {
                    try {
                        if (!station || !station.latitude || !station.longitude || !station.stationName) {
                            errorCount++;
                            return;
                        }
                        
                        var lat = parseFloat(station.latitude);
                        var lng = parseFloat(station.longitude);
                        
                        if (isNaN(lat) || isNaN(lng)) {
                            errorCount++;
                            return;
                        }
                        
                        createStationMarker(station, lat, lng);
                        successCount++;
                        
                    } catch (markerError) {
                        errorCount++;
                        log('마커 생성 오류 (역: ' + (station ? station.stationName || 'Unknown' : 'Invalid') + '): ' + markerError.message);
                    }
                });
                
                log('지하철역 마커 추가 완료 - 성공: ' + successCount + '개, 실패: ' + errorCount + '개');
                
            } catch (error) {
                logError('지하철역 마커 추가 전체 오류: ' + error.message);
            }
        }
        
        // 개별 역 마커 생성
        function createStationMarker(station, lat, lng) {
            var color = getLineColor(station.lineNumber || '1');
            var textColor = '#ffffff';
            
            var marker = new naver.maps.Marker({
                position: new naver.maps.LatLng(lat, lng),
                map: map,
                icon: {
                    content: '<div class="station-marker" style="background: linear-gradient(145deg, ' + color + ', ' + darkenColor(color, 0.15) + '); color: ' + textColor + '; padding: 6px 10px; border-radius: 20px; font-size: 12px; font-weight: bold; box-shadow: 0 3px 8px rgba(0,0,0,0.3); border: 2px solid white; min-width: 24px; text-align: center;">' + (station.lineNumber || '?') + '</div>',
                    anchor: new naver.maps.Point(20, 15)
                }
            });
            
            var infoWindow = new naver.maps.InfoWindow({
                content: createInfoWindowContent(station, color)
            });
            
            // 마커 클릭 이벤트
            naver.maps.Event.addListener(marker, 'click', function() {
                closeAllInfoWindows();
                infoWindow.open(map, marker);
                
                // 역 정보를 Flutter로 전달
                var stationData = [
                    station.stationName || 'Unknown',
                    station.lineName || 'Unknown Line',
                    station.lineNumber || '1',
                    'STATION_' + (station.stationName ? station.stationName.replace('역', '') : 'Unknown') + '_' + (station.lineNumber || '1'),
                    lat.toString(),
                    lng.toString()
                ].join('|');
                
                if (window.StationClick && window.StationClick.postMessage) {
                    window.StationClick.postMessage(stationData);
                }
            });
            
            // 마커 호버 효과
            naver.maps.Event.addListener(marker, 'mouseover', function() {
                if (!infoWindow.getMap()) {
                    infoWindow.open(map, marker);
                }
            });
            
            markers.push(marker);
            infoWindows.push(infoWindow);
        }
        
        // 정보창 콘텐츠 생성
        function createInfoWindowContent(station, color) {
            return '<div style="padding: 15px; min-width: 150px; font-family: Noto Sans KR, Arial;">' +
                   '<div style="font-size: 16px; font-weight: bold; margin-bottom: 5px;">' + (station.stationName || 'Unknown') + '</div>' +
                   '<div style="color: ' + color + '; font-weight: 600; margin-bottom: 8px;">' + (station.lineName || 'Unknown Line') + '</div>' +
                   '<div style="font-size: 12px; color: #666; border-top: 1px solid #eee; padding-top: 8px;">🚇 클릭하여 상세정보 보기</div>' +
                   '</div>';
        }
        
        // 로그 함수
        function log(message) {
            console.log(message);
            if (window.ConsoleLog && window.ConsoleLog.postMessage) {
                window.ConsoleLog.postMessage(message);
            }
        }
        
        // 에러 로그 함수
        function logError(message) {
            console.error(message);
            if (window.ErrorLog && window.ErrorLog.postMessage) {
                window.ErrorLog.postMessage(message);
            }
        }
        
        // 호선별 색상 (더 풍부한 색상)
        function getLineColor(lineNumber) {
            var colors = {
                '1': '#263c96',    // 1호선 - 진남색
                '2': '#00a650',    // 2호선 - 녹색  
                '3': '#ef7c1c',    // 3호선 - 주황색
                '4': '#00a4e3',    // 4호선 - 하늘색
                '5': '#996cac',    // 5호선 - 보라색
                '6': '#cd7c2f',    // 6호선 - 갈색
                '7': '#747f00',    // 7호선 - 올리브색
                '8': '#e6186c',    // 8호선 - 분홍색
                '9': '#bdb092',    // 9호선 - 베이지색
                '공항철도': '#0d9488', // 공항철도 - 청록색
                '경의중앙': '#06b6d4', // 경의중앙선 - 하늘색
                '분당': '#f59e0b',     // 분당선 - 노란색
                '신분당': '#dc2626'    // 신분당선 - 빨간색
            };
            return colors[lineNumber] || '#6b7280';
        }
        
        // 텍스트 색상 결정
        function getTextColor(lineNumber) {
            var darkLines = ['1', '7', '9', '6'];
            return darkLines.includes(lineNumber) ? '#ffffff' : '#ffffff';
        }
        
        // 색상 어둡게 하기
        function darkenColor(color, factor) {
            var f = parseInt(color.slice(1), 16);
            var R = f >> 16;
            var G = f >> 8 & 0x00FF;
            var B = f & 0x0000FF;
            return "#" + (0x1000000 + (Math.round((1 - factor) * R) << 16) + (Math.round((1 - factor) * G) << 8) + Math.round((1 - factor) * B)).toString(16).slice(1);
        }
        
        // 지하철 마커만 제거 (현재 위치 마커 유지)
        function clearSubwayMarkers() {
            try {
                markers.forEach(function(marker) {
                    if (marker && marker.setMap) {
                        marker.setMap(null);
                    }
                });
                markers = [];
                closeAllInfoWindows();
                console.log('지하철 마커 제거 완료');
            } catch (error) {
                console.error('지하철 마커 제거 오류:', error);
            }
        }
        
        // 모든 마커 제거 (현재 위치 포함)
        function clearAllMarkers() {
            try {
                clearSubwayMarkers();
                if (currentLocationMarker) {
                    currentLocationMarker.setMap(null);
                    currentLocationMarker = null;
                }
                console.log('모든 마커 제거 완료');
            } catch (error) {
                console.error('모든 마커 제거 오류:', error);
            }
        }
        
        // 모든 정보창 닫기
        function closeAllInfoWindows() {
            try {
                infoWindows.forEach(function(infoWindow) {
                    if (infoWindow && infoWindow.close) {
                        infoWindow.close();
                    }
                });
            } catch (error) {
                console.error('정보창 닫기 오류:', error);
            }
        }
        
        // 지도 중심 이동
        function moveToLocation(lat, lng, zoom) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                map.setCenter(new naver.maps.LatLng(lat, lng));
                if (zoom) {
                    map.setZoom(zoom);
                }
                console.log('지도 이동 완료:', lat, lng);
            } catch (error) {
                console.error('지도 이동 오류:', error);
            }
        }
        
        // 특정 역으로 이동
        function moveToStation(stationName) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                // 역 찾기
                for (var i = 0; i < markers.length; i++) {
                    var marker = markers[i];
                    // 마커에서 역명 정보를 가져와야 하는데, 여기서는 간단히 처리
                    // 실제로는 마커에 메타데이터를 저장해서 사용해야 함
                }
                
                console.log('역 검색:', stationName);
            } catch (error) {
                console.error('역 이동 오류:', error);
            }
        }
        
        // 지도 새로고침
        function refreshMap() {
            try {
                if (map) {
                    map.destroy();
                }
                isMapReady = false;
                markers = [];
                infoWindows = [];
                currentLocationMarker = null;
                
                var loadingDiv = document.getElementById('loading');
                if (loadingDiv) {
                    loadingDiv.style.display = 'block';
                    loadingDiv.innerHTML = '<div>지도를 다시 로드하고 있습니다...</div>';
                }
                
                setTimeout(function() {
                    initMap();
                }, 500);
                
                console.log('지도 새로고침 시작');
            } catch (error) {
                console.error('지도 새로고침 오류:', error);
            }
        }
        
        // 에러 처리
        window.addEventListener('error', function(e) {
            var errorMsg = 'JavaScript 에러: ' + (e.error ? e.error.message : e.message);
            logError(errorMsg);
        });
        
        // 네이버 지도 API 로드 대기 후 초기화
        waitForNaverMaps(function() {
            log('네이버 지도 API 로드 완료');
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
      
      // 지도가 준비될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;
        
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap($lat, $lng); }'
        );
        
        // 확장된 지하철역 로드
        await _loadEnhancedSubwayStations();
      } else {
        // 위치 정보가 없으면 서울시청으로 초기화
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap(37.5665, 126.9780); }'
        );
        
        // 기본 위치에서도 지하철역 표시
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
      
      // 확장된 지하철역 데이터 로드
      await locationProvider.loadEnhancedStations();
      
      final stations = locationProvider.allEnhancedStations;
      
      if (stations.isNotEmpty) {
        // 안전한 JSON 생성
        final stationsJsonList = stations.map((station) => {
          'stationName': _sanitizeString(station.stationName),
          'lineName': _sanitizeString(station.lineName),
          'lineNumber': _sanitizeString(station.lineNumber),
          'latitude': station.latitude,
          'longitude': station.longitude,
        }).toList();
        
        // JavaScript로 전달할 안전한 문자열 생성
        final stationsJsonString = _createSafeJsonString(stationsJsonList);
        
        print('🚇 지하철역 데이터 전달 시작: ${stationsJsonList.length}개');
        
        await _webViewController.runJavaScript(
          'try { '
          'if (typeof addSubwayStations === "function") { '
          'addSubwayStations($stationsJsonString, "$_selectedLine"); '
          '} else { '
          'console.log("addSubwayStations 함수가 정의되지 않음"); '
          '} '
          '} catch (e) { '
          'console.error("지하철역 추가 오류:", e.message); '
          'if (window.ErrorLog) window.ErrorLog.postMessage("지하철역 추가 오류: " + e.message); '
          '}'
        );
      } else {
        print('⚠️ 지하철역 데이터가 없음');
      }
    } catch (e) {
      print('❌ 지하철역 마커 로드 오류: $e');
      setState(() {
        _errorMessage = '지하철역 데이터를 불러오는데 실패했습니다.';
      });
    }
  }

  // 문자열 안전하게 처리
  String _sanitizeString(String? input) {
    if (input == null) return '';
    return input
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  // 안전한 JSON 문자열 생성
  String _createSafeJsonString(List<Map<String, dynamic>> data) {
    final buffer = StringBuffer('[');
    
    for (int i = 0; i < data.length; i++) {
      if (i > 0) buffer.write(',');
      
      final item = data[i];
      buffer.write('{');
      buffer.write('"stationName":"${item['stationName']}",');
      buffer.write('"lineName":"${item['lineName']}",');
      buffer.write('"lineNumber":"${item['lineNumber']}",');
      buffer.write('"latitude":${item['latitude']},');
      buffer.write('"longitude":${item['longitude']}');
      buffer.write('}');
    }
    
    buffer.write(']');
    return buffer.toString();
  }

  Future<void> _filterStationsByLine(String line) async {
    setState(() {
      _selectedLine = line;
    });
    
    try {
      final locationProvider = context.read<LocationProvider>();
      final stations = locationProvider.allEnhancedStations;
      
      if (stations.isNotEmpty) {
        final stationsJsonList = stations.map((station) => {
          'stationName': _sanitizeString(station.stationName),
          'lineName': _sanitizeString(station.lineName),
          'lineNumber': _sanitizeString(station.lineNumber),
          'latitude': station.latitude,
          'longitude': station.longitude,
        }).toList();
        
        final stationsJsonString = _createSafeJsonString(stationsJsonList);
        
        await _webViewController.runJavaScript(
          'try { '
          'if (typeof addSubwayStations === "function") { '
          'addSubwayStations($stationsJsonString, "$line"); '
          '} '
          '} catch (e) { '
          'console.error("노선 필터링 오류:", e.message); '
          '}'
        );
      }
    } catch (e) {
      print('❌ 노선 필터링 오류: $e');
    }
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
        await locationProvider.loadNearbyStations();
        await _loadMapWithCurrentLocation();
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

  Widget _buildLineFilter() {
    final lines = ['all', '1', '2', '3', '4', '5', '6', '7', '8', '9', '공항철도', '경의중앙', '분당', '신분당'];
    final lineNames = {
      'all': '전체',
      '1': '1호선',
      '2': '2호선', 
      '3': '3호선',
      '4': '4호선',
      '5': '5호선',
      '6': '6호선',
      '7': '7호선',
      '8': '8호선',
      '9': '9호선',
      '공항철도': '공항철도',
      '경의중앙': '경의중앙',
      '분당': '분당선',
      '신분당': '신분당선',
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
        title: const Text('지하철 지도'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showStationSearch ? Icons.close : Icons.search),
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
            onPressed: _getCurrentLocation,
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
                    await _webViewController.runJavaScript(
                      'if (typeof refreshMap === "function") { refreshMap(); }'
                    );
                    await Future.delayed(const Duration(milliseconds: 1500));
                    await _loadMapWithCurrentLocation();
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 'clear':
                    await _webViewController.runJavaScript(
                      'if (typeof clearSubwayMarkers === "function") { clearSubwayMarkers(); }'
                    );
                    break;
                  case 'show_all':
                    _filterStationsByLine('all');
                    break;
                  case 'debug':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DebugConsoleScreen(),
                      ),
                    );
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
                value: 'show_all',
                child: Row(
                  children: [
                    Icon(Icons.train),
                    SizedBox(width: 8),
                    Text('모든 역 표시'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear),
                    SizedBox(width: 8),
                    Text('역 마커 지우기'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('디버그 콘솔'),
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
                  hintText: '지하철역 검색...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (value) {
                  // 역 검색 구현
                  _searchStation(value);
                },
              ),
            ),
          
          // 노선 필터
          _buildLineFilter(),
          
          // 지도
          Expanded(
            child: Stack(
              children: [
                // 지도 WebView
                if (_errorMessage == null)
                  WebViewWidget(controller: _webViewController),
                
                // 에러 메시지
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                setState(() {
                                  _errorMessage = null;
                                  _isLoading = true;
                                });
                                await Future.delayed(const Duration(milliseconds: 500));
                                _initializeWebView();
                              } catch (e) {
                                print('다시 시도 오류: $e');
                                setState(() {
                                  _isLoading = false;
                                  _errorMessage = '다시 시도하는데 실패했습니다.';
                                });
                              }
                            },
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // 로딩 인디케이터
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
                            '지도를 불러오고 있습니다...',
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
      
      // 하단 정보 패널
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
            height: 80,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.train,
                      color: _getLineColor(_selectedLine),
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _selectedLine == 'all' 
                          ? '전체 지하철역 ${filteredStations.length}개'
                          : '${_getLineName(_selectedLine)} ${filteredStations.length}개',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLineColor(_selectedLine).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '역 클릭으로 상세정보',
                        style: AppTextStyles.caption.copyWith(
                          color: _getLineColor(_selectedLine),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '🚇 지하철역을 클릭하면 실시간 도착정보, 시간표, 출구정보를 확인할 수 있습니다',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
    // 역 검색 기능 구현
    print('역 검색: $query');
    // TODO: 실제 검색 로직 구현
  }
}