/// Whether a page looks like an application's confirmation, e.g. "Thank
/// you for applying" or a /thank-you URL.
abstract final class SubmissionCheck {
  static final _phrases = RegExp(
    r"thank(s| you) for (applying|your application|submitting)|"
    r'application (has been |was )?(received|submitted|sent|complete)|'
    r"(we('ve| have)|we) received your application|"
    r'successfully (applied|submitted)|you(\x27ve| have) (successfully )?applied|'
    r'your application is (in|on its way)',
    caseSensitive: false,
  );

  static final _urls = RegExp(
    r'thank[-_]?you|application[-_]?(submitted|received|complete)|'
    r'apply[-_/]?(success|confirmation)',
    caseSensitive: false,
  );

  /// The page's visible text (the start is enough) and its address.
  static bool looksSubmitted(String pageText, String url) {
    final text = pageText.length > 4000 ? pageText.substring(0, 4000) : pageText;
    if (_phrases.hasMatch(text)) return true;
    final path = Uri.tryParse(url)?.path ?? '';
    return _urls.hasMatch(path);
  }
}
