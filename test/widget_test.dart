// Transportation 앱을 위한 기본 위젯 테스트
//
// 위젯과의 상호작용을 테스트하려면 flutter_test 패키지의 WidgetTester를 사용하세요.
// 예를 들어, 탭 및 스크롤 제스처를 보낼 수 있습니다. WidgetTester를 사용하여
// 위젯 트리에서 하위 위젯을 찾고, 텍스트를 읽고, 위젯 속성 값이 올바른지 확인할 수도 있습니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transportation/main.dart';

void main() {
  testWidgets('Transportation app smoke test', (WidgetTester tester) async {
    // 앱을 빌드하고 프레임을 트리거합니다.
    await tester.pumpWidget(const TransportationApp());

    // 기본 화면 요소들이 있는지 확인합니다.
    expect(find.text('지하철 정보 앱'), findsOneWidget);
    
    // 하단 네비게이션 바가 있는지 확인합니다.
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    
    // 네비게이션 탭들이 있는지 확인합니다.
    expect(find.text('역 검색'), findsOneWidget);
    expect(find.text('주변 역'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('즐겨찾기'), findsOneWidget);
  });

  testWidgets('Navigation test', (WidgetTester tester) async {
    // 앱을 빌드합니다.
    await tester.pumpWidget(const TransportationApp());

    // 하단 네비게이션의 두 번째 탭(주변 역)을 탭합니다.
    await tester.tap(find.text('주변 역'));
    await tester.pump();

    // 주변 역 화면으로 전환되었는지 확인합니다.
    expect(find.text('주변 지하철역'), findsOneWidget);
  });

  testWidgets('Search screen test', (WidgetTester tester) async {
    // 앱을 빌드합니다.
    await tester.pumpWidget(const TransportationApp());

    // 검색 화면이 기본으로 표시되는지 확인합니다.
    expect(find.text('지하철 역 검색'), findsOneWidget);
    
    // 검색 텍스트 필드가 있는지 확인합니다.
    expect(find.byType(TextField), findsOneWidget);
    
    // 검색 힌트 텍스트가 있는지 확인합니다.
    expect(find.text('역 이름을 입력하세요 (예: 강남)'), findsOneWidget);
  });
}
