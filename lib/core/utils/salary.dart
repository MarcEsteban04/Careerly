/// Rough monthly pay in Philippine pesos, read from free-text salaries such
/// as "₱40K–₱55K/month", "PHP 50,000 - 60,000 a month" or "$15–20 an hour".
/// Uses the top of a range. Meant for sorting and filtering, not payroll:
/// foreign currencies use fixed approximate rates. Null when no amount.
int? monthlyPesos(String? salary) {
  if (salary == null) return null;
  final text = salary.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  final amounts = [
    for (final match
        in RegExp(r'(\d[\d,]*(?:\.\d+)?)\s*(k|m)?\b').allMatches(text))
      _amount(match.group(1)!, match.group(2)),
  ].where((n) => n >= 1).toList();
  if (amounts.isEmpty) return null;
  // "50,000 - 60,000" or "₱40K–₱55K": take the top of the range.
  final top = amounts.take(2).reduce((a, b) => a > b ? a : b);

  final perMonth = top * _periodsPerMonth(text);
  final pesos = perMonth * _pesoRate(text);
  // Below this is a stray number (e.g. "2 years"), not pay.
  return pesos < 1000 ? null : pesos.round();
}

double _amount(String digits, String? suffix) {
  final value = double.tryParse(digits.replaceAll(',', '')) ?? 0;
  return switch (suffix) {
    'k' => value * 1000,
    'm' => value * 1000000,
    _ => value,
  };
}

double _periodsPerMonth(String text) {
  if (RegExp(r'hour|/hr\b|\bhr\b|hourly').hasMatch(text)) return 160;
  if (RegExp(r'\bday\b|daily|/day').hasMatch(text)) return 22;
  if (RegExp(r'week').hasMatch(text)) return 4.33;
  if (RegExp(r'year|annual|annum|/yr\b|\byr\b|p\.a').hasMatch(text)) {
    return 1 / 12;
  }
  return 1;
}

/// Approximate pesos per unit, for comparing pay across currencies.
double _pesoRate(String text) {
  const rates = <String, double>{
    'sgd': 43,
    's\$': 43,
    'aud': 38,
    'a\$': 38,
    'cad': 41,
    'c\$': 41,
    'nzd': 34,
    'usd': 57,
    'us\$': 57,
    'eur': 62,
    '€': 62,
    'gbp': 72,
    '£': 72,
    'aed': 15.5,
    'sar': 15,
    'qar': 15.5,
    'jpy': 0.38,
    '¥': 0.38,
    'hkd': 7.3,
    'myr': 12.5,
  };
  for (final entry in rates.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  if (text.contains('php') || text.contains('₱')) return 1;
  if (text.contains(r'$')) return 57;
  return 1;
}
