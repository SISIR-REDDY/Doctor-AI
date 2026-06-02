import 'package:flutter/material.dart';

import '../../features/ai_chat/ai_health_assistant_screen.dart';
import '../../features/claims/claim_detail_screen.dart';
import '../../features/claims/claims_screen.dart';
import '../../features/claims/new_claim_screen.dart';
import '../../features/insurance/add_policy_screen.dart';
import '../../features/insurance/insurance_screen.dart';
import '../../features/medications/medications_screen.dart';
import '../../features/profile/health_profile_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/records/record_detail_screen.dart';
import '../../features/records/records_vault_screen.dart';
import '../../features/symptom_journal/symptom_journal_screen.dart';
import '../../models/patient_models.dart';

class AppRouter {
  static const String healthProfile = '/healthProfile';
  static const String aiChat = '/aiChat';
  static const String symptomJournal = '/symptomJournal';
  static const String medications = '/medications';
  static const String recordsVault = '/recordsVault';
  static const String recordDetail = '/recordDetail';
  static const String insurance = '/insurance';
  static const String addPolicy = '/addPolicy';
  static const String claims = '/claims';
  static const String newClaim = '/newClaim';
  static const String claimDetail = '/claimDetail';
  static const String reminders = '/reminders';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case healthProfile:
        return _slide(const HealthProfileScreen(), settings);

      case aiChat:
        return _slide(const AiHealthAssistantScreen(), settings);

      case symptomJournal:
        return _slide(const SymptomJournalScreen(), settings);

      case medications:
        return _slide(const MedicationsScreen(), settings);

      case reminders:
        return _slide(const RemindersScreen(), settings);

      case recordsVault:
        return _slide(const RecordsVaultScreen(), settings);

      case recordDetail:
        final record = settings.arguments as MedicalRecord?;
        if (record != null) {
          return _slide(RecordDetailScreen(record: record), settings);
        }
        return null;

      case insurance:
        return _slide(const InsuranceScreen(), settings);

      case addPolicy:
        final policy = settings.arguments as InsurancePolicy?;
        return _slide(AddPolicyScreen(existingPolicy: policy), settings);

      case claims:
        return _slide(const ClaimsScreen(), settings);

      case newClaim:
        return _slide(const NewClaimScreen(), settings);

      case claimDetail:
        final claim = settings.arguments as InsuranceClaim?;
        if (claim != null) {
          return _slide(ClaimDetailScreen(claim: claim), settings);
        }
        return null;
    }
    return null;
  }

  static PageRouteBuilder<void> _slide(Widget page, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }
}
