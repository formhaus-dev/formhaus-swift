<p align="center">
  <img src=".github/assets/logo.svg" alt="Formhaus" width="360">
</p>

<p align="center">
  <a href="https://github.com/formhaus-dev/formhaus-swift/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/formhaus-dev/formhaus-swift/ci.yml?branch=main&label=tests" alt="Tests"></a>
  <img src="https://img.shields.io/badge/Swift-6-blue" alt="Swift 6">
  <img src="https://img.shields.io/badge/platforms-iOS%2017%20%7C%20macOS%2014-blue" alt="iOS 17, macOS 14">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/formhaus-dev/formhaus-swift" alt="MIT license"></a>
</p>

<p align="center">
  A native Swift engine for <a href="https://github.com/formhaus-dev/formhaus">formhaus</a> form definitions.<br>
  The same JSON drives validation, conditions, steps and branching on the web, on the server and on iOS.
</p>

<p align="center">
  <a href="https://formhaus.dev/guide/">Documentation</a> ·
  <a href="https://formhaus.dev/playground">Playground</a> ·
  <a href="https://github.com/formhaus-dev/formhaus">TypeScript core</a>
</p>

## Install

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/formhaus-dev/formhaus-swift.git", branch: "main"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "FormhausCore", package: "formhaus-swift")]),
]
```

No version is tagged yet, so depend on `branch: "main"`. After the first tag, switch to `from: "<version>"`.

Requires Swift 6, iOS 17 or macOS 14. `FormhausCore` uses Foundation and `os`, so it builds for Apple platforms only. It has no JavaScript runtime.

## Usage

```swift
import FormhausCore

let json = try JSONValue(parsing: data)

let issues = checkDefinition(json)
let definition = try FormDefinition(json: json)

let result = validateSubmission(definition, try JSONValue(parsing: body))
let localized = try localize(json, overlay: overlay).definition
let slots = textSlots(localized)

