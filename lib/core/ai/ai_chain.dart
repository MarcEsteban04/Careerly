import 'package:flutter/foundation.dart';

import 'ai_provider.dart';

/// A model reply and which provider produced it.
class AiReply {
  const AiReply(this.text, this.provider);

  final String text;
  final String provider;
}

/// Tries providers in order and falls through to the next one when a
/// provider fails, e.g. runs out of credit. Order: Gemini, Groq, OpenAI.
class AiChain {
  AiChain(this.providers);

  final List<AiProvider> providers;

  bool get isConfigured => providers.any((p) => p.isConfigured);

  Future<AiReply> complete(AiRequest request) async {
    final failures = <AiProviderException>[];

    for (final provider in providers) {
      if (!provider.isConfigured) continue;
      // Providers that can't read PDFs need the extracted text instead.
      if (request.pdfBytes != null &&
          !provider.readsPdf &&
          (request.pdfText ?? '').trim().isEmpty) {
        continue;
      }
      try {
        final text = await provider.complete(request);
        if (text.trim().isEmpty) {
          throw AiProviderException(provider.name, 'Empty reply');
        }
        return AiReply(text, provider.name);
      } on AiProviderException catch (e) {
        debugPrint('AI fallback: $e');
        failures.add(e);
      } catch (e) {
        debugPrint('AI fallback: ${provider.name}: $e');
        failures.add(AiProviderException(provider.name, '$e'));
      }
    }
    throw AiUnavailableException(failures);
  }
}

/// Every provider failed (or none is configured).
class AiUnavailableException implements Exception {
  const AiUnavailableException(this.failures);

  final List<AiProviderException> failures;

  bool get allOutOfQuota =>
      failures.isNotEmpty && failures.every((f) => f.isQuota);

  @override
  String toString() => failures.isEmpty
      ? 'No AI provider configured'
      : 'All AI providers failed: ${failures.join('; ')}';
}
