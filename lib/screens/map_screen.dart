import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';
import '../providers/location_provider.dart';
import '../providers/subway_provider.dart';

/// 네이버 지도 화면
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
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
      ..loadHtmlString(_getMapHtml());
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
        body { margin: 0; padding: 0; }
        #map { width: 100%; height: 100vh; }
        .loading { 
            position: absolute; 
            top: 50%; 
            left: 50%; 
            transform: translate(-50%, -50%);
            text-align: center;
            font-family: Arial, sans-serif;
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
                    center: new naver.maps.LatLng(lat || 37.5665, lng || 126.9780), // 기본값: 서울시청
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
                
                var marker = new naver.maps.Marker({
                    position: new naver.maps.LatLng(lat, lng),
                    map: map,
                    icon: {
                        content: '<div style="background-color: #4285F4; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>',
                        anchor: new naver.maps.Point(10, 10)
                    }
                });
                
                var infoWindow = new naver.maps.InfoWindow({
                    content: '<div style="padding: 10px; font-size: 12px;">현재 위치</div>'
                });
                
                naver.maps.Event.addListener(marker, 'click', function() {
                    if (infoWindow.getMap()) {
                        infoWindow.close();
                    } else {
                        infoWindow.open(map, marker);
                    }
                });
                
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
                
                // 기존 마커 제거
                clearMarkers();
                
                if (!stations || !Array.isArray(stations)) {
                    console.log('역 데이터가 유효하지 않음');
                    return;
                }
                
                stations.forEach(function(station) {
                    if (station.latitude && station.longitude) {
                        var marker = new naver.maps.Marker({
                            position: new naver.maps.LatLng(station.latitude, station.longitude),
                            map: map,
                            icon: {
                                content: '<div style="background-color: ' + getLineColor(station.lineNumber) + '; color: white; padding: 5px 8px; border-radius: 15px; font-size: 12px; font-weight: bold; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">' + station.lineNumber + '</div>',
                                anchor: new naver.maps.Point(20, 15)
                            }
                        });
                        
                        var infoWindow = new naver.maps.InfoWindow({
                            content: '<div style="padding: 10px; min-width: 120px;"><strong>' + station.stationName + '</strong><br><span style="color: ' + getLineColor(station.lineNumber) + ';">' + station.lineName + '</span></div>'
                        });
                        
                        naver.maps.Event.addListener(marker, 'click', function() {
                            closeAllInfoWindows();
                            infoWindow.open(map, marker);
                        });
                        
                        markers.push(marker);
                        infoWindows.push(infoWindow);
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
        
        // 모든 마커 제거
        function clearMarkers() {
            try {
                markers.forEach(function(marker) {
                    if (marker && marker.setMap) {
                        marker.setMap(null);
                    }
                });
                markers = [];
                closeAllInfoWindows();
                console.log('마커 제거 완료');
            } catch (error) {
                console.error('마커 제거 오류:', error);
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
        
        // 지도 새로고침
        function refreshMap() {
            try {
                if (map) {
                    map.destroy();
                }
                isMapReady = false;
                markers = [];
                infoWindows = [];
                
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
        
        // 네이버 지도 API 로드 대기 후 초기화
        waitForNaverMaps(function() {
            console.log('네이버 지도 API 로드 완료');
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
        
        // 주변 지하철역도 표시
        if (locationProvider.nearbyStations.isNotEmpty) {
          await _loadSubwayStations();
        }
      } else {
        // 위치 정보가 없으면 서울시청으로 초기화
        await _webViewController.runJavaScript(
          'if (typeof initMap === "function") { initMap(37.5665, 126.9780); }'
        );
      }
    } catch (e) {
      print('지도 로드 오류: $e');
      setState(() {
        _errorMessage = '지도를 불러오는데 실패했습니다.';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지하철 지도'),
        actions: [
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
                      'if (typeof clearMarkers === "function") { clearMarkers(); }'
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
                            try {
                              if (station.latitude != null && station.longitude != null) {
                                await _webViewController.runJavaScript(
                                  'if (typeof moveToLocation === "function") { moveToLocation(${station.latitude}, ${station.longitude}, 17); }'
                                );
                              }
                            } catch (e) {
                              print('지도 이동 오류: $e');
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
}
