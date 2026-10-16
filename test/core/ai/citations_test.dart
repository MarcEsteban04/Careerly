import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/citations.dart';

void main() {
  test('removes source markers and the space they leave', () {
    expect(
      stripCitations(
        'An outsourcing firm in Dublin 【3†L4-L11】 【5†L87-L90】 .',
      ),
      'An outsourcing firm in Dublin.',
    );
    expect(stripCitations('Founded: 2010 [2]'), 'Founded: 2010');
    expect(stripCitations('Founded: 2010 [7†L22-L24]'), 'Founded: 2010');
  });

  test('keeps line breaks and ordinary brackets', () {
    expect(stripCitations('Hi Ana,\n\nThanks [for] this.'),
        'Hi Ana,\n\nThanks [for] this.');
  });
}
