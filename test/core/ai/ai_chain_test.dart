import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/core/ai/ai_provider.dart';
import 'package:careerly/core/ai/json_extract.dart';

import 'fake_ai_provider.dart';

void main() {
  group('AiChain', () {
    test('uses the first provider that works, in order', () async {
      final gemini = FakeAiProvider(
        'Gemini',
        error: const AiProviderException('Gemini', 'quota', statusCode: 429),
      );
      final groq = FakeAiProvider('Groq', reply: 'from groq');
      final openAi = FakeAiProvider('OpenAI', reply: 'from openai');

      final reply = await AiChain([gemini, groq, openAi])
          .complete(const AiRequest(prompt: 'hi'));

      expect(reply.text, 'from groq');
      expect(reply.provider, 'Groq');
      expect(openAi.requests, isEmpty, reason: 'OpenAI is only a last resort');
    });

    test('falls back to OpenAI when Gemini and Groq are out of credit',
        () async {
      final reply = await AiChain([
        FakeAiProvider(
          'Gemini',
          error: const AiProviderException('Gemini', 'quota', statusCode: 429),
        ),
        FakeAiProvider(
          'Groq',
          error: const AiProviderException('Groq', 'rate limit', statusCode: 429),
        ),
        FakeAiProvider('OpenAI', reply: 'ok'),
      ]).complete(const AiRequest(prompt: 'hi'));

      expect(reply.provider, 'OpenAI');
    });

    test('skips providers that cannot read a PDF without extracted text',
        () async {
      final groq = FakeAiProvider('Groq', reply: 'groq', readsPdf: false);
      final openAi = FakeAiProvider('OpenAI', reply: 'openai');

      final reply = await AiChain([groq, openAi]).complete(
        AiRequest(prompt: 'read', pdfBytes: Uint8List.fromList([1, 2, 3])),
      );

      expect(reply.provider, 'OpenAI');
      expect(groq.requests, isEmpty);
    });

    test('reports when every provider is out of quota', () async {
      final chain = AiChain([
        FakeAiProvider(
          'Gemini',
          error: const AiProviderException('Gemini', 'quota', statusCode: 429),
        ),
        FakeAiProvider('Groq', isConfigured: false),
      ]);

      await expectLater(
        chain.complete(const AiRequest(prompt: 'hi')),
        throwsA(
          isA<AiUnavailableException>()
              .having((e) => e.allOutOfQuota, 'allOutOfQuota', isTrue),
        ),
      );
    });
  });

  group('extractJson', () {
    test('reads fenced JSON', () {
      expect(extractJson('Here:\n```json\n{"a": 1}\n```'), {'a': 1});
    });

    test('reads JSON surrounded by prose', () {
      expect(extractJson('Sure! [{"x": true}] Hope that helps.'), [
        {'x': true},
      ]);
    });

    test('returns null for no JSON', () {
      expect(extractJson('nothing here'), isNull);
    });
  });
}
