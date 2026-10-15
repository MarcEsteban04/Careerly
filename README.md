# Careerly

A personal career workspace built with Flutter and Supabase.

## Setup

1. Copy `.env.app.example` to `.env.app` and fill in the Supabase project URL and anon/publishable key. These are the only values the app reads.
2. Server-side secrets (service role key, AI provider keys) live in `.env.local` (template: `.env.example`) and are never bundled into the app.
3. Create the single user account in the Supabase dashboard (**Authentication → Users → Add user**) and turn off public sign-ups (**Authentication → Sign In / Providers → Allow new users to sign up**).

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
    widgets/           Reusable UI components
  features/
    <feature>/
      data/            Repositories and data helpers
      presentation/    Screens and feature widgets
assets/
  fonts/               Bundled fonts (Inter, OFL licensed)
  icons/               App logo
test/                  Mirrors lib/ structure
```
