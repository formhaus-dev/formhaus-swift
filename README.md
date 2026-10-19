# Formhaus for Swift

A native Swift port of the [formhaus](https://github.com/ignsm/formhaus) form engine.

## Install

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "git@github.com:ignsm/formhaus-swift.git", branch: "main"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "FormhausCore", package: "formhaus-swift")]),
]
```

Requires Swift 6, iOS 16 or macOS 13. `FormhausCore` uses Foundation only.

## Usage

```swift
import FormhausCore

let json = try JSONValue(parsing: data)

let issues = checkDefinition(json)
let definition = try FormDefinition(json: json)

let result = validateSubmission(definition, try JSONValue(parsing: body))
let localized = try localize(json, overlay: overlay).definition
let slots = textSlots(localized)
```

## Status

- Definition corpus: passing. `checkDefinition` errors and warnings, overlays, text slots and value cases for the server and the browser engine.
- Engine scenarios: pending. The scenario files load and are listed in `ScenarioFileTests.pendingEngineScenarios`.

The conformance fixtures live in `Tests/FormhausCoreTests/Fixtures/conformance`. `Fixtures/VERSION` records the formhaus ref they were synced from. To sync again:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

## License

MIT
