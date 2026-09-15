import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docpilot/features/onboarding/welcome_scenes.dart';

/// The welcome scenes are the first thing a user sees, so a layout overflow
/// there is a visible yellow-and-black bar on the store screenshots. These
/// sweep the realistic range: smallest supported phone through large, at
/// default and enlarged accessibility text.

void main() {
  const sizes = <Size>[
    Size(320, 568), // iPhone SE (1st gen) — narrowest we support
    Size(375, 667), // SE 2/3
    Size(393, 852), // iPhone 15/16
    Size(440, 956), // Pro Max
  ];
  const scales = <double>[1.0, 1.3];

  Widget scene(Widget w, double scale) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: w,
              ),
            ),
          ),
        ),
      );

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets(
          'scenes fit ${size.width.toInt()}×${size.height.toInt()} @ ${scale}x text',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        for (final w in const [
          BillScene(offset: 0, active: true),
          DenialScene(offset: 0, active: true),
          MoneyScene(offset: 0, active: true),
        ]) {
          await tester.pumpWidget(scene(w, scale));
          await tester.pumpAndSettle();

          // A RenderFlex overflow surfaces as a FlutterError on the test
          // binding; takeException() returns null when the frame was clean.
          expect(tester.takeException(), isNull,
              reason: '${w.runtimeType} overflowed at $size @ ${scale}x');
        }
      });
    }
  }
}
