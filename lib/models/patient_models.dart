// ─── Patient Health Models ───────────────────────────────────────────────────
// All domain models for the patient-facing Clinix AI app.

// ─── Helpers ─────────────────────────────────────────────────────────────────

DateTime _toDateTime(Object? raw) {
  if (raw == null) return DateTime.now();
  return DateTime.tryParse(raw.toString()) ?? DateTime.now();
}

List<String> _toStringList(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const <String>[];
}

// ─── PatientProfile ───────────────────────────────────────────────────────────

class PatientProfile {
  final String id; // = Firebase uid
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String bloodGroup;
  final double height; // in cm
  final double weight; // in kg
  final String contactNumber;
  final String email;
  final String photoUrl;
  final List<String> medicalAllergies;
  final List<String> foodAllergies;
  final List<String> pastDiseases;
  final List<String> chronicConditions;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContactRelation;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientProfile({
    this.id = '',
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth = '',
    this.gender = 'Prefer not to say',
    this.bloodGroup = '',
    this.height = 0,
    this.weight = 0,
    this.contactNumber = '',
    this.email = '',
    this.photoUrl = '',
    this.medicalAllergies = const <String>[],
    this.foodAllergies = const <String>[],
    this.pastDiseases = const <String>[],
    this.chronicConditions = const <String>[],
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.emergencyContactRelation = '',
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

  List<String> get allAllergies =>
      <String>{...medicalAllergies, ...foodAllergies}.toList();

  String get bmiCategory {
    if (height <= 0 || weight <= 0) return '';
    final bmi = weight / ((height / 100) * (height / 100));
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  double get bmi {
    if (height <= 0 || weight <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  PatientProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    double? height,
    double? weight,
    String? contactNumber,
    String? email,
    String? photoUrl,
    List<String>? medicalAllergies,
    List<String>? foodAllergies,
    List<String>? pastDiseases,
    List<String>? chronicConditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      medicalAllergies: medicalAllergies ?? this.medicalAllergies,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      pastDiseases: pastDiseases ?? this.pastDiseases,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation:
          emergencyContactRelation ?? this.emergencyContactRelation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'height': height,
        'weight': weight,
        'contactNumber': contactNumber,
        'email': email,
        'photoUrl': photoUrl,
        'medicalAllergies': medicalAllergies,
        'foodAllergies': foodAllergies,
        'pastDiseases': pastDiseases,
        'chronicConditions': chronicConditions,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'emergencyContactRelation': emergencyContactRelation,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PatientProfile.fromMap(Map<String, dynamic> map) => PatientProfile(
        id: (map['id'] ?? '').toString(),
        firstName: (map['firstName'] ?? '').toString(),
        lastName: (map['lastName'] ?? '').toString(),
        dateOfBirth: (map['dateOfBirth'] ?? '').toString(),
        gender: (map['gender'] ?? 'Prefer not to say').toString(),
        bloodGroup: (map['bloodGroup'] ?? '').toString(),
        height: (map['height'] is num)
            ? (map['height'] as num).toDouble()
            : double.tryParse(map['height']?.toString() ?? '') ?? 0,
        weight: (map['weight'] is num)
            ? (map['weight'] as num).toDouble()
            : double.tryParse(map['weight']?.toString() ?? '') ?? 0,
        contactNumber: (map['contactNumber'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        photoUrl: (map['photoUrl'] ?? '').toString(),
        medicalAllergies: _toStringList(map['medicalAllergies']),
        foodAllergies: _toStringList(map['foodAllergies']),
        pastDiseases: _toStringList(map['pastDiseases']),
        chronicConditions: _toStringList(map['chronicConditions']),
        emergencyContactName: (map['emergencyContactName'] ?? '').toString(),
        emergencyContactPhone: (map['emergencyContactPhone'] ?? '').toString(),
        emergencyContactRelation:
            (map['emergencyContactRelation'] ?? '').toString(),
        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
      );
}

// ─── SymptomEntry ─────────────────────────────────────────────────────────────

class SymptomEntry {
  final String id;
  final String userId;
  final String symptom;
  final int severity; // 1–10
  final String bodyLocation;
  final String timeOfDay; // morning, afternoon, evening, night
  final String notes;
  final DateTime loggedAt;

  SymptomEntry({
    this.id = '',
    this.userId = '',
    this.symptom = '',
    this.severity = 1,
    this.bodyLocation = '',
    this.timeOfDay = 'morning',
    this.notes = '',
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  SymptomEntry copyWith({
    String? id,
    String? userId,
    String? symptom,
    int? severity,
    String? bodyLocation,
    String? timeOfDay,
    String? notes,
    DateTime? loggedAt,
  }) =>
      SymptomEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        symptom: symptom ?? this.symptom,
        severity: severity ?? this.severity,
        bodyLocation: bodyLocation ?? this.bodyLocation,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        notes: notes ?? this.notes,
        loggedAt: loggedAt ?? this.loggedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'symptom': symptom,
        'severity': severity,
        'bodyLocation': bodyLocation,
        'timeOfDay': timeOfDay,
        'notes': notes,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory SymptomEntry.fromMap(Map<String, dynamic> map) => SymptomEntry(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        symptom: (map['symptom'] ?? '').toString(),
        severity: (map['severity'] is int)
            ? map['severity'] as int
            : int.tryParse(map['severity']?.toString() ?? '') ?? 1,
        bodyLocation: (map['bodyLocation'] ?? '').toString(),
        timeOfDay: (map['timeOfDay'] ?? 'morning').toString(),
        notes: (map['notes'] ?? '').toString(),
        loggedAt: _toDateTime(map['loggedAt']),
      );
}

// ─── Medication ───────────────────────────────────────────────────────────────

class Medication {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String frequency;
  final String startDate;
  final String endDate;
  final String prescribingDoctor;
  final String purpose;
  final bool isActive;
  final String notes;
  /// Daily reminder times as 'HH:mm' (24h), e.g. ['08:00','21:00'].
  final List<String> reminderTimes;
  final DateTime createdAt;

  Medication({
    this.id = '',
    this.userId = '',
    this.name = '',
    this.dosage = '',
    this.frequency = '',
    this.startDate = '',
    this.endDate = '',
    this.prescribingDoctor = '',
    this.purpose = '',
    this.isActive = true,
    this.notes = '',
    this.reminderTimes = const <String>[],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? frequency,
    String? startDate,
    String? endDate,
    String? prescribingDoctor,
    String? purpose,
    bool? isActive,
    String? notes,
    List<String>? reminderTimes,
    DateTime? createdAt,
  }) =>
      Medication(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        prescribingDoctor: prescribingDoctor ?? this.prescribingDoctor,
        purpose: purpose ?? this.purpose,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'startDate': startDate,
        'endDate': endDate,
        'prescribingDoctor': prescribingDoctor,
        'purpose': purpose,
        'isActive': isActive,
        'notes': notes,
        'reminderTimes': reminderTimes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        dosage: (map['dosage'] ?? '').toString(),
        frequency: (map['frequency'] ?? '').toString(),
        startDate: (map['startDate'] ?? '').toString(),
        endDate: (map['endDate'] ?? '').toString(),
        prescribingDoctor: (map['prescribingDoctor'] ?? '').toString(),
        purpose: (map['purpose'] ?? '').toString(),
        isActive: map['isActive'] != false,
        notes: (map['notes'] ?? '').toString(),
        reminderTimes: _toStringList(map['reminderTimes']),
        createdAt: _toDateTime(map['createdAt']),
      );
}

// ─── MedicationLog (adherence) ───────────────────────────────────────────────

/// One logged dose event — whether the user took or skipped a scheduled dose.
class MedicationLog {
  final String id;
  final String medicationId;
  final String medicationName;
  final String date; // 'yyyy-MM-dd'
  final String time; // 'HH:mm' scheduled slot
  final String status; // taken | skipped
  final DateTime loggedAt;

  MedicationLog({
    this.id = '',
    this.medicationId = '',
    this.medicationName = '',
    this.date = '',
    this.time = '',
    this.status = 'taken',
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  bool get isTaken => status == 'taken';

  Map<String, dynamic> toMap() => {
        'id': id,
        'medicationId': medicationId,
        'medicationName': medicationName,
        'date': date,
        'time': time,
        'status': status,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory MedicationLog.fromMap(Map<String, dynamic> map) => MedicationLog(
        id: (map['id'] ?? '').toString(),
        medicationId: (map['medicationId'] ?? '').toString(),
        medicationName: (map['medicationName'] ?? '').toString(),
        date: (map['date'] ?? '').toString(),
        time: (map['time'] ?? '').toString(),
        status: (map['status'] ?? 'taken').toString(),
        loggedAt: _toDateTime(map['loggedAt']),
      );
}

// ─── HealthReminder (vaccination / appointment / custom) ─────────────────────

/// A scheduled health item with a single date/time: a vaccination due date, a
/// doctor appointment, or a free-form custom reminder.
class HealthReminder {
  final String id;
  final String userId;

  /// vaccination | appointment | custom
  final String type;
  final String title;
  final String notes;

  /// When it is due / scheduled.
  final DateTime dateTime;

  /// Clinic / doctor / place (mainly for appointments).
  final String location;

  /// Minutes before [dateTime] to fire the reminder (e.g. 60 = 1h before).
  final int notifyMinutesBefore;

  /// none | daily | weekly | monthly
  final String recurrence;

  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthReminder({
    this.id = '',
    this.userId = '',
    this.type = 'custom',
    this.title = '',
    this.notes = '',
    DateTime? dateTime,
    this.location = '',
    this.notifyMinutesBefore = 0,
    this.recurrence = 'none',
    this.completed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : dateTime = dateTime ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isRecurring => recurrence != 'none';

  /// Recurring reminders repeat, so they're never "overdue".
  bool get isOverdue =>
      !completed && !isRecurring && dateTime.isBefore(DateTime.now());

  /// The moment the reminder should fire.
  DateTime get notifyAt =>
      dateTime.subtract(Duration(minutes: notifyMinutesBefore));

  HealthReminder copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? notes,
    DateTime? dateTime,
    String? location,
    int? notifyMinutesBefore,
    String? recurrence,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HealthReminder(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        dateTime: dateTime ?? this.dateTime,
        location: location ?? this.location,
        notifyMinutesBefore: notifyMinutesBefore ?? this.notifyMinutesBefore,
        recurrence: recurrence ?? this.recurrence,
        completed: completed ?? this.completed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'notes': notes,
        'dateTime': dateTime.toIso8601String(),
        'location': location,
        'notifyMinutesBefore': notifyMinutesBefore,
        'recurrence': recurrence,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HealthReminder.fromMap(Map<String, dynamic> map) => HealthReminder(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        type: (map['type'] ?? 'custom').toString(),
        title: (map['title'] ?? '').toString(),
        notes: (map['notes'] ?? '').toString(),
        dateTime: _toDateTime(map['dateTime']),
        location: (map['location'] ?? '').toString(),
        notifyMinutesBefore: (map['notifyMinutesBefore'] is num)
            ? (map['notifyMinutesBefore'] as num).toInt()
            : int.tryParse(map['notifyMinutesBefore']?.toString() ?? '') ?? 0,
        recurrence: (map['recurrence'] ?? 'none').toString(),
        completed: map['completed'] == true,
        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
      );
}

// ─── MedicalRecord ────────────────────────────────────────────────────────────

class MedicalRecord {
  final String id;
  final String userId;
  final String title;
  /// lab | imaging | prescription | discharge | vaccination | other
  final String recordType;
  final String imagePath;
  final String imageUrl;
  final String extractedText;
  final String aiSummary;
  final bool isProcessed;
  final String doctorName;
  final String hospitalName;
  final DateTime recordDate;
  final DateTime uploadedAt;

  MedicalRecord({
    this.id = '',
    this.userId = '',
    this.title = '',
    this.recordType = 'other',
    this.imagePath = '',
    this.imageUrl = '',
    this.extractedText = '',
    this.aiSummary = '',
    this.isProcessed = false,
    this.doctorName = '',
    this.hospitalName = '',
    DateTime? recordDate,
    DateTime? uploadedAt,
  })  : recordDate = recordDate ?? DateTime.now(),
        uploadedAt = uploadedAt ?? DateTime.now();

  MedicalRecord copyWith({
    String? id,
    String? userId,
    String? title,
    String? recordType,
    String? imagePath,
    String? imageUrl,
    String? extractedText,
    String? aiSummary,
    bool? isProcessed,
    String? doctorName,
    String? hospitalName,
    DateTime? recordDate,
    DateTime? uploadedAt,
  }) =>
      MedicalRecord(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        recordType: recordType ?? this.recordType,
        imagePath: imagePath ?? this.imagePath,
        imageUrl: imageUrl ?? this.imageUrl,
        extractedText: extractedText ?? this.extractedText,
        aiSummary: aiSummary ?? this.aiSummary,
        isProcessed: isProcessed ?? this.isProcessed,
        doctorName: doctorName ?? this.doctorName,
        hospitalName: hospitalName ?? this.hospitalName,
        recordDate: recordDate ?? this.recordDate,
        uploadedAt: uploadedAt ?? this.uploadedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'recordType': recordType,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'extractedText': extractedText,
        'aiSummary': aiSummary,
        'isProcessed': isProcessed,
        'doctorName': doctorName,
        'hospitalName': hospitalName,
        'recordDate': recordDate.toIso8601String(),
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory MedicalRecord.fromMap(Map<String, dynamic> map) => MedicalRecord(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        recordType: (map['recordType'] ?? 'other').toString(),
        imagePath: (map['imagePath'] ?? '').toString(),
        imageUrl: (map['imageUrl'] ?? '').toString(),
        extractedText: (map['extractedText'] ?? '').toString(),
        aiSummary: (map['aiSummary'] ?? '').toString(),
        isProcessed: map['isProcessed'] == true,
        doctorName: (map['doctorName'] ?? '').toString(),
        hospitalName: (map['hospitalName'] ?? '').toString(),
        recordDate: _toDateTime(map['recordDate']),
        uploadedAt: _toDateTime(map['uploadedAt']),
      );
}

// ─── AiChatMessage ────────────────────────────────────────────────────────────

class AiChatMessage {
  final String id;
  final String userId;
  final String threadId;
  /// 'user' or 'assistant'
  final String role;
  final String content;
  final DateTime timestamp;

  AiChatMessage({
    this.id = '',
    this.userId = '',
    this.threadId = '',
    this.role = 'user',
    this.content = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'threadId': threadId,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) => AiChatMessage(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        threadId: (map['threadId'] ?? '').toString(),
        role: (map['role'] ?? 'user').toString(),
        content: (map['content'] ?? '').toString(),
        timestamp: _toDateTime(map['timestamp']),
      );
}

// ─── ChatSession ─────────────────────────────────────────────────────────────

class ChatSession {
  final String id;
  final String userId;
  final String title;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  ChatSession({
    required this.id,
    required this.userId,
    this.title = 'New Chat',
    this.lastMessage = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.messageCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ChatSession copyWith({
    String? title,
    String? lastMessage,
    DateTime? updatedAt,
    int? messageCount,
  }) =>
      ChatSession(
        id: id,
        userId: userId,
        title: title ?? this.title,
        lastMessage: lastMessage ?? this.lastMessage,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messageCount: messageCount ?? this.messageCount,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'lastMessage': lastMessage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
      };

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        title: (map['title'] ?? 'New Chat').toString(),
        lastMessage: (map['lastMessage'] ?? '').toString(),
        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
        messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
      );
}

// ─── InsurancePolicy ─────────────────────────────────────────────────────────

class InsurancePolicy {
  final String id;
  final String userId;
  final String insurer;
  final String policyNumber;
  /// health | term | critical_illness | accidental | other
  final String policyType;
  /// Country code from [InsuranceRegion], e.g. US/GB/CA/AU/EU/IN.
  final String country;
  /// ISO 4217 currency for this policy's amounts.
  final String currencyCode;
  final double coverageAmount;
  final double premiumAmount;
  /// monthly | quarterly | annual
  final String premiumFrequency;
  final String startDate;
  final String renewalDate;
  final String nomineeName;
  final String nomineeRelation;
  final String documentUrl;
  final bool isActive;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  InsurancePolicy({
    this.id = '',
    this.userId = '',
    this.insurer = '',
    this.policyNumber = '',
    this.policyType = 'health',
    this.country = '',
    this.currencyCode = '',
    this.coverageAmount = 0,
    this.premiumAmount = 0,
    this.premiumFrequency = 'annual',
    this.startDate = '',
    this.renewalDate = '',
    this.nomineeName = '',
    this.nomineeRelation = '',
    this.documentUrl = '',
    this.isActive = true,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  InsurancePolicy copyWith({
    String? id,
    String? userId,
    String? insurer,
    String? policyNumber,
    String? policyType,
    String? country,
    String? currencyCode,
    double? coverageAmount,
    double? premiumAmount,
    String? premiumFrequency,
    String? startDate,
    String? renewalDate,
    String? nomineeName,
    String? nomineeRelation,
    String? documentUrl,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      InsurancePolicy(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        insurer: insurer ?? this.insurer,
        policyNumber: policyNumber ?? this.policyNumber,
        policyType: policyType ?? this.policyType,
        country: country ?? this.country,
        currencyCode: currencyCode ?? this.currencyCode,
        coverageAmount: coverageAmount ?? this.coverageAmount,
        premiumAmount: premiumAmount ?? this.premiumAmount,
        premiumFrequency: premiumFrequency ?? this.premiumFrequency,
        startDate: startDate ?? this.startDate,
        renewalDate: renewalDate ?? this.renewalDate,
        nomineeName: nomineeName ?? this.nomineeName,
        nomineeRelation: nomineeRelation ?? this.nomineeRelation,
        documentUrl: documentUrl ?? this.documentUrl,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'insurer': insurer,
        'policyNumber': policyNumber,
        'policyType': policyType,
        'country': country,
        'currencyCode': currencyCode,
        'coverageAmount': coverageAmount,
        'premiumAmount': premiumAmount,
        'premiumFrequency': premiumFrequency,
        'startDate': startDate,
        'renewalDate': renewalDate,
        'nomineeName': nomineeName,
        'nomineeRelation': nomineeRelation,
        'documentUrl': documentUrl,
        'isActive': isActive,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InsurancePolicy.fromMap(Map<String, dynamic> map) => InsurancePolicy(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        insurer: (map['insurer'] ?? '').toString(),
        policyNumber: (map['policyNumber'] ?? '').toString(),
        policyType: (map['policyType'] ?? 'health').toString(),
        country: (map['country'] ?? '').toString(),
        currencyCode: (map['currencyCode'] ?? '').toString(),
        coverageAmount: (map['coverageAmount'] is num)
            ? (map['coverageAmount'] as num).toDouble()
            : double.tryParse(map['coverageAmount']?.toString() ?? '') ?? 0,
        premiumAmount: (map['premiumAmount'] is num)
            ? (map['premiumAmount'] as num).toDouble()
            : double.tryParse(map['premiumAmount']?.toString() ?? '') ?? 0,
        premiumFrequency: (map['premiumFrequency'] ?? 'annual').toString(),
        startDate: (map['startDate'] ?? '').toString(),
        renewalDate: (map['renewalDate'] ?? '').toString(),
        nomineeName: (map['nomineeName'] ?? '').toString(),
        nomineeRelation: (map['nomineeRelation'] ?? '').toString(),
        documentUrl: (map['documentUrl'] ?? '').toString(),
        isActive: map['isActive'] != false,
        notes: (map['notes'] ?? '').toString(),
        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
      );
}

// ─── CaseExpense ──────────────────────────────────────────────────────────────

/// A single itemized bill/receipt logged against an insurance [InsuranceClaim]
/// (a "case"). Many expenses roll up into one case total.
class CaseExpense {
  final String id;

  /// hospital | pharmacy | lab | consultation | imaging | procedure | other
  final String category;
  final String vendor;
  final String date; // 'dd MMM yyyy'
  final double amount;
  final String documentUrl; // uploaded receipt (remote)
  final String imagePath; // local receipt copy, if any
  final String note;

  /// Raw itemized line-items extracted from the bill by the scanner, e.g.
  /// "Room charge — 12,000\nMRI scan — 8,500". Powers line-item overcharge audit.
  final String lineItems;

  /// True when fields were pre-filled by the AI bill scanner.
  final bool aiExtracted;

  const CaseExpense({
    this.id = '',
    this.category = 'other',
    this.vendor = '',
    this.date = '',
    this.amount = 0,
    this.documentUrl = '',
    this.imagePath = '',
    this.note = '',
    this.lineItems = '',
    this.aiExtracted = false,
  });

  CaseExpense copyWith({
    String? id,
    String? category,
    String? vendor,
    String? date,
    double? amount,
    String? documentUrl,
    String? imagePath,
    String? note,
    String? lineItems,
    bool? aiExtracted,
  }) =>
      CaseExpense(
        id: id ?? this.id,
        category: category ?? this.category,
        vendor: vendor ?? this.vendor,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        documentUrl: documentUrl ?? this.documentUrl,
        imagePath: imagePath ?? this.imagePath,
        note: note ?? this.note,
        lineItems: lineItems ?? this.lineItems,
        aiExtracted: aiExtracted ?? this.aiExtracted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'vendor': vendor,
        'date': date,
        'amount': amount,
        'documentUrl': documentUrl,
        'imagePath': imagePath,
        'note': note,
        'lineItems': lineItems,
        'aiExtracted': aiExtracted,
      };

  factory CaseExpense.fromMap(Map<String, dynamic> map) => CaseExpense(
        id: (map['id'] ?? '').toString(),
        category: (map['category'] ?? 'other').toString(),
        vendor: (map['vendor'] ?? '').toString(),
        date: (map['date'] ?? '').toString(),
        amount: (map['amount'] is num)
            ? (map['amount'] as num).toDouble()
            : double.tryParse(map['amount']?.toString() ?? '') ?? 0,
        documentUrl: (map['documentUrl'] ?? '').toString(),
        imagePath: (map['imagePath'] ?? '').toString(),
        note: (map['note'] ?? '').toString(),
        lineItems: (map['lineItems'] ?? '').toString(),
        aiExtracted: map['aiExtracted'] == true,
      );
}

List<CaseExpense> _toExpenseList(Object? raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => CaseExpense.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const <CaseExpense>[];
}

// ─── InsuranceClaim ───────────────────────────────────────────────────────────

class InsuranceClaim {
  final String id;
  final String userId;
  final String policyId;
  final String policyNumber;
  final String insurer;
  final String hospitalName;
  final String admissionDate;
  final String dischargeDate;
  final String diagnosis;
  final double claimAmount;
  /// pending | approved | rejected | under_review
  final String claimStatus;
  final String claimReport;
  final List<String> documentUrls;
  final String rejectionReason;
  final String fightAnalysis;
  final String appealLetter;
  /// AI bill-overcharge audit result (flagged errors + estimated savings).
  final String auditReport;
  /// AI-drafted letter to the provider's billing dept disputing overcharges.
  final String disputeLetter;

  // ── Global "case" fields ──
  /// Short label for the case, e.g. "Knee surgery – Apr 2026".
  final String title;
  /// Country code from [InsuranceRegion], e.g. US/GB/CA/AU/EU/IN.
  final String country;
  /// ISO 4217 currency for all amounts in this case.
  final String currencyCode;
  /// inpatient | outpatient
  final String caseType;
  /// Itemized bills that roll up into this case.
  final List<CaseExpense> expenses;

  final DateTime createdAt;
  final DateTime updatedAt;

  InsuranceClaim({
    this.id = '',
    this.userId = '',
    this.policyId = '',
    this.policyNumber = '',
    this.insurer = '',
    this.hospitalName = '',
    this.admissionDate = '',
    this.dischargeDate = '',
    this.diagnosis = '',
    this.claimAmount = 0,
    this.claimStatus = 'pending',
    this.claimReport = '',
    this.documentUrls = const <String>[],
    this.rejectionReason = '',
    this.fightAnalysis = '',
    this.appealLetter = '',
    this.auditReport = '',
    this.disputeLetter = '',
    this.title = '',
    this.country = '',
    this.currencyCode = '',
    this.caseType = 'inpatient',
    this.expenses = const <CaseExpense>[],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isRejected => claimStatus == 'rejected';
  bool get isApproved => claimStatus == 'approved';
  bool get hasFightAnalysis => fightAnalysis.isNotEmpty;

  /// Sum of all itemized expenses.
  double get totalExpenses =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);

  /// The amount to display/claim: the itemized total when bills exist,
  /// otherwise the manually-entered [claimAmount].
  double get effectiveAmount =>
      expenses.isNotEmpty ? totalExpenses : claimAmount;

  InsuranceClaim copyWith({
    String? id,
    String? userId,
    String? policyId,
    String? policyNumber,
    String? insurer,
    String? hospitalName,
    String? admissionDate,
    String? dischargeDate,
    String? diagnosis,
    double? claimAmount,
    String? claimStatus,
    String? claimReport,
    List<String>? documentUrls,
    String? rejectionReason,
    String? fightAnalysis,
    String? appealLetter,
    String? auditReport,
    String? disputeLetter,
    String? title,
    String? country,
    String? currencyCode,
    String? caseType,
    List<CaseExpense>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      InsuranceClaim(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        policyId: policyId ?? this.policyId,
        policyNumber: policyNumber ?? this.policyNumber,
        insurer: insurer ?? this.insurer,
        hospitalName: hospitalName ?? this.hospitalName,
        admissionDate: admissionDate ?? this.admissionDate,
        dischargeDate: dischargeDate ?? this.dischargeDate,
        diagnosis: diagnosis ?? this.diagnosis,
        claimAmount: claimAmount ?? this.claimAmount,
        claimStatus: claimStatus ?? this.claimStatus,
        claimReport: claimReport ?? this.claimReport,
        documentUrls: documentUrls ?? this.documentUrls,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        fightAnalysis: fightAnalysis ?? this.fightAnalysis,
        appealLetter: appealLetter ?? this.appealLetter,
        auditReport: auditReport ?? this.auditReport,
        disputeLetter: disputeLetter ?? this.disputeLetter,
        title: title ?? this.title,
        country: country ?? this.country,
        currencyCode: currencyCode ?? this.currencyCode,
        caseType: caseType ?? this.caseType,
        expenses: expenses ?? this.expenses,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'policyId': policyId,
        'policyNumber': policyNumber,
        'insurer': insurer,
        'hospitalName': hospitalName,
        'admissionDate': admissionDate,
        'dischargeDate': dischargeDate,
        'diagnosis': diagnosis,
        'claimAmount': claimAmount,
        'claimStatus': claimStatus,
        'claimReport': claimReport,
        'documentUrls': documentUrls,
        'rejectionReason': rejectionReason,
        'fightAnalysis': fightAnalysis,
        'appealLetter': appealLetter,
        'auditReport': auditReport,
        'disputeLetter': disputeLetter,
        'title': title,
        'country': country,
        'currencyCode': currencyCode,
        'caseType': caseType,
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InsuranceClaim.fromMap(Map<String, dynamic> map) => InsuranceClaim(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        policyId: (map['policyId'] ?? '').toString(),
        policyNumber: (map['policyNumber'] ?? '').toString(),
        insurer: (map['insurer'] ?? '').toString(),
        hospitalName: (map['hospitalName'] ?? '').toString(),
        admissionDate: (map['admissionDate'] ?? '').toString(),
        dischargeDate: (map['dischargeDate'] ?? '').toString(),
        diagnosis: (map['diagnosis'] ?? '').toString(),
        claimAmount: (map['claimAmount'] is num)
            ? (map['claimAmount'] as num).toDouble()
            : double.tryParse(map['claimAmount']?.toString() ?? '') ?? 0,
        claimStatus: (map['claimStatus'] ?? 'pending').toString(),
        claimReport: (map['claimReport'] ?? '').toString(),
        documentUrls: _toStringList(map['documentUrls']),
        rejectionReason: (map['rejectionReason'] ?? '').toString(),
        fightAnalysis: (map['fightAnalysis'] ?? '').toString(),
        appealLetter: (map['appealLetter'] ?? '').toString(),
        auditReport: (map['auditReport'] ?? '').toString(),
        disputeLetter: (map['disputeLetter'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        country: (map['country'] ?? '').toString(),
        currencyCode: (map['currencyCode'] ?? '').toString(),
        caseType: (map['caseType'] ?? 'inpatient').toString(),
        expenses: _toExpenseList(map['expenses']),
        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
      );
}
