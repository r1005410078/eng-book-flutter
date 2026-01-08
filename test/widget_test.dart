// 基础组件测试
//
// 测试应用能够正常启动和渲染

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:engbooks/app.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // 等待路由初始化
    await tester.pumpAndSettle();

    // Verify that home screen is displayed
    expect(find.text('100LS 英语学习'), findsOneWidget);
    expect(find.text('欢迎使用 100LS 英语学习应用'), findsOneWidget);
    expect(find.byIcon(Icons.headphones), findsOneWidget);
  });
}
