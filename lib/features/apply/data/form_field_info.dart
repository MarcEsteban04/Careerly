/// The kinds of form fields Careerly fills.
enum FormFieldKind {
  text,
  email,
  tel,
  url,
  number,
  date,
  textarea,
  select,
  radio;

  static FormFieldKind parse(Object? value) => FormFieldKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => FormFieldKind.text,
      );

  /// Fields that only accept one of their options.
  bool get hasOptions => this == select || this == radio;
}

/// One field read from an application form on a web page.
class FormFieldInfo {
  const FormFieldInfo({
    required this.id,
    required this.kind,
    required this.label,
    this.name = '',
    this.autocomplete = '',
    this.placeholder = '',
    this.options = const [],
    this.required = false,
    this.maxLength,
    this.currentValue = '',
  });

  factory FormFieldInfo.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? (json[key] as String).trim() : '';
    final maxLength = json['maxLength'];
    return FormFieldInfo(
      id: text('id'),
      kind: FormFieldKind.parse(json['kind']),
      label: cleanLabel(text('label')),
      name: text('name'),
      autocomplete: text('autocomplete').toLowerCase(),
      placeholder: text('placeholder'),
      options: json['options'] is List
          ? (json['options'] as List)
              .whereType<String>()
              .map((o) => o.trim())
              .where((o) => o.isNotEmpty)
              .toList()
          : const [],
      required: json['required'] == true,
      maxLength: maxLength is num && maxLength > 0 ? maxLength.toInt() : null,
      currentValue: text('value'),
    );
  }

  /// Drops the trailing colon and required-asterisk pages put on labels.
  static String cleanLabel(String label) =>
      label.replaceAll(RegExp(r'[\s:*]+$'), '').trim();

  /// The page-side handle Careerly gave the field.
  final String id;
  final FormFieldKind kind;

  /// The question as shown on the page.
  final String label;
  final String name;
  final String autocomplete;
  final String placeholder;
  final List<String> options;
  final bool required;
  final int? maxLength;
  final String currentValue;

  /// Everything that hints at what the field wants, lowercased.
  String get hints =>
      [label, name, autocomplete, placeholder].join(' ').toLowerCase();

  /// What to show for the field when reviewing answers.
  String get displayLabel {
    for (final candidate in [label, placeholder, name]) {
      if (candidate.isNotEmpty) return candidate;
    }
    return 'Field';
  }

  /// The option that best matches [value], or null if none does.
  String? optionFor(String value) {
    final wanted = value.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final option in options) {
      if (option.toLowerCase() == wanted) return option;
    }
    for (final option in options) {
      final o = option.toLowerCase();
      if (o.contains(wanted) || wanted.contains(o)) return option;
    }
    return null;
  }
}

/// Where a proposed answer came from.
enum AnswerSource {
  /// Her saved application details or account.
  details,

  /// An answer she approved on an earlier form.
  library,

  /// Drafted by AI.
  ai,
}

/// A proposed value for one field, and where it came from.
class FieldAnswer {
  const FieldAnswer({
    required this.field,
    required this.value,
    required this.source,
  });

  final FormFieldInfo field;
  final String value;
  final AnswerSource source;

  FieldAnswer withValue(String value) =>
      FieldAnswer(field: field, value: value, source: source);
}
