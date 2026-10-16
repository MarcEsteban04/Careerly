import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictation for practice answers, on the device's speech recognizer.
/// Started only when the user taps the mic, so nothing asks for the
/// microphone up front.
class VoiceInput {
  VoiceInput([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool? _available;

  bool get isListening => _speech.isListening;

  /// Starts listening and reports the words heard so far. Returns false
  /// if speech recognition isn't available or the mic was refused.
  Future<bool> start({
    required ValueChanged<String> onWords,
    required VoidCallback onDone,
  }) async {
    try {
      _available ??= await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            onDone();
          }
        },
        onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
      );
      if (_available != true) return false;
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) =>
            onWords(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          // Long pauses are normal while thinking through an answer.
          pauseFor: const Duration(seconds: 6),
          listenFor: const Duration(minutes: 3),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Speech unavailable: $e');
      _available = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Stopping speech failed: $e');
    }
  }
}
