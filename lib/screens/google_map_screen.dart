import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';

/// Google Maps 지도 화면
class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    // 지도만 먼저 로딩 (위치와 분리)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMapOnly();
    });
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
            _loadMapOnly();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = '지도를 불러오는데 실패했습니다: ${error.description}';
            });
          },
        ),
      )
      ..loadHtmlString(_getMapHtml());
  }

  String _getMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>지하철 지도</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" 
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <style>
        body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
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
            min-width: 200px;
        }
        .loading .spinner {
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .error-text { color: #e74c3c; font-weight: bold; }
        .success-text { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div id="map"></div>
    <div id="loading" class="loading">
        <div class="spinner"></div>
        <div id="loading-text">지도를 로드하고 있습니다...</div>
    </div>
    
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" 
            integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    
    <script>
        var map;
        var markers = [];
        var isMapReady = false;
        var initAttempts = 0;
        var maxInitAttempts = 3;
        var userManuallyMoved = false; // 사용자가 수동으로 지도를 이동했는지 추적
        var autoLocationTracking = false; // 자동 위치 추적 여부
        var currentLocationMarker = null; // 현재 위치 마커 저장
        
        function updateLoadingText(text, isError = false, isSuccess = false) {
            var loadingTextDiv = document.getElementById('loading-text');
            if (loadingTextDiv) {
                loadingTextDiv.innerHTML = text;
                loadingTextDiv.className = isError ? 'error-text' : (isSuccess ? 'success-text' : '');
            }
        }
        
        function hideLoading() {
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) {
                setTimeout(function() {
                    loadingDiv.style.opacity = '0';
                    setTimeout(function() {
                        loadingDiv.style.display = 'none';
                    }, 300);
                }, 500);
            }
        }
        
        function showError(message) {
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) {
                loadingDiv.style.display = 'block';
                loadingDiv.style.opacity = '1';
                updateLoadingText(message, true);
                
                // 스피너 숨기기
                var spinner = loadingDiv.querySelector('.spinner');
                if (spinner) {
                    spinner.style.display = 'none';
                }
                
                // 3초 후 다시 시도 제안
                setTimeout(function() {
                    if (initAttempts < maxInitAttempts) {
                        updateLoadingText(message + '<br><br>3초 후 다시 시도합니다...', true);
                        setTimeout(function() {
                            retryMapInit();
                        }, 3000);
                    } else {
                        updateLoadingText(message + '<br><br>새로고침 버튼을 눌러주세요.', true);
                    }
                }, 2000);
            }
        }
        
        function retryMapInit() {
            initAttempts++;
            updateLoadingText('지도를 다시 로드하고 있습니다... (' + initAttempts + '/' + maxInitAttempts + ')');
            
            var spinner = document.querySelector('.spinner');
            if (spinner) {
                spinner.style.display = 'block';
            }
            
            setTimeout(function() {
                createMap();
            }, 1000);
        }
        
        // OpenStreetMap 기반 지도 초기화 (위치 없이)
        function initMap() {
            console.log('지도 초기화 시작 - 기본 위치 사용');
            initAttempts++;
            
            try {
                // Leaflet 라이브러리 로드 확인
                if (typeof L === 'undefined') {
                    console.error('Leaflet 라이브러리가 로드되지 않았습니다.');
                    showError('지도 라이브러리 로드에 실패했습니다.');
                    return;
                }
                
                updateLoadingText('지도를 생성하고 있습니다...');
                createMap();
                
            } catch (error) {
                console.error('지도 초기화 오류:', error);
                showError('지도 초기화에 실패했습니다.');
            }
        }
        
        function createMap() {
            try {
                var center = [37.5665, 126.9780]; // 서울시청 기본 위치
                console.log('지도 생성 중심점:', center);
                
                // 기존 지도가 있으면 제거
                if (map) {
                    map.remove();
                }
                
                // 지도 생성
                map = L.map('map', {
                    center: center,
                    zoom: 15,
                    zoomControl: true,
                    attributionControl: true
                });
                
                updateLoadingText('지도 타일을 로드하고 있습니다...');
                
                // OpenStreetMap 타일 레이어 추가
                var tileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 19,
                    minZoom: 10
                });
                
                // 타일 로딩 이벤트 처리
                var tilesLoaded = 0;
                var tilesTotal = 0;
                
                tileLayer.on('loading', function() {
                    console.log('타일 로딩 시작');
                });
                
                tileLayer.on('load', function() {
                    console.log('타일 로딩 완료');
                    updateLoadingText('지도 로드 완료!', false, true);
                    isMapReady = true;
                    
                    // 로딩 숨기기
                    hideLoading();
                });
                
                tileLayer.on('tileerror', function(e) {
                    console.warn('타일 로딩 오류:', e);
                });
                
                // 지도에 타일 레이어 추가
                tileLayer.addTo(map);
                
                // 사용자 드래그 이벤트 감지
                map.on('dragstart', function() {
                    console.log('사용자가 드래그 시작');
                    userManuallyMoved = true;
                    autoLocationTracking = false; // 자동 위치 추적 비활성화
                });
                
                map.on('drag', function() {
                    userManuallyMoved = true;
                });
                
                map.on('dragend', function() {
                    console.log('사용자 드래그 종료 - 수동 이동 플래그 설정');
                    userManuallyMoved = true;
                    autoLocationTracking = false; // 자동 위치 추적 완전 비활성화
                });
                
                // 지도 이벤트 처리 - 자동 현재위치 복귀 방지
                map.on('zoomend moveend', function() {
                    console.log('지도 이동/줌 완료 - 수동이동:', userManuallyMoved, ', 자동추적:', autoLocationTracking);
                    // 사용자가 수동으로 이동한 경우 자동 위치 추적 비활성화 유지
                    if (userManuallyMoved) {
                        autoLocationTracking = false;
                        console.log('사용자 수동 이동 감지 - 자동 복귀 방지');
                    }
                });
                
                // 타임아웃 설정 (10초)
                setTimeout(function() {
                    if (!isMapReady) {
                        console.warn('지도 로딩 타임아웃');
                        showError('지도 로딩에 시간이 너무 오래 걸립니다.');
                    }
                }, 10000);
                
                console.log('지도 초기화 성공');
                
            } catch (error) {
                console.error('지도 생성 오류:', error);
                showError('지도 생성에 실패했습니다: ' + error.message);
            }
        }
        
        function showError(message) {
            console.error('에러 표시:', message);
            var loadingDiv = document.getElementById('loading');
            if (loadingDiv) {
                loadingDiv.style.display = 'block';
                loadingDiv.style.opacity = '1';
                updateLoadingText(message, true);
                
                // 스피너 숨기기
                var spinner = loadingDiv.querySelector('.spinner');
                if (spinner) {
                    spinner.style.display = 'none';
                }
            }
        }
        
        // 화면 범위 내에 위치가 있는지 체크
        function isLocationInViewBounds(lat, lng) {
            try {
                if (!isMapReady || !map) {
                    return false;
                }
                
                var bounds = map.getBounds();
                var point = L.latLng(lat, lng);
                var inBounds = bounds.contains(point);
                
                console.log('위치 범위 체크:', lat, lng, '범위 내:', inBounds);
                return inBounds;
            } catch (error) {
                console.error('범위 체크 오류:', error);
                return false;
            }
        }
        
        // 현재 위치 마커 추가 (화면 범위 체크 포함)
        function addCurrentLocationMarker(lat, lng, forceAdd = false) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                // 강제 추가가 아닌 경우 화면 범위 체크
                if (!forceAdd && !isLocationInViewBounds(lat, lng)) {
                    console.log('현재 위치가 화면 범위를 벗어나서 마커를 표시하지 않습니다.');
                    return;
                }
                
                // 기존 현재 위치 마커 제거
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
                currentLocationMarker.bindPopup('현재 위치').openPopup();
                
                console.log('현재 위치 마커 추가 완료');
            } catch (error) {
                console.error('현재 위치 마커 추가 오류:', error);
            }
        }
        
        // 지하철역 마커 추가
        function addSubwayStations(stations) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                clearMarkers();
                
                if (!stations || !Array.isArray(stations)) {
                    console.log('역 데이터가 유효하지 않음');
                    return;
                }
                
                stations.forEach(function(station) {
                    if (station.latitude && station.longitude) {
                        var color = getLineColor(station.lineNumber);
                        
                        var stationIcon = L.divIcon({
                            className: 'subway-station-marker',
                            html: '<div style="background-color: ' + color + '; color: white; padding: 5px 8px; border-radius: 15px; font-size: 12px; font-weight: bold; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">' + station.lineNumber + '</div>',
                            iconSize: [40, 30],
                            iconAnchor: [20, 15]
                        });
                        
                        var marker = L.marker([station.latitude, station.longitude], {icon: stationIcon}).addTo(map);
                        
                        var popupContent = '<div style="padding: 10px; min-width: 120px;"><strong>' + station.stationName + '</strong><br><span style="color: ' + color + ';">' + station.lineName + '</span></div>';
                        marker.bindPopup(popupContent);
                        
                        markers.push(marker);
                    }
                });
                
                console.log('지하철역 마커 추가 완료:', stations.length, '개');
            } catch (error) {
                console.error('지하철역 마커 추가 오류:', error);
            }
        }
        
        // 호선별 색상
        function getLineColor(lineNumber) {
            var colors = {
                '1': '#263c96',
                '2': '#00a650',
                '3': '#ef7c1c',
                '4': '#00a4e3',
                '5': '#996cac',
                '6': '#cd7c2f',
                '7': '#747f00',
                '8': '#e6186c',
                '9': '#bdb092'
            };
            return colors[lineNumber] || '#757575';
        }
        
        // 모든 마커 제거 (현재 위치 마커 제외)
        function clearMarkers() {
            try {
                markers.forEach(function(marker) {
                    if (marker && map) {
                        map.removeLayer(marker);
                    }
                });
                markers = [];
                console.log('마커 제거 완료');
            } catch (error) {
                console.error('마커 제거 오류:', error);
            }
        }
        
        // 지도 중심 이동 (사용자 수동 이동시 자동 복귀 방지)
        function moveToLocation(lat, lng, zoom) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return;
                }
                
                console.log('moveToLocation 호출 - 자동추적 재활성화');
                // 내 위치 버튼을 누른 경우만 자동 추적 재활성화
                userManuallyMoved = false;
                autoLocationTracking = true;
                
                // 지도 중심 이동
                map.setView([lat, lng], zoom || 15);
                
                // 현재 위치 마커 추가/업데이트 (강제 추가)
                addCurrentLocationMarker(lat, lng, true);
                
                console.log('지도 이동 완료:', lat, lng);
            } catch (error) {
                console.error('지도 이동 오류:', error);
            }
        }
        
        // 현재 위치 체크 및 조건부 마커 추가
        function checkAndAddLocationMarker(lat, lng) {
            try {
                if (!isMapReady || !map) {
                    console.log('지도가 준비되지 않음');
                    return false;
                }
                
                // 화면 범위 내에 있는지 체크
                if (isLocationInViewBounds(lat, lng)) {
                    addCurrentLocationMarker(lat, lng, false);
                    console.log('화면 범위 내 위치 - 마커 추가');
                    return true;
                } else {
                    console.log('화면 범위 밖 위치 - 마커 추가 안함');
                    return false;
                }
            } catch (error) {
                console.error('위치 체크 오류:', error);
                return false;
            }
        }
        
        // 지도 새로고침
        function refreshMap() {
            try {
                clearMarkers();
                
                var loadingDiv = document.getElementById('loading');
                if (loadingDiv) {
                    loadingDiv.style.display = 'block';
                    loadingDiv.innerHTML = '<div>지도를 새로고침하고 있습니다...</div>';
                }
                
                setTimeout(function() {
                    if (map) {
                        map.invalidateSize();
                    }
                    var loadingDiv = document.getElementById('loading');
                    if (loadingDiv) {
                        loadingDiv.style.display = 'none';
                    }
                }, 1000);
                
                console.log('지도 새로고침 완료');
            } catch (error) {
                console.error('지도 새로고침 오류:', error);
            }
        }
        
        // 페이지 로드 완료 후 지도 초기화
        document.addEventListener('DOMContentLoaded', function() {
            console.log('DOM 로드 완료, 지도 초기화 대기 중...');
            // 약간의 지연 후 초기화 (라이브러리 완전 로드 대기)
            setTimeout(function() {
                initMap();
            }, 500);
        });
        
        // 백업: DOMContentLoaded가 이미 발생했을 경우
        if (document.readyState === 'loading') {
            // 아직 로딩 중
        } else {
            // 이미 로드 완료
            setTimeout(function() {
                initMap();
            }, 500);
        }
    </script>
