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
import '../legal/legal_screens.dart';

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
  bool _agreed = false;
  bool _loadingGoogle = false;
  bool _loadingApple = false;

  static const _slideCount = 3;
  bool get _onSignIn => _index == _slideCount;

  @override
  void initState() {
    super.initState();
    Analytics.screen('welcome');
  }

  @override
  void dispose() {
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
                      art: const _BillArt(),
                      title: 'Scan any medical bill.',
                      body:
                          'Clinix reads every line, checks it against fair-price references, and flags what you shouldn’t be paying.',
                    ),
                    _Slide(
                      art: const _DenialArt(),
                      title: 'Denied? Appeal in minutes.',
                      body:
                          'Photograph the letter. Get a plain-English explanation, your rights, the deadlines, and a ready-to-send appeal.',
                    ),
                    _Slide(
                      art: const _MoneyArt(),
                      title: 'Your money, tracked.',
                      body:
                          'Letters, deadlines and outcomes in one place — with documents stored privately on your device first.',
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

class _Slide extends StatelessWidget {
  final Widget art;
  final String title;
  final String body;
  const _Slide({required this.art, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 560;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Expanded(
              flex: compact ? 5 : 6,
              child: Center(child: art),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 28 : 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.08,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: compact ? 12 : 24),
          ],
        ),
      );
    });
  }
}

/// Mock "bill" card with flagged lines — product-in-context illustration.
class _BillArt extends StatelessWidget {
  const _BillArt();

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    Widget line(String label, String amount, {bool flagged = false, String? tag}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: flagged ? AppTheme.dangerColor : AppTheme.successColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
            if (tag != null) ...[
              Pill(tag, color: AppTheme.dangerColor),
              const SizedBox(width: 8),
            ],
            Text(amount,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: flagged ? AppTheme.dangerColor : AppTheme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
    }

    return _ArtFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(CupertinoIcons.doc_text_fill, color: AppTheme.primaryColor, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riverside Medical Center',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                    Text('Itemized statement · 4 lines',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 22, color: AppTheme.dividerColor),
          line('Office visit, level 4', r'$389'),
          line('CBC with differential', r'$92', flagged: true, tag: '×2 billed'),
          line('CT head w/o contrast', r'$1,850', flagged: true, tag: '5.9× ref'),
          line('Venipuncture', r'$18'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: dark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 16, color: AppTheme.successColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Potential saving  \$1,420 – \$1,610',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DenialArt extends StatelessWidget {
  const _DenialArt();

  @override
  Widget build(BuildContext context) {
    return _ArtFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(CupertinoIcons.envelope_fill, color: AppTheme.dangerColor, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Claim denied — MRI lumbar spine',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                    Text('“Not medically necessary”',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StepRow(done: true, text: 'Denial explained in plain English'),
          _StepRow(done: true, text: 'Your rights & the insurer’s obligations'),
          _StepRow(done: true, text: 'Appeal letter drafted, citing your policy'),
          _StepRow(done: false, text: 'Internal appeal due in 172 days', accent: AppTheme.warningColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill('Strong case', color: AppTheme.successColor, icon: CupertinoIcons.checkmark_seal_fill),
              const SizedBox(width: 8),
              Pill('Deadline tracked', color: AppTheme.primaryColor, icon: CupertinoIcons.bell_fill),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final bool done;
  final String text;
  final Color? accent;
  const _StepRow({required this.done, required this.text, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? (done ? AppTheme.successColor : AppTheme.textTertiary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.clock_fill, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _MoneyArt extends StatelessWidget {
  const _MoneyArt();

  @override
  Widget build(BuildContext context) {
    return _ArtFrame(
      gradient: AppTheme.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Recovered so far',
                  value: r'$2,340',
                  foreground: Colors.white,
                  icon: CupertinoIcons.arrow_down_circle_fill,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Still in dispute',
                  value: r'$1,610',
                  foreground: Colors.white,
                  icon: CupertinoIcons.hourglass,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.lock_shield_fill, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Documents stay on your device first. Nothing is sold, ever.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtFrame extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  const _ArtFrame({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? AppTheme.surfaceColor : null,
            borderRadius: DS.squircle(DS.rXl),
            border: Border.all(color: AppTheme.glassBorder, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B2A4A).withValues(alpha: AppTheme.isDark ? 0.5 : 0.14),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
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
