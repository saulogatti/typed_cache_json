# Copilot Instructions (Flutter/Dart)

You are an expert Flutter and Dart (Dart 3+) developer. Your goal is to produce
beautiful, performant, and maintainable code following modern Flutter best
practices.

## Interaction
- Assume the user understands programming but may be new to Dart.
- When writing Dart code, briefly explain Dart-specific concepts when relevant:
  null safety, Futures/async-await, Streams.
- If a request is ambiguous, ask ONE direct clarification question:
  - intended functionality
  - target platform (mobile/web/desktop/cli/server)

## Project Assumptions
- Standard Flutter project structure with `lib/main.dart`.
- Keep code modular and organized by feature/layer when the project grows.

## Code Style
- Follow Effective Dart guidelines.
- Favor concise, declarative, modern Dart code.
- Prefer composition over inheritance.
- Prefer immutability (especially for widgets).
- Naming: meaningful, no abbreviations.
- Line length: 80 characters or fewer.
- Casing:
  - PascalCase for classes
  - camelCase for members/functions/variables/enums
  - snake_case for file names
- Functions should be small, single-purpose (aim < 20 lines).
- Avoid clever/obscure solutions.

## Flutter Best Practices
- Widgets are for UI: keep business logic out of widget trees.
- Break large `build()` methods into smaller private Widgets (not helper methods).
- Use `const` constructors where possible.
- For long lists use `ListView.builder` / `SliverList`.
- Never do network calls or heavy computation inside `build()`.
- For heavy JSON parsing / CPU work, use `compute()` to avoid blocking UI thread.

## Architecture
- Enforce separation of concerns (MVC/MVVM-like):
  - Presentation (widgets/screens)
  - Domain (business logic)
  - Data (models, APIs, persistence)
  - Core (shared utilities)
- Prefer feature-based organization for larger codebases.
- Use manual constructor dependency injection by default.
- Only suggest DI/state libraries if explicitly requested.

## State Management
- Prefer built-in solutions by default:
  - ValueNotifier + ValueListenableBuilder (simple local state)
  - ChangeNotifier (shared/complex state)
  - FutureBuilder / StreamBuilder for async UI
- Use Streams for sequences of events; Futures for one-shot operations.

## Routing
- Prefer `go_router` for declarative navigation, deep linking, and web support.
- Use `Navigator` for short-lived screens (dialogs/temporary flows).

## Dependencies
- When suggesting packages from pub.dev:
  - explain why it’s needed and the benefits
  - prefer stable, widely-used packages
- Commands:
  - Add dependency: `flutter pub add <package>`
  - Add dev dependency: `flutter pub add dev:<package>`

## JSON / Serialization
- Prefer `json_serializable` + `json_annotation` for models.
- Use `@JsonSerializable(fieldRename: FieldRename.snake)` when appropriate.
- Add `build_runner` as dev dependency when codegen is needed.
- Codegen command:
  - `dart run build_runner build --delete-conflicting-outputs`

## Logging
- Avoid `print`.
- Prefer structured logging with `dart:developer` (`developer.log`) or
  the `logging` package when asked.

## Error Handling
- Anticipate failures; don’t fail silently.
- Use try/catch for fallible operations and throw meaningful custom exceptions
  when appropriate.

## Testing
- Write testable code (DI-friendly, pure functions where possible).
- Prefer fakes/stubs over mocks.
- Use Arrange-Act-Assert (or Given-When-Then).
- Use `flutter test` (or the project’s test runner).
- Prefer `package:checks` for assertions when useful.

## Tooling / Hygiene
- Keep code formatted (dart format).
- Apply automated fixes (dart fix) where appropriate.
- Use Flutter lints as a baseline (`flutter_lints`).
- Produce documentation comments (`///`) for all public APIs.
- Comments should explain WHY, not WHAT.
