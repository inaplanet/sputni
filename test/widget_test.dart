import 'package:flutter_test/flutter_test.dart';

import 'package:teleck/main.dart';

void main() {
  testWidgets('home screen shows camera and monitor entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TeleckApp());

    expect(find.text('Teleck'), findsOneWidget);
    expect(find.text('Open camera'), findsOneWidget);
    expect(find.text('Open monitor'), findsOneWidget);
  });
}
