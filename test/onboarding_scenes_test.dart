import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docpilot/features/onboarding/welcome_scenes.dart';
import 'package:docpilot/theme/motion.dart';

/// The welcome scenes animate on a timeline. These guard the two failure modes
/// that would ship a broken first impression: a scene that never advances (so
/// the user sees a blank card), and one that never settles (so the pump in a
/// real device frame loop never idles).

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// Effective opacity applied to [finder] by the nearest enclosing [Opacity].
double _opacityAbove(WidgetTester tester, Finder finder) {
  final op = find.ancestor(of: finder, matching: find.byType(Opacity));
  if (op.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(op.first).opacity;
}

void main() {
  group('welcome scenes', () {
    testWidgets('bill scene plays its story and settles', (tester) async {
      await tester.pumpWidget(_host(const BillScene(offset: 0, active: true)));

      // Mid-story the sample bill is on screen.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('Riverside Medical Center'), findsOneWidget);

      // The flags land late in the timeline, after the scan sweep passes.
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('5.9× rate'), findsOneWidget);
      expect(find.text('2 problems found'), findsOneWidget);
      expect(find.text('Itemized statement · 4 lines'), findsOneWidget);
    });

    testWidgets('denial scene ticks every step', (tester) async {
      await tester.pumpWidget(_host(const DenialScene(offset: 0, active: true)));
      await tester.pumpAndSettle();

      expect(find.text('Denial reason decoded in plain English'), findsOneWidget);
      expect(find.text('Deadline set — 172 days to file'), findsOneWidget);
      expect(find.text('Appeal ready to send'), findsOneWidget);
    });

    testWidgets('money scene counts up to the final figure', (tester) async {
      await tester.pumpWidget(_host(const MoneyScene(offset: 0, active: true)));
      await tester.pumpAndSettle();

      // CountUp lands exactly on the target, not near it.
      expect(find.text(r'$2,340'), findsWidgets);
      expect(find.text(r'$1,610'), findsOneWidget);
    });

    testWidgets('an inactive scene stays hidden until activated',
        (tester) async {
      await tester.pumpWidget(_host(const BillScene(offset: 0, active: false)));
      await tester.pump(const Duration(milliseconds: 1500));

      // The subtree is built but fully transparent — the summary has not
      // been revealed, so an off-screen page never spoils its own reveal.
      expect(_opacityAbove(tester, find.text('2 problems found')), 0);

      await tester.pumpWidget(_host(const BillScene(offset: 0, active: true)));
      await tester.pumpAndSettle();
      expect(_opacityAbove(tester, find.text('2 problems found')), 1);
    });
  });

  group('CountUp', () {
    test('money formatting inserts thousands separators', () {
      expect(CountUp.money(0), '0');
      expect(CountUp.money(940), '940');
      expect(CountUp.money(2340), '2,340');
      expect(CountUp.money(1234567), '1,234,567');
    });
  });

  group('Motion.stagger', () {
    test('never produces an interval beyond the parent timeline', () {
      for (var i = 0; i < 40; i++) {
        final iv = Motion.stagger(i);
        expect(iv.begin, lessThanOrEqualTo(1.0));
        expect(iv.end, lessThanOrEqualTo(1.0));
        expect(iv.begin, lessThanOrEqualTo(iv.end));
      }
    });
  });
}
