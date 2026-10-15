/// An AI reply shaped like the interview coach's JSON contract, wrapped in
/// chatter the parser has to skip.
const sampleKitReply = '''
Here you go:
{
  "company_brief": "Acme builds design tools for small teams.",
  "focus_areas": ["Visual design", "Collaboration"],
  "questions": [
    {"category": "behavioral", "question": "Tell me about a time you handled feedback.", "why": "Tests openness.", "answer": "- Redesigned onboarding after user tests"},
    {"category": "Role", "question": "Walk me through your design process.", "answer": "- Research, wireframes, testing"},
    {"category": "unknown", "question": "Why Acme?", "answer": "- Their focus on small teams"},
    {"category": "role", "question": "", "answer": "dropped"}
  ],
  "questions_to_ask": ["What does success look like in 90 days?"],
  "tips": ["Bring two case studies."]
}''';
