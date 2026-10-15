import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';

const _timeout = Duration(seconds: 90);

Never _fail(String provider, http.Response response) {
  String message;
  try {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final error = body['error'];
    message = error is Map ? '${error['message'] ?? error}' : '$error';
  } catch (_) {
    message = 'HTTP ${response.statusCode}';
  }
  throw AiProviderException(provider, message, statusCode: response.statusCode);
}

/// Google Gemini. Reads PDFs natively; web search via Google Search.
class GeminiProvider implements AiProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-flash-latest',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  String get name => 'Gemini';

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  bool get readsPdf => true;

  @override
  Future<String> complete(AiRequest request) async {
    final pdf = request.pdfBytes;
    final response = await _http
        .post(
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/$model:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            if (request.system != null)
              'systemInstruction': {
                'parts': [
                  {'text': request.system},
                ],
              },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': request.prompt},
                  if (pdf != null)
                    {
                      'inline_data': {
                        'mime_type': 'application/pdf',
                        'data': base64Encode(pdf),
                      },
                    },
                ],
              },
            ],
            if (request.webSearch)
              'tools': [
                {'google_search': {}},
              ],
            // JSON mode can't be combined with search grounding.
            if (request.json && !request.webSearch)
              'generationConfig': {'responseMimeType': 'application/json'},
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) _fail(name, response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw AiProviderException(name, 'No candidates in reply');
    }
    final parts = (candidates.first['content']?['parts'] as List<dynamic>?) ??
        const [];
    return parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text'] as String? ?? '')
        .join();
  }
}

/// Groq (OpenAI-compatible). Fast; web search via its browser tool. Can't
/// read PDFs, so resumes are sent as extracted text.
class GroqProvider implements AiProvider {
  GroqProvider({
    required this.apiKey,
    this.model = 'openai/gpt-oss-120b',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  String get name => 'Groq';

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  bool get readsPdf => false;

  @override
  Future<String> complete(AiRequest request) async {
    final pdfText = request.pdfText;
    final userContent = pdfText == null
        ? request.prompt
        : '${request.prompt}\n\n--- RESUME TEXT ---\n$pdfText';

    final response = await _http
        .post(
          Uri.https('api.groq.com', '/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              if (request.system != null)
                {'role': 'system', 'content': request.system},
              {'role': 'user', 'content': userContent},
            ],
            if (request.webSearch)
              'tools': [
                {'type': 'browser_search'},
              ],
            if (request.json && !request.webSearch)
              'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) _fail(name, response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) throw AiProviderException(name, 'No choices in reply');
    return choices.first['message']?['content'] as String? ?? '';
  }
}

/// OpenAI Responses API. Last resort when Gemini and Groq are unavailable.
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    required this.apiKey,
    this.model = 'gpt-5.4-mini',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  @override
  String get name => 'OpenAI';

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  bool get readsPdf => true;

  @override
  Future<String> complete(AiRequest request) async {
    final pdf = request.pdfBytes;
    final response = await _http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'instructions': ?request.system,
            'input': [
              {
                'role': 'user',
                'content': [
                  {'type': 'input_text', 'text': request.prompt},
                  if (pdf != null)
                    {
                      'type': 'input_file',
                      'filename': 'resume.pdf',
                      'file_data':
                          'data:application/pdf;base64,${base64Encode(pdf)}',
                    },
                ],
              },
            ],
            if (request.webSearch)
              'tools': [
                {'type': 'web_search'},
              ],
            if (request.json && !request.webSearch)
              'text': {
                'format': {'type': 'json_object'},
              },
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) _fail(name, response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final output = body['output'] as List<dynamic>? ?? const [];
    return [
      for (final item in output.whereType<Map<String, dynamic>>())
        if (item['type'] == 'message')
          for (final part
              in (item['content'] as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>())
            if (part['type'] == 'output_text') part['text'] as String? ?? '',
    ].join();
  }
}
