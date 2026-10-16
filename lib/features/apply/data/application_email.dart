/// Finds where to email an application: a mailto: apply link, or an
/// address the job post asks for CVs to be sent to.
abstract final class ApplicationEmail {
  static final _address = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');

  /// Words that, near an address, mean "send your application here".
  static final _cue = RegExp(
    r'send|email|e-mail|submit|cv|resume|résumé|application|apply|forward',
    caseSensitive: false,
  );

  static final _ignored = RegExp(
    r'no-?reply|donotreply|example\.com|privacy|unsubscribe|support@',
    caseSensitive: false,
  );

  /// The address to apply to, or null when the job isn't applied for by
  /// email.
  static String? find({String? description, String? applyUrl}) {
    final url = applyUrl?.trim() ?? '';
    if (url.toLowerCase().startsWith('mailto:')) {
      final address = Uri.tryParse(url)?.path.trim() ?? '';
      if (_address.hasMatch(address)) return _address.firstMatch(address)!.group(0);
    }
    final text = description ?? '';
    String? fallback;
    for (final match in _address.allMatches(text)) {
      final address = match.group(0)!.replaceAll(RegExp(r'\.+$'), '');
      if (_ignored.hasMatch(address)) continue;
      final start = match.start - 80 < 0 ? 0 : match.start - 80;
      if (_cue.hasMatch(text.substring(start, match.start))) return address;
      fallback ??= address;
    }
    return fallback;
  }
}
