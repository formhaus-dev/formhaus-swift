<p align="center">
  <img src=".github/assets/logo.svg" alt="Formhaus" width="360">
</p>

<p align="center">
  <a href="https://github.com/formhaus-dev/formhaus-swift/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/formhaus-dev/formhaus-swift/ci.yml?branch=main&label=tests" alt="Tests"></a>
  <img src="https://img.shields.io/badge/Swift-6.2-blue" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/platforms-iOS%2017%20%7C%20macOS%2014-blue" alt="iOS 17, macOS 14">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/formhaus-dev/formhaus-swift" alt="MIT license"></a>
</p>

<p align="center">
  Native Swift engine and SwiftUI renderer for <a href="https://github.com/formhaus-dev/formhaus">formhaus</a> JSON form definitions.
</p>

<p align="center">
  <a href="https://formhaus.dev/guide/">Documentation</a> ·
  <a href="https://formhaus.dev/playground">Playground</a> ·
  <a href="https://github.com/formhaus-dev/formhaus">TypeScript core</a> ·
  <a href="#demo-app">Demo</a>
</p>

## Install

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/formhaus-dev/formhaus-swift.git", from: "0.1.2"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "FormhausCore", package: "formhaus-swift"),
        .product(name: "FormhausUI", package: "formhaus-swift"),
    ]),
]
```

| Product | Contents |
|---|---|
| `FormhausCore` | Engine, validation, `validateSubmission` |
| `FormhausUI` | SwiftUI renderer |

Requires Swift 6.2, iOS 17 or macOS 14. `FormhausCore` uses Foundation and `os`, so it builds for Apple platforms only. There is no JavaScript runtime.

## Quick start

Load a definition and render it. The submit handler returns `.ok`, or `.rejected` with errors that the form shows on the fields:

```swift
import FormhausCore
import FormhausUI
import SwiftUI

let url = Bundle.main.url(forResource: "signup", withExtension: "json")!
let endpoint = URL(string: "https://example.com/signup")!
let definition = try FormDefinition(json: JSONValue(parsing: Data(contentsOf: url)))

struct SignupView: View {
    let definition: FormDefinition

    var body: some View {
        FormhausForm(definition: definition) { values, _ in
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = values.jsonData()
            let (data, _) = try await URLSession.shared.data(for: request)
            return try SubmitResult(json: JSONValue(parsing: data))
        }
    }
}
```

`.rejected(errors:formErrors:)` also takes errors that belong to no field. `SubmitResult(json:)` reads the `{ ok, errors, formErrors }` object that a formhaus endpoint returns. `jsonData()` and `jsonString()` on `JSONValue` and `JSONObject` write compact JSON in JavaScript key order. `JSONValue` is also `Codable`, but Foundation's keyed decoding may not keep the key order of the source JSON; use `JSONValue(parsing:)` when order matters. `FormEngine` runs the same form without a UI, for a renderer of your own. The [documentation](https://formhaus.dev/guide/) covers the definition format.

## Choose a look

The same form in the three sets:

| formhaus | `.system` | Your own |
|:---:|:---:|:---:|
| <img src=".github/assets/set-formhaus.png" alt="The formhaus set" width="240"> | <img src=".github/assets/set-system.png" alt="The native iOS system set" width="240"> | <img src=".github/assets/set-kiln.png" alt="A custom brand set" width="240"> |

### The formhaus set

The default. It matches the web renderers of `@formhaus/react` and `@formhaus/vue`, and uses the formhaus design tokens.

### Native iOS

`.system` renders a grouped `Form`, like a Settings screen. Put it in a `NavigationStack`:

```swift
NavigationStack {
    FormhausForm(definition: definition) { values, _ in .ok }
        .formhausComponents(.system)
}
```

On iOS steps swap in place and never push screens onto your navigation stack. The primary action sits in the toolbar, and from the second step a Back item replaces the back button.

### Your own components

Register a view per field type on top of a built-in set. Types you leave out keep the built-in views:

```swift
extension FormComponents {
    static let kiln = FormComponents.standard
        .field("text") { KilnTextField(context: $0) }
        .field("email") { KilnTextField(context: $0) }
}

