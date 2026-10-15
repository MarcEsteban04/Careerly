import 'package:careerly/core/ai/ai_provider.dart';

/// Test double: replies with [reply] or throws [error], and records calls.
class FakeAiProvider implements AiProvider {
  FakeAiProvider(
    this.name, {
    this.reply = '',
    this.error,
    this.readsPdf = true,
    this.isConfigured = true,
  });

  @override
  final String name;
  @override
  final bool readsPdf;
  @override
  final bool isConfigured;

  String reply;
  AiProviderException? error;
  final requests = <AiRequest>[];

  @override
  Future<String> complete(AiRequest request) async {
    requests.add(request);
    if (error != null) throw error!;
    return reply;
  }
}
