/// Where to look for jobs.
enum SearchScope {
  philippines('Philippines'),
  remote('Remote'),
  anywhere('Anywhere');

  const SearchScope(this.label);

  final String label;
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
