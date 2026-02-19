import 'package:engbooks/src/features/practice/presentation/widgets/short_video_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not show course title text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShortVideoHeader(
            currentIndex: 1,
            total: 10,
            courseTitle: 'UI设计入门',
            lessonTitle: '布局与网格',
            onTapCourseUnitPicker: () {},
            onOpenDownloadCenter: () {},
          ),
        ),
      ),
    );

    expect(find.text('UI设计入门'), findsNothing);
    expect(find.text('布局与网格'), findsOneWidget);
  });

  testWidgets('tap lesson title also triggers picker callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShortVideoHeader(
            currentIndex: 1,
            total: 10,
            courseTitle: 'UI设计入门',
            lessonTitle: '布局与网格',
            onTapCourseUnitPicker: () => tapped = true,
            onOpenDownloadCenter: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('布局与网格'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
