import 'package:flutter_test/flutter_test.dart';
import 'package:docpilot/core/config/insurance_regions.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // kInsuranceRegions list integrity
  // ═══════════════════════════════════════════════════════════════════════════

  group('kInsuranceRegions list', () {
    test('contains exactly 6 regions', () {
      expect(kInsuranceRegions.length, 6);
    });

    test('contains all expected country codes', () {
      final codes = kInsuranceRegions.map((r) => r.code).toSet();
      expect(codes, containsAll({'US', 'GB', 'CA', 'AU', 'EU', 'IN'}));
    });

    test('every region has a non-empty code', () {
      for (final r in kInsuranceRegions) {
        expect(r.code, isNotEmpty, reason: 'Empty code for region: ${r.name}');
      }
    });

    test('every region has a non-empty name', () {
      for (final r in kInsuranceRegions) {
        expect(r.name, isNotEmpty, reason: 'Empty name for code: ${r.code}');
      }
    });

    test('every region has a non-empty currencyCode', () {
      for (final r in kInsuranceRegions) {
        expect(r.currencyCode, isNotEmpty, reason: 'Empty currencyCode for: ${r.code}');
      }
    });

    test('every region has a non-empty currencySymbol', () {
      for (final r in kInsuranceRegions) {
        expect(r.currencySymbol, isNotEmpty, reason: 'Empty symbol for: ${r.code}');
      }
    });

    test('every region has a non-empty locale', () {
      for (final r in kInsuranceRegions) {
        expect(r.locale, isNotEmpty, reason: 'Empty locale for: ${r.code}');
      }
    });

    test('every region has a non-empty regulator', () {
      for (final r in kInsuranceRegions) {
        expect(r.regulator, isNotEmpty, reason: 'Empty regulator for: ${r.code}');
      }
    });

    test('every region has a non-empty ombudsman', () {
      for (final r in kInsuranceRegions) {
        expect(r.ombudsman, isNotEmpty, reason: 'Empty ombudsman for: ${r.code}');
      }
    });

    test('every region has at least one escalation step', () {
      for (final r in kInsuranceRegions) {
        expect(r.escalationSteps, isNotEmpty, reason: 'No escalation steps for: ${r.code}');
      }
    });

    test('every region has non-empty keyRights', () {
      for (final r in kInsuranceRegions) {
        expect(r.keyRights, isNotEmpty, reason: 'Empty keyRights for: ${r.code}');
      }
    });

    test('no duplicate region codes', () {
      final codes = kInsuranceRegions.map((r) => r.code).toList();
      final uniqueCodes = codes.toSet();
      expect(codes.length, uniqueCodes.length);
    });

    test('no duplicate currency codes', () {
      final currencies = kInsuranceRegions.map((r) => r.currencyCode).toList();
      final uniqueCurrencies = currencies.toSet();
      expect(currencies.length, uniqueCurrencies.length);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Per-region correctness
  // ═══════════════════════════════════════════════════════════════════════════

  group('Individual region data', () {
    test('US region has correct currency', () {
      final us = kInsuranceRegions.firstWhere((r) => r.code == 'US');
      expect(us.currencyCode, 'USD');
      expect(us.currencySymbol, r'$');
      expect(us.beneficiaryTerm, 'Beneficiary');
    });

    test('GB region has correct currency and FCA reference', () {
      final gb = kInsuranceRegions.firstWhere((r) => r.code == 'GB');
      expect(gb.currencyCode, 'GBP');
      expect(gb.currencySymbol, '£');
      expect(gb.regulator, contains('FCA'));
      expect(gb.ombudsman, contains('FOS'));
    });

    test('IN region uses Nominee terminology', () {
      final india = kInsuranceRegions.firstWhere((r) => r.code == 'IN');
      expect(india.beneficiaryTerm, 'Nominee');
      expect(india.currencyCode, 'INR');
      expect(india.currencySymbol, '₹');
      expect(india.regulator, contains('IRDAI'));
    });

    test('AU region references AFCA', () {
      final au = kInsuranceRegions.firstWhere((r) => r.code == 'AU');
      expect(au.ombudsman, contains('AFCA'));
      expect(au.currencyCode, 'AUD');
    });

    test('CA region references OLHI', () {
      final ca = kInsuranceRegions.firstWhere((r) => r.code == 'CA');
      expect(ca.ombudsman, contains('OLHI'));
      expect(ca.currencyCode, 'CAD');
    });

    test('EU region references EIOPA', () {
      final eu = kInsuranceRegions.firstWhere((r) => r.code == 'EU');
      expect(eu.currencyCode, 'EUR');
      expect(eu.currencySymbol, '€');
      expect(eu.regulator, contains('EIOPA'));
    });

    test('IN has 4 escalation steps', () {
      final india = kInsuranceRegions.firstWhere((r) => r.code == 'IN');
      expect(india.escalationSteps.length, 4);
    });

    test('US has 5 escalation steps', () {
      final us = kInsuranceRegions.firstWhere((r) => r.code == 'US');
      expect(us.escalationSteps.length, 5);
    });

    test('GB has 3 escalation steps', () {
      final gb = kInsuranceRegions.firstWhere((r) => r.code == 'GB');
      expect(gb.escalationSteps.length, 3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // kDefaultRegion
  // ═══════════════════════════════════════════════════════════════════════════

  group('kDefaultRegion', () {
    test('defaults to India', () {
      expect(kDefaultRegion.code, 'IN');
    });

    test('default region has INR currency', () {
      expect(kDefaultRegion.currencyCode, 'INR');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // regionByCode
  // ═══════════════════════════════════════════════════════════════════════════

  group('regionByCode()', () {
    test('returns correct region for "US"', () {
      expect(regionByCode('US').code, 'US');
      expect(regionByCode('US').currencyCode, 'USD');
    });

    test('returns correct region for "GB"', () {
      expect(regionByCode('GB').code, 'GB');
    });

    test('returns correct region for "IN"', () {
      expect(regionByCode('IN').code, 'IN');
    });

    test('returns correct region for "CA"', () {
      expect(regionByCode('CA').code, 'CA');
    });

    test('returns correct region for "AU"', () {
      expect(regionByCode('AU').code, 'AU');
    });

    test('returns correct region for "EU"', () {
      expect(regionByCode('EU').code, 'EU');
    });

    test('falls back to default (IN) for unknown code', () {
      expect(regionByCode('ZZ').code, 'IN');
    });

    test('falls back to default for null', () {
      expect(regionByCode(null).code, 'IN');
    });

    test('falls back to default for empty string', () {
      expect(regionByCode('').code, 'IN');
    });

    test('is case-sensitive — lowercase "us" falls back to default', () {
      // Codes are stored uppercase; lowercase lookup should miss and return default
      expect(regionByCode('us').code, 'IN');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // regionByCurrency
  // ═══════════════════════════════════════════════════════════════════════════

  group('regionByCurrency()', () {
    test('returns US region for "USD"', () {
      expect(regionByCurrency('USD').code, 'US');
    });

    test('returns GB region for "GBP"', () {
      expect(regionByCurrency('GBP').code, 'GB');
    });

    test('returns IN region for "INR"', () {
      expect(regionByCurrency('INR').code, 'IN');
    });

    test('returns CA region for "CAD"', () {
      expect(regionByCurrency('CAD').code, 'CA');
    });

    test('returns AU region for "AUD"', () {
      expect(regionByCurrency('AUD').code, 'AU');
    });

    test('returns EU region for "EUR"', () {
      expect(regionByCurrency('EUR').code, 'EU');
    });

    test('falls back to default for unknown currency', () {
      expect(regionByCurrency('JPY').code, 'IN');
    });

    test('falls back to default for null', () {
      expect(regionByCurrency(null).code, 'IN');
    });

    test('falls back to default for empty string', () {
      expect(regionByCurrency('').code, 'IN');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // formatMoney
  // ═══════════════════════════════════════════════════════════════════════════

  group('formatMoney()', () {
    test('formats USD whole number without decimals', () {
      final result = formatMoney(1250, 'USD');
      expect(result, contains('1,250'));
      expect(result, contains(r'$'));
      expect(result, isNot(contains('.')));
    });

    test('formats USD fractional amount with 2 decimals', () {
      final result = formatMoney(1250.50, 'USD');
      expect(result, contains('1,250'));
      expect(result, contains('.50'));
    });

    test('formats INR whole number without decimals', () {
      final result = formatMoney(500000, 'INR');
      expect(result, contains('₹'));
      expect(result, isNot(contains('.')));
    });

    test('formats GBP correctly', () {
      final result = formatMoney(1000, 'GBP');
      expect(result, contains('£'));
    });

    test('formats EUR correctly', () {
      final result = formatMoney(2000, 'EUR');
      expect(result, contains('€'));
    });

    test('zero amount formats without crash', () {
      expect(() => formatMoney(0, 'USD'), returnsNormally);
    });

    test('very large amount formats without crash', () {
      expect(() => formatMoney(99999999, 'INR'), returnsNormally);
    });

    test('unknown currency falls back to INR symbol (default region)', () {
      final result = formatMoney(500, 'JPY');
      expect(result, contains('₹')); // falls back to IN default
    });

    test('whole number check: amount exactly at .0 is treated as whole', () {
      final result = formatMoney(100.0, 'USD');
      expect(result, isNot(contains('.')));
    });

    test('fractional check: amount with .5 shows decimals', () {
      final result = formatMoney(100.5, 'USD');
      expect(result, contains('.'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // InsuranceRegion.flag
  // ═══════════════════════════════════════════════════════════════════════════

  group('InsuranceRegion.flag', () {
    test('US flag is a non-empty string', () {
      expect(regionByCode('US').flag, isNotEmpty);
    });

    test('EU flag is the EU emoji', () {
      expect(regionByCode('EU').flag, '🇪🇺');
    });

    test('IN flag is a non-empty string', () {
      expect(regionByCode('IN').flag, isNotEmpty);
    });

    test('all regions produce a non-empty flag', () {
      for (final r in kInsuranceRegions) {
        expect(r.flag, isNotEmpty, reason: 'Empty flag for: ${r.code}');
      }
    });
  });
}
