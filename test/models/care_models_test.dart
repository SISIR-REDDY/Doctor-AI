import 'package:flutter_test/flutter_test.dart';

import 'package:docpilot/models/care_models.dart';
import 'package:docpilot/models/patient_models.dart';

void main() {
  group('LabMarker', () {
    test('uses the lab’s own flag when printed', () {
      final m = LabMarker.fromMap({
        'name': 'LDL', 'value': 90, 'refLow': 0, 'refHigh': 100, 'flag': 'high',
      });
      // The lab said high even though 90 < 100 — trust the lab over our maths.
      expect(m.status, LabStatus.high);
    });

    test('derives status from the printed range when no flag', () {
      LabStatus at(double v) => LabMarker.fromMap(
            {'name': 'x', 'value': v, 'refLow': 30, 'refHigh': 100, 'flag': ''},
          ).status;
      expect(at(19), LabStatus.low);
      expect(at(50), LabStatus.normal);
      expect(at(148), LabStatus.high);
    });

    test('"< X" ranges: refLow 0 means only the upper bound applies', () {
      final m = LabMarker.fromMap(
          {'name': 'LDL', 'value': 148, 'refLow': 0, 'refHigh': 100, 'flag': ''});
      expect(m.status, LabStatus.high);
      final ok = LabMarker.fromMap(
          {'name': 'LDL', 'value': 5, 'refLow': 0, 'refHigh': 100, 'flag': ''});
      expect(ok.status, LabStatus.normal); // not "low" — there is no floor
    });

    test('never invents a status without a range', () {
      final m = LabMarker.fromMap({'name': 'x', 'value': 5, 'flag': ''});
      expect(m.status, LabStatus.unknown);
      expect(m.position, isNull);
    });

    test('position keeps out-of-range values inside the bar', () {
      final m = LabMarker(name: 'x', value: 148, refLow: 0, refHigh: 100);
      final p = m.position!;
      expect(p, greaterThan(0.78)); // past the normal band
      expect(p, lessThanOrEqualTo(1.0));
      final wild = LabMarker(name: 'x', value: 900, refLow: 0, refHigh: 100);
      expect(wild.position, 1.0);
    });

    test('key normalises names so the same marker matches across reports', () {
      expect(LabMarker(name: 'LDL Cholesterol', value: 1).key,
          LabMarker(name: 'ldl  cholesterol ', value: 1).key);
      expect(LabMarker(name: 'Vitamin D, serum', value: 1).key,
          LabMarker(name: 'Vitamin D', value: 1).key);
      expect(LabMarker(name: 'HbA1c', value: 1).key,
          isNot(LabMarker(name: 'LDL', value: 1).key));
    });

    test('listFrom drops junk and unnamed entries', () {
      final list = LabMarker.listFrom([
        {'name': 'A', 'value': 1},
        {'value': 2}, // no name
        'garbage',
        null,
      ]);
      expect(list.map((m) => m.name), ['A']);
      expect(LabMarker.listFrom('nope'), isEmpty);
    });

    test('round-trips through toMap/fromMap', () {
      final m = LabMarker(
          name: 'LDL', value: 148, unit: 'mg/dL', refHigh: 100, refText: '< 100',
          status: LabStatus.high);
      final back = LabMarker.fromMap(m.toMap());
      expect(back.name, m.name);
      expect(back.value, m.value);
      expect(back.unit, m.unit);
      expect(back.refText, m.refText);
      expect(back.status, LabStatus.high);
    });
  });

  group('priorReadings', () {
    MedicalRecord rec(String id, DateTime date, Map<String, double> values) =>
        MedicalRecord(
          id: id,
          recordType: 'lab',
          recordDate: date,
          labMarkers: [
            for (final e in values.entries) LabMarker(name: e.key, value: e.value),
          ],
        );

    test('finds the most recent earlier reading of each marker', () {
      final current = rec('c', DateTime(2026, 9, 14), {'LDL': 148, 'HbA1c': 5.4});
      final all = [
        current,
        rec('a', DateTime(2026, 3, 2), {'LDL': 131}),
        rec('b', DateTime(2025, 11, 1), {'LDL': 120, 'HbA1c': 5.6}),
        rec('z', DateTime(2026, 10, 1), {'LDL': 99}), // later — must be ignored
      ];
      final priors = priorReadings(current, all);
      expect(priors[LabMarker(name: 'LDL', value: 0).key]!.value, 131);
      expect(priors[LabMarker(name: 'HbA1c', value: 0).key]!.value, 5.6);
    });

    test('is empty with no earlier lab records', () {
      final current = rec('c', DateTime(2026, 9, 14), {'LDL': 148});
      expect(priorReadings(current, [current]), isEmpty);
    });
  });

  group('Adherence', () {
    final today = DateTime(2026, 9, 16);
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    MedicationLog taken(DateTime d, {String time = '08:00'}) =>
        MedicationLog(medicationId: 'm', medicationName: 'Metformin', date: ymd(d), time: time, status: 'taken');
    MedicationLog skipped(DateTime d) =>
        MedicationLog(medicationId: 'm', medicationName: 'Metformin', date: ymd(d), time: '08:00', status: 'skipped');
    final oneDaily = [Medication(id: 'm', name: 'Metformin', isActive: true, reminderTimes: const ['08:00'])];

    test('counts consecutive complete days ending today', () {
      final logs = [for (var i = 0; i < 5; i++) taken(today.subtract(Duration(days: i)))];
      final a = Adherence.compute(logs: logs, medications: oneDaily, today: today);
      expect(a.streakDays, 5);
    });

    test('an untaken dose today does not break a streak yet', () {
      // 8pm dose, 9am check: yesterday and before are complete.
      final logs = [for (var i = 1; i <= 3; i++) taken(today.subtract(Duration(days: i)))];
      final a = Adherence.compute(logs: logs, medications: oneDaily, today: today);
      expect(a.streakDays, 3);
    });

    test('a skipped dose breaks the streak', () {
      final logs = [
        taken(today),
        skipped(today.subtract(const Duration(days: 1))),
        taken(today.subtract(const Duration(days: 2))),
      ];
      final a = Adherence.compute(logs: logs, medications: oneDaily, today: today);
      expect(a.streakDays, 1);
    });

    test('a day needs every scheduled slot taken', () {
      final twice = [Medication(id: 'm', name: 'x', isActive: true, reminderTimes: const ['08:00', '20:00'])];
      final logs = [
        taken(today, time: '08:00'), taken(today, time: '20:00'),
        taken(today.subtract(const Duration(days: 1)), time: '08:00'), // evening missed
      ];
      final a = Adherence.compute(logs: logs, medications: twice, today: today);
      expect(a.streakDays, 1);
    });

    test('rate is doses taken over doses scheduled in the window', () {
      final logs = [for (var i = 0; i < 24; i++) taken(today.subtract(Duration(days: i)))];
      final a = Adherence.compute(logs: logs, medications: oneDaily, today: today, windowDays: 30);
      expect(a.rate, closeTo(0.8, 0.001));
      expect(a.scheduledInWindow, 30);
      expect(a.takenInWindow, 24);
    });

    test('rate is null when nothing is scheduled; any taken dose counts', () {
      final noTimes = [Medication(id: 'm', name: 'x', isActive: true, reminderTimes: const [])];
      final logs = [taken(today), taken(today.subtract(const Duration(days: 1)))];
      final a = Adherence.compute(logs: logs, medications: noTimes, today: today);
      expect(a.rate, isNull);
      expect(a.streakDays, 2);
    });

    test('inactive medications do not add scheduled slots', () {
      final meds = [
        Medication(id: 'm', name: 'x', isActive: true, reminderTimes: const ['08:00']),
        Medication(id: 'old', name: 'y', isActive: false, reminderTimes: const ['08:00', '20:00']),
      ];
      final a = Adherence.compute(logs: [taken(today)], medications: meds, today: today);
      expect(a.streakDays, 1);
    });
  });
}
