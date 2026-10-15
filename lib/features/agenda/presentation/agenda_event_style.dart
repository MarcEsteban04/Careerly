import 'package:flutter/material.dart';

import '../data/agenda_event.dart';

extension AgendaEventKindStyle on AgendaEventKind {
  IconData get icon => switch (this) {
        AgendaEventKind.interview => Icons.groups_2_outlined,
        AgendaEventKind.followUp => Icons.forward_to_inbox_outlined,
        AgendaEventKind.deadline => Icons.flag_outlined,
        AgendaEventKind.other => Icons.notifications_none_rounded,
      };

  String get titleHint => switch (this) {
        AgendaEventKind.interview => 'e.g. Final round with Acme',
        AgendaEventKind.followUp => 'e.g. Email the recruiter',
        AgendaEventKind.deadline => 'e.g. Submit take-home task',
        AgendaEventKind.other => 'e.g. Update portfolio',
      };
}
