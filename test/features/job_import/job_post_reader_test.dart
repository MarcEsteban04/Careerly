import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/job_import/data/job_post_reader.dart';

import '../../core/ai/fake_ai_provider.dart';

const _jobPage = '''
<html><head>
<script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},{
  "@type":"JobPosting",
  "title":"UI/UX Designer",
  "hiringOrganization":{"@type":"Organization","name":"Acme PH"},
  "jobLocation":{"@type":"Place","address":{"addressLocality":"Makati","addressRegion":"Metro Manila"}},
  "baseSalary":{"currency":"PHP","value":{"minValue":40000,"maxValue":55000,"unitText":"MONTH"}},
  "description":"<p>Design delightful mobile experiences in Figma.</p><ul><li>Run user research with real customers every sprint</li><li>Own the design system</li></ul>"
}]}</script>
</head><body>Apply now</body></html>''';

void main() {
  test('reads the JobPosting data a job board publishes, without AI', () async {
    final ai = FakeAiProvider('Gemini');
    final reader = JobPostReader(
      AiChain([ai]),
      httpClient: MockClient((_) async => http.Response(_jobPage, 200)),
    );

    final draft = await reader.read(
      'Check this out https://www.linkedin.com/jobs/view/123/ #hiring',
    );

    expect(draft.role, 'UI/UX Designer');
    expect(draft.company, 'Acme PH');
    expect(draft.location, 'Makati, Metro Manila');
    expect(draft.salary, '₱40,000–55,000/month');
    expect(draft.description, contains('user research'));
    expect(draft.url, 'https://www.linkedin.com/jobs/view/123/');
    expect(draft.source, 'LinkedIn');
    expect(ai.requests, isEmpty);
  });

  test('asks AI to look the link up when the page is a login wall', () async {
    final ai = FakeAiProvider(
      'Groq',
      reply: '{"is_job": true, "role": "Virtual Assistant", '
          '"company": "Bright Co", "location": "Remote", '
          '"description": "Manage calendars and inboxes."}',
    );
    final reader = JobPostReader(
      AiChain([ai]),
      httpClient: MockClient((_) async => http.Response('Log in', 403)),
    );

    final draft = await reader.read('https://www.facebook.com/groups/1/posts/2');

    expect(draft.role, 'Virtual Assistant');
    expect(draft.company, 'Bright Co');
    expect(draft.source, 'Facebook');
    expect(ai.requests.single.webSearch, isTrue);
  });

  test('reads pasted post text with no link', () async {
    final ai = FakeAiProvider(
      'Gemini',
      reply: '{"is_job": true, "role": "Data Encoder", "company": "Globex"}',
    );
    final reader = JobPostReader(AiChain([ai]));

    final draft = await reader.read('HIRING: Data Encoder at Globex, Cebu!');

    expect(draft.role, 'Data Encoder');
    expect(draft.url, isNull);
    expect(ai.requests.single.webSearch, isFalse);
    expect(ai.requests.single.prompt, contains('HIRING: Data Encoder'));
  });

  test('says when something isn\'t a job post', () async {
    final reader = JobPostReader(
      AiChain([FakeAiProvider('Gemini', reply: '{"is_job": false}')]),
    );

    expect(() => reader.read('happy birthday!'), throwsA(isA<NotAJobException>()));
  });

  test('finds links and names sources', () {
    expect(
      JobPostReader.firstUrl('see https://ph.jobstreet.com/job/1). thanks'),
      'https://ph.jobstreet.com/job/1',
    );
    expect(JobPostReader.firstUrl('no link here'), isNull);
    expect(JobPostReader.sourceFor('https://ph.indeed.com/viewjob?jk=1'), 'Indeed');
    expect(JobPostReader.sourceFor('https://careers.example.com/x'), 'careers.example.com');
  });
}