</body>
</html>
    ''';
  }

  // 지도만 로딩 (위치 없이)
  Future<void> _loadMapOnly() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('지도만 로딩 - 기본 위치 사용'); // 디버깅
      
      await _webViewController.runJavaScript(
        'if (typeof initMap === "function") { initMap(); }'
      );
    } catch (e) {
      print('지도 로드 오류: $e');
      setState(() {
        _errorMessage = '지도를 불러오는데 실패했습니다.';
      });
    }
  }
  
  // 지도 초기화 (위치 없이)
  Future<void> _initializeMapOnly() async {
    // 지도만 먼저 로딩
    // 위치는 별도의 사용자 액션으로만 처리
  }
  
  // 현재 위치 체크 및 조건부 마커 표시
  Future<void> _checkAndShowLocationMarker() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      
      if (locationProvider.currentPosition != null) {
        final lat = locationProvider.currentPosition!.latitude;
        final lng = locationProvider.currentPosition!.longitude;
        
        print('위치 마커 체크: $lat, $lng'); // 디버깅
        
        await _webViewController.runJavaScript(
          'if (typeof checkAndAddLocationMarker === "function") { checkAndAddLocationMarker($lat, $lng); }'
        );
        
        if (locationProvider.nearbyStations.isNotEmpty) {
          await _loadSubwayStations();
        }
      }
    } catch (e) {
      print('위치 마커 체크 오류: $e');
    }
  }
  
  // 기존 함수 - 호환성을 위해 유지하지만 사용하지 않음
  Future<void> _loadMapWithCurrentLocation() async {
    // 더 이상 사용하지 않음 - 위치와 지도 로딩을 분리
    print('경고: _loadMapWithCurrentLocation은 더 이상 사용되지 않습니다.');
  }

  // 위치만 가져오기 (지도 로딩과 분리)
  Future<void> _requestLocationOnly() async {
    try {
      print('위치만 가져오기 시작'); // 디버깅
      
      final locationProvider = context.read<LocationProvider>();
      
      // 위치 서비스 상태 초기화
      await locationProvider.initializeLocationStatus();
      
      print('위치 권한: ${locationProvider.hasLocationPermission}'); // 디버깅
      print('위치 서비스: ${locationProvider.isLocationServiceEnabled}'); // 디버깅
      
      // 위치 권한이 없는 경우 요청
      if (!locationProvider.hasLocationPermission) {
        final granted = await locationProvider.requestLocationPermission();
        print('위치 권한 요청 결과: $granted'); // 디버깅
        
        if (!granted) {
          print('위치 권한 거부됨 - 위치 서비스 사용 안함');
          return;
        }
      }
      
      // 현재 위치 가져오기
      await locationProvider.getCurrentLocation();
      
      if (locationProvider.currentPosition != null) {
        print('현재 위치 가져오기 성공'); // 디버깅
        // 주변 역 로드
        await locationProvider.loadNearbyStations();
        
        // 위치 마커 체크 및 조건부 표시
        await _checkAndShowLocationMarker();
      } else {
        print('현재 위치 가져오기 실패'); // 디버깅
      }
      
    } catch (e) {
      print('위치 요청 오류: $e');
    }
  }
  
  // 기존 함수 - 호환성을 위해 유지
  Future<void> _requestLocationAndLoadMap() async {
    await _requestLocationOnly();
  }

  Future<void> _loadSubwayStations() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      final stations = locationProvider.nearbyStations;
      
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
          'if (typeof addSubwayStations === "function") { addSubwayStations($stationsJsonString); }'
        );
      }
    } catch (e) {
      print('지하철역 마커 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지하철 지도 (OpenStreetMap)'),
        actions: [
          // 현재 위치 체크 버튼 (화면 범위 내에서만 마커 표시)
          IconButton(
            icon: const Icon(Icons.location_searching),
            tooltip: '현재 위치 체크',
            onPressed: () async {
              try {
                final locationProvider = context.read<LocationProvider>();
                
                // 위치 권한 확인 및 요청
                if (!locationProvider.hasLocationPermission) {
                  final granted = await locationProvider.requestLocationPermission();
                  if (!granted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('위치 권한이 필요합니다.')),
                    );
                    return;
                  }
                }
                
                // 현재 위치 가져오기
                await locationProvider.getCurrentLocation();
                
                if (locationProvider.currentPosition != null) {
                  // 주변 역 로드
                  await locationProvider.loadNearbyStations();
                  
                  // 화면 범위 체크 및 조건부 마커 표시
                  await _checkAndShowLocationMarker();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('현재 위치를 체크했습니다.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('현재 위치를 가져올 수 없습니다.')),
                  );
                }
              } catch (e) {
                print('위치 체크 오류: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('위치 체크에 실패했습니다.')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  setState(() {
                    _isLoading = true;
                  });
                  await _webViewController.runJavaScript(
                    'if (typeof refreshMap === "function") { refreshMap(); }'
                  );
                  // 지도만 새로고침 (위치는 별도 처리)
                  await _loadMapOnly();
                  setState(() {
                    _isLoading = false;
                  });
                  break;
                case 'clear':
                  await _webViewController.runJavaScript(
                    'if (typeof clearMarkers === "function") { clearMarkers(); }'
                  );
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
          if (_errorMessage == null)
            WebViewWidget(controller: _webViewController),
          
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
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeWebView();
                        setState(() {
                          _isLoading = false;
                        });
                      },
                      child: const Text('다시 시도'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 위치 권한 관련 에러일 때 추가 버튼
                    if (_errorMessage!.contains('권한') || _errorMessage!.contains('위치'))
                      TextButton(
                        onPressed: () async {
                          final locationProvider = context.read<LocationProvider>();
                          await locationProvider.requestLocationPermission();
                          if (locationProvider.hasLocationPermission) {
                            setState(() {
                              _errorMessage = null;
                            });
                            // 위치만 가져오기 (지도는 이미 로드된 상태)
                            await _requestLocationOnly();
                          }
                        },
                        child: const Text('위치 권한 설정'),
                      ),
                  ],
                ),
              ),
            ),
          
          // 내 위치 버튼을 우측하단에 배치
          Positioned(
            right: 16,
            bottom: 100, // 하단 내비게이션 바 위에 배치
            child: FloatingActionButton(
              heroTag: "location_button",
              onPressed: () async {
                try {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  
                  print('위치 버튼 클릭'); // 디버깅
                  
                  final locationProvider = context.read<LocationProvider>();
                  
                  // 위치 권한 확인 및 요청
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
                    
                    print('위치 버튼: 현재 위치 $lat, $lng로 이동'); // 디버깅
                    
                    // 지도 중심을 현재 위치로 이동 (강제 이동 - 내 위치 버튼)
                    await _webViewController.runJavaScript(
                      'if (typeof moveToLocation === "function") { moveToLocation($lat, $lng, 17); }'
                    );
                    
                    // 주변 역 로드
                    await locationProvider.loadNearbyStations();
                    if (locationProvider.nearbyStations.isNotEmpty) {
                      await _loadSubwayStations();
                    }
                    
                  } else {
                    setState(() {
                      _errorMessage = '현재 위치를 가져올 수 없습니다. GPS가 켜져 있는지 확인해주세요.';
                    });
                  }
                  
                  setState(() {
                    _isLoading = false;
                  });
                  
                } catch (e) {
                  print('위치 버튼 오류: $e');
                  setState(() {
                    _isLoading = false;
                    _errorMessage = '위치 서비스를 사용할 수 없습니다.';
                  });
                }
              },
              mini: false,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location),
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
                      '지도를 불러오고 있습니다...',
                      style: AppTextStyles.bodyMedium,
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
