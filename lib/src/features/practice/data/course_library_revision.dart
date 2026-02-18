import 'package:flutter/foundation.dart';

final ValueNotifier<int> courseLibraryRevision = ValueNotifier<int>(0);

void bumpCourseLibraryRevision() {
  courseLibraryRevision.value = courseLibraryRevision.value + 1;
}
