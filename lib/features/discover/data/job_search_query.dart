/// A country to search abroad.
class JobCountry {
  const JobCountry(this.code, this.name);

  /// ISO 3166 alpha-2, lowercase, as JSearch expects.
  final String code;
  final String name;

  /// The country's flag, from its regional-indicator letters.
  String get flag => String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

  /// Popular with Filipino job seekers, most common first.
  static const all = [
    JobCountry('sg', 'Singapore'),
    JobCountry('ae', 'United Arab Emirates'),
    JobCountry('sa', 'Saudi Arabia'),
    JobCountry('qa', 'Qatar'),
    JobCountry('au', 'Australia'),
    JobCountry('nz', 'New Zealand'),
    JobCountry('jp', 'Japan'),
    JobCountry('hk', 'Hong Kong'),
    JobCountry('tw', 'Taiwan'),
    JobCountry('kr', 'South Korea'),
    JobCountry('my', 'Malaysia'),
    JobCountry('ca', 'Canada'),
    JobCountry('us', 'United States'),
    JobCountry('gb', 'United Kingdom'),
    JobCountry('ie', 'Ireland'),
    JobCountry('de', 'Germany'),
    JobCountry('nl', 'Netherlands'),
  ];

  static JobCountry? byCode(String code) =>
      all.where((c) => c.code == code).firstOrNull;
}

/// Where to look for jobs: the Philippines, remote jobs open to Filipinos,
/// one country abroad, or anywhere.
class SearchScope {
  const SearchScope._(this.name, this.label, {this.country});

  static const philippines = SearchScope._('philippines', 'Philippines');
  static const remote = SearchScope._('remote', 'Remote');
  static const anywhere = SearchScope._('anywhere', 'Anywhere');

  factory SearchScope.abroad(JobCountry country) =>
      SearchScope._('country:${country.code}', country.name, country: country);

  /// The fixed choices, besides a country abroad.
  static const presets = [philippines, remote, anywhere];

  /// Reads a stored [name]; unknown values fall back to the Philippines.
  static SearchScope parse(Object? name) {
    final value = '$name';
    for (final preset in presets) {
      if (preset.name == value) return preset;
    }
    if (value.startsWith('country:')) {
      final country = JobCountry.byCode(value.substring('country:'.length));
      if (country != null) return SearchScope.abroad(country);
    }
    return philippines;
  }

  /// Stored id: a preset's name, or `country:<code>`.
  final String name;
  final String label;

  /// Set when searching one country abroad.
  final JobCountry? country;

  bool get isAbroad => country != null;

  @override
  bool operator ==(Object other) => other is SearchScope && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// How recent postings must be.
enum PostedWithin {
  today('Today', 'today'),
  week('This week', 'week'),
  month('This month', 'month'),
  any('Any time', 'all');

  const PostedWithin(this.label, this.jsearchValue);

  final String label;
  final String jsearchValue;
}

class JobSearchQuery {
  const JobSearchQuery({
    required this.keywords,
    this.scope = SearchScope.philippines,
    this.postedWithin = PostedWithin.month,
    this.location,
    this.page = 1,
  });

  final String keywords;
  final SearchScope scope;
  final PostedWithin postedWithin;

  /// City or region to bias Philippine searches, e.g. "Manila".
  final String? location;

  /// Results page, from 1.
  final int page;

  JobSearchQuery copyWith({int? page}) => JobSearchQuery(
        keywords: keywords,
        scope: scope,
        postedWithin: postedWithin,
        location: location,
        page: page ?? this.page,
      );

  /// Identifies the search (not the page) for caching.
  String get cacheKey =>
      '${keywords.toLowerCase().trim()}|${scope.name}|${postedWithin.name}|'
      '${location?.toLowerCase().trim() ?? ''}';
}
