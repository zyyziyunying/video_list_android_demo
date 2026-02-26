import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgets(
    'smoke test harness runs',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(SizedBox), findsOneWidget);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );
}
