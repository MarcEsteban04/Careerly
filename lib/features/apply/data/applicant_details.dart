import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The extra details job application forms ask for, beyond the career
/// profile. Kept only on this device.
class ApplicantDetails {
  const ApplicantDetails({
    this.phone,
    this.address,
    this.city,
    this.birthday,
    this.linkedin,
    this.portfolio,
    this.github,
    this.expectedSalary,
    this.availability,
    this.school,
    this.degree,
    this.graduationYear,
    this.other,
  });

  factory ApplicantDetails.fromJson(Map<String, dynamic> json) {
    String? read(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return ApplicantDetails(
      phone: read('phone'),
      address: read('address'),
      city: read('city'),
      birthday: read('birthday'),
      linkedin: read('linkedin'),
      portfolio: read('portfolio'),
      github: read('github'),
      expectedSalary: read('expected_salary'),
      availability: read('availability'),
      school: read('school'),
      degree: read('degree'),
      graduationYear: read('graduation_year'),
      other: read('other'),
    );
  }

  final String? phone;

  /// Street address, as she'd write it on a form.
  final String? address;
  final String? city;

  /// As YYYY-MM-DD, so date fields can use it.
  final String? birthday;
  final String? linkedin;
  final String? portfolio;
  final String? github;
  final String? expectedSalary;

  /// When she can start, e.g. "Immediately" or "2 weeks' notice".
  final String? availability;
  final String? school;
  final String? degree;
  final String? graduationYear;

  /// Anything else forms often ask, e.g. "Willing to relocate: Yes".
  final String? other;

  Map<String, String?> get _labeled => {
        'Mobile number': phone,
        'Address': address,
        'City': city,
        'Birthday': birthday,
        'LinkedIn': linkedin,
        'Portfolio or website': portfolio,
        'GitHub': github,
        'Expected salary': expectedSalary,
        'Availability to start': availability,
        'School': school,
        'Degree': degree,
        'Graduation year': graduationYear,
        'Other details': other,
      };

  /// How many details are filled in.
  int get filledCount => _labeled.values.whereType<String>().length;

  bool get isEmpty => filledCount == 0;

  /// "Label: value" lines for the AI, skipping empty ones.
  List<String> get lines => [
        for (final MapEntry(:key, :value) in _labeled.entries)
          if (value != null) '$key: $value',
      ];

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'address': address,
        'city': city,
        'birthday': birthday,
        'linkedin': linkedin,
        'portfolio': portfolio,
        'github': github,
        'expected_salary': expectedSalary,
        'availability': availability,
        'school': school,
        'degree': degree,
        'graduation_year': graduationYear,
        'other': other,
      };
}

/// Saves [ApplicantDetails] on the device.
class ApplicantDetailsStore {
  ApplicantDetailsStore({SharedPreferencesAsync? prefs}) : _injectedPrefs = prefs;

  final SharedPreferencesAsync? _injectedPrefs;
  late final _prefs = _injectedPrefs ?? SharedPreferencesAsync();

  static const _key = 'applicant_details';

  Future<ApplicantDetails> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return const ApplicantDetails();
      final json = jsonDecode(raw);
      return json is Map<String, dynamic>
          ? ApplicantDetails.fromJson(json)
          : const ApplicantDetails();
    } catch (e) {
      debugPrint('Applicant details unreadable: $e');
      return const ApplicantDetails();
    }
  }

  Future<void> save(ApplicantDetails details) =>
      _prefs.setString(_key, jsonEncode(details.toJson()));
}
