import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/patient_models.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';

class HealthDataProvider extends ChangeNotifier {
  final FirestoreService _db = FirestoreService();
  final AuthService _auth = AuthService();

  PatientProfile? _profile;
  bool _profileLoaded = false;

  PatientProfile? get profile => _profile;
  bool get profileLoaded => _profileLoaded;
  String? get uid => _auth.currentUser?.uid;

  String get displayName {
    if (_profile != null && _profile!.firstName.isNotEmpty) {
      return _profile!.firstName;
    }
    return _auth.currentUser?.displayName?.split(' ').first ?? 'there';
  }

  Future<void> loadProfile() async {
    final userId = uid;
    if (userId == null) return;
    try {
      _profile = await _db.loadPatientProfile(userId);
    } catch (_) {}
    _profileLoaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(PatientProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _db.savePatientProfile(profile);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _profile = null;
    _profileLoaded = false;
    await FirestoreService.clearAllCaches();
    notifyListeners();
  }

  User? get currentUser => _auth.currentUser;
}
