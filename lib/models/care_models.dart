import 'patient_models.dart';

/// One measured value from a lab report, as extracted by the backend.
///
/// Status is taken from the lab's own flag when printed, otherwise derived
/// from the value against the printed reference range. We never invent a
/// range: with no range, status is [LabStatus.unknown] and the UI shows the
/// value without a colour.
enum LabStatus { low, normal, high, abnormal, unknown }

class LabMarker {
  final String name;
  final double value;
  final String unit;

  /// Reference bounds. 0 means "not printed" for that side.
  final double refLow;
  final double refHigh;

  /// The range exactly as printed, for display.
  final String refText;
  final LabStatus status;

  const LabMarker({
    required this.name,
    required this.value,
    this.unit = '',
    this.refLow = 0,
    this.refHigh = 0,
    this.refText = '',
    this.status = LabStatus.unknown,
  });

  bool get hasRange => refHigh > 0 || refLow > 0;

  /// Where the value sits along the range bar, 0–1, with a little headroom
  /// either side so out-of-range values stay visible instead of pinning to
  /// the ends. Null when there is no range to place it on.
  double? get position {
    if (!hasRange) return null;
    // "< X" ranges: bar runs 0 → X with 40% headroom beyond.
    final low = refLow;
    final high = refHigh > 0 ? refHigh : refLow * 2;
    final span = (high - low).abs();
    if (span == 0) return null;
    final padded = span * 0.4;
    final start = low - padded;
    final end = high + padded;
    return ((value - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Normalised key for matching the same marker across reports —
  /// "LDL Cholesterol", "LDL-C" and "ldl cholesterol " should collide.
  String get key => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\b(serum|plasma|total|level|test)\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static LabStatus _statusFrom(String raw, double value, double lo, double hi) {
    switch (raw.toLowerCase()) {
      case 'low':
        return LabStatus.low;
      case 'normal':
        return LabStatus.normal;
      case 'high':
        return LabStatus.high;
      case 'abnormal':
        return LabStatus.abnormal;
    }
    // Derive only when the model gave us a usable range.
    if (hi > 0 && value > hi) return LabStatus.high;
    if (lo > 0 && value < lo) return LabStatus.low;
    if (hi > 0 || lo > 0) return LabStatus.normal;
    return LabStatus.unknown;
  }

  factory LabMarker.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final lo = d(m['refLow']);
    final hi = d(m['refHigh']);
    final value = d(m['value']);
    return LabMarker(
      name: (m['name'] ?? '').toString().trim(),
      value: value,
      unit: (m['unit'] ?? '').toString().trim(),
      refLow: lo,
      refHigh: hi,
      refText: (m['refText'] ?? '').toString().trim(),
      status: _statusFrom((m['flag'] ?? m['status'] ?? '').toString(), value, lo, hi),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'value': value,
        'unit': unit,
        'refLow': refLow,
        'refHigh': refHigh,
        'refText': refText,
        'status': status.name,
      };

  static List<LabMarker> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => LabMarker.fromMap(Map<String, dynamic>.from(m)))
        .where((x) => x.name.isNotEmpty)
        .toList();
  }
}

/// A marker's earlier reading, for the trend line under a result.
class LabPrior {
  final double value;
  final DateTime date;
  const LabPrior({required this.value, required this.date});
}

/// Finds each marker's most recent earlier reading across the user's other
/// lab records, so a result can say "was 131 in March".
Map<String, LabPrior> priorReadings(
  MedicalRecord current,
  Iterable<MedicalRecord> all,
) {
  final out = <String, LabPrior>{};
  final earlier = all.where((r) =>
      r.id != current.id &&
      r.labMarkers.isNotEmpty &&
      r.recordDate.isBefore(current.recordDate));
  for (final r in earlier) {
    for (final m in r.labMarkers) {
      final existing = out[m.key];
      if (existing == null || r.recordDate.isAfter(existing.date)) {
        out[m.key] = LabPrior(value: m.value, date: r.recordDate);
      }
    }
  }
  return out;
}

/// Medication adherence, computed from daily logs.
///
/// A day counts toward the streak when every scheduled dose for that day was
/// logged as taken and none was skipped. "Scheduled" is the sum of reminder
/// slots across active medications; a user with no reminder times set still
/// gets credit for any day with at least one dose taken.
class Adherence {
  final int streakDays;

  /// Doses taken ÷ doses scheduled over the window, 0–1. Null when nothing
  /// was scheduled.
  final double? rate;
  final int takenInWindow;
  final int scheduledInWindow;

  const Adherence({
    required this.streakDays,
    required this.rate,
    required this.takenInWindow,
    required this.scheduledInWindow,
  });

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Adherence compute({
    required List<MedicationLog> logs,
    required List<Medication> medications,
    required DateTime today,
    int windowDays = 30,
  }) {
    final active = medications.where((m) => m.isActive).toList();
    final slotsPerDay = active.fold<int>(0, (n, m) => n + m.reminderTimes.length);

    final takenByDay = <String, int>{};
    final skippedByDay = <String, int>{};
    for (final l in logs) {
      if (l.status == 'taken') {
        takenByDay[l.date] = (takenByDay[l.date] ?? 0) + 1;
      } else if (l.status == 'skipped') {
        skippedByDay[l.date] = (skippedByDay[l.date] ?? 0) + 1;
      }
    }

    bool dayComplete(String day) {
      final taken = takenByDay[day] ?? 0;
      if ((skippedByDay[day] ?? 0) > 0) return false;
      if (slotsPerDay == 0) return taken > 0;
      return taken >= slotsPerDay;
    }

    // Today only breaks the streak once it is over; until then start from
    // yesterday so an 8pm dose does not zero a streak at 9am.
    final start = DateTime(today.year, today.month, today.day);
    var cursor = dayComplete(_ymd(start)) ? start : start.subtract(const Duration(days: 1));
    var streak = 0;
    while (dayComplete(_ymd(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak > 3650) break; // defensive: corrupt data
    }

    var taken = 0;
    for (var i = 0; i < windowDays; i++) {
      taken += takenByDay[_ymd(start.subtract(Duration(days: i)))] ?? 0;
    }
    final scheduled = slotsPerDay * windowDays;
    return Adherence(
      streakDays: streak,
      rate: scheduled == 0 ? null : (taken / scheduled).clamp(0.0, 1.0),
      takenInWindow: taken,
      scheduledInWindow: scheduled,
    );
  }
}
