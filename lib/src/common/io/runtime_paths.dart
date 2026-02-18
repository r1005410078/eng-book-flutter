import 'dart:io';

import 'package:path_provider/path_provider.dart';

String? _runtimeRootOverridePath;

void debugSetRuntimeRootOverridePath(String? path) {
  _runtimeRootOverridePath = path;
}

Future<Directory> resolveRuntimeRootDir() async {
  final overridePath = _runtimeRootOverridePath;
  if (overridePath != null && overridePath.isNotEmpty) {
    return Directory(overridePath);
  }
  try {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/.runtime');
  } catch (_) {
    return Directory('${Directory.current.path}/.runtime');
  }
}

Future<Directory> resolveRuntimeTasksDir() async {
  final root = await resolveRuntimeRootDir();
  return Directory('${root.path}/tasks');
}
