import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../theme/app_theme.dart';
import '../scan/document_scan_screen.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';

/// Every dated obligation across cases — appeal windows, follow-ups,
/// external-review deadlines — with reminders that actually fire.
class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  final _db = FirestoreService();
  Stream<List<CaseDeadline>>? _stream;
  Stream<List<InsuranceClaim>>? _claims;
  String? _uid;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<HealthDataProvider>().uid;
    if (uid != null && uid != _uid) {
      _uid = uid;
      _stream = _db.watchDeadlines(uid);
      _claims = _db.watchClaims(uid);
    }
    return LargeTitleScaffold(
      title: 'Deadlines',
      subtitle: 'Appeal windows and follow-ups across all your cases',
      slivers: [
        if (uid == null)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Please sign in')))
        else
          StreamBuilder<List<CaseDeadline>>(
            stream: _stream,
            builder: (context, snap) {
              final all = snap.data ?? const <CaseDeadline>[];
              final open = all.where((d) => !d.completed).toList();
              final done = all.where((d) => d.completed).toList();
              if (all.isEmpty && snap.connectionState != ConnectionState.waiting) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBadge(CupertinoIcons.calendar_badge_plus, color: AppTheme.primaryColor, size: 72),
                        const SizedBox(height: 18),
                        Text('No deadlines yet', style: AppTheme.headingMedium),
                        const SizedBox(height: 8),
                        Text(
                          'When you add a denial letter or plan an appeal, Clinix adds the appeal windows here and reminds you before they close.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        HeroButton(
                          label: 'Scan a denial letter',
                          icon: CupertinoIcons.doc_text_viewfinder,
                          onTap: () => DocumentScanScreen.open(context, trigger: 'deadlines_empty', docType: DocType.denial),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(DS.gutter, 4, DS.gutter, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (open.isNotEmpty) const DSSectionLabel('UPCOMING'),
                    for (final d in open) _DeadlineCard(deadline: d, uid: uid, db: _db, claims: _claims),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const DSSectionLabel('COMPLETED'),
                      for (final d in done) _DeadlineCard(deadline: d, uid: uid, db: _db, claims: _claims),
                    ],
                  ]),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final CaseDeadline deadline;
  final String uid;
  final FirestoreService db;
  final Stream<List<InsuranceClaim>>? claims;
  const _DeadlineCard({required this.deadline, required this.uid, required this.db, required this.claims});

  Future<void> _toggle() async {
    final updated = deadline.copyWith(completed: !deadline.completed);
    await db.saveDeadline(uid, updated);
    final nid = NotificationService.idFor('deadline_${deadline.id}');
    if (updated.completed) {
      await NotificationService.instance.cancel(nid);
    } else {
      await DeadlineScheduler.schedule(updated);
    }
  }

  Future<void> _openCase(BuildContext context) async {
    final list = await (claims ?? db.watchClaims(uid)).first;
    final c = list.where((x) => x.id == deadline.caseId).firstOrNull;
    if (c != null && context.mounted) {
      Navigator.pushNamed(context, AppRouter.claimDetail, arguments: c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = deadline;
    final color = d.completed
        ? AppTheme.textTertiary
        : d.isOverdue
            ? AppTheme.dangerColor
            : d.daysLeft <= 7
                ? AppTheme.warningColor
                : AppTheme.primaryColor;
    final when = d.completed
        ? 'Done'
        : d.isOverdue
            ? 'Overdue by ${-d.daysLeft} ${-d.daysLeft == 1 ? 'day' : 'days'}'
            : d.daysLeft == 0
                ? 'Due today'
                : 'In ${d.daysLeft} ${d.daysLeft == 1 ? 'day' : 'days'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DSPressable(
        onTap: () => _openCase(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: DS.squircle(DS.rLg),
            border: Border.all(color: AppTheme.glassBorder, width: 0.7),
            boxShadow: DS.softShadow(),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => runGuarded(context, _toggle),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: d.completed ? AppTheme.successColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: d.completed ? AppTheme.successColor : color, width: 1.8),
                  ),
                  child: d.completed ? const Icon(CupertinoIcons.checkmark, size: 16, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            decoration: d.completed ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 2),
                    Text(
                      [if (d.caseTitle.isNotEmpty) d.caseTitle, DateFormat('EEE d MMM yyyy').format(d.dueDate)].join(' · '),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(when, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schedules local notifications for a deadline: 7 days before, 1 day
/// before and on the day (morning). Safe to call repeatedly.
class DeadlineScheduler {
  static Future<void> schedule(CaseDeadline d) async {
    final base = NotificationService.idFor('deadline_${d.id}');
    final ns = NotificationService.instance;
    await ns.cancel(base);
    await ns.cancel(base + 1);
    await ns.cancel(base + 2);
    if (d.completed) return;
    final now = DateTime.now();
    final at9 = DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day, 9);
    final offsets = [
      (const Duration(days: 7), base, 'One week left'),
      (const Duration(days: 1), base + 1, 'Due tomorrow'),
      (Duration.zero, base + 2, 'Due today'),
    ];
    for (final (offset, id, label) in offsets) {
      final when = at9.subtract(offset);
      if (when.isAfter(now)) {
        await ns.scheduleOnce(
          id: id,
          title: '$label: ${d.title}',
          body: d.caseTitle.isNotEmpty ? d.caseTitle : 'Open Clinix to act before the window closes.',
          when: when,
        );
      }
    }
  }

  static Future<void> cancel(CaseDeadline d) async {
    final base = NotificationService.idFor('deadline_${d.id}');
    final ns = NotificationService.instance;
    await ns.cancel(base);
    await ns.cancel(base + 1);
    await ns.cancel(base + 2);
  }
}
