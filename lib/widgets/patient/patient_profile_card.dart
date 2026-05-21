import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_error_handler.dart';
import '../../models/health_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';
import 'patient_avatar.dart';
import 'patient_record_section.dart';

const double _profileAvatarSize = 148;

/// Field keys for tap-to-edit on the profile card.
abstract final class PatientFieldKeys {
  static const name = 'name';
  static const phone = 'phone';
  static const email = 'email';
  static const dob = 'dob';
}

/// Premium patient profile card — tap any detail to edit in place.
class PatientProfileCard extends StatefulWidget {
  final ProviderPatientRecord patient;
  final ValueChanged<ProviderPatientRecord>? onPatientUpdated;
  final String? activeField;
  final ValueChanged<String> onActivateField;
  final Future<void> Function() onSaveField;

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController contactController;
  final TextEditingController emailController;
  final TextEditingController dateOfBirthController;
  final String gender;
  final String bloodType;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onBloodTypeChanged;
  final Future<void> Function() onPickDateOfBirth;

  static const genderOptions = ['Male', 'Female', 'Other', 'Unknown'];
  static const bloodTypeOptions = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  const PatientProfileCard({
    super.key,
    required this.patient,
    required this.firstNameController,
    required this.lastNameController,
    required this.contactController,
    required this.emailController,
    required this.dateOfBirthController,
    required this.gender,
    required this.bloodType,
    required this.onActivateField,
    required this.onSaveField,
    required this.onGenderChanged,
    required this.onBloodTypeChanged,
    required this.onPickDateOfBirth,
    this.onPatientUpdated,
    this.activeField,
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
    _storage.warmPatientPhotosCache();
  }

  @override
  void didUpdateWidget(covariant PatientProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.updatedAt != widget.patient.updatedAt ||
        oldWidget.patient.id != widget.patient.id ||
        oldWidget.patient.photoUrl != widget.patient.photoUrl) {
      _patient = widget.patient;
    }
  }

  bool get _hasPhoto =>
      _storage.resolvePatientPhotoPathSync(
        photoUrl: _patient.photoUrl,
        photoFileName: _patient.photoFileName,
        patientId: _patient.id,
      ) !=
      null;

