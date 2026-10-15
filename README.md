# Careerly

A personal career workspace built with Flutter and Supabase.

## Setup

1. Copy `.env.app.example` to `.env.app` and fill in the Supabase URL and anon/publishable key, plus the JSearch (OpenWeb Ninja) and Jooble keys for job search and the Gemini, Groq and OpenAI keys for resume reading, AI ranking and backup job search (tried in that order; OpenAI is the last resort). Everything in `.env.app` is bundled into the app, which is fine for this personal, sideloaded build; never put the service role key there.
2. `.env.local` (template: `.env.example`) holds every secret, including ones the app must not ship with (service role key, AI provider keys).
3. Create the database tables: open the Supabase dashboard → **SQL Editor**, paste the contents of `supabase/migrations/20261016000000_init_dashboard_schema.sql`, and run it.
4. Create your account from the app's sign-up screen (or in the Supabase dashboard under **Authentication → Users**). Afterwards you can turn off public sign-ups under **Authentication → Sign In / Providers**.

## Run

```sh
flutter run --dart-define-from-file=.env.app
```

In VS Code, the **Careerly** launch configuration passes this flag for you.

## Project structure

```
lib/
  main.dart            App entry: config + Supabase init
  app.dart             MaterialApp, themes, root route
  core/
    ai/                AI providers with automatic fallback
    config/            Build-time environment values
    theme/             Colors, spacing, ThemeData
    utils/             Date and error helpers
    widgets/           Reusable UI components
  features/
    auth/              Login, sign-up, biometric unlock
    shell/             Tabs, floating nav bar, shared workspace data
    dashboard/         Home tab
    applications/      Job application tracker
    agenda/            Interviews and reminders
    goals/             Career goals
    discover/          Job search (JSearch, Jooble) and match scoring
    profile/           Career profile used for matching
    resume/            Resume upload and AI reading
    studio/            AI resume enhancement and cover letters
    documents/         Saved resumes and cover letters, PDF export
    settings/          Account sheet
    (each has data/ for models + repositories, presentation/ for UI)
assets/
  fonts/               Bundled fonts (Inter, OFL licensed)
  icons/               App logo
supabase/migrations/   Database schema (SQL, run in order)
test/                  Mirrors lib/ structure
```
