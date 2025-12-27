import 'package:flutter_test/flutter_test.dart';

import 'package:girlschan_app/utils/platform_helper.dart';

void main() {
  tearDown(() {
    PlatformHelper.setTestPlatform(null);
  });

  test('isDesktop is true when test platform is macOS', () {
    PlatformHelper.setTestPlatform(PlatformKind.macOS);

    expect(PlatformHelper.isDesktop, isTrue);
    expect(PlatformHelper.isMacOS, isTrue);
    expect(PlatformHelper.isWindows, isFalse);
  });

  test('isDesktop is true when test platform is windows', () {
    PlatformHelper.setTestPlatform(PlatformKind.windows);

    expect(PlatformHelper.isDesktop, isTrue);
    expect(PlatformHelper.isWindows, isTrue);
  });

  test('isDesktop is false when test platform is android', () {
    PlatformHelper.setTestPlatform(PlatformKind.android);

    expect(PlatformHelper.isDesktop, isFalse);
    expect(PlatformHelper.isWindows, isFalse);
    expect(PlatformHelper.isMacOS, isFalse);
  });
}
