import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../services/analytics_service.dart';
import '../../services/consent_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';
import '../legal/legal_screens.dart';
import 'welcome_scenes.dart';

/// First-run experience: three value slides, then consent + sign-in.
///
/// Consent (Terms, Privacy, "not medical/legal advice") is captured on the
/// sign-in step — the checkbox must be ticked before either sign-in button
/// is enabled, which satisfies App Review 1.4.1 / 5.1.1 without a separate
/// blocking screen.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  final _auth = AuthService();
  int _index = 0;
  /// Continuous scroll position, for per-scene parallax.
  double _scroll = 0;
  bool _agreed = false;
  bool _loadingGoogle = false;
  bool _loadingApple = false;

  static const _slideCount = 3;
  bool get _onSignIn => _index == _slideCount;

  @override
  void initState() {
    super.initState();
    Analytics.screen('welcome');
    _page.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_page.hasClients) return;
    final p = _page.page ?? 0;
    if ((p - _scroll).abs() > 0.004) setState(() => _scroll = p);
  }

  @override
  void dispose() {
    _page.removeListener(_onScroll);
    _page.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_index < _slideCount) {
      _page.animateToPage(_index + 1,
          duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  void _skip() => _page.animateToPage(_slideCount,
      duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);

  Future<void> _signIn(Future<void> Function() action, void Function(bool) setLoading) async {
    if (!_agreed) return;
    setLoading(true);
    try {
      await action();
      await ConsentService.instance.accept();
      Analytics.log('sign_in_success');
    } catch (error) {
      if (!mounted) return;
      final code = error is AppException ? error.code : '';
      if (code != 'google-sign-in-canceled') {
        AppErrorHandler.showSnackBar(context, error);
      }
    } finally {
      if (mounted) setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF0E1420), Color(0xFF0B0B0F)]
                : const [Color(0xFFE4EEFF), Color(0xFFF4F7FC), Color(0xFFF0F4FB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: brand + skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    const _BrandMark(),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _onSignIn ? 0 : 1,
                      child: TextButton(
                        onPressed: _onSignIn ? null : _skip,
                        child: Text('Skip',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    Analytics.onboardingStep('welcome_$i');
                  },
                  children: [
                    _Slide(
                      index: 0,
                      scroll: _scroll,
                      active: _index == 0,
                      art: (o, a) => BillScene(offset: o, active: a),
                      eyebrow: '8 in 10 bills contain an error',
                      title: 'Photograph it.\nWe find the errors.',
                      body:
                          'Clinix reads every line, matches each code against published Medicare rates, and shows you exactly which charges don’t hold up — and what they should have cost.',
                    ),
                    _Slide(
                      index: 1,
                      scroll: _scroll,
                      active: _index == 1,
                      art: (o, a) => DenialScene(offset: o, active: a),
                      eyebrow: 'Fewer than 1% of denials are ever appealed',
                      title: 'Denied?\nThat’s not the end.',
                      body:
                          'Roughly half of appeals succeed — most people just never file one. Snap the letter and Clinix explains the real reason, finds your rights, drafts the appeal and tracks the deadline.',
                    ),
                    _Slide(
                      index: 2,
                      scroll: _scroll,
                      active: _index == 2,
                      art: (o, a) => MoneyScene(offset: o, active: a),
                      eyebrow: 'Every letter, deadline and outcome in one place',
                      title: 'You send it.\nYou keep it.',
                      body:
                          'Clinix never contacts your insurer or takes a cut — it prepares the case and you stay in control. Every dollar you win back is counted here.',
                    ),
                    _SignInStep(
                      agreed: _agreed,
                      onAgreedChanged: (v) => setState(() => _agreed = v),
                      loadingGoogle: _loadingGoogle,
                      loadingApple: _loadingApple,
                      onGoogle: () => _signIn(
                          () => _auth.signInWithGoogle(),
                          (v) => setState(() => _loadingGoogle = v)),
                      onApple: () => _signIn(
                          () => _auth.signInWithApple(),
                          (v) => setState(() => _loadingApple = v)),
                    ),
                  ],
                ),
              ),
              // Bottom: dots + continue
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Column(
                  children: [
                    _Dots(count: _slideCount + 1, index: _index),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _onSignIn
                          ? const SizedBox(height: 0, key: ValueKey('none'))
                          : HeroButton(
                              key: const ValueKey('next'),
                              label: _index == _slideCount - 1
                                  ? 'Get started'
                                  : 'Continue',
                              onTap: _next,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text('Clinix',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: on ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: on ? AppTheme.primaryColor : AppTheme.textTertiary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _Slide extends StatefulWidget {
  final int index;
  final double scroll;
  final bool active;
  final Widget Function(double offset, bool active) art;
  final String eyebrow;
  final String title;
  final String body;

  const _Slide({
    required this.index,
    required this.scroll,
    required this.active,
    required this.art,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(_Slide old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  @override
  Widget build(BuildContext context) {
    // How far this page is from centre: 0 when settled, ±1 when a page away.
    final offset = widget.scroll - widget.index;
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 620;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Expanded(
              flex: compact ? 5 : 6,
              child: Center(child: widget.art(offset, widget.active)),
            ),
            // Copy trails the art slightly so the eye lands on the card first.
            FadeSlide(
              animation: scene,
              interval: const Interval(0.05, 0.55, curve: Motion.enter),
              dy: 16,
              child: Text(
                widget.eyebrow.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 11),
            FadeSlide(
              animation: scene,
              interval: const Interval(0.15, 0.7, curve: Motion.enter),
              dy: 18,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 29 : 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.06,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            SizedBox(height: compact ? 9 : 13),
            FadeSlide(
              animation: scene,
              interval: const Interval(0.28, 0.85, curve: Motion.enter),
              dy: 20,
              child: Text(
                widget.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 14.5 : 15.5,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 20),
          ],
        ),
      );
    });
  }
}

// ── Sign-in step ──────────────────────────────────────────────────────────────

class _SignInStep extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;
  final bool loadingGoogle;
  final bool loadingApple;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const _SignInStep({
    required this.agreed,
    required this.onAgreedChanged,
    required this.loadingGoogle,
    required this.loadingApple,
    required this.onGoogle,
    required this.onApple,
  });

  void _open(BuildContext context, LegalDoc doc) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Create your account',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to keep your documents backed up and your cases in sync.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 26),
          _ConsentCard(
            agreed: agreed,
            onChanged: onAgreedChanged,
            onOpen: (d) => _open(context, d),
          ),
          const SizedBox(height: 18),
          if (Platform.isIOS) ...[
            _AuthButton(
              label: 'Continue with Apple',
              icon: const Icon(Icons.apple, color: Colors.white, size: 24),
              background: Colors.black,
              foreground: Colors.white,
              loading: loadingApple,
              enabled: agreed,
              onTap: onApple,
            ),
            const SizedBox(height: 10),
          ],
          _AuthButton(
            label: 'Continue with Google',
            icon: Image.asset('assets/images/google_logo.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.g_mobiledata, size: 24, color: Colors.black87)),
            background: Colors.white,
            foreground: const Color(0xFF1C1C1E),
            loading: loadingGoogle,
            enabled: agreed,
            onTap: onGoogle,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.lock_fill, size: 12, color: AppTheme.textTertiary),
              const SizedBox(width: 5),
              Text('Encrypted in transit and at rest',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatefulWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;
  final void Function(LegalDoc) onOpen;
  const _ConsentCard({required this.agreed, required this.onChanged, required this.onOpen});

  @override
  State<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends State<_ConsentCard> {
  late final Map<LegalDoc, TapGestureRecognizer> _taps = {
    for (final d in LegalDoc.values)
      d: TapGestureRecognizer()..onTap = () => widget.onOpen(d),
  };

  @override
  void dispose() {
    for (final r in _taps.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agreed = widget.agreed;
    final link = TextStyle(
        color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13);
    final base = TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.45);
    return InsetCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bullet(icon: CupertinoIcons.heart_fill, color: AppTheme.dangerColor,
              text: 'General information only — not medical advice. In an emergency call your local emergency number.'),
          _Bullet(icon: CupertinoIcons.doc_plaintext, color: AppTheme.warningColor,
              text: 'Letters and analyses are drafts for you to review and send yourself — not legal or financial advice.'),
          _Bullet(icon: CupertinoIcons.sparkles, color: AppTheme.primaryColor,
              text: 'Documents you scan are processed by our AI provider on a no-training, no-human-review tier.'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onChanged(!agreed);
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: agreed ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: agreed ? AppTheme.primaryColor : AppTheme.textTertiary,
                        width: 1.6,
                      ),
                    ),
                    child: agreed
                        ? const Icon(CupertinoIcons.checkmark, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(TextSpan(style: base, children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(text: 'Terms of Use', style: link, recognizer: _taps[LegalDoc.terms]),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: link, recognizer: _taps[LegalDoc.privacy]),
                    const TextSpan(text: ', and I understand the '),
                    TextSpan(text: 'Medical', style: link, recognizer: _taps[LegalDoc.medical]),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Insurance', style: link, recognizer: _taps[LegalDoc.insurance]),
                    const TextSpan(text: ' disclaimers.'),
                  ])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Bullet({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color background;
  final Color foreground;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: AppTheme.glassBorder, width: 0.8),
            boxShadow: DS.softShadow(y: 4, blur: 14),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Text(label,
                          style: TextStyle(
                              color: foreground,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
