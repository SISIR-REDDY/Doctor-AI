class ProviderPatientRecord {
  final String id;
  final String doctorId;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String bloodType;
  final String contactNumber;
  final String email;
  /// Local absolute path (runtime only; not written to Firestore).
  final String photoUrl;
  /// Filename stored in Firestore, e.g. `patient_<id>.jpg` (efficient, portable).
  final String photoFileName;
  final String lastVisitSummary;
  final List<String> prescriptions;
  final List<String> reports;
  final List<String> foodAllergies;
  final List<String> medicinalAllergies;
  final List<String> medicalHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProviderPatientRecord({
    this.id = '',
    this.doctorId = '',
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth = '',
    this.gender = 'Unknown',
    this.bloodType = '',
    this.contactNumber = '',
    this.email = '',
    this.photoUrl = '',
    this.photoFileName = '',
    this.lastVisitSummary = '',
    this.prescriptions = const <String>[],
    this.reports = const <String>[],
    this.foodAllergies = const <String>[],
    this.medicinalAllergies = const <String>[],
    this.medicalHistory = const <String>[],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();

  int get age {
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return 0;
    final now = DateTime.now();
    var years = now.year - dob.year;
    final hadBirthday =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) years--;
    return years < 0 ? 0 : years;
  }

  List<String> get allergies => <String>{
        ...foodAllergies,
        ...medicinalAllergies,
      }.toList();

  ProviderPatientRecord copyWith({
    String? id,
    String? doctorId,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    String? contactNumber,
    String? email,
    String? photoUrl,
    String? photoFileName,
    String? lastVisitSummary,
    List<String>? prescriptions,
    List<String>? reports,
    List<String>? foodAllergies,
    List<String>? medicinalAllergies,
    List<String>? medicalHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProviderPatientRecord(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      photoFileName: photoFileName ?? this.photoFileName,
      lastVisitSummary: lastVisitSummary ?? this.lastVisitSummary,
      prescriptions: prescriptions ?? this.prescriptions,
      reports: reports ?? this.reports,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      medicinalAllergies: medicinalAllergies ?? this.medicinalAllergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodType': bloodType,
      'contactNumber': contactNumber,
      'email': email,
      if (photoFileName.trim().isNotEmpty) 'photoFileName': photoFileName.trim(),
      'lastVisitSummary': lastVisitSummary,
      'prescriptions': prescriptions,
      'reports': reports,
      'foodAllergies': foodAllergies,
      'medicinalAllergies': medicinalAllergies,
      'medicalHistory': medicalHistory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProviderPatientRecord.fromMap(Map<String, dynamic> map) {
    return ProviderPatientRecord(
      id: (map['id'] ?? '').toString(),
      doctorId: (map['doctorId'] ?? '').toString(),
      firstName: (map['firstName'] ?? '').toString(),
      lastName: (map['lastName'] ?? '').toString(),
      dateOfBirth: (map['dateOfBirth'] ?? '').toString(),
      gender: (map['gender'] ?? 'Unknown').toString(),
      bloodType: (map['bloodType'] ?? '').toString(),
      contactNumber: (map['contactNumber'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      photoUrl: '',
      photoFileName: _resolvePhotoFileName(map),
      lastVisitSummary: (map['lastVisitSummary'] ?? '').toString(),
      prescriptions: _toStringList(map['prescriptions']),
      reports: _toStringList(map['reports']),
      foodAllergies: _toStringList(map['foodAllergies']),
      medicinalAllergies: _toStringList(map['medicinalAllergies']),
      medicalHistory: _toStringList(map['medicalHistory']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }
}

class ClinicalNote {
  final String id;
  final String patientId;
  final String doctorId;
  final String title;
  final String content;
  final String? diagnosis;
  final List<String> treatments;
  final List<String> followUpItems;
  final String createdBy;
  /// `written`, `voice`, or `ai`
  final String noteType;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClinicalNote({
    this.id = '',
    this.patientId = '',
    this.doctorId = '',
    this.title = '',
    this.content = '',
    this.diagnosis,
    this.treatments = const <String>[],
    this.followUpItems = const <String>[],
    this.createdBy = 'Clinician',
    this.noteType = 'written',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ClinicalNote copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? title,
    String? content,
    String? diagnosis,
    List<String>? treatments,
    List<String>? followUpItems,
    String? createdBy,
    String? noteType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClinicalNote(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      title: title ?? this.title,
      content: content ?? this.content,
      diagnosis: diagnosis ?? this.diagnosis,
      treatments: treatments ?? this.treatments,
      followUpItems: followUpItems ?? this.followUpItems,
      createdBy: createdBy ?? this.createdBy,
      noteType: noteType ?? this.noteType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'title': title,
      'content': content,
      'diagnosis': diagnosis,
      'treatments': treatments,
      'followUpItems': followUpItems,
      'createdBy': createdBy,
      'noteType': noteType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ClinicalNote.fromMap(Map<String, dynamic> map) {
    return ClinicalNote(
      id: (map['id'] ?? '').toString(),
      patientId: (map['patientId'] ?? '').toString(),
      doctorId: (map['doctorId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      diagnosis: map['diagnosis']?.toString(),
      treatments: _toStringList(map['treatments']),
      followUpItems: _toStringList(map['followUpItems']),
      createdBy: (map['createdBy'] ?? 'Clinician').toString(),
      noteType: (map['noteType'] ?? 'written').toString(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }
}

String _resolvePhotoFileName(Map<String, dynamic> map) {
  final stored = (map['photoFileName'] ?? '').toString().trim();
  if (stored.isNotEmpty) return stored;

  final legacyPath = (map['photoUrl'] ?? '').toString().trim();
  if (legacyPath.isEmpty) return '';

  final parts = legacyPath.replaceAll('\\', '/').split('/');
  return parts.isNotEmpty ? parts.last : '';
}

class ConsultationSession {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String transcript;
  final String summary;
  final String prescription;
  final String source;
  final String? audioUrl;
  final int durationSeconds;
  final DateTime createdAt;

  const ConsultationSession({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.transcript,
    required this.summary,
    required this.prescription,
    required this.source,
    required this.audioUrl,
    required this.durationSeconds,
    required this.createdAt,
  });

  bool get hasAudio => (audioUrl ?? '').trim().isNotEmpty;

  String get formattedDuration {
    if (durationSeconds <= 0) return '0:00';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'transcript': transcript,
      'summary': summary,
      'prescription': prescription,
      'source': source,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ConsultationSession.fromMap(Map<String, dynamic> map) {
    return ConsultationSession(
      id: (map['id'] ?? '').toString(),
      doctorId: (map['doctorId'] ?? '').toString(),
      patientId: (map['patientId'] ?? '').toString(),
      patientName: (map['patientName'] ?? '').toString(),
      transcript: (map['transcript'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      prescription: (map['prescription'] ?? '').toString(),
      source: (map['source'] ?? 'voice').toString(),
      audioUrl: map['audioUrl']?.toString(),
      durationSeconds: int.tryParse((map['durationSeconds'] ?? '0').toString()) ?? 0,
      createdAt: _toDateTime(map['createdAt']),
    );
  }
}

class DocumentScan {
  final String id;
  final String patientId;
  final String documentType;
  final String imagePath;
  final String extractedText;
  final String analysis;
  final bool isProcessed;
  final DateTime dateScanned;

  DocumentScan({
    this.id = '',
    this.patientId = '',
    this.documentType = '',
    this.imagePath = '',
    this.extractedText = '',
    this.analysis = '',
    this.isProcessed = false,
    DateTime? dateScanned,
  }) : dateScanned = dateScanned ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'documentType': documentType,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'analysis': analysis,
      'isProcessed': isProcessed,
      'dateScanned': dateScanned.toIso8601String(),
    };
  }

  factory DocumentScan.fromMap(Map<String, dynamic> map) {
    return DocumentScan(
      id: (map['id'] ?? '').toString(),
      patientId: (map['patientId'] ?? '').toString(),
      documentType: (map['documentType'] ?? map['type'] ?? '').toString(),
      imagePath: (map['imagePath'] ?? '').toString(),
      extractedText: (map['extractedText'] ?? '').toString(),
      analysis: (map['analysis'] ?? '').toString(),
      isProcessed: map['isProcessed'] == true,
      dateScanned: _toDateTime(map['dateScanned']),
    );
  }
}

typedef PatientProfile = ProviderPatientRecord;

class DoctorProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String licenseNumber;
  final String specialty;
  final String hospitalName;
  final String contactNumber;
  final String email;
  final String? departmentName;
  final String? degree;

  DoctorProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    required this.specialty,
    required this.hospitalName,
    required this.contactNumber,
    required this.email,
    this.departmentName,
    this.degree,
  });

  String get fullName => '$firstName $lastName'.trim();

  DoctorProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? licenseNumber,
    String? specialty,
    String? hospitalName,
    String? contactNumber,
    String? email,
    String? departmentName,
    String? degree,
  }) {
    return DoctorProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialty: specialty ?? this.specialty,
      hospitalName: hospitalName ?? this.hospitalName,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      departmentName: departmentName ?? this.departmentName,
      degree: degree ?? this.degree,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'licenseNumber': licenseNumber,
      'specialty': specialty,
      'hospitalName': hospitalName,
      'contactNumber': contactNumber,
      'email': email,
      'departmentName': departmentName,
      'degree': degree,
    };
  }

  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    return DoctorProfile(
      id: (map['id'] ?? '').toString(),
      firstName: (map['firstName'] ?? '').toString(),
      lastName: (map['lastName'] ?? '').toString(),
      licenseNumber: (map['licenseNumber'] ?? '').toString(),
      specialty: (map['specialty'] ?? '').toString(),
      hospitalName: (map['hospitalName'] ?? '').toString(),
      contactNumber: (map['contactNumber'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      departmentName: map['departmentName']?.toString(),
      degree: map['degree']?.toString(),
    );
  }
}

DateTime _toDateTime(Object? raw) {
  if (raw == null) return DateTime.now();
  return DateTime.tryParse(raw.toString()) ?? DateTime.now();
}

List<String> _toStringList(Object? raw) {
  if (raw is List) {
    return raw.map((item) => item.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const <String>[];
}
