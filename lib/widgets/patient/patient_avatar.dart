import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';

/// Displays a patient profile photo from local storage, or initials as fallback.
class PatientAvatar extends StatelessWidget {
  final ProviderPatientRecord? patient;
  final String? photoUrl;
  final String? firstName;
  final String? lastName;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? initialsColor;
  final Color? borderColor;
  final double borderWidth;

  const PatientAvatar({
    super.key,
    this.patient,
    this.photoUrl,
    this.firstName,
    this.lastName,
    this.size = 72,
    this.borderRadius = 16,
    this.backgroundColor,
    this.initialsColor,
    this.borderColor,
    this.borderWidth = 0,
  }) : assert(patient != null || photoUrl != null || firstName != null || lastName != null);

  factory PatientAvatar.fromPatient(
    ProviderPatientRecord patient, {
    double size = 72,
    double borderRadius = 16,
    Color? backgroundColor,
    Color? initialsColor,
    Color? borderColor,
    double borderWidth = 0,
  }) {
    return PatientAvatar(
      patient: patient,
      photoUrl: patient.photoUrl,
      firstName: patient.firstName,
      lastName: patient.lastName,
      size: size,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      initialsColor: initialsColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  bool get _isCircle => borderRadius >= size / 2;

  String get _resolvedFirstName => firstName ?? patient?.firstName ?? '';
  String get _resolvedLastName => lastName ?? patient?.lastName ?? '';
  String get _patientId => patient?.id ?? '';

  String? get _resolvedPhotoPath {
    final storage = StorageService();
    return storage.resolvePatientPhotoPathSync(
      photoUrl: photoUrl ?? patient?.photoUrl ?? '',
      photoFileName: patient?.photoFileName ?? '',
      patientId: _patientId,
    );
  }

  String get _initials {
    final first = _resolvedFirstName.trim();
    final last = _resolvedLastName.trim();
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    final combined = '$a$b';
    if (combined.isNotEmpty) return combined;
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.12);
    final path = _resolvedPhotoPath;
    final hasPhoto = path != null;

    Widget content;
    if (hasPhoto) {
      content = Image.file(
        File(path),
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _initialsPlaceholder(bg),
      );
    } else {
      content = _initialsPlaceholder(bg);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _isCircle ? null : BorderRadius.circular(borderRadius),
        shape: _isCircle ? BoxShape.circle : BoxShape.rectangle,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _initialsPlaceholder(Color bg) {
    return ColoredBox(
      color: bg,
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: initialsColor ?? AppTheme.primaryColor,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
