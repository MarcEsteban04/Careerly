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

const _onlineJobsPage = '''
<html><head><title>Virtual Assistant 1700001 - OnlineJobs.ph</title></head><body>
<nav><a>find jobs</a><a>log in</a></nav>
<p>Please login or register as jobseeker to apply for this job.</p>
<h1 class="fs-24 job__title" data-jobid="1700001">Virtual Assistant</h1>
<div><h3>TYPE OF WORK</h3><p>Part Time</p></div>
<div><h3>WAGE / SALARY</h3><p>PHP 25,000/month</p></div>
<div><h3>HOURS PER WEEK</h3><p>20</p></div>
<div><h3>DATE UPDATED</h3><p>Oct 16, 2026</p></div>
<div><h3>JOB OVERVIEW</h3><p>Manage the inbox and calendar.</p><p>Reply to customers within a day.</p></div>
<div><h3>SKILL REQUIREMENT</h3><span>Email Management</span><br><span>Customer Service</span></div>
<div><h3>VIEW OTHER JOB POSTS FROM:</h3></div>
<footer><p>Employers</p><p>Job Search</p></footer>
</body></html>''';

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

  test('reads OnlineJobs.ph pages without AI', () async {
    final ai = FakeAiProvider('Gemini');
    final reader = JobPostReader(
      AiChain([ai]),
      httpClient: MockClient((_) async => http.Response(_onlineJobsPage, 200)),
    );

    final draft = await reader.read(
      'https://www.onlinejobs.ph/jobseekers/job/virtual-assistant-1700001',
    );

    expect(draft.role, 'Virtual Assistant');
    // Hidden from guests: a placeholder, and a note saying so.
    expect(draft.company, 'Employer on OnlineJobs.ph');
    expect(draft.notice, contains('employer'));
    expect(draft.location, 'Remote');
    expect(draft.salary, 'PHP 25,000/month');
    expect(draft.description, startsWith('Part Time · 20 hours/week · Updated Oct 16, 2026'));
    expect(draft.description, contains('Skills: Email Management, Customer Service'));
    expect(draft.description, contains('Reply to customers within a day.'));
    expect(draft.description, isNot(contains('Employers')));
    expect(draft.source, 'OnlineJobs.ph');
    expect(ai.requests, isEmpty);
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
