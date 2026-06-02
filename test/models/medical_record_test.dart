import 'package:flutter_test/flutter_test.dart';
import 'package:docpilot/models/patient_models.dart';

void main() {
  group('MedicalRecord', () {
    // ── Defaults ────────────────────────────────────────────────────────────

    test('default values are correct', () {
      final r = MedicalRecord();
      expect(r.id, '');
      expect(r.userId, '');
      expect(r.title, '');
      expect(r.recordType, 'other');
      expect(r.imagePath, '');
      expect(r.imageUrl, '');
      expect(r.extractedText, '');
      expect(r.aiSummary, '');
      expect(r.isProcessed, false);
      expect(r.doctorName, '');
      expect(r.hospitalName, '');
    });

    test('recordDate and uploadedAt default to approximately now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final r = MedicalRecord();
      final after = DateTime.now().add(const Duration(seconds: 1));
      expect(r.recordDate.isAfter(before), true);
      expect(r.recordDate.isBefore(after), true);
      expect(r.uploadedAt.isAfter(before), true);
      expect(r.uploadedAt.isBefore(after), true);
    });

    // ── toMap / fromMap roundtrip ────────────────────────────────────────────

    test('toMap produces all expected keys', () {
      final r = _sampleRecord();
      final map = r.toMap();
      expect(map['id'], 'rec-1');
      expect(map['userId'], 'user-1');
      expect(map['title'], 'Blood Test June 2026');
      expect(map['recordType'], 'lab');
      expect(map['imagePath'], '/local/path.jpg');
      expect(map['imageUrl'], 'https://example.com/img.jpg');
      expect(map['extractedText'], 'Hemoglobin: 14.2');
      expect(map['aiSummary'], 'Normal blood count.');
      expect(map['isProcessed'], true);
      expect(map['doctorName'], 'Dr. Smith');
      expect(map['hospitalName'], 'City Hospital');
      expect(map.containsKey('recordDate'), true);
      expect(map.containsKey('uploadedAt'), true);
    });

    test('fromMap restores all fields correctly', () {
      final original = _sampleRecord();
      final restored = MedicalRecord.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.title, original.title);
      expect(restored.recordType, original.recordType);
      expect(restored.imagePath, original.imagePath);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.imageUrls, original.imageUrls);
      expect(restored.extractedText, original.extractedText);
      expect(restored.aiSummary, original.aiSummary);
      expect(restored.isProcessed, original.isProcessed);
      expect(restored.doctorName, original.doctorName);
      expect(restored.hospitalName, original.hospitalName);
    });

    // ── imageUrls (multi-page) ───────────────────────────────────────────────

    test('imageUrls defaults to empty list', () {
      expect(MedicalRecord().imageUrls, isEmpty);
    });

    test('imageUrls round-trips correctly', () {
      final r = MedicalRecord(imageUrls: [
        'https://example.com/page1.jpg',
        'https://example.com/page2.jpg',
        'https://example.com/page3.jpg',
      ]);
      final restored = MedicalRecord.fromMap(r.toMap());
      expect(restored.imageUrls.length, 3);
      expect(restored.imageUrls[0], 'https://example.com/page1.jpg');
      expect(restored.imageUrls[2], 'https://example.com/page3.jpg');
    });

    test('fromMap: imageUrls is empty list when key is absent', () {
      final r = MedicalRecord.fromMap({});
      expect(r.imageUrls, isEmpty);
    });

    test('fromMap: imageUrls is empty list when value is null', () {
      final r = MedicalRecord.fromMap({'imageUrls': null});
      expect(r.imageUrls, isEmpty);
    });

    test('fromMap: imageUrls filters out empty strings', () {
      final r = MedicalRecord.fromMap({
        'imageUrls': ['https://a.com/1.jpg', '', 'https://a.com/2.jpg'],
      });
      expect(r.imageUrls.length, 2);
    });

    test('allImageUrls returns imageUrls when non-empty', () {
      final r = MedicalRecord(
        imageUrl: 'https://old.com/single.jpg',
        imageUrls: ['https://new.com/p1.jpg', 'https://new.com/p2.jpg'],
      );
      expect(r.allImageUrls, r.imageUrls);
    });

    test('allImageUrls falls back to [imageUrl] when imageUrls is empty', () {
      final r = MedicalRecord(imageUrl: 'https://old.com/single.jpg');
      expect(r.allImageUrls, ['https://old.com/single.jpg']);
    });

    test('allImageUrls is empty when both imageUrl and imageUrls are empty', () {
      final r = MedicalRecord();
      expect(r.allImageUrls, isEmpty);
    });

    test('copyWith: imageUrls can be updated', () {
      final original = _sampleRecord();
      final copy = original.copyWith(imageUrls: ['https://x.com/1.jpg']);
      expect(copy.imageUrls.length, 1);
      expect(copy.id, original.id);
    });

    test('fromMap with all null/missing keys uses safe defaults', () {
      final r = MedicalRecord.fromMap({});
      expect(r.id, '');
      expect(r.recordType, 'other');
      expect(r.isProcessed, false);
      expect(r.aiSummary, '');
    });

    test('fromMap: isProcessed is false when key is absent', () {
      final r = MedicalRecord.fromMap({'isProcessed': null});
      expect(r.isProcessed, false);
    });

    test('fromMap: isProcessed is false when value is false', () {
      final r = MedicalRecord.fromMap({'isProcessed': false});
      expect(r.isProcessed, false);
    });

    test('fromMap: isProcessed is true when value is true', () {
      final r = MedicalRecord.fromMap({'isProcessed': true});
      expect(r.isProcessed, true);
    });

    test('fromMap: recordType defaults to "other" when missing', () {
      final r = MedicalRecord.fromMap({});
      expect(r.recordType, 'other');
    });

    test('fromMap: recordType preserved for all valid types', () {
      for (final type in ['lab', 'imaging', 'prescription', 'discharge', 'vaccination', 'other']) {
        final r = MedicalRecord.fromMap({'recordType': type});
        expect(r.recordType, type, reason: 'Failed for type: $type');
      }
    });

    test('fromMap: numeric/non-string values for string fields coerced to string', () {
      final r = MedicalRecord.fromMap({'id': 123, 'title': 456});
      expect(r.id, '123');
      expect(r.title, '456');
    });

    test('fromMap: invalid date string falls back to approximately now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final r = MedicalRecord.fromMap({'recordDate': 'not-a-date'});
      expect(r.recordDate.isAfter(before), true);
    });

    test('fromMap: valid ISO date string parsed correctly', () {
      final date = DateTime(2026, 6, 1, 10, 30);
      final r = MedicalRecord.fromMap({'recordDate': date.toIso8601String()});
      expect(r.recordDate.year, 2026);
      expect(r.recordDate.month, 6);
      expect(r.recordDate.day, 1);
    });

    // ── copyWith ────────────────────────────────────────────────────────────

    test('copyWith changes only specified fields', () {
      final original = _sampleRecord();
      final copy = original.copyWith(title: 'Updated Title', isProcessed: false);
      expect(copy.title, 'Updated Title');
      expect(copy.isProcessed, false);
      // Unchanged fields
      expect(copy.id, original.id);
      expect(copy.recordType, original.recordType);
      expect(copy.aiSummary, original.aiSummary);
      expect(copy.doctorName, original.doctorName);
    });

    test('copyWith with no args returns identical values', () {
      final original = _sampleRecord();
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.recordType, original.recordType);
      expect(copy.isProcessed, original.isProcessed);
    });

    test('copyWith: recordDate can be updated independently', () {
      final original = _sampleRecord();
      final newDate = DateTime(2025, 1, 15);
      final copy = original.copyWith(recordDate: newDate);
      expect(copy.recordDate, newDate);
      expect(copy.uploadedAt, original.uploadedAt);
    });

    // ── Edge cases ───────────────────────────────────────────────────────────

    test('empty title is preserved (not replaced with default)', () {
      final r = MedicalRecord(title: '');
      expect(r.title, '');
    });

    test('very long aiSummary is stored without truncation', () {
      final longSummary = 'A' * 5000;
      final r = MedicalRecord(aiSummary: longSummary);
      final restored = MedicalRecord.fromMap(r.toMap());
      expect(restored.aiSummary.length, 5000);
    });

    test('special characters in title survive roundtrip', () {
      final r = MedicalRecord(title: 'Hemoglobin A1c — 5.6% ✓');
      final restored = MedicalRecord.fromMap(r.toMap());
      expect(restored.title, 'Hemoglobin A1c — 5.6% ✓');
    });
  });
}

MedicalRecord _sampleRecord() => MedicalRecord(
      id: 'rec-1',
      userId: 'user-1',
      title: 'Blood Test June 2026',
      recordType: 'lab',
      imagePath: '/local/path.jpg',
      imageUrl: 'https://example.com/img.jpg',
      imageUrls: [
        'https://example.com/page1.jpg',
        'https://example.com/page2.jpg',
      ],
      extractedText: 'Hemoglobin: 14.2',
      aiSummary: 'Normal blood count.',
      isProcessed: true,
      doctorName: 'Dr. Smith',
      hospitalName: 'City Hospital',
      recordDate: DateTime(2026, 6, 1),
      uploadedAt: DateTime(2026, 6, 1, 12, 0),
    );
