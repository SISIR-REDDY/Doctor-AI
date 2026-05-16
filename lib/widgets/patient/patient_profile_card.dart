import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_error_handler.dart';
import '../../models/health_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';

/// Premium patient profile card with avatar, vitals chips, and contact details.
class PatientProfileCard extends StatefulWidget {
  final ProviderPatientRecord patient;
  final ValueChanged<ProviderPatientRecord>? onPatientUpdated;

  const PatientProfileCard({
    super.key,
    required this.patient,
    this.onPatientUpdated,
  });

  @override
  State<PatientProfileCard> createState() => _PatientProfileCardState();
}

class _PatientProfileCardState extends State<PatientProfileCard> {
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();

  late ProviderPatientRecord _patient;
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  @override
  void didUpdateWidget(covariant PatientProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.id != widget.patient.id ||
        oldWidget.patient.updatedAt != widget.patient.updatedAt) {
      _patient = widget.patient;
    }
  }

  bool get _hasPhoto {
    final path = _patient.photoUrl;
    return path.isNotEmpty && File(path).existsSync();
  }

  Future<void> _showPhotoOptions() async {
    final hasPhoto = _hasPhoto;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Patient Photo', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.lg),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.secondaryColor),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick an existing photo'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppTheme.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                  ),
                  title: const Text('Remove Photo'),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              const SizedBox(height: AppTheme.sm),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'camera':
        await _pickAndSavePhoto(ImageSource.camera);
      case 'gallery':
        await _pickAndSavePhoto(ImageSource.gallery);
      case 'remove':
        await _removePhoto();
    }
  }

  Future<void> _pickAndSavePhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUpdatingPhoto = true);

      final savedPath = await _storage.savePatientPhoto(
        sourcePath: picked.path,
        patientId: _patient.id,
      );
      if (savedPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save photo')),
          );
        }
        return;
      }

      final oldPath = _patient.photoUrl;
      final updated = _patient.copyWith(
        photoUrl: savedPath,
        updatedAt: DateTime.now(),
      );

      await _firestore.savePatientRecord(updated);
      if (oldPath.isNotEmpty && oldPath != savedPath) {
        await _storage.deletePatientPhoto(oldPath);
      }

      if (!mounted) return;
      setState(() => _patient = updated);
      widget.onPatientUpdated?.call(updated);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUpdatingPhoto = true);
    try {
      final oldPath = _patient.photoUrl;
      final updated = _patient.copyWith(
        photoUrl: '',
        updatedAt: DateTime.now(),
      );
      await _firestore.savePatientRecord(updated);
      if (oldPath.isNotEmpty) {
        await _storage.deletePatientPhoto(oldPath);
      }
      if (!mounted) return;
      setState(() => _patient = updated);
      widget.onPatientUpdated?.call(updated);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _patient.fullName.isEmpty ? 'Unknown Patient' : _patient.fullName;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.lg, AppTheme.lg, AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(displayName),
          _buildDetails(),
        ],
      ),
    );
  }

  Widget _buildHeader(String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.xl, AppTheme.lg, AppTheme.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0078D4), Color(0xFF00A4BD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUpdatingPhoto ? null : _showPhotoOptions,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _buildAvatar()),
                ),
                if (_isUpdatingPhoto)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            displayName,
            style: AppTheme.headingSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.xs,
            alignment: WrapAlignment.center,
            children: [
              _chip(Icons.cake_outlined, '${_patient.age} yrs'),
              _chip(Icons.wc_outlined, _displayOr(_patient.gender, 'Unknown')),
              if (_patient.bloodType.isNotEmpty)
                _chip(Icons.bloodtype_outlined, _patient.bloodType),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_hasPhoto) {
      return Image.file(
        File(_patient.photoUrl),
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (_, __, ___) => _placeholderAvatar(),
      );
    }
    return _placeholderAvatar();
  }

  Widget _placeholderAvatar() {
    final initials = _getInitials();
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const Icon(Icons.person, size: 48, color: Colors.white70),
      ),
    );
  }

  String _getInitials() {
    final first = _patient.firstName.trim();
    final last = _patient.lastName.trim();
    if (first.isEmpty && last.isEmpty) return '';
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$a$b';
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: Column(
        children: [
          _detailRow(Icons.phone_outlined, 'Phone', _patient.contactNumber),
          const Divider(height: AppTheme.xl, color: AppTheme.dividerColor),
          _detailRow(Icons.email_outlined, 'Email', _patient.email),
          if (_patient.dateOfBirth.isNotEmpty) ...[
            const Divider(height: AppTheme.xl, color: AppTheme.dividerColor),
            _detailRow(
              Icons.calendar_today_outlined,
              'Date of Birth',
              _formatDate(_patient.dateOfBirth),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final display = _displayOr(value, 'Not set');
    final isEmpty = value.trim().isEmpty;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sm),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: AppTheme.smallRadius,
          ),
          child: Icon(icon, size: 20, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelSmall.copyWith(color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 2),
              Text(
                display,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _displayOr(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
