import 'dart:async';

// sqlite3 3.x ships its own native library through build hooks, on every desktop the tests run on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
