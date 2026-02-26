import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings =
      LeakTesting.settings.withIgnored(createdByTestHelpers: true);

  // Avoid matcher.expect outside a running test case while still failing
  // the run if global leak collection finds problems.
  LeakTesting.collectedLeaksReporter = (Leaks leaks) {
    if (leaks.total == 0) {
      return;
    }
    throw StateError(
      'Leak tracking found ${leaks.total} leak(s).\n'
      '${leaks.toYaml(phasesAreTests: true)}',
    );
  };

  await testMain();
  await maybeTearDownLeakTrackingForAll();
}
