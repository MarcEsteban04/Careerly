import 'dart:convert';

/// Pulls the first JSON object or array out of a model reply, tolerating
/// code fences and prose around it. Returns null if none parses.
Object? extractJson(String text) {
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  final candidates = [if (fenced != null) fenced.group(1)!, text];

  for (final candidate in candidates) {
    final trimmed = candidate.trim();
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      // Fall back to the outermost {...} or [...] span, whichever opens
      // first, so an array of objects isn't cut down to its first object.
      final spans = [('{', '}'), ('[', ']')]
          .where((s) => trimmed.contains(s.$1))
          .toList()
        ..sort((a, b) => trimmed.indexOf(a.$1).compareTo(trimmed.indexOf(b.$1)));
      for (final (open, close) in spans) {
        final start = trimmed.indexOf(open);
        final end = trimmed.lastIndexOf(close);
        if (start != -1 && end > start) {
          try {
            return jsonDecode(trimmed.substring(start, end + 1));
          } catch (_) {}
        }
      }
    }
  }
  return null;
}
