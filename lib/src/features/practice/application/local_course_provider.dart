import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_course_package_loader.dart';

class LocalCourseContext {
  final String packageRoot;
  final String? courseTitle;

  const LocalCourseContext({
    required this.packageRoot,
    this.courseTitle,
  });
}

final localCourseListProvider = FutureProvider<List<LocalCourseSummary>>((
  ref,
) async {
  return listLocalCoursePackages();
});

final localCourseContextProvider = StateProvider<LocalCourseContext?>(
  (ref) => null,
);

final localCourseSentencesProvider = FutureProvider<LocalSentenceLoadResult>((
  ref,
) async {
  final context = ref.watch(localCourseContextProvider);
  const fromDefine = String.fromEnvironment(
    'COURSE_PACKAGE_DIR',
    defaultValue: '',
  );
  final discovered = await discoverLatestReadyPackageRoot();
  final packageRoot = context?.packageRoot.isNotEmpty == true
      ? context!.packageRoot
      : (fromDefine.isNotEmpty ? fromDefine : discovered ?? '');

  if (packageRoot.isEmpty) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning:
          '本地课程包未设置，已使用默认内容。请设置 COURSE_PACKAGE_DIR 或确保 .runtime/tasks 下有 ready 任务。',
    );
  }
  return loadSentencesFromLocalPackage(packageRoot: packageRoot);
});
