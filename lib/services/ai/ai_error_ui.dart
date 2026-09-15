import 'package:flutter/cupertino.dart';

import '../../core/errors/app_error_handler.dart';
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
  if (context.mounted) AppErrorHandler.showSnackBar(context, error);
}
