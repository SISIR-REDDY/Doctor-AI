import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../theme/app_theme.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyPhoneCtrl;

  String _gender = 'Male';
  String _bloodGroup = 'Unknown';
  String _emergencyRelation = 'Spouse';
  DateTime? _dob;

  // Allergy / condition lists
  late List<String> _medAllergies;
  late List<String> _foodAllergies;
  late List<String> _pastDiseases;
  late List<String> _chronicConditions;

  final _addCtrl = TextEditingController();

  final _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown'
  ];
  final _relations = [
    'Spouse', 'Parent', 'Sibling', 'Child', 'Friend', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initFromProfile(context.read<HealthDataProvider>().profile);
  }

  void _initFromProfile(PatientProfile? p) {
    _firstNameCtrl = TextEditingController(text: p?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: p?.lastName ?? '');
    _heightCtrl =
        TextEditingController(text: p != null && p.height > 0 ? '${p.height}' : '');
    _weightCtrl =
        TextEditingController(text: p != null && p.weight > 0 ? '${p.weight}' : '');
    _phoneCtrl = TextEditingController(text: p?.contactNumber ?? '');
    _emergencyNameCtrl =
        TextEditingController(text: p?.emergencyContactName ?? '');
    _emergencyPhoneCtrl =
        TextEditingController(text: p?.emergencyContactPhone ?? '');
    _gender = p?.gender ?? 'Male';
    _bloodGroup = p?.bloodGroup ?? 'Unknown';
    _emergencyRelation = p?.emergencyContactRelation ?? 'Spouse';
    _dob = p != null && p.dateOfBirth.isNotEmpty
        ? DateTime.tryParse(p.dateOfBirth)
        : null;
    _medAllergies = List<String>.from(p?.medicalAllergies ?? []);
    _foodAllergies = List<String>.from(p?.foodAllergies ?? []);
    _pastDiseases = List<String>.from(p?.pastDiseases ?? []);
    _chronicConditions = List<String>.from(p?.chronicConditions ?? []);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final updated = PatientProfile(
        id: uid,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dateOfBirth: _dob?.toIso8601String().split('T').first ?? '',
        gender: _gender,
        bloodGroup: _bloodGroup,
        height: double.tryParse(_heightCtrl.text) ?? 0,
        weight: double.tryParse(_weightCtrl.text) ?? 0,
        contactNumber: _phoneCtrl.text.trim(),
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        medicalAllergies: _medAllergies,
        foodAllergies: _foodAllergies,
        pastDiseases: _pastDiseases,
        chronicConditions: _chronicConditions,
        emergencyContactName: _emergencyNameCtrl.text.trim(),
        emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
        emergencyContactRelation: _emergencyRelation,
      );
      await context.read<HealthDataProvider>().saveProfile(updated);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dob = d);
  }

  void _showAddDialog(String title, List<String> list) {
    _addCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $title'),
        content: TextField(
          controller: _addCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: 'e.g. Penicillin'),
          onSubmitted: (_) => _confirmAdd(list),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => _confirmAdd(list),
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _confirmAdd(List<String> list) {
    final v = _addCtrl.text.trim();
    if (v.isNotEmpty && !list.contains(v)) {
      setState(() => list.add(v));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<HealthDataProvider>().profile;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Health Profile'),
        actions: [
          if (!_editing)
            TextButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('Edit'))
          else
            TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          // Avatar & summary
          _ProfileHeader(profile: profile),
          const SizedBox(height: AppTheme.lg),

          // Basic Info
          _Section(
            title: 'Personal Details',
            children: [
              if (_editing) ...[
                Row(
                  children: [
                    Expanded(
                        child: _Field('First Name', _firstNameCtrl,
                            enabled: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Field('Last Name', _lastNameCtrl,
                            enabled: true)),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: _Field(
                      'Date of Birth',
                      TextEditingController(
                          text: _dob == null
                              ? ''
                              : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
                      enabled: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                _DropdownField('Gender', _gender, _genders,
                    (v) => setState(() => _gender = v!)),
                const SizedBox(height: AppTheme.md),
                _DropdownField('Blood Group', _bloodGroup, _bloodGroups,
                    (v) => setState(() => _bloodGroup = v!)),
                const SizedBox(height: AppTheme.md),
                Row(
                  children: [
                    Expanded(
                        child: _Field('Height (cm)', _heightCtrl,
                            enabled: true,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Field('Weight (kg)', _weightCtrl,
                            enabled: true,
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                _Field('Phone', _phoneCtrl,
                    enabled: true,
                    keyboardType: TextInputType.phone),
              ] else ...[
                _InfoRow(Icons.person_outline_rounded, 'Name',
                    profile?.fullName ?? '—'),
                _InfoRow(Icons.cake_outlined, 'Date of Birth',
                    _dob == null
                        ? '—'
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
                _InfoRow(
                    Icons.wc_rounded, 'Gender', profile?.gender ?? '—'),
                _InfoRow(Icons.bloodtype_outlined, 'Blood Group',
                    profile?.bloodGroup ?? '—'),
                _InfoRow(Icons.height_rounded, 'Height/Weight',
                    profile != null && profile.height > 0
                        ? '${profile.height} cm / ${profile.weight} kg'
                        : '—'),
                if (profile != null && profile.bmi > 0)
                  _InfoRow(Icons.monitor_weight_outlined, 'BMI',
                      '${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})'),
                _InfoRow(Icons.phone_outlined, 'Phone',
                    profile?.contactNumber ?? '—'),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Medical Allergies
          _ChipSection(
            title: 'Medical Allergies',
            icon: Icons.warning_amber_rounded,
            iconColor: AppTheme.dangerColor,
            items: _medAllergies,
            chipColor: AppTheme.dangerColor,
            editing: _editing,
            onAdd: () => _showAddDialog('Medical Allergy', _medAllergies),
            onRemove: (v) => setState(() => _medAllergies.remove(v)),
          ),
          const SizedBox(height: AppTheme.lg),

          // Food Allergies
          _ChipSection(
            title: 'Food Allergies',
            icon: Icons.no_food_rounded,
            iconColor: AppTheme.warningColor,
            items: _foodAllergies,
            chipColor: AppTheme.warningColor,
            editing: _editing,
            onAdd: () => _showAddDialog('Food Allergy', _foodAllergies),
            onRemove: (v) => setState(() => _foodAllergies.remove(v)),
          ),
          const SizedBox(height: AppTheme.lg),

          // Past Diseases
          _ChipSection(
            title: 'Past Diseases',
            icon: Icons.history_rounded,
            iconColor: AppTheme.infoColor,
            items: _pastDiseases,
            chipColor: AppTheme.infoColor,
            editing: _editing,
            onAdd: () => _showAddDialog('Past Disease', _pastDiseases),
            onRemove: (v) => setState(() => _pastDiseases.remove(v)),
          ),
          const SizedBox(height: AppTheme.lg),

          // Chronic Conditions
          _ChipSection(
            title: 'Chronic Conditions',
            icon: Icons.monitor_heart_outlined,
            iconColor: AppTheme.cardiologyColor,
            items: _chronicConditions,
            chipColor: AppTheme.cardiologyColor,
            editing: _editing,
            onAdd: () =>
                _showAddDialog('Chronic Condition', _chronicConditions),
            onRemove: (v) => setState(() => _chronicConditions.remove(v)),
          ),
          const SizedBox(height: AppTheme.lg),

          // Emergency Contact
          _Section(
            title: 'Emergency Contact',
            children: [
              if (_editing) ...[
                _Field('Contact Name', _emergencyNameCtrl, enabled: true),
                const SizedBox(height: AppTheme.md),
                _Field('Contact Phone', _emergencyPhoneCtrl,
                    enabled: true, keyboardType: TextInputType.phone),
                const SizedBox(height: AppTheme.md),
                _DropdownField('Relationship', _emergencyRelation, _relations,
                    (v) => setState(() => _emergencyRelation = v!)),
              ] else ...[
                _InfoRow(Icons.person_pin_outlined, 'Name',
                    profile?.emergencyContactName ?? '—'),
                _InfoRow(Icons.call_outlined, 'Phone',
                    profile?.emergencyContactPhone ?? '—'),
                _InfoRow(Icons.people_outline_rounded, 'Relation',
                    profile?.emergencyContactRelation ?? '—'),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Sign out
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content:
                      const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<HealthDataProvider>().signOut();
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerColor),
            label: const Text('Sign Out',
                style: TextStyle(color: AppTheme.dangerColor)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.dangerColor),
              padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.md, horizontal: AppTheme.lg),
              shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius),
            ),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final PatientProfile? profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile != null && profile!.firstName.isNotEmpty
        ? (profile!.firstName[0] +
                (profile!.lastName.isNotEmpty ? profile!.lastName[0] : ''))
            .toUpperCase()
        : 'U';

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.largeRadius,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppTheme.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName.isEmpty == false
                      ? profile!.fullName
                      : 'Your Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile != null && profile!.age > 0)
                  Text(
                    '${profile!.age} yrs · ${profile!.gender} · ${profile!.bloodGroup}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                if (profile != null && profile!.allAllergies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${profile!.allAllergies.length} known allerg${profile!.allAllergies.length == 1 ? 'y' : 'ies'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall.copyWith(fontSize: 15)),
          const SizedBox(height: AppTheme.md),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.md),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySmall),
              Text(value, style: AppTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;
  final TextInputType? keyboardType;
  const _Field(this.label, this.ctrl,
      {required this.enabled, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        textCapitalization: keyboardType == null
            ? TextCapitalization.words
            : TextCapitalization.none,
      );
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField(this.label, this.value, this.items, this.onChanged);

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) =>
                DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      );
}

class _ChipSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final Color chipColor;
  final bool editing;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ChipSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.chipColor,
    required this.editing,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: AppTheme.headingSmall.copyWith(fontSize: 15))),
              if (editing)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: chipColor),
                        const SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: chipColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (items.isEmpty)
            Text('None recorded',
                style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => Chip(
                        label: Text(item,
                            style: TextStyle(
                                color: chipColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        backgroundColor: chipColor.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: chipColor.withValues(alpha: 0.3)),
                        deleteIcon: editing
                            ? Icon(Icons.close, size: 16, color: chipColor)
                            : null,
                        onDeleted: editing ? () => onRemove(item) : null,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
