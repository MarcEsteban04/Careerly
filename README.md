# Careerly

A personal career workspace built with Flutter and Supabase.

## Setup

1. Copy `.env.app.example` to `.env.app` and fill in the Supabase project URL and anon/publishable key. These are the only values the app reads.
2. Server-side secrets (service role key, AI provider keys) live in `.env.local` (template: `.env.example`) and are never bundled into the app.
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
    settings/          Account sheet
    (each has data/ for models + repositories, presentation/ for UI)
assets/
  fonts/               Bundled fonts (Inter, OFL licensed)
  icons/               App logo
supabase/migrations/   Database schema (SQL, run in order)
test/                  Mirrors lib/ structure
```
