import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docpilot/features/records/lab_results_view.dart';
import 'package:docpilot/models/care_models.dart';

/// The real results view, across the same device sweep as the onboarding —
/// long marker names, units, ranges and trend lines all on one row.
void main() {
  final markers = [
    const LabMarker(name: 'HbA1c', value: 5.4, unit: '%', refHigh: 5.7, refText: '< 5.7', status: LabStatus.normal),
    const LabMarker(name: 'LDL cholesterol, calculated', value: 148, unit: 'mg/dL', refHigh: 100, refText: '< 100', status: LabStatus.high),
    const LabMarker(name: 'Vitamin D, 25-hydroxy', value: 19, unit: 'ng/mL', refLow: 30, refHigh: 100, refText: '30 – 100', status: LabStatus.low),
    const LabMarker(name: 'Something with no range', value: 42, unit: 'U/L'),
  ];
  final priors = {
    markers[1].key: LabPrior(value: 131, date: DateTime(2026, 3, 2)),
    markers[2].key: LabPrior(value: 19, date: DateTime(2026, 1, 9)),
  };

  for (final size in const [Size(320, 568), Size(393, 852)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('fits ${size.width.toInt()}pt @ ${scale}x', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LabResultsView(markers: markers, priors: priors),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Abnormal first, and the trend line is present.
        expect(find.textContaining('2 outside range'), findsOneWidget);
        expect(find.textContaining('since Mar (was 131)'), findsOneWidget);
        expect(find.textContaining('Unchanged from Jan'), findsOneWidget);
      });
    }
  }
}
