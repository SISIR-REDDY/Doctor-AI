import 'dart:io';
import 'dart:math' as math;

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
import 'welcome_backdrop.dart';
import 'welcome_scenes.dart';
import 'welcome_overview.dart';
import 'welcome_scenes_care.dart';

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

  /// Continuous scroll position — drives the backdrop, rail and parallax.
  double _scroll = 0;
  bool _agreed = false;
  bool _loadingGoogle = false;
  bool _loadingApple = false;

  static const _slideCount = 7;
  bool get _onSignIn => _index == _slideCount;

  /// Backdrop accent per page. The sign-in step keeps the last slide's hue so
  /// the transition into it feels continuous rather than like a new screen.
  static const _accents = <Color>[
    Color(0xFF007AFF), // overview
    Color(0xFF007AFF), // bills
    Color(0xFF5856D6), // denials
    Color(0xFF32ADE6), // reports
    Color(0xFF34C759), // assistant
    Color(0xFFAF52DE), // vault
    Color(0xFF30B0C7), // money
    Color(0xFF30B0C7), // sign-in keeps the last hue
  ];

  /// One chapter per problem the app solves. Order: the money hook first
  /// (largest, most immediate payoff), then understanding, then the daily
  /// tools, then the payoff. Every statistic is sourced in the launch
  /// checklist; keep them defensible.
  static const _slides = <_SlideCopy>[
    _SlideCopy(
      eyebrow: 'Bills · appeals · results · meds · records · family',
      title: 'Healthcare is a mess.\nClinix sorts it.',
      body:
          'One private place for every bill, letter, report and prescription — read for you, explained in plain English, and turned into the next step.',
    ),
    _SlideCopy(
      eyebrow: '8 in 10 medical bills contain an error',
      title: 'Photograph it.\nWe find the errors.',
      body:
          'Clinix reads every line, matches each code against published Medicare rates, and shows you which charges don’t hold up — and what they should have cost.',
    ),
    _SlideCopy(
      eyebrow: 'Under 1% of denials are ever appealed',
      title: 'Denied?\nThat’s not the end.',
      body:
          'Roughly half of appeals succeed — most people just never file one. Snap the letter and Clinix explains the reason, drafts the appeal, and sets the deadlines for your country — ACA external review in the US, the Ombudsman in the UK and Australia, OLHI in Canada.',
    ),
    _SlideCopy(
      eyebrow: 'Results now arrive before your doctor calls',
      title: 'Your results,\nin plain English.',
      body:
          'By law, labs and reports land in your portal instantly — as raw numbers. Scan any report and Clinix tells you what each marker means, what’s off, and what to ask about.',
    ),
    _SlideCopy(
      eyebrow: 'Doctor-messaging apps charge \$49 a month',
      title: 'Ask anything.\nAny hour.',
      body:
          'An AI health assistant that has actually read your records — talk or type, and it answers with your own history in view. Clear about what it is: information, never a diagnosis.',
    ),
    _SlideCopy(
      eyebrow: '125,000 lives a year lost to missed medication',
      title: 'One vault.\nThe whole family.',
      body:
          'Records, prescriptions, lab history and reminders in one private place — yours, your parents’, your kids’. The reminder fires; the streak counts; nothing gets lost between doctors.',
    ),
    _SlideCopy(
      eyebrow: 'Every letter, deadline and outcome in one place',
      title: 'You send it.\nYou keep it.',
      body:
          'Clinix never contacts your insurer and never takes a cut. It prepares the case; you stay in control. Every dollar you win back is counted here.',
    ),
  ];

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
          duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  void _skip() {
    HapticFeedback.selectionClick();
    _page.animateToPage(_slideCount,
        duration: const Duration(milliseconds: 560), curve: Curves.easeOutCubic);
  }

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
    final accent = _accents[_index.clamp(0, _accents.length - 1)];
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Full-bleed: the backdrop runs under the status bar and home indicator.
      body: Stack(
        children: [
          Positioned.fill(
            child: WelcomeBackdrop(scroll: _scroll, accents: _accents),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  onSkip: _onSignIn ? null : _skip,
                  showSkip: !_onSignIn,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _slideCount + 1,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                      Analytics.onboardingStep('welcome_$i');
                    },
                    itemBuilder: (context, i) {
                      if (i == _slideCount) {
                        return _SignInStep(
                          agreed: _agreed,
                          onAgreedChanged: (v) => setState(() => _agreed = v),
                          loadingGoogle: _loadingGoogle,
                          loadingApple: _loadingApple,
                          onGoogle: () => _signIn(() => _auth.signInWithGoogle(),
                              (v) => setState(() => _loadingGoogle = v)),
                          onApple: () => _signIn(() => _auth.signInWithApple(),
                              (v) => setState(() => _loadingApple = v)),
                        );
                      }
                      return _Slide(
                        index: i,
                        scroll: _scroll,
                        active: _index == i,
                        copy: _slides[i],
                        scene: switch (i) {
                          0 => (o, a) => OverviewScene(offset: o, active: a),
                          1 => (o, a) => BillScene(offset: o, active: a),
                          2 => (o, a) => DenialScene(offset: o, active: a),
                          3 => (o, a) => ReportScene(offset: o, active: a),
                          4 => (o, a) => AssistantScene(offset: o, active: a),
                          5 => (o, a) => VaultScene(offset: o, active: a),
                          _ => (o, a) => MoneyScene(offset: o, active: a),
                        },
                      );
                    },
                  ),
                ),
                _BottomBar(
                  index: _index,
                  scroll: _scroll,
                  slideCount: _slideCount,
                  accent: accent,
                  onNext: _next,
                  onSignIn: _onSignIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy for one slide, kept separate so the slide widget stays presentational.
class _SlideCopy {
  final String eyebrow;
  final String title;
  final String body;
  const _SlideCopy({required this.eyebrow, required this.title, required this.body});
}

// ── Chrome ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback? onSkip;
  final bool showSkip;
  const _TopBar({required this.onSkip, required this.showSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 14, 0),
      child: Row(
        children: [
          const _BrandMark(),
          const Spacer(),
          AnimatedOpacity(
            duration: Motion.fast,
            opacity: showSkip ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Skip',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final double scroll;
  final int slideCount;
  final Color accent;
  final VoidCallback onNext;
  final bool onSignIn;

  const _BottomBar({
    required this.index,
    required this.scroll,
    required this.slideCount,
    required this.accent,
    required this.onNext,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 14 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressRail(
            count: slideCount,
            scroll: scroll.clamp(0.0, slideCount.toDouble()),
            color: accent,
          ),
          const SizedBox(height: 18),
          // The CTA collapses on the sign-in page, where the auth buttons
          // are the only affordance that should be competing for attention.
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.enter,
            child: onSignIn
                ? const SizedBox(width: double.infinity, height: 0)
                : HeroButton(
                    label: index == slideCount - 1 ? 'Get started' : 'Continue',
                    onTap: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}

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
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(CupertinoIcons.shield_fill, color: Colors.white, size: 17),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text('Clinix',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ── Slide ─────────────────────────────────────────────────────────────────────

typedef _SceneBuilder = Widget Function(double offset, bool active);

class _Slide extends StatefulWidget {
  final int index;
  final double scroll;
  final bool active;
  final _SlideCopy copy;
  final _SceneBuilder scene;

  const _Slide({
    required this.index,
    required this.scroll,
    required this.active,
    required this.copy,
    required this.scene,
  });

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 1400);

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
    // Distance from centre: 0 settled, ±1 a full page away.
    final offset = widget.scroll - widget.index;

    return LayoutBuilder(builder: (context, c) {
      final tight = c.maxHeight < 640;
      final titleSize = tight ? 30.0 : 36.0;

      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeSlide(
            animation: scene,
            interval: const Interval(0.0, 0.45, curve: Motion.enter),
            dy: 14,
            dx: 10,
            child: _Eyebrow(text: widget.copy.eyebrow),
          ),
          SizedBox(height: tight ? 10 : 14),
          FadeSlide(
            animation: scene,
            interval: const Interval(0.12, 0.62, curve: Motion.springHeavy),
            dy: 20,
            child: Text(
              widget.copy.title,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.04,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(height: tight ? 10 : 14),
          FadeSlide(
            animation: scene,
            interval: const Interval(0.26, 0.8, curve: Motion.enter),
            dy: 22,
            child: Text(
              widget.copy.body,
              style: TextStyle(
                fontSize: tight ? 14.5 : 16,
                height: 1.5,
                letterSpacing: -0.1,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: tight ? 8 : 16),
        ],
      );

      // Reserve a floor for the demo; if the copy needs more than what is
      // left, the slide scrolls rather than squeezing the demo to nothing —
      // the same thing iOS does under large Dynamic Type.
      const demoFloor = 180.0;
      final gap = tight ? 14.0 : 26.0;

      return Padding(
        padding: EdgeInsets.fromLTRB(24, tight ? 4 : 12, 24, 0),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            // Fill the viewport when content is short, grow past it when not.
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // A plain box, not a flex child: inside a scrollable the
                // height is unbounded, so flex has nothing to divide.
                SizedBox(
                  height: math.max(demoFloor, c.maxHeight * 0.52),
                  width: double.infinity,
                  // Bottom-aligned: the card meets the copy instead of
                  // floating mid-region with a void beneath it.
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    // The card itself arrives with weight — a heavy spring
                    // from 94% — before its contents start their story.
                    child: FadeSlide(
                      animation: scene,
                      interval: const Interval(0.0, 0.55, curve: Motion.springHeavy),
                      dy: 26,
                      from: 0.94,
                      child: widget.scene(offset, widget.active),
                    ),
                  ),
                ),
                SizedBox(height: gap),
                copy,
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Small capsule above the headline carrying the statistic that makes the case.
class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow({required this.text});

  @override
  Widget build(BuildContext context) {
    // iOS tinted capsule: accent text on a light accent fill.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: AppTheme.isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: AppTheme.primaryColor,
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
        CupertinoPageRoute(builder: (_) => LegalDocumentScreen(doc: doc)),
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
              // Wraps instead of overflowing at large accessibility type.
              Flexible(
                child: Text('Encrypted in transit and at rest',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600)),
              ),
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
                    child: const CupertinoActivityIndicator())
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      // Ellipsise rather than overflow on a narrow phone or
                      // at large type — the icon already identifies the button.
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: foreground,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
