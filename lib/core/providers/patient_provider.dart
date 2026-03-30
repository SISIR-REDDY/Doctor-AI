import '../../models/health_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/auth_service.dart';
import 'base_provider.dart';

class PatientProvider extends BaseProvider {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final List<ProviderPatientRecord> _items = <ProviderPatientRecord>[];
  String _doctorId = '';

  List<ProviderPatientRecord> get items => List.unmodifiable(_items);

  Future<void> loadPatientsForDoctor(String doctorId) async {
    _doctorId = doctorId;
    setLoading(true);
    try {
      final patients = await _firestoreService.getDoctorPatients(doctorId);
      _items
        ..clear()
        ..addAll(patients);
      clearError();
      notifyListeners();
    } catch (error) {
      setError(error.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> refresh() async {
    final doctorId = _doctorId.isNotEmpty
        ? _doctorId
        : (_authService.currentUser?.uid ?? '');
    if (doctorId.isEmpty) return;
    await loadPatientsForDoctor(doctorId);
  }

  List<ProviderPatientRecord> searchPatients(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return _items.where((patient) {
      final haystack = <String>[
        patient.fullName,
        patient.contactNumber,
        patient.email,
        patient.lastVisitSummary,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
}
