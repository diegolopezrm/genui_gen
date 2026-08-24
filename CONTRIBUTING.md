# Contributing

## Layout

This repository is a Dart workspace (`pubspec.yaml` at the root declares the
members). One `flutter pub get` resolves every package against a single
lockfile.

| Path | Package | Tests run with |
|---|---|---|
| `packages/genui_gen` | annotations + runtime helpers (Flutter package) | `flutter test` |
| `packages/genui_gen_builder` | `build_runner` generator (pure Dart) | `dart test` |
| `example` | Flutter app with five annotated widgets and one `@GenUiData` model | `flutter test` (smoke tests over the generated catalog) |

## Setup

Requirements: Flutter 3.35 or newer (Dart 3.10 or newer). Then, from the repo
root:

```sh
flutter pub get
```

Do not run `pub get` inside a member package; the workspace resolution handles
all of them.

## Running tests

```sh
# Runtime helpers (GenUiBindings, genUiActionHandler)
cd packages/genui_gen && flutter test

# Generator: golden output per supported type, plus error cases
cd packages/genui_gen_builder && dart test

# Example app widget tests
cd example && flutter test
```

Generator tests use `build_test`'s `testBuilder` and assert the full generated
source. When you change the generated shape on purpose, update the expected
strings in the affected test and say so in the PR description.

## Regenerating the example

The example app commits its generated `*.genui.dart` parts so it runs without
a build step. After changing the generator, any annotated widget under
`example/lib/widgets/` or any `@GenUiData` model under `example/lib/models/`,
regenerate and commit the result:

```sh
cd example
dart run build_runner build
```

Then run the app to see the generated examples rendered offline through
genui's `DebugCatalogView` (no API key or network needed):

```sh
flutter run
```

## Before opening a PR

From the repo root:

```sh
dart format .
dart analyze
```

Both must come back clean. Each package uses `flutter_lints` (or `lints` for
the pure-Dart builder); do not suppress lints without a comment explaining why.

Checklist:

- Tests added or updated for the change, and green locally.
- The example regenerated if the generator output changed.
- `CHANGELOG.md` of each affected package updated under the unreleased
  version.
- The design docs updated when the public API, the type mapping or the
  generated code shape changes. `DESIGN.md` is the 0.1 contract and must keep
  holding; `DESIGN-0.2.md` covers `@GenUiData` and object bindings. Together
  they are the contract the generator is written against.

## Conventions

- Code, comments, docs and commit messages in English.
- Generator diagnostics are `InvalidGenerationSourceError` with `element:` set
  so `build_runner` points at the offending line; they name the widget, the
  parameter and the type, and suggest a fix when there is one.
- The generator uses the current analyzer element model (`ClassElement`,
  `ConstructorElement`, `FormalParameterElement`, ...). Do not reintroduce the
  legacy element API.
- Verify third-party behaviour against the package sources in your pub cache
  rather than from memory; genui is pre-1.0 and changes between minors.
- Keep generated code free of dependencies beyond `genui`, `genui_gen` and
  `json_schema_builder`; everything it calls must be reachable through the
  annotated file's imports.

## Reporting issues

Open an issue at <https://github.com/diegolopezrm/genui_gen/issues> with the
genui version, the annotated constructor, and the generated output or the
build error.
