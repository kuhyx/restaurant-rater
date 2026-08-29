/// Entry point.
library;

import 'package:restaurant_rater/app.dart';

// coverage:ignore-line
// A Dart entry point is never invoked by flutter_test, so this line cannot be
// covered by construction. It is kept to exactly one statement for that
// reason: everything it delegates to -- runRater, bootstrap, RaterApp -- is
// ordinary code with ordinary tests.
Future<void> main() => runRater(); // coverage:ignore-line
