import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink/main.dart';

void main() {
  testWidgets('home screen shows camera and monitor entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AetherLinkApp());

    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('Open camera'), findsOneWidget);
    expect(find.text('Open monitor'), findsOneWidget);
  });
}
