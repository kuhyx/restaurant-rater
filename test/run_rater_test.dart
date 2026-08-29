/// Startup end to end: real bootstrap, real widget tree, mocked channels.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:restaurant_rater/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `runRater` reaches three platform surfaces: application support (for the
  // log file and the photo directory), SharedPreferences (for this install's
  // device id) and the keystore (for a sync session).
  //
  // An unanswered channel does not throw here -- it HANGS. The
  // MissingPluginException that would end it is delivered by the real event
  // loop, which `testWidgets`'s fake clock never pumps, so the await never
  // completes and the whole file times out. A hung file writes no coverage at
  // all, which is exactly how a startup path silently drops out of the report.
  //
  // SharedPreferences goes through `setMockInitialValues` rather than a raw
  // MethodChannel handler: the plugin now talks to a per-platform channel
  // whose name is not the legacy `plugins.flutter.io/shared_preferences`, so
  // mocking that name answers nothing and the await hangs anyway.
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('rater-run');
    PathProviderPlatform.instance = _FakePathProvider(support.path);
    // First launch: no stored device id, so one is generated and written back.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // No stored session: the device reads as not enrolled, which is a normal
    // state and keeps the suite off the network entirely.
    messenger.setMockMethodCallHandler(secureChannel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    support.deleteSync(recursive: true);
  });

  testWidgets('runRater builds the real tree on a fresh install', (
    tester,
  ) async {
    // Inside runAsync: runRater awaits real file IO and real platform calls,
    // and a future created under the widget tester's fake clock never
    // progresses -- awaiting it directly hangs the file rather than failing it.
    await tester.runAsync(runRater);
    await tester.pump();

    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('No restaurants yet'), findsOneWidget);
  });

  testWidgets('the first launch creates the photo directory', (tester) async {
    await tester.runAsync(runRater);
    await tester.pump();

    expect(
      Directory('${support.path}/photos').existsSync(),
      isTrue,
      reason: 'PhotoStore.open creates it rather than failing on first save',
    );
  });
}

/// Answers `getApplicationSupportDirectory` with a temp directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}
