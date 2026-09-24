# AGENTS.md - SysQuest Backend

This file is the permanent working manual for code agents contributing to the SysQuest backend repository.

## Project Context

SysQuest is an educational gamified application for university students. The MVP direction is a 2D pixel-art turn-based RPG where a user enters a technical topic and receives a dynamically generated quest.

Core product loop:

1. User signs up or logs in.
2. User enters a technical topic.
3. Backend generates or retrieves a quest for that topic.
4. The quest contains encounters.
5. Each encounter presents a multiple-choice question.
6. The player answers.
7. Answer quality affects combat.
8. Enemies scale in difficulty.
9. A basic boss appears at the end.
10. Player progress is saved.

## Stack

Frontend repository:

- Flutter.
- Dart.
- Android target for the current cycle.
- Local persistence with SQLite through `sqflite`.

Backend repository:

- Supabase.
- PostgreSQL.
- Supabase Auth.
- Server-side AI generation through Gemini or Groq.

Important rule: the frontend must never call the AI provider directly. AI keys and provider calls belong only behind backend-controlled services.

## Backend Architecture

Use this responsibility flow:

```text
API
  -> Business Logic
  -> Services
  -> Repositories
  -> Supabase / PostgreSQL
```

For AI generation:

```text
Flutter
  -> Backend
  -> AI Provider
  -> Quest JSON
  -> Backend
  -> Flutter
```

For fallback:

```text
Flutter
  -> Backend
  -> Fallback local/pre-generated content
  -> Quest JSON
  -> Flutter
```

Recommended backend areas:

- `auth`: Supabase Auth/JWT verification.
- `quests`: quest generation, retrieval, validation, and persistence.
- `encounters`: answer validation and encounter outcome rules.
- `progress`: remote progress persistence.
- `ai`: AI provider abstraction and adapters.
- `fallback`: pre-generated quests/questions for outages or rate limits.
- `admin`: basic admin capabilities.

## Coding Rules

- Keep changes small and tied to one Jira issue.
- Do not implement future-scope features without explicit approval.
- Separate API handlers, business logic, services, and repositories.
- Validate all external input.
- Validate all AI-generated quest JSON before storing or returning it.
- Prefer simple, testable modules over broad abstractions.
- Document significant architecture decisions before implementing them.
- Do not remove existing code automatically when requirements conflict; document the contradiction first.

## Security Rules

- Never hardcode API keys, passwords, tokens, JWT secrets, Supabase service keys, or AI provider credentials.
- Use environment variables for sensitive configuration.
- Commit `.env.example`, not `.env`.
- Keep provider credentials backend-side only.
- Treat all AI output as untrusted input.
- Use least-privilege database policies and access tokens.
- Public repositories require extra care with generated files, logs, and local config.

## Git Rules

- Never work directly on `main`.
- Use one branch per Jira task.
- Branch format: `feature/SQ-XXX-description`.
- Commit messages must include the Jira id, for example: `SQ-001 add backend audit docs`.
- Keep commits small and reviewable.
- Pull requests must include:
  - Summary.
  - Changes made.
  - Tests run.
  - Possible risks.
  - Related Jira tasks.

## Testing Rules

- Add or update tests for any backend behavior.
- For scaffold-only or documentation-only changes, state that no runtime tests were applicable.
- Add contract tests around quest JSON before AI generation is integrated.
- Add tests for fallback behavior before depending on external AI providers.
- Do not merge feature code without at least basic automated validation.

## Current MVP Scope

Included:

- Register/login.
- App/web synchronization through Supabase Auth.
- Functional turn-based combat.
- AI-generated quest from a free topic.
- Local fallback content.
- Local and remote progress.
- 2-3 character skins by gender.
- Basic boss.
- Basic hints/items.
- Bilingual informational web page.
- Basic admin panel.

Out of scope:

- Local multiplayer.
- Complete layered equipment system.
- Advanced animations.
- iOS.
- Complete monetization.

## Ambiguous Decisions

When a decision is unclear:

1. Check this file and `docs/INITIAL_TECHNICAL_AUDIT.md` first.
2. If the decision affects architecture, security, cost, provider choice, or data contracts, document the options.
3. Do not silently choose a path that creates lock-in or exposes credentials.
4. Ask for human confirmation when the tradeoff materially affects product direction.

## Documentation Rules

- Keep architecture decisions in `docs/`.
- Update documentation in the same branch as the related change.
- Record assumptions when requirements are incomplete.
- Keep setup instructions current whenever dependencies or environment variables change.

## First Recommended Slice

Start with authentication/session foundation:

```text
Register/Login
  -> Flutter
  -> Supabase Auth
  -> local session persistence
  -> main screen
```

Backend responsibilities for that slice are limited to setup, auth verification, and minimal health/auth validation endpoints. Do not begin quest generation, combat, or admin features until the slice is reviewed and accepted.
