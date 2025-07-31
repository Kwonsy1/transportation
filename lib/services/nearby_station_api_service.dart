
import '../models/subway_station.dart';
import 'http_service.dart';
import '../constants/api_constants.dart';

class NearbyStationApiService {
  final HttpService _httpService = HttpService();

  Future<List<SubwayStation>> getNearbyStations({
    required double tmX,
    required double tmY,
    int radius = 1000,
  }) async {
    final params = {
      'serviceKey': ApiConstants.subwayApiKey,
      'tmX': tmX,
      'tmY': tmY,
      'radius': radius,
    };

    // The API endpoint from swagger is /getNearbyStatio, but this seems like a typo.
    // I will assume the correct endpoint is /getNearbyStations
    final response = await _httpService.get('/getNearbyStations', params: params);

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['data'];
      return data.map((item) => SubwayStation.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load nearby stations');
    }
  }
}
