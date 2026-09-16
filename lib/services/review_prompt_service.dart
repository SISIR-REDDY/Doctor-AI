import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Asks for a store review only at a moment of genuine delight, and rarely.
///
/// The system dialog is rate-limited by Apple (≈3 per year) and Google, and
/// asking at the wrong time — after an error, on first launch, mid-task — is
/// how apps collect two-star "keeps nagging me" reviews. So:
///   • only after the user has recorded money recovered (a real win),
///   • never more than once per 120 days,
///   • never in the first 24 hours of use.
class ReviewPromptService {
  ReviewPromptService._();
  static final instance = ReviewPromptService._();

  static const _kLastAsked = 'review_prompt.last_asked';
  static const _kFirstOpen = 'review_prompt.first_open';
  static const _minGap = Duration(days: 120);
  static const _minAge = Duration(hours: 24);

  Future<void> noteAppOpened() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_kFirstOpen)) {
      await p.setInt(_kFirstOpen, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Call after a positive outcome. Returns true if the prompt was requested
  /// (the OS decides whether it is actually shown).
  Future<bool> maybeAskAfterWin({required double amount}) async {
    if (amount <= 0) return false;
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final first = p.getInt(_kFirstOpen);
    if (first == null || now.difference(DateTime.fromMillisecondsSinceEpoch(first)) < _minAge) {
      return false;
    }
    final last = p.getInt(_kLastAsked);
    if (last != null && now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < _minGap) {
      return false;
    }
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return false;
    await p.setInt(_kLastAsked, now.millisecondsSinceEpoch);
    Analytics.log('review_prompt_requested');
    await review.requestReview();
    return true;
  }
}