struct KilnTextField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: context.label).formhausText(.label)
            TextField(context.accessibilityName, text: context.textBinding)
                .formhausFocus(context, $focused)
                .overlay(alignment: .bottom) {
                    Capsule().fill(focused ? tokens.colors.primary : tokens.colors.border).frame(height: 1.5)
                }
            if let error = context.error {
                Text(verbatim: error).formhausText(.error)
            }
        }
        .formhausScrollAnchor(context)
    }
}
```

Apply it with `.formhausComponents(.kiln)`. `.formhausFocus` joins focus to the first error, and `.formhausScrollAnchor` lets the form scroll to the field. `.section`, `.group`, `.groupItem`, `.confirmDialog`, `.progress` and `.actions` replace the containers. The full Kiln set is in [`Examples/FormhausDemo/FormhausDemo/Brand`](Examples/FormhausDemo/FormhausDemo/Brand).

Switching the components or the theme of a running form keeps its values, step and errors.

## Validate on the server

`validateSubmission` checks the values against the same definition, with the visibility, steps and routes of the client:

```swift
import FormhausCore

let definition = try FormDefinition(json: JSONValue(parsing: definitionData))

let result = validateSubmission(definition, try JSONValue(parsing: requestBody))
if result.errors.isEmpty {
    save(result.values)
} else {
    reject(result.errors)
}
```

The body is the values object. `result.values` holds the values of the active path, and `result.errors` maps keys to messages. Pass skipped steps and custom validators in `SubmissionOptions`. `checkDefinition(json)` lists the issues of a definition before you use it.

## Theming

`FormhausTheme` holds the [formhaus design tokens](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/tokens): light and dark palettes, type sizes, spacing, radii, control sizes and motion. `.standard` picks `.touch` on iOS and `.pointer` on macOS.

```swift
extension FormhausTheme {
    static let brand: FormhausTheme = {
        var theme = FormhausTheme.standard
        theme.light.primary = Color(red: 0.72, green: 0.31, blue: 0.16)
        theme.dark.primary = Color(red: 0.91, green: 0.51, blue: 0.35)
        theme.radii.control = 22
        return theme
    }()
}

FormhausForm(definition: definition) { values, _ in .ok }
    .formhausTheme(.brand)
