import 'dart:io';

import 'package:engbooks/src/common/io/runtime_paths.dart';
import 'package:engbooks/src/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalCurrent = Directory.current;
    tempDir = await Directory.systemTemp.createTemp('home_screen_empty_test_');
    Directory.current = tempDir;
    debugSetRuntimeRootOverridePath('${tempDir.path}/.runtime');
  });

  tearDown(() async {
    debugSetRuntimeRootOverridePath(null);
    Directory.current = originalCurrent;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('shows empty guide when no usable course exists', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('前往下载中心'), findsOneWidget);
  });
}
