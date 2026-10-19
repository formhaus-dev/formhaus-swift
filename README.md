# Formhaus for Swift

A native Swift port of the [formhaus](https://github.com/ignsm/formhaus) form engine.

## Install

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/ignsm/formhaus-swift.git", branch: "main"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "FormhausCore", package: "formhaus-swift")]),
]
```

No version is tagged yet, so depend on `branch: "main"`. After the first tag, switch to `from: "<version>"`.

Requires Swift 6, iOS 16 or macOS 13. `FormhausCore` uses Foundation and JavaScriptCore, so it builds for Apple platforms only.

## Usage

```swift
import FormhausCore

let json = try JSONValue(parsing: data)

let issues = checkDefinition(json)
let definition = try FormDefinition(json: json)

let result = validateSubmission(definition, try JSONValue(parsing: body))
let localized = try localize(json, overlay: overlay).definition
let slots = textSlots(localized)

let engine = FormEngine(definition: definition)
let errors = engine.validate()
```

`FormEngine` is `@MainActor`. `checkDefinition`, `validateSubmission`, `localize` and `textSlots` run on any thread.

## Status

- Definition corpus: passing. `checkDefinition` errors and warnings, overlays, text slots and value cases for the server and the browser engine.
- Engine scenarios: pending. The scenario files load and are listed in `ScenarioFileTests.pendingEngineScenarios`.

The conformance fixtures live in `Tests/FormhausCoreTests/Fixtures/conformance`. They are pinned to formhaus commit `ec53afff48308581ca1e7037b3759ebc26e7b623`. A tag will replace the commit once a `@formhaus/core` release contains the suite. `Fixtures/VERSION` records the ref and the resolved sha. To sync again:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

## Differences from @formhaus/core

- Patterns compile with JavaScriptCore's `RegExp`. Syntax added to JavaScript after the installed OS version of JavaScriptCore can behave differently than in Node.
- If a pattern match throws inside JavaScriptCore, the value fails the pattern rule. `@formhaus/core` lets the value pass.
- The JSON parser rejects strings with unpaired surrogate escapes such as `"\uD800"`. Swift `String` cannot hold them, and replacing them with U+FFFD would change the value.
- The JSON parser rejects documents nested deeper than 512 levels (`JSONValue.maxNestingDepth`). Swift compares and frees nested values recursively, so deeper values could overflow the stack.
- `JSONValue` equality compares structure. A new array or object with the same contents counts as the same value, where JavaScript compares object identity.

## License

MIT
