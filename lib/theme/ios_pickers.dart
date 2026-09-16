import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import 'app_theme.dart';

/// iOS wheel pickers in a bottom sheet, with the same signatures as the
/// Material `showDatePicker` / `showTimePicker` so call sites swap 1:1.
///
/// Material's calendar dialog is the single most "Android" moment in an
/// otherwise native-feeling app; a wheel with a Done bar is what iOS users
/// expect for a date-of-birth or a reminder time.

Future<DateTime?> showIosDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '',
}) {
  var picked = initialDate.isBefore(firstDate)
      ? firstDate
      : initialDate.isAfter(lastDate)
          ? lastDate
          : initialDate;
  return _sheet<DateTime>(
    context,
    title: title,
    onDone: () => picked,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: picked,
      minimumDate: firstDate,
      maximumDate: lastDate,
      onDateTimeChanged: (d) => picked = d,
    ),
  );
}

Future<TimeOfDay?> showIosTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = '',
}) {
  final now = DateTime.now();
  var picked = DateTime(now.year, now.month, now.day, initialTime.hour, initialTime.minute);
  return _sheet<TimeOfDay>(
    context,
    title: title,
    onDone: () => TimeOfDay(hour: picked.hour, minute: picked.minute),
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: picked,
      minuteInterval: 5,
      onDateTimeChanged: (d) => picked = d,
    ),
  );
}

Future<T?> _sheet<T>(
  BuildContext context, {
  required String title,
  required T Function() onDone,
  required Widget child,
}) {
  final dark = AppTheme.isDark;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Cancel · title · Done bar, as in UIKit's inline picker sheets.
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx, onDone()),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppTheme.dividerColor),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(fontSize: 21, color: AppTheme.textPrimary),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
