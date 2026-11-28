---
paths:
  - "android/**"
---

# Android architecture

Applies to everything under `android/`. Package: `app.beverageinventory`. minSdk 26.

## UI

- MUST build the UI with Jetpack Compose only. No XML layouts, no Fragments.
- MUST use unidirectional data flow: the UI renders state and sends events up, the ViewModel handles events and produces the next state.
- MUST expose screen state from the ViewModel as a single `StateFlow<UiState>`, collected in Compose with `collectAsStateWithLifecycle()`.
- MUST keep composables stateless where possible: they take state and lambdas, and the screen-level composable connects them to the ViewModel.
- NEVER expose `MutableStateFlow`, `LiveData` or Room entities from a ViewModel.
- MUST use one-off effects (navigation, opening WhatsApp) through state or a dedicated channel. NEVER call them from inside a composable body.

## Data

- MUST treat Room as the source of truth for the UI (see `offline-sync.md`).
- MUST send the outbox with WorkManager. NEVER call the network from a ViewModel.
- MUST put repositories between ViewModels and data sources. Repositories return `Flow` for observed data and `suspend` functions for one-shot work.
- MUST export the Room schema to a tracked folder and add a `Migration` with a `MigrationTestHelper` test for every schema version bump.
- NEVER edit an exported Room schema JSON once it is merged. A Claude Code hook blocks edits to schemas that exist in `origin/main`; bump the database version instead.
- NEVER use `fallbackToDestructiveMigration`. It would erase unsent counts.

## Modules

- `:core:domain` is pure Kotlin/JVM with no Android dependency: entities, value objects, the suggested-order calculation and validation rules.
- NEVER import `android.*`, `androidx.*` or any Android library in `:core:domain`.
- `:app` depends on `:core:domain`, never the other way around.

## Dependency injection

- MUST use Hilt. ViewModels use `@HiltViewModel` with constructor injection.
- NEVER create repositories, DAOs or `WorkManager` instances by hand inside ViewModels or composables.

## Text and language

- MUST put all user-facing text in `res/values/strings.xml`, written in Brazilian Portuguese (pt-BR).
- NEVER hard-code user-facing text in Kotlin. Use `stringResource` or `pluralStringResource`.
- Code, identifiers, comments, logs and resource names are in English. User-facing strings are the only Portuguese in the repository.

## Concurrency

- MUST inject dispatchers and the clock (`Clock` or a `TimeSource`) so tests can control them.
- NEVER use `GlobalScope` or `runBlocking` in production code.

## WhatsApp hand-off

- MUST open WhatsApp with an `ACTION_VIEW` intent on a `https://wa.me/<number>?text=<url-encoded text>` link. NEVER use the WhatsApp API.
- MUST build the order text in `:core:domain` so it can be unit-tested without Android.

## Review

The `android-reviewer` subagent (`.claude/agents/android-reviewer.md`) reviews Compose and Kotlin changes against these rules. It gives advice and does not block anything.
