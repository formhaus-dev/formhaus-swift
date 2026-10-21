# Contributing

## Setup

```sh
git clone https://github.com/formhaus-dev/formhaus-swift.git
cd formhaus-swift
swift build
```

Requires Swift 6.2 and Xcode on macOS. The token build needs Node 22.

## Build and test

```sh
swift test
scripts/lint.sh
```

`scripts/lint.sh` runs swift-format, SwiftLint, jscpd, the generated token check and Periphery at the versions CI uses. It downloads them into `.build/tools` on first run. `scripts/lint.sh format`, `swiftlint`, `duplicates`, `tokens` or `periphery` runs one check.

## Conformance

Behaviour is defined by the conformance suite of the [TypeScript core](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/fixtures/conformance). A behaviour change starts as a fixture in the formhaus repository. When the Swift engine disagrees with a fixture, fix the engine.

The copy in `Tests/FormhausCoreTests/Fixtures/conformance` is synced, never edited:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

`Fixtures/VERSION` records the ref and the resolved sha. The definition corpus runs `checkDefinition`, overlays, text slots, value cases and recall cases. Every scenario in `Fixtures/conformance/scenarios` runs through `FormEngine` as its own test, named `<file>: <scenario>`.

`Tests/FormhausCoreTests/Scenarios` ports the TypeScript scenario runner. Each action runs as a main-actor task. Waiting "one macrotask" means yielding the main actor until every task that is not blocked on a `defer` reply has run. A `defer` reply is a continuation that the `resolve` step resumes. The runner fails on unknown action, hook and expectation names, on actions that never settle, and on `defer` replies that are never resolved.

## Regex fixtures

`Tests/FormhausCoreTests/Fixtures/regex/cases.json` holds the expected results of the regex engine, recorded with Node. To record them again:

```sh
node scripts/regex-cases.mjs
```

Node 24.15 folds case wrongly in some modifier groups, where the native engine follows the specification. The script leaves these cases out and checks every recorded case again in a new node process.

## Design tokens

`scripts/sync-fixtures.sh` also copies the [DTCG design tokens](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/tokens) into `Tests/FormhausUITests/Fixtures/tokens`. They are never edited here. A colour, size or spacing change starts in the tokens of the formhaus repository.

`tokens-build` resolves every context of `formhaus.resolver.json` with Style Dictionary and writes `Sources/FormhausUI/Theme/FormhausTokens.generated.swift`:

| Tokens | Swift |
|---|---|
| `theme` light and dark | `Palette.light`, `Palette.dark` |
| `theme` with `contrast: more` | Increase Contrast palettes |
| `pointer` fine and coarse | type and star sizes |
| `width` regular and compact | card padding |

After a sync, regenerate and commit the file:

```sh
npm ci --prefix tokens-build
npm --prefix tokens-build run build
```

A new token needs a Swift mapping in `tokens-build/mapping.mjs`, or the build fails. `scripts/lint.sh tokens` fails when the generated file differs from the tokens. Values with no token, such as the 44 pt hit target, live in `Sources/FormhausUI/Theme/NativeMetrics.swift`.

## Benchmarks and heavy tests

CI runs fast checks that count work, such as renders and matcher steps, and never measures time. The large cases run only with `scripts/heavy-tests.sh`: counted repeats up to 4,001, 10,000 character inputs with the full step budget, 200,000 nested arrays, the full regex fuzz set and the thread stress, together with the thread sanitizer and the benchmarks.

```sh
scripts/heavy-tests.sh
scripts/heavy-tests.sh tests
scripts/heavy-tests.sh tsan
scripts/heavy-tests.sh benchmarks
```

Run it before a release and after changes to the renderer, the regex engine or the engine core. CI runs the thread sanitizer on pull requests that change `Sources/FormhausCore/Regex`.

To run one benchmark target:

```sh
cd Benchmarks && swift package benchmark --target RegexBenchmarks
```

The benchmarks use jemalloc when it is installed. Without it, set `BENCHMARK_DISABLE_JEMALLOC=true`. Run builds and benchmarks under `nice -n 15` on a busy machine.

## Demo

`Examples/FormhausDemo` uses the package from the repository by path. CI builds it for the iOS Simulator and macOS, runs the system set navigation tests on pull requests, and runs the iOS Simulator accessibility audit on pushes to `main`.

`Examples/FormhausDemo/scripts/render-assets.sh` renders the app icon and the option pictures.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep files under 250 lines and the code free of comments.
3. Make sure `swift test` and `scripts/lint.sh` pass. Run `scripts/heavy-tests.sh` when the change needs it.
4. Commit using [conventional commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`).
5. Open a pull request against `main`. The `test`, `lint` and `demo` checks must pass.

## Releases

1. Sync the fixtures and tokens to a tagged `@formhaus/core` release with `scripts/sync-fixtures.sh @formhaus/core@X.Y.Z`.
2. Run `scripts/heavy-tests.sh`.
3. Add the release to `CHANGELOG.md` and update the compatibility table in `README.md`.
4. Tag `main` with the plain version, such as `0.1.0`, and push the tag.