let engine = FormEngine(definition: definition, options: FormEngineOptions(
    onBeforeStepChange: { context in context.toStepId != "blocked" },
    onFormEvent: { event in print(event.type) }
))
engine.start()
engine.setValue("email", "ada@example.com")
if try await engine.next() {
    let sent = try await engine.submit { values, skippedSteps in
        let reply = try await api.send(values)
        return SubmitResult(json: reply)
    }
}
```

`FormEngine` is `@MainActor`. `checkDefinition`, `validateSubmission`, `localize` and `textSlots` run on any thread.

## API

`FormEngine` follows the `FormEngine` class of `@formhaus/core` and keeps its names.

- State: `values`, `errors`, `topLevelErrors`, `stepErrors`, `currentStep`, `currentStepIndex`, `visibleSteps`, `visibleFields`, `visibleNodes`, `isFirstStep`, `isLastStep`, `isMultiStep`, `canGoNext`, `progress`, `submitting`, `stepValidating`, `fieldLoading`, `items(_:)`, `isStepSkipped(_:)`, `getSubmitValues()`.
- Values: `setValue`, `setItemValue`, `addItem`, `removeItem`, `reset`.
- Errors: `validate`, `validateField`, `setErrors`, `setFieldLoading`.
- Navigation: `start`, `next`, `back`, `skip(_:)`, `submit(_:)`, `goToStepWithField`, `cancelPendingActions`. `next`, `back`, `skip` and `submit` are `async throws` and return `Bool`, like the promises in TypeScript.
- Changes: `subscribe(_:)` calls the listener after every state change and returns a function that cancels the subscription. A listener added during a notification is called in it, and one removed before its turn is not.

`FormEngineOptions` holds `onBeforeStepChange`, `onAfterStepChange`, `onBeforeSubmit`, `onAfterSubmit`, `onStepValidate`, `onFormEvent`, `onWarning`, `validators` and `messages`. Hooks are `@MainActor @Sendable` and `async throws`. A hook that returns `Bool?` cancels with `false`, and `nil` stands for `undefined`. A submit handler returns `SubmitResult?`: `.ok`, `.rejected(errors:formErrors:)` or `nil`. `SubmitResult(json:)` reads the `{ ok, errors, formErrors }` object that a TypeScript handler returns. An error thrown by `onAfterStepChange` or `onAfterSubmit` comes back as `FormLifecycleError` with its `phase` and `cause`. A `CancellationError` thrown by a hook or submit handler is never rethrown. The action clears `stepValidating` and `submitting` and returns `false`, or `true` when `onAfterStepChange` or `onAfterSubmit` threw it after the step change or submit.

## Status

- Definition corpus: passing. `checkDefinition` errors and warnings, overlays, text slots and value cases for the server and the browser engine.
- Engine scenarios: passing. Every scenario in `Fixtures/conformance/scenarios` runs through `FormEngine` as its own test, named `<file>: <scenario>`.

The conformance fixtures live in `Tests/FormhausCoreTests/Fixtures/conformance`. They are pinned to the formhaus tag `@formhaus/core@0.19.0`. `Fixtures/VERSION` records the ref and the resolved sha. To sync again:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

## Differences from @formhaus/core

- Patterns run on a native engine that follows `new RegExp(pattern).test(value)` in ECMAScript 2025 with no flags, including Annex B syntax, modifier groups such as `(?i:...)` and duplicate named groups. `Tests/FormhausCoreTests/Fixtures/regex/cases.json` holds the expected results, recorded with Node. To record them again, run `node scripts/regex-cases.mjs`.
- Node 24.15 folds case wrongly in some modifier groups. It returns `false` for `(?i:b|[ab])`, `(?i:x|[a-c])` and `(?i:((3|([a]))))` on `A`, and for `^(?i:\u0178)$` on `ÿ`, where the specification says `true`. It returns `true` for `(?i:(?=\W{2}|(W))(A|(?<![a])))` on `A😀`, where the specification says `false`. JavaScriptCore and the native engine follow the specification. `scripts/regex-cases.mjs` leaves these cases out and checks every recorded case again in a new node process.
- Duplicate group names follow V8, which accepts some patterns that the specification rejects, such as `(?<a>a)(?:b|(?<a>c))`.
- A pattern with more than 100 nested groups counts as invalid. JavaScript accepts it.
- Values are at most 10,000 code units long, so a counted repeat is cut to the number of iterations such a value can use. `^.{0,50000}$` compiles like `^.{0,10000}$`. Such a pattern fails the rule for a longer value. A pattern that still compiles to more than 262,144 instructions fails the rule, unless the value is shorter than any match. A single character or class repeated in a pattern with backreferences, such as `\w{1,5000}`, takes one instruction. V8 rejects literals of 32,768 code units or more, and the native engine accepts them.
- Patterns with backreferences use a backtracking matcher. A match there that needs more than 10,000,000 steps fails the pattern rule. Clearing captures, copying them for a lookaround and comparing a backreference count as steps. Patterns that nest quantified groups which can match empty and also use backreferences, such as `(?:((\1?\1.?){2})*K?)+[ab]`, can run out of steps even on values of about 10 code units. `@formhaus/core` keeps matching until it finishes.
- All other patterns match in time proportional to the input length times the compiled pattern size.
- The JSON parser rejects strings with unpaired surrogate escapes such as `"\uD800"`. Swift `String` cannot hold them, and replacing them with U+FFFD would change the value.
- The JSON parser rejects documents nested deeper than 512 levels (`JSONValue.maxNestingDepth`). Swift compares and frees nested values recursively, so deeper values could overflow the stack.
- `JSONValue` equality compares structure. A new array or object with the same contents counts as the same value, where JavaScript compares object identity. `FormEngine` keeps the JavaScript rule: every array or object passed to `setValue` or `setItemValue` counts as a change, and group items keep their identity across edits.
- Without `onWarning`, definition warnings go to `os.Logger` with subsystem `dev.formhaus`. `@formhaus/core` logs them with `console.warn`.
- Hooks are always `async`. A TypeScript hook can also return a plain value. The engine suspends after every hook call, as TypeScript does at each `await`, so main-actor tasks queued during an action run before it continues, even when the hook returns at once.
- `FieldErrors` holds strings. A TypeScript `onStepValidate` can return other values, which the engine keeps as they are.

## Performance

Patterns without backreferences compile to a lazy DFA, so nested quantifiers such as `(a+)+$` cannot backtrack. A lookaround without backreferences runs as one automaton scan over the whole input, so its result for every position costs time linear in the input. Only patterns with backreferences use a backtracking matcher. It memoizes the part of the pattern after the last backreference, and it runs lookarounds that contain no backreferences as scans too. Each pattern keeps up to 8 DFA copies, so threads that match the same pattern at once each get their own cache. One copy may use 1 MB, and all copies of all patterns together 32 MB. When the total is full, copies that were not used since the last reclaim give their memory back first. When a copy reaches its own limit, its states are cleared once per match. The pattern cache keeps at most 256 patterns and 16 MB of compiled programs, and drops the least recently used patterns first. A pattern larger than 16 MB on its own still runs, but is compiled again on every call. If the limit is reached again in the same match, the match continues on the NFA without caching, so the result stays the same.

Median time of one `validateFieldValue` call with a `pattern` rule, on an Apple M5 Pro with macOS 26 and Swift 6.4. "Long" inputs have 10,000 code units. "Compile" uses a new pattern on every call, so it includes the first match.

| Benchmark | JavaScriptCore | Native |
| --- | ---: | ---: |
| compile email | 3.0 µs | 11 µs |
| compile phone | 2.8 µs | 11 µs |
| compile postcode | 3.1 µs | 8.9 µs |
| compile IBAN | 2.9 µs | 13 µs |
| compile password (3 lookaheads) | 3.3 µs | 29 µs |
| compile quoted (backreference) | 2.5 µs | 3.2 µs |
| match email, short / long | 1.5 µs / 21 µs | 0.74 µs / 15 µs |
| match phone, short / long | 1.4 µs / 44 µs | 0.70 µs / 2.4 µs |
| match postcode, short / long | 1.5 µs / 44 µs | 0.71 µs / 2.5 µs |
| match IBAN, short / long | 1.4 µs / 44 µs | 0.73 µs / 2.5 µs |
| match password, short / long | 1.7 µs / 120 µs | 1.2 µs / 74 µs |
| match quoted, short / long | 1.3 µs / 93 µs | 1.1 µs / 143 µs |
| `(a+)+$` on 9,999 `a` and `!` | 882 ms | 12 µs |
| `(a\|aa)+$` on 9,999 `a` and `!` | 1,249 ms | 12 µs |
| `(x+x+)+y` on 10,000 `x` | 929 ms | 12 µs |
| `(?:a\|[]()…)*\1(?!)` with 15,000 `()` on 9,999 `a` | 5.4 ms | 5.6 ms |
| `(?=(?!b)[^]*x)y(?:z\|$)` on 9,999 `y` and `x` | 46 ms | 2.3 ms |
| `[^]*a[^]{3900}$` on 10,000 random `a` and `b` | 12 µs | 97 ms |
| `[a-z]{0,4001}1` on 6,000 `b` and `1` | 26 ms | 188 ms |
| `[ab]*a[ab]{12}$` on 10,000 random `a` and `b` | 15 µs | 2.0 ms |

JavaScriptCore stops the pathological patterns at its backtracking limit and returns `false`. The native engine fails the rule for the pattern with 15,000 captures when it runs out of steps. Node takes 94 s for `[^]*a[^]{3900}$` on the same input. The last three patterns build many large DFA states, so they run on the NFA without caching once a copy reaches its 1 MB limit. The native engine adds 165 KB to a stripped release executable that links `FormhausCore`: 1,008,336 bytes against 839,664 on main.

To run the benchmarks:

```sh
cd Benchmarks && swift package benchmark
```

The benchmarks use jemalloc when it is installed. Without it, set `BENCHMARK_DISABLE_JEMALLOC=true`.

## Scenario runner

`Tests/FormhausCoreTests/Scenarios` ports the TypeScript scenario runner. Each action runs as a main-actor task. Waiting "one macrotask" means yielding the main actor until every task that is not blocked on a `defer` reply has run. A `defer` reply is a continuation that the `resolve` step resumes. The runner fails on unknown action, hook and expectation names, on actions that never settle, and on `defer` replies that are never resolved.

## License

MIT
