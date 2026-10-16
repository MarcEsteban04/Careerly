import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/theme/app_theme.dart';
import 'package:careerly/features/apply/data/form_field_info.dart';
import 'package:careerly/features/apply/presentation/fill_review_sheet.dart';

void main() {
  const email = FormFieldInfo(id: 'f0', kind: FormFieldKind.email, label: 'Email');
  const why = FormFieldInfo(
    id: 'f1',
    kind: FormFieldKind.textarea,
    label: 'Why Acme?',
  );
  const answers = [
    FieldAnswer(field: email, value: 'princess@example.com', fromAi: false),
    FieldAnswer(field: why, value: 'I love your product.', fromAi: true),
  ];

  testWidgets('edits and leaves out answers before filling', (tester) async {
    List<FieldAnswer>? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  chosen = await showFillReviewSheet(
                    context,
                    answers: answers,
                    leftForYou: 3,
                    detailsMissing: false,
                    onAddDetails: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('2 answers ready · 1 drafted by AI · 3 left for you'),
        findsOneWidget);
    expect(find.text('AI draft'), findsOneWidget);
    expect(find.text('Fill 2 fields'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'I love your product.'),
      'I use your app every day.',
    );
    await tester.tap(find.bySemanticsLabel('Fill "Email"'));
    await tester.pumpAndSettle();
    expect(find.text('Fill 1 field'), findsOneWidget);

    await tester.tap(find.text('Fill 1 field'));
    await tester.pumpAndSettle();

    expect(chosen!.single.field.id, 'f1');
    expect(chosen!.single.value, 'I use your app every day.');
  });
}
