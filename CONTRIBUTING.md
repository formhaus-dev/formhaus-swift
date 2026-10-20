# Contributing

## Setup

```sh
git clone https://github.com/formhaus-dev/formhaus-swift.git
cd formhaus-swift
swift build
```

Requires Swift 6 and Xcode on macOS.

## Build and test

```sh
swift test
scripts/lint.sh
```

`scripts/lint.sh` runs swift-format, SwiftLint, jscpd and Periphery at the versions CI uses, and downloads them into `.build/tools` on first run. CI runs both on pushes to `main` and on pull requests; both must pass.

## Conformance

Behaviour is defined by the conformance suite of the [TypeScript core](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/fixtures/conformance). The copy in `Tests/FormhausCoreTests/Fixtures/conformance` is synced, never edited:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

A behaviour change starts as a fixture in the formhaus repository. When the Swift engine disagrees with a fixture, fix the engine.

## Making changes

1. Fork the repo and create a branch from `main`.
2. Make your changes, keeping files under 250 lines and the code free of comments.
3. Make sure `swift test` and `scripts/lint.sh` pass. After changes to the renderer, the regex engine or the engine core, also run `scripts/heavy-tests.sh`.
4. Commit using [conventional commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`).
5. Open a pull request against `main`.
