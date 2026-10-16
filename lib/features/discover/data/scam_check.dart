import '../../../core/utils/salary.dart';
import 'job_listing.dart';

enum ScamRisk { none, caution, high }

/// Warning signs in a job post, common in Philippine job scams.
class ScamCheck {
  const ScamCheck(this.risk, this.reasons);

  static const clear = ScamCheck(ScamRisk.none, []);

  final ScamRisk risk;

  /// What looked off, in plain words.
  final List<String> reasons;

  bool get isFlagged => risk != ScamRisk.none;

  /// Reads the post's text for red flags. Heuristic: a flag means "look
  /// closer", not proof.
  static ScamCheck of(JobListing job) {
    final text = [
      job.title,
      job.company,
      job.description,
      ...job.qualifications,
      ...job.responsibilities,
      ...job.benefits,
      job.salary ?? '',
    ].join('\n').toLowerCase();

    final high = <String>[];
    final caution = <String>[];

    bool has(String pattern) => RegExp(pattern).hasMatch(text);

    if (has(r'(registration|processing|training|placement|application|'
        r'uniform|starter kit|membership|reservation|activation)'
        r'\s+fee') ||
        has(r'(pay|send)\s+(a|the|an)?\s*(small\s+)?(fee|deposit)') ||
        has(r'refundable\s+deposit')) {
      high.add('Asks you to pay a fee or deposit. Real employers never '
          'charge you to apply or be hired.');
    }
    if (has(r'\bgcash\b|\bpaymaya\b|\bremittance\b') &&
        has(r'\b(send|pay|fee|deposit|transfer|cash ?in)\b')) {
      high.add('Mentions sending money through GCash, Maya or remittance.');
    }
    // "We invest in our people" is fine; investing your money isn't.
    if (has(r'\b(crypto|bitcoin|usdt|forex)\b') ||
        has(r'investment (opportunity|scheme|package|plan)|'
            r'invest (your )?(own )?(money|capital|₱|php|\$)')) {
      high.add('Talks about crypto, forex or investing your money, which '
          "job posts shouldn't.");
    }
    if (has(r'(like|subscribe|rate)\s+(and\s+\w+\s+)?'
        r'(videos?|products?|hotels?)') ||
        has(r'(per|each)\s+task|tasks?\s+to\s+earn|prepaid\s+task|'
            r'commission\s+per\s+(task|order)')) {
      high.add('Looks like a "task" scam: paid per like, review or order.');
    }

    if (has(r'\b(telegram|whatsapp|viber|wechat)\b')) {
      caution.add('Asks you to reach them on Telegram, WhatsApp or Viber '
          'instead of a company email or site.');
    }
    if (has(r'[a-z0-9._%+-]+@(gmail|yahoo|outlook|hotmail|ymail)\.com')) {
      caution.add('Uses a personal email address (Gmail, Yahoo…) rather '
          'than a company one.');
    }
    if (has(r'no interview|without interview|hired (immediately|on the spot)|'
        r'instant hiring')) {
      caution.add('Promises hiring with no interview.');
    }
    if (has(r'(earn|kita)\s+(up\s+to\s+)?(₱|php|p)?\s?\d[\d,]*k?\s*'
        r'(daily|a day|per day|weekly|a week)') ||
        has(r'easy money|quick money|work 1-2 hours')) {
      caution.add('Promises easy daily or weekly earnings.');
    }
    final pay = monthlyPesos(job.salary);
    final entryLevel = has(r'no experience|fresh grad|entry level|'
        r'data entry|chat support|virtual assistant|encoder');
    if (pay != null && entryLevel && pay >= 150000) {
      caution.add('The pay is far above what similar roles offer.');
    }
    final company = job.company.toLowerCase().trim();
    if (company.isEmpty ||
        company == 'unknown company' ||
        company.contains('confidential')) {
      caution.add("Doesn't name the company.");
    }

    if (high.isNotEmpty) return ScamCheck(ScamRisk.high, [...high, ...caution]);
    if (caution.isNotEmpty) return ScamCheck(ScamRisk.caution, caution);
    return clear;
  }
}
