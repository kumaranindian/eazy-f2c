# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

F2C (Farm2Community) — a **Flutter Web-only** app (no mobile targets are built/shipped) with a Firebase backend (Auth, Firestore, Storage) connecting farmers directly to consumers. Package name is `f2c`; import internal code as `package:f2c/...` (`always_use_package_imports` lint is enforced).

## Commands

```bash
flutter pub get                                                       # install deps
flutter pub run build_runner build --delete-conflicting-outputs       # regenerate Freezed/json_serializable/Riverpod code

flutter run -d chrome -t lib/main_dev.dart     # run against dev Firebase project (f2c-dev-ddd82)
flutter run -d chrome -t lib/main_test.dart    # run against test env
flutter run -d chrome -t lib/main_uat.dart     # run against UAT env
flutter run -d chrome -t lib/main_prod.dart    # run against prod env

flutter build web -t lib/main_dev.dart                  # dev build
flutter build web -t lib/main_prod.dart --release       # prod build (output in build/web/)

flutter test                                    # run all tests
flutter test test/features/authentication/models/user_model_test.dart   # run a single test file
flutter analyze                                 # static analysis (flutter_lints + custom rules in analysis_options.yaml)
```

There is no separate `flutter format`/lint CI script checked in — `flutter analyze` is the linting step.

### Deployment

`scripts/deploy_{dev,test,uat,prod}.bat` are the deploy scripts (Windows `.bat`, but each step is a plain `flutter`/`firebase` CLI call you can run manually on macOS/Linux). Each does: `flutter build web --release -t lib/main_<env>.dart` → `firebase use <project-id>` → `firebase deploy --only hosting` → `firebase deploy --only firestore` → `firebase deploy --only storage`. Firebase project ids/aliases live in `.firebaserc` (`dev` → `f2c-dev-ddd82`, plus `test`/`uat`/`prod`). Never run a deploy script without explicit user confirmation — it pushes to a real Firebase project.

### Admin bootstrap

`dart run scripts/create_admin.dart --username admin --email admin@f2c.com --password ... --name "..." --environment dev` creates the first admin user directly against Firebase Auth/Firestore for a given environment.

## Architecture

Clean Architecture, organized by feature under `lib/features/<feature>/`, each with up to: `datasources/` (raw Firebase/Firestore/SharedPreferences access), `models/` (Freezed immutable models + generated `.freezed.dart`/`.g.dart`), `repositories/` (abstract + `*Impl`, combine datasources, translate to `AppException` subtypes), `providers/` (Riverpod `Provider`/`StateNotifierProvider`/`FutureProvider`/`StreamProvider` — this is the DI layer), `services/` (feature-specific helpers, e.g. PDF/bill/WhatsApp), `presentation/pages/` and `presentation/widgets/`.

Features: `authentication`, `admin`, `customer`, `packaging`, `delivery`. `lib/core/` holds cross-cutting concerns: `config/` (env + per-environment Firebase options), `routes/app_router.dart` (go_router config + auth/role redirect guard), `constants/app_constants.dart` (route paths, Firestore collection names, SharedPreferences keys), `exceptions/` (`AppException` hierarchy), `shared/logger`, `shared/utils`, `shared/converters` (Firestore Timestamp <-> DateTime, etc.), `theme/`, `widgets/` (shared UI).

State management is Riverpod throughout; there is no other state layer. Routing is `go_router`; `appRouterProvider` in `lib/core/routes/app_router.dart` is the single source of truth for both the route table and the login/role-based redirect logic — when adding a page, add both a `RouteNames` constant in `app_constants.dart` and a `GoRoute` (and update `_isAuthorized` if it's role-restricted).

### Multi-environment setup

Four environments (`dev`/`test`/`uat`/`prod`), each with its own Firebase project, its own entry point (`lib/main_<env>.dart`), and its own `lib/core/config/firebase/firebase_options_<env>.dart`. `AppEnvironment` (`lib/core/config/app_environment.dart`) drives environment-conditional behavior (e.g. `showEnvironmentBadge` is true for all but prod). Each `main_<env>.dart` calls `AppConfig.initialize(environment: ...)`, initializes `SharedPreferences` and Firebase, then runs `F2CApp` inside a `ProviderScope` with `sharedPreferencesProvider` overridden — this is the pattern to follow if a new environment-level dependency needs injecting at startup.

### Roles

`UserRole` (`lib/features/authentication/models/user_role.dart`): `superAdmin`, `admin`, `customer`, `farmer`, `packaging`, `delivery`. Each has a `dashboardRoute`; router path-prefix checks (`/admin`, `/customer`, `/packaging`, `/delivery`) gate access — note `farmer` currently has no dedicated route prefix check in `_isAuthorized`, so farmer-only pages need explicit handling if added. Authentication is username-based (not email) against Firebase Auth, with a mandatory first-login password change and a first-run "no users yet" setup flow (`systemSetupCheckProvider` / `FirstUserSetupPage`).

### Data model

Firestore collection names are centralized in `FirestoreCollections` (`lib/core/constants/app_constants.dart`) — always reference that class rather than hardcoding collection strings. Security is enforced via `firestore.rules` / `storage.rules` (deployed via the scripts above), so Firestore-side query/permission behavior should be cross-checked against those files, not assumed from the Dart code alone. Composite query indexes are declared in `firestore.indexes.json`.

## Known repo quirks

- Several `presentation/pages/` files are dead code left over from past rewrites, e.g. `customer_dashboard_page_old.dart`, `customer_dashboard_page_backup_20260924_083656.dart`, `checkout_page_new.dart`, `order_history_page_new.dart`. None are imported by `app_router.dart` or anything else — confirm what `app_router.dart` actually wires up before assuming a `*_page.dart` file is live, and don't edit the `_old`/`_backup`/`_new` variants expecting them to take effect.
- The repository root has many dated `*_COMPLETE.md`/`*_FIX.md`/etc. files documenting past feature work; they are historical notes, not current specs — prefer reading the actual code/tests over these when they might be stale.
- `analysis_options.yaml` enforces `always_use_package_imports`, `require_trailing_commas`, `prefer_single_quotes`, `avoid_print`, and several `unawaited_futures`/`cancel_subscriptions`/`close_sinks` resource-safety rules — run `flutter analyze` after non-trivial changes.
