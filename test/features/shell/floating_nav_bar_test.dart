import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/shell/presentation/widgets/floating_nav_bar.dart';

void main() {
  const items = [
    FloatingNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    FloatingNavItem(icon: Icons.work_outline, selectedIcon: Icons.work, label: 'Jobs'),
    FloatingNavItem(icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: 'Agenda'),
    FloatingNavItem(icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'Goals'),
    FloatingNavItem(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome, label: 'Studio'),
  ];

  Widget bar({required double width, int selected = 0, Map<int, int> badges = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: FloatingNavBar(
                items: items,
                selectedIndex: selected,
                onSelected: (_) {},
                onAdd: () {},
                badges: badges,
              ),
            ),
          ),
        ),
      );

  testWidgets('never builds negative widths on a near-zero first frame',
      (tester) async {
    // Overflow stripes are acceptable for one tiny frame; a negative
    // constraint is not, because it breaks the bar until restart.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(bar(width: 90));
    await tester.pumpAndSettle();

    expect(
      errors.where((e) => e.exceptionAsString().contains('negative')),
      isEmpty,
    );
  });

  testWidgets('shows the active label and a badge', (tester) async {
    await tester.pumpWidget(bar(width: 390, selected: 4, badges: {2: 3}));
    await tester.pumpAndSettle();

    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Agenda, 3 due soon'), findsOneWidget);
  });
}
