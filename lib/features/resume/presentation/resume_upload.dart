import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/ai_chain.dart';
import '../data/resume_insights.dart';

/// Reads a resume PDF (with AI) into insights.
typedef ResumeReaderCallback = Future<ResumeInsights> Function(
  Uint8List bytes,
  String fileName,
);

/// Outcome of picking and reading a resume.
sealed class ResumeUploadResult {
  const ResumeUploadResult();
}

class ResumeUploaded extends ResumeUploadResult {
  const ResumeUploaded(this.resume);

  final ResumeInsights resume;

  /// What was found, to show the user.
  String get summary => 'Found ${resume.roles.length} roles and '
      '${resume.skills.length} skills in your resume.';
}

class ResumeUploadFailed extends ResumeUploadResult {
  const ResumeUploadFailed(this.message);

  final String message;
}

/// Lets the user pick a PDF and reads it. Returns null if they cancel.
/// [onReading] fires once a file is chosen, before the slow AI read.
Future<ResumeUploadResult?> pickAndReadResume({
  required ResumeReaderCallback read,
  void Function()? onReading,
}) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  onReading?.call();

  try {
    final bytes = await file.xFile.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      return const ResumeUploadFailed('That PDF is over 10 MB.');
    }
    return ResumeUploaded(await read(bytes, file.name));
  } catch (error) {
    return ResumeUploadFailed(switch (error) {
      AiUnavailableException(allOutOfQuota: true) =>
        'All AI providers are out of credit right now. Try again later.',
      AiUnavailableException() =>
        "Couldn't read your resume. Check your connection and try again.",
      _ => "Couldn't read that PDF. Try another file, or fill in the details "
          'yourself.',
    });
  }
}
