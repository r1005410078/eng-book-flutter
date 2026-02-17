import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  assert(() {
    // Ensure accidental debug paint toggles do not leak into normal development UX.
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    debugRepaintTextRainbowEnabled = false;
    debugProfilePaintsEnabled = false;
    return true;
  }());

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
