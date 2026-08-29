/// The photo picker seam itself.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restaurant_rater/ui/rating/photo_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the default picker really is image_picker', () async {
    // Covers the production closure rather than only the injected fake. Off
    // device there is no host for the channel, so the call is expected to
    // fail -- what is being pinned is that the default reaches the plugin at
    // all, so an injected fake in every other test cannot mask a seam that
    // was never wired up.
    await expectLater(
      defaultPickPhoto(ImageSource.camera),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