```

Custom views read the resolved tokens from `@Environment(\.formhausTokens)` and style text with `.formhausText(_:)`. Under Increase Contrast the built-in palettes switch to the `contrast: more` values of the tokens, and custom palettes get raised borders and text. Set `lightIncreased` and `darkIncreased` to choose those colours yourself.

## Accessibility

- Every control has a VoiceOver label from the field label, with "required" for required fields.
- After a failed Continue or Submit, VoiceOver focus moves to the error summary when it lists two or more errors, and to the invalid field otherwise. On a step change it moves to the step title.
- Text sizes follow Dynamic Type, and motion stops with Reduce Motion.
- Tap targets are at least 44 pt.
- At standard contrast the input border is about 2:1 against the background, below the 3:1 of WCAG 1.4.11. This is deliberate and matches the web renderers.
- Increase Contrast switches to the `contrast: more` palette. Input, card and secondary borders then reach about 3.7:1, and muted text, placeholders, errors and the primary colour are raised to the native targets.

## Compatibility

| formhaus-swift | @formhaus/core | Format |
|---|---|---|
| 0.1.0 | 0.22.0 | 1.5 |

Each release pins a tag of [@formhaus/core](https://github.com/formhaus-dev/formhaus) and runs its [conformance suite](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/fixtures/conformance): 73 definition files with their issues, value cases and recall cases, and 429 engine scenarios. Every scenario runs through `FormEngine` as its own test.

## Performance

Patterns run on a native ECMAScript 2025 regex engine with `new RegExp(p).test(s)` semantics. Patterns without backreferences match in time linear in the input.

- An email pattern check takes 0.79 µs, and 12 µs on a 10,000 character value.
- `(a+)+$` on 9,999 `a` and `!` takes 2.8 µs.
- A label that recalls four answers resolves in 3.7 µs with the identity formatter.
- A form with 3,000 picture options renders in 152 ms, and a selection takes 3.5 ms.

Measured on an Apple M5 Pro with macOS 26.6 and Swift 6.4, in a release build, as the package-benchmark median of 2 runs. Each row is one `validateFieldValue` call with a `pattern` rule. It compares `new RegExp(p).test(s)` in JavaScriptCore, the engine the package used before, with the formhaus native engine, on the same patterns and inputs. Long inputs have 10,000 code units.

| Benchmark | JavaScriptCore | formhaus | Difference |
| --- | ---: | ---: | --- |
| match email, short | 1.5 µs | 🟢 0.79 µs | ×1.9 faster |
| match email, long | 21 µs | 🟢 12 µs | ×1.8 faster |
| match phone, short | 1.4 µs | 🟢 0.77 µs | ×1.8 faster |
| match phone, long | 44 µs | 🟢 2.8 µs | ×16 faster |
| match postcode, short | 1.5 µs | 🟢 0.79 µs | ×1.9 faster |
| match postcode, long | 44 µs | 🟢 2.8 µs | ×16 faster |
| match IBAN, short | 1.4 µs | 🟢 0.80 µs | ×1.7 faster |
| match IBAN, long | 44 µs | 🟢 2.9 µs | ×15 faster |
| match password, short | 1.7 µs | 🟢 1.3 µs | ×1.3 faster |
| match password, long | 120 µs | 🟢 72 µs | ×1.7 faster |
| `(a+)+$` on 9,999 `a` and `!` | 882 ms | 🟢 2.8 µs | ×320,000 faster |
| `(a\|aa)+$` on 9,999 `a` and `!` | 1,249 ms | 🟢 2.8 µs | ×450,000 faster |
| `(x+x+)+y` on 10,000 `x` | 929 ms | 🟢 5.0 µs | ×190,000 faster |
| `(?:a\|[]()…)*\1(?!)` with 15,000 `()` on 9,999 `a` | 5.4 ms | 🟢 5.4 ms | ×1.0 faster |
| `(?=(?!b)[^]*x)y(?:z\|$)` on 9,999 `y` and `x` | 46 ms | 🟢 2.6 ms | ×17 faster |
| `[^]*a[^]{3900}$` on 10,000 random `a` and `b` | 12 µs | 🟢 7.9 µs | ×1.5 faster |
| `[a-z]{0,4001}1` on 6,000 `b` and `1` | 26 ms | 🟢 4.1 µs | ×6,300 faster |
| `[ab]*a[ab]{12}$` on 10,000 random `a` and `b` | 15 µs | 🟢 1.8 µs | ×8.5 faster |
| match quoted (backreference), short | 1.3 µs | 🟢 1.1 µs | ×1.2 faster |
| match quoted (backreference), long | 93 µs | 🟢 20 µs | ×4.7 faster |
| compile email ✓ | 3.0 µs | 🔴 7.4 µs | ×2.5 slower |
| compile phone ✓ | 2.8 µs | 🔴 8.3 µs | ×3.0 slower |
| compile postcode ✓ | 3.1 µs | 🔴 7.1 µs | ×2.3 slower |
| compile IBAN ✓ | 2.9 µs | 🔴 8.9 µs | ×3.1 slower |
| compile password (3 lookaheads) ✓ | 3.3 µs | 🔴 16 µs | ×5.0 slower |
| compile quoted (backreference) ✓ | 2.5 µs | 🔴 3.4 µs | ×1.3 slower |

✓ A pattern compiles once and is then served from the 256-pattern cache, so this is a one-time cost when a form first renders. A compile row uses a new pattern on every call, so it includes the first match. The pattern with 15,000 captures runs out of steps and fails the rule.

## Differences from TypeScript

- Answer recall formats with Foundation format styles in UTC. A `RecallFormatFn` receives a `RecallAnswer`, the field and the locale.
- A pattern match stops after 10,000,000 steps, and one validation call has 20,000,000 steps for all its patterns. A pattern that runs out fails its rule. Values are at most 10,000 code units long, and a pattern with more than 100 nested groups is invalid.
- The JSON parser rejects unpaired surrogate escapes and documents nested deeper than 512 levels.
- Hooks are always `async`. Without `onWarning`, definition warnings go to `os.Logger` with subsystem `dev.formhaus`.
- A `file` field writes the URL of a copy in the temporary directory. Read it with `FormModel.pickedFile(forKey:)`.
- Hidden field `source` values are not resolved. Pass them in the initial values.
- There are no drafts and no Cloud client.

## Demo app

`Examples/FormhausDemo` is a SwiftUI app for iPhone, iPad and Mac. It renders a three-step project inquiry with a route, conditional fields, picture options, a rating, a matrix, a scale, recall and a server error. The options menu switches between the formhaus, native and Kiln sets on the same form, and to German.

Open `Examples/FormhausDemo/FormhausDemo.xcodeproj` and run the `FormhausDemo` scheme, or build it from the command line:

```sh
xcodebuild build -project Examples/FormhausDemo/FormhausDemo.xcodeproj -scheme FormhausDemo -destination 'generic/platform=macOS'
```

The fake server takes about a second and rejects `ada@lovelace.dev` as already registered. The same definition runs in the [playground](https://formhaus.dev/playground).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Behaviour changes start in the [formhaus](https://github.com/formhaus-dev/formhaus) repository.

## Security

Report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
