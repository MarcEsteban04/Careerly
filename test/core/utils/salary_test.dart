import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/utils/salary.dart';

void main() {
  test('reads monthly peso salaries, taking the top of a range', () {
    expect(monthlyPesos('PHP 50,000 - 60,000 a month'), 60000);
    expect(monthlyPesos('₱40K–₱55K/month'), 55000);
    expect(monthlyPesos('₱30,000/month'), 30000);
  });

  test('converts other periods to a month', () {
    expect(monthlyPesos('₱600,000 a year'), 50000);
    expect(monthlyPesos('PHP 1,000 per day'), 22000);
  });

  test('converts foreign currencies roughly', () {
    // \$15/hour × 160 hours × ₱57.
    expect(monthlyPesos(r'$15 an hour'), 136800);
    expect(monthlyPesos('SGD 4,000/month'), 172000);
  });

  test('ignores text without pay', () {
    expect(monthlyPesos(null), isNull);
    expect(monthlyPesos('Competitive'), isNull);
    expect(monthlyPesos('2 years experience'), isNull);
  });
}
