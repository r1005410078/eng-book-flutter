import 'package:engbooks/src/features/home/domain/course.dart';
import 'package:engbooks/src/features/home/presentation/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
      'CourseDetailScreen navigates to sentence practice with package context',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/course',
      routes: [
        GoRoute(
          path: '/course',
          builder: (context, state) => CourseDetailScreen(
            course: const Course(
              id: 'c1',
              title: 'Local Course',
              subtitle: '1 章节',
              type: CourseType.audio,
              packageRoot: '/tmp/local_package',
              firstSentenceId: '01-0001',
            ),
          ),
        ),
        GoRoute(
          path: '/practice/sentence/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final package = state.uri.queryParameters['package'] ?? '';
            final course = state.uri.queryParameters['course'] ?? '';
            return Scaffold(
              body: Text('id=$id;package=$package;course=$course'),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始学习'), findsOneWidget);
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();

    expect(find.textContaining('id=01-0001;'), findsOneWidget);
    expect(find.textContaining('package=%2Ftmp%2Flocal_package'), findsNothing);
    expect(find.textContaining('package=/tmp/local_package;'), findsOneWidget);
    expect(find.textContaining('course=Local Course'), findsOneWidget);
  });
}
