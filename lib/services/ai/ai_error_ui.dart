import 'package:flutter/cupertino.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_router.dart';
import '../analytics_service.dart';
import 'ai_service.dart';

/// Shows AI failures consistently: quota exhaustion opens the paywall path,
/// anything else is a plain snackbar.
Future<void> showAiError(BuildContext context, Object error, {required String trigger}) async {
  if (error is AiQuotaException) {
    Analytics.quotaHit(error.op);
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(error.isFreePlan ? 'Free limit reached' : 'Limit reached'),
        content: Text('\n${error.message}'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          if (error.isFreePlan)
            CupertinoDialogAction(
                isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('See Pro')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      Analytics.paywallShown('quota_$trigger');
      Navigator.pushNamed(context, AppRouter.paywall);
    }
    return;
  }
  // Not deployed yet: every AI feature fails the same way, and a snackbar
  // reads like a random bug. Say exactly what is wrong and what to run.
  if (error is AppException && error.code == 'ai-backend-missing') {
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Backend not deployed'),
        content: const Text(
          '\nScanning, audits, lab decoding and the assistant all run on the Clinix Cloud Functions, which are not live for this project yet.\n\n'
          'From the repo:\nfirebase deploy --only functions\n\n'
          'See functions/README.md for secrets and setup.',
        ),
        actions: [
          CupertinoDialogAction(
              isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return;
  }
  if (context.mounted) AppErrorHandler.showSnackBar(context, error);
}
