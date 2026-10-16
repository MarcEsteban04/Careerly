import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/theme/app_theme.dart';
import 'package:careerly/core/widgets/island_toast.dart';

void main() {
  test('guesses the tone from the wording', () {
    expect(IslandTone.guess("Couldn't save the PDF. Try again."), IslandTone.error);
    expect(IslandTone.guess('Saved to Studio'), IslandTone.success);
    expect(IslandTone.guess('Opening the application form…'), IslandTone.info);
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    // The Undo ring drains for as long as the notice shows; with motion
    // reduced it holds still, so settling doesn't run out the clock.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('shows, runs its action, and hides itself', (tester) async {
    final context = await pump(tester);
    var undone = false;

    Island.show(
      context,
      'Answer deleted',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Answer deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('Answer deleted'), findsNothing);

    // A newer notice replaces the current one, then times out.
    Island.show(context, 'First');
    await tester.pumpAndSettle();
    Island.show(context, 'Saved to notes');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Saved to notes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Saved to notes'), findsNothing);
  });

  testWidgets('swipes up to dismiss', (tester) async {
    final context = await pump(tester);
    Island.show(context, 'Copied');
    await tester.pumpAndSettle();

    await tester.drag(find.text('Copied'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsNothing);
  });
}
