import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/subway_station.dart';
import '../services/location_service.dart';
import '../services/subway_api_service.dart';

/// 확장된 위치 정보 상태 관리 Provider (더 많은 지하철역 데이터 포함)
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService.instance;
  final SubwayApiService _subwayApiService = SubwayApiService();

  // 서울시 전체 지하철역 좌표 데이터 (확장판)
  static const Map<String, Map<String, dynamic>> _seoulStationCoordinates = {
    // 1호선
    '서울역': {'lat': 37.5546, 'lng': 126.9707, 'lines': ['1', '4', '경의중앙', '공항철도']},
    '시청역': {'lat': 37.5657, 'lng': 126.9769, 'lines': ['1', '2']},
    '종각역': {'lat': 37.5703, 'lng': 126.9826, 'lines': ['1']},
    '종로3가역': {'lat': 37.5706, 'lng': 126.9915, 'lines': ['1', '3', '5']},
    '종로5가역': {'lat': 37.5717, 'lng': 127.0017, 'lines': ['1']},
    '동대문역': {'lat': 37.5717, 'lng': 127.0092, 'lines': ['1', '4']},
    '신설동역': {'lat': 37.5750, 'lng': 127.0253, 'lines': ['1', '2']},
    '제기동역': {'lat': 37.5781, 'lng': 127.0364, 'lines': ['1']},
    '청량리역': {'lat': 37.5800, 'lng': 127.0478, 'lines': ['1', '경의중앙']},
    '동묘앞역': {'lat': 37.5712, 'lng': 127.0145, 'lines': ['1', '6']},
    '용산역': {'lat': 37.5299, 'lng': 126.9648, 'lines': ['1', '경의중앙']},
    '노량진역': {'lat': 37.5144, 'lng': 126.9422, 'lines': ['1', '9']},
    '대방역': {'lat': 37.5133, 'lng': 126.9267, 'lines': ['1']},
    '신도림역': {'lat': 37.5087, 'lng': 126.8913, 'lines': ['1', '2']},
    '구로역': {'lat': 37.5030, 'lng': 126.8818, 'lines': ['1']},
    '가산디지털단지역': {'lat': 37.4817, 'lng': 126.8827, 'lines': ['1', '7']},
    '금천구청역': {'lat': 37.4569, 'lng': 126.8955, 'lines': ['1']},
    '석수역': {'lat': 37.4353, 'lng': 126.8969, 'lines': ['1']},
    '관악역': {'lat': 37.4765, 'lng': 126.9816, 'lines': ['1']},

    // 2호선
    '강남역': {'lat': 37.4979, 'lng': 127.0276, 'lines': ['2', '신분당']},
    '역삼역': {'lat': 37.5000, 'lng': 127.0364, 'lines': ['2']},
    '선릉역': {'lat': 37.5044, 'lng': 127.0489, 'lines': ['2', '분당']},
    '삼성역': {'lat': 37.5090, 'lng': 127.0633, 'lines': ['2']},
    '종합운동장역': {'lat': 37.5115, 'lng': 127.0734, 'lines': ['2', '9']},
    '삼전역': {'lat': 37.5067, 'lng': 127.0831, 'lines': ['2']},
    '잠실나루역': {'lat': 37.5202, 'lng': 127.1032, 'lines': ['2']},
    '잠실역': {'lat': 37.5132, 'lng': 127.1000, 'lines': ['2', '8']},
    '잠실새내역': {'lat': 37.5118, 'lng': 127.0927, 'lines': ['2']},
    '건대입구역': {'lat': 37.5401, 'lng': 127.0699, 'lines': ['2', '7']},
    '구의역': {'lat': 37.5370, 'lng': 127.0851, 'lines': ['2']},
    '강변역': {'lat': 37.5345, 'lng': 127.0945, 'lines': ['2']},
    '신촌역': {'lat': 37.5561, 'lng': 126.9364, 'lines': ['2']},
    '이대역': {'lat': 37.5569, 'lng': 126.9456, 'lines': ['2']},
    '아현역': {'lat': 37.5577, 'lng': 126.9566, 'lines': ['2']},
    '충정로역': {'lat': 37.5596, 'lng': 126.9635, 'lines': ['2', '5']},
    '을지로입구역': {'lat': 37.5660, 'lng': 126.9822, 'lines': ['2']},
    '을지로3가역': {'lat': 37.5665, 'lng': 126.9915, 'lines': ['2', '3']},
    '을지로4가역': {'lat': 37.5667, 'lng': 126.9984, 'lines': ['2', '5']},
    '동대문역사문화공원역': {'lat': 37.5665, 'lng': 127.0079, 'lines': ['2', '4', '5']},
    '신당역': {'lat': 37.5656, 'lng': 127.0180, 'lines': ['2', '6']},
    '상왕십리역': {'lat': 37.5614, 'lng': 127.0293, 'lines': ['2']},
    '왕십리역': {'lat': 37.5610, 'lng': 127.0379, 'lines': ['2', '5', '경의중앙', '분당']},
    '한양대역': {'lat': 37.5556, 'lng': 127.0438, 'lines': ['2']},
    '뚝섬역': {'lat': 37.5474, 'lng': 127.0474, 'lines': ['2']},
    '성수역': {'lat': 37.5445, 'lng': 127.0557, 'lines': ['2']},
    '홍대입구역': {'lat': 37.5563, 'lng': 126.9243, 'lines': ['2', '6', '공항철도', '경의중앙']},
    '합정역': {'lat': 37.5497, 'lng': 126.9138, 'lines': ['2', '6']},
    '당산역': {'lat': 37.5345, 'lng': 126.9025, 'lines': ['2', '9']},
    '영등포구청역': {'lat': 37.5244, 'lng': 126.8962, 'lines': ['2', '5']},
    '문래역': {'lat': 37.5185, 'lng': 126.8950, 'lines': ['2']},
    '대림역': {'lat': 37.4930, 'lng': 126.8958, 'lines': ['2', '7']},
    '구로디지털단지역': {'lat': 37.4853, 'lng': 126.9013, 'lines': ['2']},
    '신대방역': {'lat': 37.4873, 'lng': 126.9130, 'lines': ['2']},
    '신림역': {'lat': 37.4843, 'lng': 126.9296, 'lines': ['2']},
    '봉천역': {'lat': 37.4816, 'lng': 126.9426, 'lines': ['2']},
    '서울대입구역': {'lat': 37.4813, 'lng': 126.9527, 'lines': ['2']},
    '낙성대역': {'lat': 37.4766, 'lng': 126.9630, 'lines': ['2']},
    '사당역': {'lat': 37.4767, 'lng': 126.9816, 'lines': ['2', '4']},
    '방배역': {'lat': 37.4817, 'lng': 127.0017, 'lines': ['2']},
    '서초역': {'lat': 37.4837, 'lng': 127.0119, 'lines': ['2']},
    '교대역': {'lat': 37.4928, 'lng': 127.0143, 'lines': ['2', '3']},

    // 3호선
    '압구정역': {'lat': 37.5273, 'lng': 127.0287, 'lines': ['3']},
    '신사역': {'lat': 37.5164, 'lng': 127.0206, 'lines': ['3']},
    '잠원역': {'lat': 37.5116, 'lng': 127.0117, 'lines': ['3']},
    '고속터미널역': {'lat': 37.5048, 'lng': 127.0051, 'lines': ['3', '7', '9']},
    '남부터미널역': {'lat': 37.4764, 'lng': 127.0063, 'lines': ['3']},
    '양재역': {'lat': 37.4674, 'lng': 127.0347, 'lines': ['3', '신분당']},
    '매봉역': {'lat': 37.4599, 'lng': 127.0378, 'lines': ['3']},
    '도곡역': {'lat': 37.4914, 'lng': 127.0516, 'lines': ['3']},
    '대치역': {'lat': 37.4951, 'lng': 127.0627, 'lines': ['3']},
    '학여울역': {'lat': 37.4929, 'lng': 127.0816, 'lines': ['3']},
    '대청역': {'lat': 37.4935, 'lng': 127.0920, 'lines': ['3']},
    '일원역': {'lat': 37.4869, 'lng': 127.0969, 'lines': ['3']},
    '수서역': {'lat': 37.4874, 'lng': 127.1008, 'lines': ['3', '분당']},
    '가락시장역': {'lat': 37.4924, 'lng': 127.1179, 'lines': ['3', '8']},
    '경찰병원역': {'lat': 37.4943, 'lng': 127.1267, 'lines': ['3']},
    '오금역': {'lat': 37.5026, 'lng': 127.1283, 'lines': ['3', '5']},
    '충무로역': {'lat': 37.5615, 'lng': 126.9946, 'lines': ['3', '4']},
    '동대입구역': {'lat': 37.5583, 'lng': 126.9754, 'lines': ['3', '6']},
    '약수역': {'lat': 37.5544, 'lng': 127.0096, 'lines': ['3', '6']},
    '금고개역': {'lat': 37.5492, 'lng': 127.0144, 'lines': ['3']},
    '옥수역': {'lat': 37.5404, 'lng': 127.0172, 'lines': ['3']},
    '안국역': {'lat': 37.5763, 'lng': 126.9850, 'lines': ['3']},
    '경복궁역': {'lat': 37.5759, 'lng': 126.9732, 'lines': ['3']},
    '독립문역': {'lat': 37.5747, 'lng': 126.9558, 'lines': ['3']},
    '무악재역': {'lat': 37.5823, 'lng': 126.9532, 'lines': ['3']},
    '홍제역': {'lat': 37.5896, 'lng': 126.9415, 'lines': ['3']},
    '녹번역': {'lat': 37.5999, 'lng': 126.9298, 'lines': ['3']},
    '불광역': {'lat': 37.6108, 'lng': 126.9298, 'lines': ['3', '6']},
    '연신내역': {'lat': 37.6191, 'lng': 126.9212, 'lines': ['3', '6']},
    '구파발역': {'lat': 37.6369, 'lng': 126.9203, 'lines': ['3']},
    '지축역': {'lat': 37.6475, 'lng': 126.9158, 'lines': ['3']},

    // 4호선
    '명동역': {'lat': 37.5636, 'lng': 126.9866, 'lines': ['4']},
    '회현역': {'lat': 37.5591, 'lng': 126.9785, 'lines': ['4']},
    '숙대입구역': {'lat': 37.5446, 'lng': 126.9689, 'lines': ['4']},
    '삼각지역': {'lat': 37.5347, 'lng': 126.9729, 'lines': ['4', '6']},
    '신용산역': {'lat': 37.5299, 'lng': 126.9648, 'lines': ['4']},
    '이촌역': {'lat': 37.5219, 'lng': 126.9758, 'lines': ['4']},
    '동작역': {'lat': 37.5127, 'lng': 126.9797, 'lines': ['4', '9']},
    '총신대입구역': {'lat': 37.5016, 'lng': 126.9853, 'lines': ['4', '7']},
    '남태령역': {'lat': 37.4635, 'lng': 126.9889, 'lines': ['4']},
    '혜화역': {'lat': 37.5821, 'lng': 127.0021, 'lines': ['4']},
    '한성대입구역': {'lat': 37.5889, 'lng': 127.0062, 'lines': ['4']},
    '성신여대입구역': {'lat': 37.5924, 'lng': 127.0167, 'lines': ['4']},
    '길음역': {'lat': 37.6025, 'lng': 127.0258, 'lines': ['4']},
    '미아역': {'lat': 37.6136, 'lng': 127.0306, 'lines': ['4']},
    '미아사거리역': {'lat': 37.6136, 'lng': 127.0306, 'lines': ['4']},
    '수유역': {'lat': 37.6376, 'lng': 127.0254, 'lines': ['4']},
    '쌍문역': {'lat': 37.6507, 'lng': 127.0373, 'lines': ['4']},
    '창동역': {'lat': 37.6536, 'lng': 127.0470, 'lines': ['4']},
    '노원역': {'lat': 37.6541, 'lng': 127.0618, 'lines': ['4', '7']},
    '상계역': {'lat': 37.6546, 'lng': 127.0627, 'lines': ['4']},
    '당고개역': {'lat': 37.6703, 'lng': 127.0668, 'lines': ['4']},

    // 5호선  
    '방화역': {'lat': 37.5784, 'lng': 126.8126, 'lines': ['5']},
    '김포공항역': {'lat': 37.5623, 'lng': 126.8014, 'lines': ['5', '9', '공항철도']},
    '송정역': {'lat': 37.5499, 'lng': 126.8171, 'lines': ['5']},
    '마곡역': {'lat': 37.5598, 'lng': 126.8248, 'lines': ['5']},
    '발산역': {'lat': 37.5584, 'lng': 126.8377, 'lines': ['5']},
    '우장산역': {'lat': 37.5501, 'lng': 126.8358, 'lines': ['5']},
    '화곡역': {'lat': 37.5411, 'lng': 126.8407, 'lines': ['5']},
    '까치산역': {'lat': 37.5308, 'lng': 126.8456, 'lines': ['5']},
    '신정역': {'lat': 37.5247, 'lng': 126.8565, 'lines': ['5']},
    '목동역': {'lat': 37.5266, 'lng': 126.8649, 'lines': ['5']},
    '오목교역': {'lat': 37.5244, 'lng': 126.8754, 'lines': ['5']},
    '양평역(5호선)': {'lat': 37.5218, 'lng': 126.8906, 'lines': ['5']},
    '영등포시장역': {'lat': 37.5266, 'lng': 126.9057, 'lines': ['5']},
    '신길역': {'lat': 37.5178, 'lng': 126.9140, 'lines': ['5']},
    '여의도역': {'lat': 37.5219, 'lng': 126.9245, 'lines': ['5', '9']},
    '여의나루역': {'lat': 37.5267, 'lng': 126.9344, 'lines': ['5']},
    '마포역': {'lat': 37.5444, 'lng': 126.9456, 'lines': ['5']},
    '공덕역': {'lat': 37.5448, 'lng': 126.9516, 'lines': ['5', '6', '경의중앙', '공항철도']},
    '애오개역': {'lat': 37.5516, 'lng': 126.9556, 'lines': ['5']},
    '서대문역': {'lat': 37.5656, 'lng': 126.9366, 'lines': ['5']},
    '광화문역': {'lat': 37.5720, 'lng': 126.9762, 'lines': ['5']},
    '청구역': {'lat': 37.5601, 'lng': 127.0153, 'lines': ['5', '6']},
    '신금호역': {'lat': 37.5453, 'lng': 127.0174, 'lines': ['5']},
    '행당역': {'lat': 37.5566, 'lng': 127.0236, 'lines': ['5']},
    '마장역': {'lat': 37.5661, 'lng': 127.0443, 'lines': ['5']},
    '답십리역': {'lat': 37.5666, 'lng': 127.0543, 'lines': ['5']},
    '장한평역': {'lat': 37.5612, 'lng': 127.0643, 'lines': ['5']},
    '군자역': {'lat': 37.5574, 'lng': 127.0794, 'lines': ['5', '7']},
    '아차산역': {'lat': 37.5557, 'lng': 127.0910, 'lines': ['5']},
    '광나루역': {'lat': 37.5450, 'lng': 127.1050, 'lines': ['5']},
    '천호역': {'lat': 37.5387, 'lng': 127.1236, 'lines': ['5', '8']},
    '강동역': {'lat': 37.5269, 'lng': 127.1265, 'lines': ['5']},
    '길동역': {'lat': 37.5300, 'lng': 127.1443, 'lines': ['5']},
    '굽은다리역': {'lat': 37.5267, 'lng': 127.1522, 'lines': ['5']},
    '명일역': {'lat': 37.5511, 'lng': 127.1472, 'lines': ['5']},
    '고덕역': {'lat': 37.5553, 'lng': 127.1543, 'lines': ['5']},
    '상일동역': {'lat': 37.5567, 'lng': 127.1670, 'lines': ['5']},
    '마천역': {'lat': 37.4942, 'lng': 127.1477, 'lines': ['5']},

    // 6호선
    '응암역': {'lat': 37.6022, 'lng': 126.9134, 'lines': ['6']},
    '역촌역': {'lat': 37.5998, 'lng': 126.9269, 'lines': ['6']},
    '구산역': {'lat': 37.6102, 'lng': 126.9037, 'lines': ['6']},
    '새절역': {'lat': 37.5996, 'lng': 126.8873, 'lines': ['6']},
    '증산역': {'lat': 37.5899, 'lng': 126.8949, 'lines': ['6']},
    '디지털미디어시티역': {'lat': 37.5768, 'lng': 126.9003, 'lines': ['6', '공항철도', '경의중앙']},
    '월드컵경기장역': {'lat': 37.5679, 'lng': 126.9003, 'lines': ['6']},
    '마포구청역': {'lat': 37.5637, 'lng': 126.9058, 'lines': ['6']},
    '망원역': {'lat': 37.5555, 'lng': 126.9104, 'lines': ['6']},
    '상수역': {'lat': 37.5479, 'lng': 126.9227, 'lines': ['6']},
    '대흥역': {'lat': 37.5570, 'lng': 126.9589, 'lines': ['6']},
    '효창공원앞역': {'lat': 37.5398, 'lng': 126.9609, 'lines': ['6']},
    '녹사평역': {'lat': 37.5346, 'lng': 126.9879, 'lines': ['6']},
    '이태원역': {'lat': 37.5346, 'lng': 126.9946, 'lines': ['6']},
    '한강진역': {'lat': 37.5319, 'lng': 127.0050, 'lines': ['6']},
    '버티고개역': {'lat': 37.5408, 'lng': 127.0079, 'lines': ['6']},
    '창신역': {'lat': 37.5760, 'lng': 127.0174, 'lines': ['6']},
    '보문역': {'lat': 37.5837, 'lng': 127.0172, 'lines': ['6']},
    '안암역': {'lat': 37.5858, 'lng': 127.0297, 'lines': ['6']},
    '고려대역': {'lat': 37.5890, 'lng': 127.0326, 'lines': ['6']},
    '월곡역': {'lat': 37.6008, 'lng': 127.0319, 'lines': ['6']},
    '상월곡역': {'lat': 37.6069, 'lng': 127.0337, 'lines': ['6']},
    '돌곶이역': {'lat': 37.6124, 'lng': 127.0412, 'lines': ['6']},
    '석계역': {'lat': 37.6175, 'lng': 127.0488, 'lines': ['6']},
    '태릉입구역': {'lat': 37.6240, 'lng': 127.0567, 'lines': ['6', '7']},
    '화랑대역': {'lat': 37.6346, 'lng': 127.0631, 'lines': ['6']},
    '봉화산역': {'lat': 37.6449, 'lng': 127.0706, 'lines': ['6']},

    // 7호선
    '장암역': {'lat': 37.6458, 'lng': 126.8345, 'lines': ['7']},
    '도봉산역': {'lat': 37.6689, 'lng': 127.0471, 'lines': ['1', '7']},
    '수락산역': {'lat': 37.6377, 'lng': 127.0771, 'lines': ['7']},
    '마들역': {'lat': 37.6298, 'lng': 127.0594, 'lines': ['7']},
    '중계역': {'lat': 37.6412, 'lng': 127.0726, 'lines': ['7']},
    '하계역': {'lat': 37.6374, 'lng': 127.0700, 'lines': ['7']},
    '공릉역': {'lat': 37.6254, 'lng': 127.0730, 'lines': ['7']},
    '먹골역': {'lat': 37.6175, 'lng': 127.0773, 'lines': ['7']},
    '중화역': {'lat': 37.6068, 'lng': 127.0779, 'lines': ['7']},
    '상봉역': {'lat': 37.5967, 'lng': 127.0858, 'lines': ['7', '경의중앙']},
    '면목역': {'lat': 37.5901, 'lng': 127.0897, 'lines': ['7']},
    '사가정역': {'lat': 37.5809, 'lng': 127.0890, 'lines': ['7']},
    '용마산역': {'lat': 37.5742, 'lng': 127.0856, 'lines': ['7']},
    '중곡역': {'lat': 37.5663, 'lng': 127.0824, 'lines': ['7']},
    '어린이대공원역': {'lat': 37.5480, 'lng': 127.0742, 'lines': ['7']},
    '뚝섬유원지역': {'lat': 37.5303, 'lng': 127.0667, 'lines': ['7']},
    '청담역': {'lat': 37.5197, 'lng': 127.0533, 'lines': ['7']},
    '강남구청역': {'lat': 37.5173, 'lng': 127.0417, 'lines': ['7']},
    '학동역': {'lat': 37.5142, 'lng': 127.0317, 'lines': ['7']},
    '논현역': {'lat': 37.5104, 'lng': 127.0221, 'lines': ['7']},
    '반포역': {'lat': 37.5048, 'lng': 127.0051, 'lines': ['7']},
    '내방역': {'lat': 37.4997, 'lng': 126.9966, 'lines': ['7']},
    '이수역': {'lat': 37.4863, 'lng': 126.9820, 'lines': ['7']},
    '남성역': {'lat': 37.4843, 'lng': 126.9583, 'lines': ['7']},
    '숭실대입구역': {'lat': 37.4965, 'lng': 126.9574, 'lines': ['7']},
    '상도역': {'lat': 37.5016, 'lng': 126.9477, 'lines': ['7']},
    '장승배기역': {'lat': 37.4845, 'lng': 126.9349, 'lines': ['7']},
    '신대방삼거리역': {'lat': 37.4873, 'lng': 126.9234, 'lines': ['7']},
    '보라매역': {'lat': 37.4939, 'lng': 126.9249, 'lines': ['7']},
    '신풍역': {'lat': 37.4887, 'lng': 126.9087, 'lines': ['7']},
    '남구로역': {'lat': 37.4860, 'lng': 126.8874, 'lines': ['7']},
    '철산역': {'lat': 37.4800, 'lng': 126.8700, 'lines': ['7']},
    '광명사거리역': {'lat': 37.4761, 'lng': 126.8649, 'lines': ['7']},
    '천왕역': {'lat': 37.4669, 'lng': 126.8621, 'lines': ['7']},
    '온수역': {'lat': 37.4402, 'lng': 126.8258, 'lines': ['7']},
    '까치울역': {'lat': 37.4348, 'lng': 126.8092, 'lines': ['7']},
    '부천종합운동장역': {'lat': 37.4347, 'lng': 126.7922, 'lines': ['7']},
    '춘의역': {'lat': 37.4379, 'lng': 126.7755, 'lines': ['7']},
    '신중동역': {'lat': 37.4388, 'lng': 126.7634, 'lines': ['7']},
    '부천시청역': {'lat': 37.4378, 'lng': 126.7519, 'lines': ['7']},
    '상동역': {'lat': 37.4379, 'lng': 126.7388, 'lines': ['7']},
    '삼산체육관역': {'lat': 37.4379, 'lng': 126.7298, 'lines': ['7']},
    '굴포천역': {'lat': 37.4421, 'lng': 126.7174, 'lines': ['7']},
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
    '산성역': {'lat': 37.4519, 'lng': 127.1374, 'lines': ['8']},
    '남한산성입구역': {'lat': 37.4448, 'lng': 127.1551, 'lines': ['8']},
    '단대오거리역': {'lat': 37.4398, 'lng': 127.1638, 'lines': ['8']},
    '신흥역': {'lat': 37.4313, 'lng': 127.1755, 'lines': ['8']},
    '수진역': {'lat': 37.4242, 'lng': 127.1886, 'lines': ['8']},
    '모란역': {'lat': 37.3932, 'lng': 127.1279, 'lines': ['8', '분당']},

    // 9호선
    '개화역': {'lat': 37.5784, 'lng': 126.7955, 'lines': ['9']},
    '공항시장역': {'lat': 37.5627, 'lng': 126.8121, 'lines': ['9']},
    '신방화역': {'lat': 37.5575, 'lng': 126.8137, 'lines': ['9']},
    '마곡나루역': {'lat': 37.5660, 'lng': 126.8248, 'lines': ['9']},
    '양천향교역': {'lat': 37.5516, 'lng': 126.8395, 'lines': ['9']},
    '가양역': {'lat': 37.5619, 'lng': 126.8554, 'lines': ['9']},
    '증미역': {'lat': 37.5686, 'lng': 126.8639, 'lines': ['9']},
    '등촌역': {'lat': 37.5505, 'lng': 126.8665, 'lines': ['9']},
    '염창역': {'lat': 37.5467, 'lng': 126.8745, 'lines': ['9']},
    '신목동역': {'lat': 37.5260, 'lng': 126.8745, 'lines': ['9']},
    '선유도역': {'lat': 37.5345, 'lng': 126.8936, 'lines': ['9']},
    '국회의사당역': {'lat': 37.5293, 'lng': 126.9179, 'lines': ['9']},
    '샛강역': {'lat': 37.5173, 'lng': 126.9388, 'lines': ['9']},
    '노들역': {'lat': 37.5185, 'lng': 126.9508, 'lines': ['9']},
    '흑석역': {'lat': 37.5080, 'lng': 126.9616, 'lines': ['9']},
    '구반포역': {'lat': 37.5167, 'lng': 126.9963, 'lines': ['9']},
    '신반포역': {'lat': 37.5042, 'lng': 126.9963, 'lines': ['9']},
    '사평역': {'lat': 37.4933, 'lng': 127.0093, 'lines': ['9']},
    '신논현역': {'lat': 37.4941, 'lng': 127.0251, 'lines': ['9']},
    '언주역': {'lat': 37.4849, 'lng': 127.0378, 'lines': ['9']},
    '선정릉역': {'lat': 37.5044, 'lng': 127.0489, 'lines': ['9', '분당']},
    '삼성중앙역': {'lat': 37.5090, 'lng': 127.0633, 'lines': ['9']},
    '석촌고분역': {'lat': 37.5014, 'lng': 127.0915, 'lines': ['9']},
    '송파나루역': {'lat': 37.5152, 'lng': 127.1103, 'lines': ['9']},
    '한성백제역': {'lat': 37.5205, 'lng': 127.1193, 'lines': ['9']},
    '올림픽공원역': {'lat': 37.5218, 'lng': 127.1242, 'lines': ['9']},
    '둔촌오륜역': {'lat': 37.5272, 'lng': 127.1364, 'lines': ['9']},
    '중앙보훈병원역': {'lat': 37.5618, 'lng': 127.1284, 'lines': ['9']},

    // 공항철도
    '인천국제공항역': {'lat': 37.4602, 'lng': 126.4407, 'lines': ['공항철도']},
    '인천공항2터미널역': {'lat': 37.4486, 'lng': 126.4520, 'lines': ['공항철도']},
    '운서역': {'lat': 37.4919, 'lng': 126.4930, 'lines': ['공항철도']},
    '영종역': {'lat': 37.5349, 'lng': 126.5581, 'lines': ['공항철도']},
    '청라국제도시역': {'lat': 37.5380, 'lng': 126.6472, 'lines': ['공항철도']},
    '검암역': {'lat': 37.5679, 'lng': 126.6235, 'lines': ['공항철도']},
    '계양역': {'lat': 37.5373, 'lng': 126.7375, 'lines': ['공항철도']},

    // 경의중앙선
    '수색역': {'lat': 37.5800, 'lng': 126.8950, 'lines': ['경의중앙']},
    '화전역': {'lat': 37.6344, 'lng': 126.8384, 'lines': ['경의중앙']},
    '행신역': {'lat': 37.6153, 'lng': 126.8356, 'lines': ['경의중앙']},
    '강매역': {'lat': 37.6050, 'lng': 126.8240, 'lines': ['경의중앙']},
    '곡산역': {'lat': 37.5936, 'lng': 126.8117, 'lines': ['경의중앙']},
    '백마역': {'lat': 37.5842, 'lng': 126.8018, 'lines': ['경의중앙']},
    '풍산역': {'lat': 37.5717, 'lng': 126.7942, 'lines': ['경의중앙']},
    '일산역': {'lat': 37.6589, 'lng': 126.7739, 'lines': ['경의중앙']},
    '탄현역': {'lat': 37.6681, 'lng': 126.7581, 'lines': ['경의중앙']},
    '야당역': {'lat': 37.6792, 'lng': 126.7433, 'lines': ['경의중앙']},
    '운정역': {'lat': 37.7443, 'lng': 126.7315, 'lines': ['경의중앙']},
    '금릉역': {'lat': 37.7617, 'lng': 126.7281, 'lines': ['경의중앙']},
    '금촌역': {'lat': 37.7546, 'lng': 126.7168, 'lines': ['경의중앙']},
    '월롱역': {'lat': 37.7373, 'lng': 126.7063, 'lines': ['경의중앙']},
    '파주역': {'lat': 37.7178, 'lng': 126.7007, 'lines': ['경의중앙']},
    '문산역': {'lat': 37.7600, 'lng': 126.7379, 'lines': ['경의중앙']},
    '서강대역': {'lat': 37.5497, 'lng': 126.9386, 'lines': ['경의중앙']},
    '가좌역': {'lat': 37.5700, 'lng': 126.9100, 'lines': ['경의중앙']},
    '회기역': {'lat': 37.5893, 'lng': 127.0578, 'lines': ['경의중앙']},
    '중랑역': {'lat': 37.5956, 'lng': 127.0742, 'lines': ['경의중앙']},
    '망우역': {'lat': 37.5987, 'lng': 127.0923, 'lines': ['경의중앙']},
    '양원역': {'lat': 37.6034, 'lng': 127.1043, 'lines': ['경의중앙']},
    '구리역': {'lat': 37.5939, 'lng': 127.1294, 'lines': ['경의중앙']},
    '도농역': {'lat': 37.5876, 'lng': 127.1574, 'lines': ['경의중앙']},
    '양정역': {'lat': 37.5795, 'lng': 127.1872, 'lines': ['경의중앙']},
    '덕소역': {'lat': 37.5789, 'lng': 127.2172, 'lines': ['경의중앙']},
    '도심역': {'lat': 37.5717, 'lng': 127.2434, 'lines': ['경의중앙']},
    '팔당역': {'lat': 37.5452, 'lng': 127.2644, 'lines': ['경의중앙']},
    '운길산역': {'lat': 37.5279, 'lng': 127.2793, 'lines': ['경의중앙']},
    '양수역': {'lat': 37.4851, 'lng': 127.2836, 'lines': ['경의중앙']},
    '신원역': {'lat': 37.4446, 'lng': 127.2859, 'lines': ['경의중앙']},
    '국수역': {'lat': 37.4125, 'lng': 127.2883, 'lines': ['경의중앙']},
    '아신역': {'lat': 37.3948, 'lng': 127.2972, 'lines': ['경의중앙']},
    '오빈역': {'lat': 37.3770, 'lng': 127.3051, 'lines': ['경의중앙']},
    '양평역(경의중앙)': {'lat': 37.4920, 'lng': 127.4886, 'lines': ['경의중앙']},
    '원덕역': {'lat': 37.3439, 'lng': 127.3364, 'lines': ['경의중앙']},
    '용문역': {'lat': 37.3133, 'lng': 127.5789, 'lines': ['경의중앙']},

    // 분당선
    '가천대역': {'lat': 37.4530, 'lng': 127.1289, 'lines': ['분당']},
    '태평역': {'lat': 37.4428, 'lng': 127.1298, 'lines': ['분당']},
    '야탑역': {'lat': 37.4114, 'lng': 127.1278, 'lines': ['분당']},
    '이매역': {'lat': 37.4020, 'lng': 127.1278, 'lines': ['분당']},
    '서현역': {'lat': 37.3856, 'lng': 127.1232, 'lines': ['분당']},
    '수내역': {'lat': 37.3836, 'lng': 127.1022, 'lines': ['분당']},
    '정자역': {'lat': 37.3653, 'lng': 127.1067, 'lines': ['분당']},
    '미금역': {'lat': 37.3499, 'lng': 127.1089, 'lines': ['분당']},
    '오리역': {'lat': 37.3397, 'lng': 127.1135, 'lines': ['분당']},
    '죽전역': {'lat': 37.3246, 'lng': 127.1067, 'lines': ['분당']},
    '보정역': {'lat': 37.3198, 'lng': 127.0853, 'lines': ['분당']},
    '구성역': {'lat': 37.3212, 'lng': 127.0637, 'lines': ['분당']},
    '신갈역': {'lat': 37.2916, 'lng': 127.0625, 'lines': ['분당']},
    '기흥역': {'lat': 37.2758, 'lng': 127.1159, 'lines': ['분당']},
    '상갈역': {'lat': 37.2407, 'lng': 127.1107, 'lines': ['분당']},
    '청명역': {'lat': 37.2291, 'lng': 127.0808, 'lines': ['분당']},
    '영통역': {'lat': 37.2844, 'lng': 127.0713, 'lines': ['분당']},
    '망포역': {'lat': 37.2497, 'lng': 127.0617, 'lines': ['분당']},
    '매탄권선역': {'lat': 37.2296, 'lng': 126.9859, 'lines': ['분당']},
    '수원역': {'lat': 37.2661, 'lng': 127.0016, 'lines': ['분당']},
    '서울숲역': {'lat': 37.5442, 'lng': 127.0441, 'lines': ['분당']},
    '압구정로데오역': {'lat': 37.5274, 'lng': 127.0408, 'lines': ['분당']},

    // 신분당선
    '양재시민의숲역': {'lat': 37.4700, 'lng': 127.0578, 'lines': ['신분당']},
    '청계산입구역': {'lat': 37.4258, 'lng': 127.0474, 'lines': ['신분당']},
    '판교역': {'lat': 37.3951, 'lng': 127.1116, 'lines': ['신분당']},
    '동천역': {'lat': 37.3372, 'lng': 127.1243, 'lines': ['신분당']},
    '수지구청역': {'lat': 37.3234, 'lng': 127.1260, 'lines': ['신분당']},
    '성복역': {'lat': 37.3173, 'lng': 127.1392, 'lines': ['신분당']},
    '상현역': {'lat': 37.2576, 'lng': 127.1359, 'lines': ['신분당']},
    '광교중앙역': {'lat': 37.2928, 'lng': 127.0595, 'lines': ['신분당']},
    '광교역': {'lat': 37.2847, 'lng': 127.0448, 'lines': ['신분당']},
  };

  // 현재 위치
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // 주변 역 목록
  List<SubwayStation> _nearbyStations = [];
  List<SubwayStation> get nearbyStations => _nearbyStations;

  // 전체 확장 역 목록
  List<SubwayStation> _allEnhancedStations = [];
  List<SubwayStation> get allEnhancedStations => _allEnhancedStations;

  // 전체 역 목록 (캐시용)
  List<SubwayStation> _allStations = [];
  bool _allStationsLoaded = false;

  // 위치 권한 상태
  bool _hasLocationPermission = false;
  bool get hasLocationPermission => _hasLocationPermission;

  // 위치 서비스 활성화 상태
  bool _isLocationServiceEnabled = false;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  // 로딩 상태
  bool _isLoadingLocation = false;
  bool _isLoadingNearbyStations = false;
  bool _isLoadingAllStations = false;
  bool _isLoadingEnhancedStations = false;

  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingNearbyStations => _isLoadingNearbyStations;
  bool get isLoadingAllStations => _isLoadingAllStations;
  bool get isLoadingEnhancedStations => _isLoadingEnhancedStations;

  // 에러 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 위치 권한 상태 초기화
  Future<void> initializeLocationStatus() async {
    try {
      _hasLocationPermission = await _locationService.checkLocationPermission();
      _isLocationServiceEnabled = await _locationService.isLocationServiceEnabled();
      notifyListeners();
    } catch (e) {
      _errorMessage = '위치 권한 상태 확인에 실패했습니다: ${e.toString()}';
      notifyListeners();
    }
  }

  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    try {
      _hasLocationPermission = await _locationService.requestLocationPermission();
      notifyListeners();
      return _hasLocationPermission;
    } catch (e) {
      _errorMessage = '위치 권한 요청에 실패했습니다: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// 현재 위치 가져오기
  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPosition = await _locationService.getCurrentPosition();
    } catch (e) {
      _errorMessage = '현재 위치를 가져오는데 실패했습니다: ${e.toString()}';
      _currentPosition = null;
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// 확장된 지하철역 데이터 로드
  Future<void> loadEnhancedStations() async {
    if (_allEnhancedStations.isNotEmpty) return;

    _isLoadingEnhancedStations = true;
    notifyListeners();

    try {
      _allEnhancedStations = [];
      
      _seoulStationCoordinates.forEach((stationName, coords) {
        // 각 호선별로 별도 역으로 생성
        for (String line in coords['lines']) {
          _allEnhancedStations.add(SubwayStation(
            subwayStationId: 'STATION_${stationName.replaceAll('역', '')}_$line',
            subwayStationName: stationName,
            subwayRouteName: _getLineFullName(line),
            latitude: coords['lat'],
            longitude: coords['lng'],
          ));
        }
      });

      print('확장된 지하철역 데이터 로드 완료: ${_allEnhancedStations.length}개');
    } catch (e) {
      _errorMessage = '확장된 지하철역 데이터 로드에 실패했습니다: ${e.toString()}';
      print('확장된 지하철역 데이터 로드 오류: $e');
    } finally {
      _isLoadingEnhancedStations = false;
      notifyListeners();
    }
  }

  /// 호선명을 전체 이름으로 변환
  String _getLineFullName(String line) {
    switch (line) {
      case '1': return '서울 1호선';
      case '2': return '서울 2호선';
      case '3': return '서울 3호선';
      case '4': return '서울 4호선';
      case '5': return '서울 5호선';
      case '6': return '서울 6호선';
      case '7': return '서울 7호선';
      case '8': return '서울 8호선';
      case '9': return '서울 9호선';
      case '공항철도': return '인천공항철도';
      case '경의중앙': return '경의중앙선';
      case '분당': return '분당선';
      case '신분당': return '신분당선';
      default: return '서울 ${line}호선';
    }
  }

  /// 전체 지하철역 목록 로드 (캐시)
  Future<void> _loadAllStations() async {
    if (_allStationsLoaded) return;

    _isLoadingAllStations = true;
    notifyListeners();

    try {
      _allStations = await _subwayApiService.getAllStations();
      _allStationsLoaded = true;
      print('전체 지하철역 로드 완료: ${_allStations.length}개');
    } catch (e) {
      _errorMessage = '지하철역 목록 로드에 실패했습니다: ${e.toString()}';
      print('전체 지하철역 로드 오류: $e');
    } finally {
      _isLoadingAllStations = false;
      notifyListeners();
    }
  }

  /// 주변 지하철역 검색
  Future<void> loadNearbyStations({int radius = 3000}) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
      if (_currentPosition == null) {
        print('현재 위치를 가져올 수 없어서 기본 위치(서울역) 사용');
        _currentPosition = Position(
          latitude: 37.5546,
          longitude: 126.9707,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    _isLoadingNearbyStations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 확장된 데이터 먼저 로드
      await loadEnhancedStations();
      
      // 좌표 기반으로 주변 역 찾기
      List<Map<String, dynamic>> nearbyStationsWithDistance = [];
      
      for (final station in _allEnhancedStations) {
        if (station.latitude != null && station.longitude != null) {
          final distance = _locationService.calculateDistance(
            startLatitude: _currentPosition!.latitude,
            startLongitude: _currentPosition!.longitude,
            endLatitude: station.latitude!,
            endLongitude: station.longitude!,
          );
          
          if (distance <= radius) {
            nearbyStationsWithDistance.add({
              'station': station,
              'distance': distance,
            });
          }
        }
      }
      
      // 거리순으로 정렬
      nearbyStationsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));
      
      // SubwayStation 리스트로 변환 (최대 20개)
      _nearbyStations = nearbyStationsWithDistance
          .take(20)
          .map((item) => item['station'] as SubwayStation)
          .toList();

      print('확장된 주변 지하철역 검색 완료: ${_nearbyStations.length}개');
      print('현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      if (_nearbyStations.isNotEmpty) {
        print('가장 가까운 역: ${_nearbyStations.first.subwayStationName}');
      }

    } catch (e) {
      _errorMessage = '주변 지하철역 검색에 실패했습니다: ${e.toString()}';
      _nearbyStations = [];
      print('주변 지하철역 검색 오류: $e');
    } finally {
      _isLoadingNearbyStations = false;
      notifyListeners();
    }
  }

  /// 두 지점 간 거리 계산 (실제 좌표 기반)
  double? calculateDistanceToStation(SubwayStation station) {
    if (_currentPosition == null) {
      return null;
    }

    // 역에 좌표 정보가 있는 경우 실제 거리 계산
    if (station.latitude != null && station.longitude != null) {
      return _locationService.calculateDistance(
        startLatitude: _currentPosition!.latitude,
        startLongitude: _currentPosition!.longitude,
        endLatitude: station.latitude!,
        endLongitude: station.longitude!,
      );
    }

    return null;
  }

  /// 거리를 읽기 쉬운 형태로 포맷팅
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 노선별 지하철역 필터링
  List<SubwayStation> getStationsByLine(String lineNumber) {
    return _allEnhancedStations
        .where((station) => station.lineNumber == lineNumber)
        .toList();
  }

  /// 역명으로 지하철역 검색
  List<SubwayStation> searchStationsByName(String query) {
    if (query.isEmpty) return [];
    
    return _allEnhancedStations
        .where((station) => 
            station.subwayStationName.contains(query) ||
            station.subwayRouteName.contains(query))
        .toList();
  }

  /// 위치 서비스 설정으로 이동
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// 앱 설정으로 이동
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 위치 정보 새로고침
  Future<void> refreshLocation() async {
    await getCurrentLocation();
    if (_currentPosition != null) {
      await loadNearbyStations();
    }
  }

  /// 실시간 위치 추적 시작
  void startLocationTracking() {
    _locationService.getPositionStream().listen(
      (position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '위치 추적 중 오류가 발생했습니다: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  /// 특정 역명으로 주변 역 필터링
  List<SubwayStation> filterStationsByName(String query) {
    if (query.isEmpty) return _nearbyStations;
    
    return _nearbyStations
        .where((station) => 
            station.subwayStationName.contains(query) ||
            station.subwayRouteName.contains(query))
        .toList();
  }

  /// 호선별 주변 역 필터링
  List<SubwayStation> filterStationsByLine(String lineNumber) {
    return _nearbyStations
        .where((station) => station.lineNumber == lineNumber)
        .toList();
  }

  /// 주변 역 목록 강제 새로고침
  Future<void> forceRefreshNearbyStations() async {
    _allStationsLoaded = false;
    _allStations.clear();
    _allEnhancedStations.clear();
    await loadNearbyStations();
  }
}