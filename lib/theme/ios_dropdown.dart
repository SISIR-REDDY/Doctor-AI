import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Drop-in for `DropdownButtonFormField` that opens an iOS action sheet
/// instead of a Material menu. Same parameters, so call sites swap 1:1.
///
/// The field itself uses the app's `InputDecoration` theme so it lines up
/// with the text fields around it; the chevron marks it as a chooser.
class IosDropdownFormField<T> extends StatelessWidget {
  final T? value;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final bool isExpanded;
  final Widget? hint;

  const IosDropdownFormField({
    super.key,
    this.value,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.decoration,
    this.isExpanded = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final current = value ?? initialValue;
    DropdownMenuItem<T>? selected;
    for (final i in items) {
      if (i.value == current) {
        selected = i;
        break;
      }
    }
    final enabled = onChanged != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _open(context, current) : null,
      child: InputDecorator(
        decoration: (decoration ?? const InputDecoration()).copyWith(
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(CupertinoIcons.chevron_up_chevron_down, size: 16, color: AppTheme.textTertiary),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        isEmpty: selected == null && hint == null,
        child: DefaultTextStyle(
          style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          child: selected?.child ?? hint ?? const SizedBox(height: 20),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, T? current) async {
    final title = decoration?.labelText ?? decoration?.hintText;
    final picked = await showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final i in items)
            CupertinoActionSheetAction(
              isDefaultAction: i.value == current,
              onPressed: () => Navigator.pop(ctx, i.value),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: i.value == current ? FontWeight.w600 : FontWeight.w400,
                  color: AppTheme.primaryColor,
                ),
                child: i.child,
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) onChanged?.call(picked);
  }
}
