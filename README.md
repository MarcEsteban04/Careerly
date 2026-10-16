# Careerly

A personal career workspace built with Flutter and Supabase.

## Setup

1. Copy `.env.app.example` to `.env.app` and fill in the Supabase URL and anon/publishable key, plus the JSearch (OpenWeb Ninja) and Jooble keys for job search and the Gemini, Groq and OpenAI keys for the AI features: resume reading, writing, interview prep, reading shared job posts and backup job search (tried in that order; OpenAI is the last resort). Everything in `.env.app` is bundled into the app, which is fine for this personal, sideloaded build; never put the service role key there.
2. `.env.local` (template: `.env.example`) holds every secret, including ones the app must not ship with (service role key, AI provider keys).
3. Create the database tables: open the Supabase dashboard → **SQL Editor** and run each file in `supabase/migrations/` in filename order (each is safe to re-run from the second migration on).
4. Create your account from the app's sign-up screen (or in the Supabase dashboard under **Authentication → Users**). Afterwards you can turn off public sign-ups under **Authentication → Sign In / Providers**.

## Run

```sh
flutter run --dart-define-from-file=.env.app
```

In VS Code, the **Careerly** launch configuration passes this flag for you.

## Release APK

```sh
flutter build apk --release --dart-define-from-file=.env.app
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. It's signed with `android/careerly-release.jks`, using the passwords in `android/key.properties`. Both files are git-ignored, so back them up somewhere safe: updates must be signed with the same key to install over the existing app and keep its data. Bump `version` in `pubspec.yaml` for each release.

After changing the logo, regenerate the icon and launch screen with `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`. Settings for both are in `pubspec.yaml`.

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
    job_alerts/        Daily background check of saved searches
    job_import/        Jobs shared in from other apps or pasted links
    profile/           Career profile used for matching
    onboarding/        First-run Get started flow
    resume/            Resume upload and AI reading
    studio/            AI resume enhancement and cover letters
    interview_prep/    AI interview kits and mock interviews
    messages/          Follow-up, thank-you and offer emails
    apply/             Application kit and "Did you apply?" tracking
    documents/         Saved resumes and cover letters, PDF export
    notifications/     Device notifications and the notification center
    reminders/         Agenda reminders
    settings/          Profile screen and photo
    (each has data/ for models + repositories, presentation/ for UI)
assets/
  branding/            Icon and launch-screen layers cut from the logo
  fonts/               Bundled fonts (Inter, OFL licensed)
  icons/               App logo
supabase/migrations/   Database schema (SQL, run in order)
test/                  Mirrors lib/ structure
```
