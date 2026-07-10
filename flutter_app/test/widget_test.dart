import 'package:flutter_test/flutter_test.dart';
import 'package:roboarm_flutter/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoboArmApp());
    expect(find.text('RoboArm'), findsOneWidget);
  });
}
