import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/ios18_components.dart';
import '../../theme/motion.dart';
import 'welcome_scenes.dart';

/// The first screen: every use case at a glance, iOS grouped-grid style.
///
/// The chapter slides that follow each demonstrate one of these in depth;
/// this one exists so a user who never swipes still knows the app's scope.
class OverviewScene extends SceneWidget {
  const OverviewScene({
    super.key,
    required super.offset,
    required super.active,
  });

  @override
  State<OverviewScene> createState() => _OverviewSceneState();
}

class _OverviewSceneState extends State<OverviewScene>
    with SingleTickerProviderStateMixin, SceneTimeline {
  @override
  Duration get sceneDuration => const Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    if (widget.active) playScene();
  }

  @override
  void didUpdateWidget(OverviewScene old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) playScene();
  }

  static const _cases = <_UseCase>[
    _UseCase(
      CupertinoIcons.doc_text_viewfinder,
      Color(0xFF007AFF),
      'Bill audit',
      'Overcharges, duplicates, wrong codes',
    ),
    _UseCase(
      CupertinoIcons.envelope_open_fill,
      Color(0xFF5856D6),
      'Denial appeals',
      'Rights, deadlines, ready-to-send letters',
    ),
    _UseCase(
      CupertinoIcons.lab_flask_solid,
      Color(0xFF32ADE6),
      'Lab results decoded',
      'Every marker in plain English, with trends',
    ),
    _UseCase(
      CupertinoIcons.waveform,
      Color(0xFF34C759),
      'AI health assistant',
      'Talk or type — it has read your records',
    ),
    _UseCase(
      CupertinoIcons.capsule_fill,
      Color(0xFFAF52DE),
      'Medications',
      'Reminders, streaks, refill dates',
    ),
    _UseCase(
      CupertinoIcons.folder_fill,
      Color(0xFFFF9500),
      'Records vault',
      'Scans, reports, prescriptions — private',
    ),
    _UseCase(
      CupertinoIcons.shield_lefthalf_fill,
      Color(0xFFFF2D55),
      'Coverage tracker',
      'Deductible, out-of-pocket, what’s left',
    ),
    _UseCase(
      CupertinoIcons.person_2_fill,
      Color(0xFF30B0C7),
      'Family profiles',
      'Parents, kids — one place for all of it',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      offset: widget.offset,
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, c) {
          // Cell height follows the type scale: icon row + two text lines +
          // padding. A fixed aspect ratio would clip at large Dynamic Type.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final cellHeight =
              30 + 8 + (13 * 1.25 + 10.5 * 1.25) * scale + 19 + 6;
          final cellWidth = (c.maxWidth - 8) / 2;
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: cellWidth / cellHeight,
            children: [
              for (var i = 0; i < _cases.length; i++)
                FadeSlide(
                  animation: scene,
                  // Reveal reads left-to-right, row by row.
                  interval: Motion.stagger(
                    i,
                    start: 0.02,
                    step: 0.07,
                    span: 0.42,
                  ),
                  dy: 10,
                  from: 0.94,
                  child: _UseCaseTile(_cases[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UseCase {
  final IconData icon;
  final Color color;
  final String title;
  final String blurb;
  const _UseCase(this.icon, this.color, this.title, this.blurb);
}

class _UseCaseTile extends StatelessWidget {
  final _UseCase c;
  const _UseCaseTile(this.c);

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 10, 9),
      decoration: BoxDecoration(
        // iOS grouped-cell grey on white; lifted grey on dark.
        color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: DS.squircle(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: DS.squircle(8),
            ),
            child: Icon(c.icon, size: 16, color: Colors.white),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                c.blurb,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