  Future<void> _showPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.md),
            Text('Patient Photo', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: PatientDetailPalette.charcoal),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: PatientDetailPalette.gold),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                title: const Text('Remove Photo'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: AppTheme.sm),
          ],
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
        imageQuality: 72,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUpdatingPhoto = true);
      final saved = await _storage.savePatientPhoto(
        sourcePath: picked.path,
        patientId: _patient.id,
      );
      if (saved == null) return;
      final oldPath = _patient.photoUrl;
      final updated = _patient.copyWith(
        photoUrl: saved.remoteUrl ?? saved.localPath,
        photoFileName: saved.fileName,
        updatedAt: DateTime.now(),
      );
      await _firestore.savePatientRecord(updated);
      if (oldPath.isNotEmpty && oldPath != saved.localPath) {
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
        photoFileName: '',
        updatedAt: DateTime.now(),
      );
      await _firestore.savePatientRecord(updated);
      if (oldPath.isNotEmpty) await _storage.deletePatientPhoto(oldPath);
      if (!mounted) return;
      setState(() => _patient = updated);
      widget.onPatientUpdated?.call(updated);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _showPickerSheet({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.55;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: AppTheme.md, bottom: AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.sm, AppTheme.lg, AppTheme.md),
                  child: Text(title, style: AppTheme.headingSmall),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: AppTheme.lg),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: AppTheme.lg, endIndent: AppTheme.lg),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected = opt == current;
                      return ListTile(
                        title: Text(
                          opt,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? PatientDetailPalette.charcoal : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: PatientDetailPalette.gold)
                            : null,
                        onTap: () => Navigator.pop(ctx, opt),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      onSelected(picked);
      await widget.onSaveField();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.lg, AppTheme.lg, AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: PatientDetailPalette.charcoal.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [_buildHeader(), _buildDetails()],
      ),
    );
  }

  Widget _buildHeader() {
    final editingName = widget.activeField == PatientFieldKeys.name;
    final displayName = _patient.fullName.isEmpty ? 'Tap to add name' : _patient.fullName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.xxl, AppTheme.lg, AppTheme.xl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PatientDetailPalette.charcoal, PatientDetailPalette.slate],
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
                PatientAvatar.fromPatient(
                  _patient,
                  size: _profileAvatarSize,
                  borderRadius: _profileAvatarSize / 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  initialsColor: Colors.white,
                  borderColor: Colors.white,
                  borderWidth: 3,
                ),
                if (_isUpdatingPhoto)
                  Container(
                    width: _profileAvatarSize,
                    height: _profileAvatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  )
                else
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, size: 18, color: PatientDetailPalette.gold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),
          if (editingName) ...[
            _inlineHeaderField(widget.firstNameController, 'First name', autofocus: true),
            const SizedBox(height: AppTheme.sm),
            _inlineHeaderField(widget.lastNameController, 'Last name'),
            const SizedBox(height: AppTheme.sm),
            TextButton.icon(
              onPressed: widget.onSaveField,
              icon: const Icon(Icons.check, color: PatientDetailPalette.gold, size: 18),
              label: const Text('Done', style: TextStyle(color: PatientDetailPalette.gold)),
            ),
          ] else
            _tapTarget(
              fieldKey: PatientFieldKeys.name,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: AppTheme.headingSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontStyle: _patient.fullName.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.xs,
            alignment: WrapAlignment.center,
            children: [
              _tapChip(
                icon: Icons.cake_outlined,
                label: '${_computedAge} yrs',
                onTap: () async {
                  widget.onActivateField(PatientFieldKeys.dob);
                  await widget.onPickDateOfBirth();
                  await widget.onSaveField();
                },
              ),
              _tapChip(
                icon: Icons.wc_outlined,
                label: widget.gender.isEmpty ? 'Gender' : widget.gender,
                onTap: () => _showPickerSheet(
                  title: 'Select Gender',
                  options: PatientProfileCard.genderOptions,
                  current: widget.gender,
                  onSelected: widget.onGenderChanged,
                ),
              ),
              _tapChip(
                icon: Icons.bloodtype_outlined,
                label: widget.bloodType.isEmpty ? 'Blood type' : widget.bloodType,
                onTap: () => _showPickerSheet(
                  title: 'Select Blood Type',
                  options: PatientProfileCard.bloodTypeOptions,
                  current: widget.bloodType.isEmpty
                      ? PatientProfileCard.bloodTypeOptions.first
                      : widget.bloodType,
                  onSelected: widget.onBloodTypeChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _computedAge {
    final dob = DateTime.tryParse(widget.dateOfBirthController.text);
    if (dob == null) return _patient.age;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    return years < 0 ? 0 : years;
  }

  Widget _tapTarget({required String fieldKey, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onActivateField(fieldKey),
        borderRadius: AppTheme.smallRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: AppTheme.xs),
          child: child,
        ),
      ),
    );
  }

  Widget _tapChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
        ),
      ),
    );
  }

  Widget _inlineHeaderField(TextEditingController controller, String hint, {bool autofocus = false}) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => widget.onSaveField(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: AppTheme.smallRadius,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.smallRadius,
          borderSide: const BorderSide(color: PatientDetailPalette.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: Column(
        children: [
          _detailField(
            fieldKey: PatientFieldKeys.phone,
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _patient.contactNumber,
            controller: widget.contactController,
            keyboardType: TextInputType.phone,
          ),
          const Divider(height: AppTheme.xl, color: AppTheme.dividerColor),
          _detailField(
            fieldKey: PatientFieldKeys.email,
            icon: Icons.email_outlined,
            label: 'Email',
            value: _patient.email,
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const Divider(height: AppTheme.xl, color: AppTheme.dividerColor),
          _detailField(
            fieldKey: PatientFieldKeys.dob,
            icon: Icons.calendar_today_outlined,
            label: 'Date of Birth',
            value: _patient.dateOfBirth.isEmpty ? '' : _formatDate(_patient.dateOfBirth),
            controller: widget.dateOfBirthController,
            readOnly: true,
            onTapWhenActive: widget.onPickDateOfBirth,
          ),
        ],
      ),
    );
  }

  Widget _detailField({
    required String fieldKey,
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool readOnly = false,
    Future<void> Function()? onTapWhenActive,
  }) {
    final isActive = widget.activeField == fieldKey;
    final display = value.trim().isEmpty ? 'Tap to add' : value.trim();

    if (isActive) {
      Future<void> openDatePicker() async {
        if (onTapWhenActive != null) {
          await onTapWhenActive();
          await widget.onSaveField();
        }
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldIcon(icon),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: !readOnly,
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              onTap: readOnly ? openDatePicker : null,
              onSubmitted: (_) => widget.onSaveField(),
              decoration: InputDecoration(
                labelText: label,
                hintText: readOnly ? 'Tap to pick date' : null,
                filled: true,
                fillColor: PatientDetailPalette.gold.withValues(alpha: 0.08),
                suffixIcon: readOnly
                    ? IconButton(
                        tooltip: 'Pick date',
                        icon: const Icon(Icons.calendar_today, color: PatientDetailPalette.goldMuted),
                        onPressed: openDatePicker,
                      )
                    : IconButton(
                        tooltip: 'Save',
                        icon: const Icon(Icons.check_circle, color: PatientDetailPalette.gold),
                        onPressed: () => widget.onSaveField(),
                      ),
                border: OutlineInputBorder(borderRadius: AppTheme.smallRadius),
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onActivateField(fieldKey),
        borderRadius: AppTheme.smallRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.xs),
          child: Row(
            children: [
              _fieldIcon(icon),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTheme.labelSmall.copyWith(color: AppTheme.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      display,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value.trim().isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary,
                        fontStyle: value.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sm),
      decoration: BoxDecoration(
        color: PatientDetailPalette.gold.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
      ),
      child: Icon(icon, size: 20, color: PatientDetailPalette.goldMuted),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
