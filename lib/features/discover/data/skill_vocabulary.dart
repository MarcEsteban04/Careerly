/// Skills commonly asked for in job posts, used to spot what a post wants
/// that the profile doesn't list. Covers tech, design, support and office
/// work, leaving out names that are also everyday words ("Go", "Swift").
/// Matching is case- and punctuation-insensitive ("Next.js" =
/// "Nextjs", "ReactJS" = "React").
abstract final class SkillVocabulary {
  static const skills = [
    // Web and software
    'JavaScript', 'TypeScript', 'React', 'Next.js', 'Vue', 'Angular',
    'Svelte', 'Node.js', 'NestJS', 'PHP', 'Laravel',
    'WordPress', 'Shopify', 'Python', 'Django', 'Flask', 'FastAPI', 'Java',
    'Spring Boot', 'Kotlin', 'SwiftUI', 'Dart', 'Flutter', 'React Native', 'C#',
    '.NET', 'C++', 'Golang', 'Ruby on Rails', 'HTML', 'CSS', 'Sass',
    'Tailwind', 'Bootstrap', 'jQuery', 'Redux', 'GraphQL', 'REST API',
    // Data and infrastructure
    'SQL', 'MySQL', 'PostgreSQL', 'MongoDB', 'Firebase', 'Supabase',
    'Redis', 'AWS', 'Azure', 'Google Cloud', 'Docker', 'Kubernetes',
    'Linux', 'Git', 'GitHub', 'CI/CD', 'Vercel', 'Netlify', 'Excel',
    'Power BI', 'Tableau', 'Looker', 'Pandas', 'Machine Learning',
    'Data Analysis', 'Prompt Engineering', 'LLM', 'OpenAI',
    // Testing and process
    'Jest', 'Cypress', 'Selenium', 'Unit Testing', 'QA', 'Agile', 'Scrum',
    'Jira', 'Trello', 'Asana', 'Confluence',
    // Design
    'Figma', 'Adobe XD', 'Photoshop', 'Illustrator', 'Canva', 'UI Design',
    'UX Design', 'UX Research', 'Wireframing', 'Prototyping',
    'Design Systems', 'Premiere Pro', 'After Effects',
    // Support, IT and office
    'Technical Support', 'Customer Service', 'Troubleshooting',
    'Networking', 'Active Directory', 'Windows Server', 'Help Desk',
    'Zendesk', 'Freshdesk', 'Salesforce', 'HubSpot', 'CRM', 'SEO',
    'Google Analytics', 'Google Workspace', 'Microsoft Office',
    'MS Word', 'PowerPoint', 'Data Entry', 'Copywriting',
    'Social Media', 'Email Marketing', 'Project Management',
    'Business English',
  ];

  /// Whether lowercase [text] mentions [skill] as a whole word, allowing for
  /// the usual JavaScript spellings: "React" also matches "ReactJS" and
  /// "React.js"; "Nextjs" also matches "Next.js".
  static bool mentions(String text, String skill) {
    final needle = skill.toLowerCase().trim();
    if (needle.isEmpty) return false;
    final base = needle.endsWith('.js')
        ? needle.substring(0, needle.length - 3)
        : needle.endsWith('js') && needle.length > 4
            ? needle.substring(0, needle.length - 2)
            : needle;
    final spellings = {needle, '${base}js', '$base.js'};
    // Whole-word match so "Go" doesn't match "Google".
    return spellings.any(
      (s) => RegExp('(^|[^a-z0-9+#])${RegExp.escape(s)}(\$|[^a-z0-9+#])')
          .hasMatch(text),
    );
  }

  /// Lowercase, without spaces or punctuation, and without a trailing
  /// "js" so "ReactJS" and "React" compare equal.
  static String normalize(String skill) {
    var key = skill.toLowerCase().replaceAll(RegExp(r'[\s._\-/]'), '');
    if (key.length > 4 && key.endsWith('js')) {
      key = key.substring(0, key.length - 2);
    }
    return key;
  }
}
