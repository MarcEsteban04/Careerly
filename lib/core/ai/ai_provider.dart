import 'dart:typed_data';

/// One request to a language model.
class AiRequest {
  const AiRequest({
    required this.prompt,
    this.system,
    this.pdfBytes,
    this.pdfText,
    this.webSearch = false,
    this.json = false,
  });

  final String prompt;
  final String? system;

  /// A PDF for models that can read files directly.
  final Uint8List? pdfBytes;

  /// The same PDF as extracted text, for models that can't read files.
  final String? pdfText;

  /// Let the model search the web for current information.
  final bool webSearch;

  /// Ask for a JSON-only reply.
  final bool json;
}

/// A language model API.
abstract class AiProvider {
  String get name;
  bool get isConfigured;

  /// Whether [AiRequest.pdfBytes] can be sent as-is.
  bool get readsPdf;

  /// Returns the model's text reply, or throws [AiProviderException].
  Future<String> complete(AiRequest request);
}

class AiProviderException implements Exception {
  const AiProviderException(this.provider, this.message, {this.statusCode});

  final String provider;
  final String message;
  final int? statusCode;

  /// Out of credit, quota or rate limit (as opposed to a bad request).
  bool get isQuota =>
      statusCode == 429 ||
      statusCode == 402 ||
      message.toLowerCase().contains('quota') ||
      message.toLowerCase().contains('credit') ||
      message.toLowerCase().contains('rate limit');

  @override
  String toString() => '$provider: $message';
}
