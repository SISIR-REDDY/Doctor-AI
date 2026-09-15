import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docpilot/features/onboarding/welcome_backdrop.dart';
import 'package:docpilot/theme/liquid_glass.dart';

/// Renders to pixels rather than inspecting the widget tree. The bug these
/// guard against — a BoxDecoration whose gradient silently discards its
/// colour — is invisible to a tree inspection: every widget is present and
/// correct, and the panel still paints as a near-transparent film.

Future<ui.Color> _pixelAt(WidgetTester tester, Finder finder, Offset local) async {
  final element = finder.evaluate().single;
  final boundary = element.findRenderObject()! as RenderRepaintBoundary;
  // toImage completes on a real event loop; the test binding's fake async
  // zone never delivers it, so run the capture outside that zone.
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  }))!;
  final image = await tester.runAsync(() => boundary.toImage());
  final x = local.dx.round(), y = local.dy.round();
  final i = ((y * image!.width) + x) * 4;
  return ui.Color.fromARGB(
    bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2),
  );
}

void main() {
  testWidgets('tinted glass actually carries its tint', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: const Key('boundary'),
            child: const LiquidGlass(
              tint: Color(0xFF0A57C2),
              opacity: 1.55,
              child: SizedBox(width: 200, height: 120),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Sample the middle of the panel, away from the rim and the top sheen.
    final c = await _pixelAt(tester, find.byKey(const Key('boundary')), const Offset(120, 80));
    // Blue must dominate. Before the fix this came back ~white (r≈g≈b≈0.96).
    expect(c.b, greaterThan(0.6), reason: 'blue channel lost: $c');
    expect(c.r, lessThan(0.45), reason: 'fill bleached toward white: $c');
  });

  testWidgets('neutral glass is opaque enough to read as a surface', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF007AFF), // saturated backdrop
        body: Center(
          child: RepaintBoundary(
            key: const Key('boundary'),
            child: const LiquidGlass(child: SizedBox(width: 200, height: 120)),
          ),
        ),
      ),
    ));
    await tester.pump();
    final c = await _pixelAt(tester, find.byKey(const Key('boundary')), const Offset(120, 80));
    // A white fill at ~0.62 over pure blue must land clearly lighter than
    // the backdrop — otherwise the panel is film, not glass.
    expect(c.r, greaterThan(0.45), reason: 'panel too transparent: $c');
    expect(c.g, greaterThan(0.6), reason: 'panel too transparent: $c');
  });

  testWidgets('progress rail paints its fill', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 300,
            child: RepaintBoundary(
              key: Key('boundary'),
              child: ProgressRail(count: 3, scroll: 1.0, color: Color(0xFF0000FF)),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    // scroll=1.0 → segment 0 full, segment 1 empty. Sample inside segment 0.
    final filled = await _pixelAt(tester, find.byKey(const Key('boundary')), const Offset(30, 2));
    final empty = await _pixelAt(tester, find.byKey(const Key('boundary')), const Offset(200, 2));
    expect(filled.b, greaterThan(0.8), reason: 'segment 0 not filled: $filled');
    expect(filled.r, lessThan(0.25), reason: 'segment 0 not solid: $filled');
    // The boundary captures without the scaffold behind it, so the track
    // (accent at 0.18 alpha) reads as translucent, not as light grey.
    expect(empty.a, lessThan(0.3), reason: 'segment 1 should be track only: $empty');
  });
}
