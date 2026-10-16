import 'package:flutter/material.dart';

import '../../../core/theme/app_accents.dart';

/// Every tool Studio offers, in the order of its grid.
enum StudioTool {
  enhanceResume(
    'Enhance resume',
    'Stronger bullets for a target role',
    Icons.auto_fix_high_rounded,
    Accent.violet,
  ),
  coverLetter(
    'Cover letter',
    'Tailored to a specific job',
    Icons.edit_note_rounded,
    Accent.blue,
  ),
  interviewPrep(
    'Interview prep',
    'Likely questions and answers for a job you track',
    Icons.record_voice_over_outlined,
    Accent.amber,
  ),
  mockInterview(
    'Mock interview',
    'Practice out loud and get scored',
    Icons.mic_none_rounded,
    Accent.rose,
  ),
  atsCheck(
    'ATS check',
    'How well your resume gets past screening software',
    Icons.fact_check_outlined,
    Accent.teal,
  ),
  resumeDesign(
    'Resume design',
    'Choose how your resume PDF looks',
    Icons.palette_outlined,
    Accent.violet,
  ),
  message(
    'Message',
    'Follow-ups, thank-yous and offer replies',
    Icons.mail_outline_rounded,
    Accent.blue,
  ),
  negotiate(
    'Negotiate',
    'A fair counter-offer and what to say',
    Icons.handshake_outlined,
    Accent.emerald,
  ),
  companyResearch(
    'Company research',
    'What an employer does and what to ask them',
    Icons.apartment_rounded,
    Accent.teal,
  );

  const StudioTool(this.label, this.hint, this.icon, this.accent);

  final String label;

  /// One line on what it does, e.g. for a tooltip.
  final String hint;
  final IconData icon;
  final Accent accent;
}
