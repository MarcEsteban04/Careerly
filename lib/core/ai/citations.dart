/// Removes the source markers some models leave in web-search answers,
/// e.g. "【3†L4-L11】" or "[2]", and tidies the space they leave behind.
String stripCitations(String text) => text
    .replaceAll(RegExp(r'【[^】]*】'), '')
    .replaceAll(RegExp(r'\[\d+(?:†[^\]]*)?\]'), '')
    .replaceAllMapped(RegExp(r'[ \t]+([.,;:!?])'), (m) => m[1]!)
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .trim();
