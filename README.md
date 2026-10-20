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

Add `.product(name: "FormhausUI", package: "formhaus-swift")` for the SwiftUI renderer.

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

`FormEngine` is `@MainActor`. `checkDefinition`, `validateSubmission`, `localize`, `textSlots`, `recallText` and `recallStatic` run on any thread.

## API

`FormEngine` follows the `FormEngine` class of `@formhaus/core` and keeps its names.

- State: `values`, `errors`, `topLevelErrors`, `stepErrors`, `currentStep`, `currentStepIndex`, `visibleSteps`, `visibleFields`, `visibleNodes`, `isFirstStep`, `isLastStep`, `isMultiStep`, `canGoNext`, `progress`, `submitting`, `stepValidating`, `fieldLoading`, `items(_:)`, `isStepSkipped(_:)`, `getSubmitValues()`.
- Values: `setValue`, `setItemValue`, `addItem`, `removeItem`, `reset`, `replaceDefinition`. `replaceDefinition` switches to a new definition and keeps the answers that still fit.
- Errors: `validate`, `validateField`, `setErrors`, `setFieldLoading`.
- Navigation: `start`, `next`, `back`, `skip(_:)`, `submit(_:)`, `goToStepWithField`, `cancelPendingActions`. `next`, `back`, `skip` and `submit` are `async throws` and return `Bool`, like the promises in TypeScript.
- Recall: `recallText(_:options:)` resolves the `{{key}}` tokens of a text with the submit values and the active path. `RecallOptions` holds `item`, `lang` and `format`.
- Changes: `subscribe(_:)` calls the listener after every state change and returns a function that cancels the subscription. A listener added during a notification is called in it, and one removed before its turn is not.

`FormEngineOptions` holds `onBeforeStepChange`, `onAfterStepChange`, `onBeforeSubmit`, `onAfterSubmit`, `onStepValidate`, `onFormEvent`, `onWarning`, `validators`, `messages`, `lang` and `formatRecall`. Hooks are `@MainActor @Sendable` and `async throws`. A hook that returns `Bool?` cancels with `false`, and `nil` stands for `undefined`. A submit handler returns `SubmitResult?`: `.ok`, `.rejected(errors:formErrors:)` or `nil`. `SubmitResult(json:)` reads the `{ ok, errors, formErrors }` object that a TypeScript handler returns. An error thrown by `onAfterStepChange` or `onAfterSubmit` comes back as `FormLifecycleError` with its `phase` and `cause`. A `CancellationError` thrown by a hook or submit handler is never rethrown. The action clears `stepValidating` and `submitting` and returns `false`, or `true` when `onAfterStepChange` or `onAfterSubmit` threw it after the step change or submit.

## SwiftUI renderer

`FormhausUI` renders a definition with native controls on iOS and macOS. It follows `FormRenderer` and `HeadlessFormRenderer` of `@formhaus/react`.

```swift
import FormhausCore
import FormhausUI

FormhausForm(definition: definition, renderer: FormRendererOptions(labels: .catalog(labels))) { values, skippedSteps in
    let reply = try await api.send(values)
    return SubmitResult(json: reply)
}
.formhausBehavior(FormBehavior(errorSummary: true))
.formhausTheme(.standard)
```

- `FormModel` owns a `FormEngine` and publishes Observation-tracked state. `field(key)` returns a `FieldState` with `value`, `error`, `loading` and `version` for one key or item path, so a keystroke re-renders only that field. `structure`, `actions`, `errorGroups`, `topLevelErrors` and `stepErrorCounts` change only when their content changes. `errorGroups` lists the errors per step, each `ErrorGroup` with a `title` and `entries`, and each `ErrorEntry.text` joins the label and the message. It replaces `errorEntries`, which is removed; for a flat list use `model.errorGroups.flatMap(\.entries)`. `version`, `structureVersion` and `valuesVersion` count changes like `getSnapshot`, `getStructureSnapshot` and `subscribeValues`.
- `FormModel` actions: `setValue(_:forKey:)`, `commitValue(_:forKey:)`, `next`, `back`, `skip`, `submit`, `performPrimaryAction`, `cancel`, `setErrors`, `focus(field:)`, `addItem(toGroup:)`, `removeItem(_:fromGroup:)` and `text(forLabel:_:)`. `commitValue` runs auto-advance. `focus(field:)` opens the step of the field and focuses it. `FormModel(localized:)` takes the result of `localize`.
- `FormRendererOptions` holds `labels`, `optionsProviders`, `onCancel`, `onFieldChange`, `onValuesChange`, `onError`, `lang` and `formatRecall`. The model passes `lang` and `formatRecall` to the engine it creates, unless `FormEngineOptions` sets them.
- Answer recall: in a format 1.5 definition, the step and section `title` and `description`, the field and group `label`, `helperText` and `placeholder`, and the group `itemLabel` show the answers of their `{{key}}` tokens. Option labels, actions, catalogs and messages show the tokens as written. `FieldContext.label`, `helperText`, `placeholder` and `accessibilityName`, `SectionContext.title` and `description`, `GroupContext.label` and `helperText`, `GroupItemContext.title`, `ProgressContext` and `errorGroups` carry the resolved texts. `FieldContext.field`, `SectionContext.section` and `GroupContext.group` stay the nodes of the definition. `FormModel.texts(for:)` returns the `RecalledTexts` (`title`, `description`, `label`, `helperText`, `placeholder`) of a field, section or step for a custom view. Resolved texts are never nodes, so an answer is resolved once and a typed `{{key}}` stays as written. A view re-renders only when an answer that its texts recall changes. Recalled answers are user input, so draw them with `Text(verbatim:)` and never as a `LocalizedStringKey`, which parses Markdown.
- `FormhausForm(model:)` scrolls, moves focus to the first invalid field and scrolls to the top on a step change. `FormhausForm(definition:…)` builds a new model when the definition changes and always calls the latest handlers. An equal definition keeps the values and progress; to start over, give the form a new `.id()`. Pending actions are cancelled when the model is replaced or the form leaves the view tree, not when it is only hidden by navigation or a tab switch. `FormhausFormContent(model:)` is the same form without the scroll view. Inside an app's own `ScrollView` it scrolls to errors and to the top the same way. `FormFields`, `FormhausField`, `StepProgressView`, `FormActionsBar`, `FormErrorSummary` and `FormTopLevelErrors` are the building blocks.
- `FormComponents` maps field types to views: `.standard.field("x-color") { ColorField($0) }`. A view gets a `FieldContext` with the field, value, error, options, `setValue` and `commitValue`. `FieldContext(field:key:model:)` builds one for previews and tests. Custom controls join focus-to-error with `.formhausFocus(context, $focused)` or `.onFormhausFocus(context) { … }`, and scrolling with `.formhausScrollAnchor(context)`; `FieldShell` does both. `.section`, `.group`, `.groupItem`, `.confirmDialog`, `.progress` and `.actions` replace the containers. `FormComponents.headless` has no built-in fields.
- `FormComponents.system` renders the form as a native grouped `Form`, like a Settings screen. Put it in a `NavigationStack`. On iOS each step is a pushed screen with the step title and a "Step N" subtitle; Next or Submit sits in the toolbar, Cancel only on the first step, and the back button or a swipe goes back a step. On macOS the step content swaps in place, with Cancel, Back and Next in a bottom row. Text fields are labeled rows, select, radio and multiselect are navigation rows to a checklist on iOS and menus or checkboxes on macOS, checkbox and switch are toggles, dates expand inline on iOS, a scale is a wrapping row of numbered round buttons, and picture options, ratings and long text get their own section. A step description sits above its fields. Field errors are red section footers, and errors that belong to no field open an alert. The theme sets the accent and error colours. Registered fields and the `.section`, `.group`, `.groupItem`, `.progress` and `.actions` builders replace the native rows and containers; a section builder's view goes straight into the grouped `Form`, so return a `Section`. In a matrix section the rows stay native pickers even when `radio` is overridden, in this set and in the built-in one.
- `FormhausTheme` holds the design tokens of `@formhaus/core`: palettes for light and dark, type sizes, spacing, radii, control sizes and motion. `.pointer` uses the fine-pointer and regular-width values, `.touch` the coarse-pointer and compact-width values, and `.standard` picks one per platform. Under Increase Contrast the formhaus palettes use the `contrast: more` values. Sizes follow Dynamic Type, and motion stops with Reduce Motion. Custom views read the resolved tokens from `@Environment(\.formhausTokens)` and style text with `.formhausText(_:)`. `TextRole` is a struct, so apps can define their own roles.

Differences from the web renderer:

- `switch` uses the native switch, with the label before it.
- `date`, `time` and `datetime` show the value as text and open the system picker in a popover on macOS and a sheet on iOS. A date is written when a day is tapped or Done is pressed; a time or date and time only on Done. Closing the picker any other way keeps the old value. Optional fields have a clear button.
- `file` writes a file URL as a string. The renderer copies the picked file, with its security scope, into `formhaus-uploads` in the temporary directory, so the URL stays readable after the picker closes. It deletes the copy when the field is cleared, another file is picked, the form is reset or the model goes away, and it only ever deletes folders it created. Move the file before the app exits if it must outlive the session. On iOS a field that accepts only images opens the photo picker. Any other string, such as a `file:` URL or an upload id in the initial values, is a reference the app supplied: the engine keeps and submits it as given, and the field shows no chosen file and never opens, reads or links it.
- The labels `clear`, `chooseFile`, `done`, `required`, `skip`, `submit`, `stepTitle` and `stepErrors` of the 0.20 catalog are available now. Catalogs and overlays set them like any other label.
- Hidden field `source` values are not resolved. Pass them in the initial values.
- On a step change, VoiceOver moves to the step title. Keyboard focus moves only to an invalid field.

## How to plug in your design system

Register your own views per field type and container on top of a built-in set. Types you leave out keep the built-in views, styled by your theme. The demo's Kiln set in `Examples/FormhausDemo/FormhausDemo/Brand` uses only the public API:

```swift
extension FormComponents {
    static let kiln = FormComponents.standard
        .field("text") { KilnTextField(context: $0) }
        .field("radio") { KilnChoiceField(context: $0) }
        .field("scale") { KilnScaleField(context: $0) }
        .progress { KilnStepHeader(context: $0) }
        .actions { KilnActions(context: $0) }
}

struct KilnTextField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: context.label).font(.system(.subheadline, design: .rounded).weight(.semibold))
            TextField(context.accessibilityName, text: context.textBinding)
                .overlay(alignment: .bottom) { Capsule().fill(focused ? tokens.colors.primary : tokens.colors.border).frame(height: 1.5) }
                .formhausFocus(context, $focused)
            if let error = context.error { Text(verbatim: error).foregroundStyle(tokens.colors.error) }
        }
        .formhausScrollAnchor(context)
    }
}

FormhausFormContent(model: model)
    .formhausComponents(.kiln)
    .formhausTheme(.kiln)
```

`.formhausFocus` joins focus-to-error, and `.formhausScrollAnchor` lets the form scroll to the field. Switching the components or theme of a running form keeps its values, step and errors, because they live in the `FormModel`.

## Demo

`Examples/FormhausDemo` is a SwiftUI app for iPhone, iPad and Mac. It renders the project inquiry form in `FormhausDemo/Resources/project-inquiry.json`: three steps, a route that skips a step, conditional fields, picture options, a rating, a matrix, a scale, a helper text that recalls the name, an error summary and a server error. The same file runs in the [playground](https://formhaus.dev/playground). The options menu switches between the formhaus, native and Kiln component sets on the same `FormModel`, and to the German overlay in `project-inquiry.de.json`. On macOS the component sets are a segmented control in the window toolbar.

Open `Examples/FormhausDemo/FormhausDemo.xcodeproj` in Xcode and run the `FormhausDemo` scheme, or build it from the command line:

```sh
xcodebuild build -project Examples/FormhausDemo/FormhausDemo.xcodeproj -scheme FormhausDemo -destination 'generic/platform=macOS'
```

The app uses the package from the repository by path. Packages that depend on `formhaus-swift` never build it.

The fake server takes about a second and rejects `ada@lovelace.dev` as already registered.

Script mode plays a fixed interaction through the public `FormModel` API, for screen recordings. Pass the launch arguments in the scheme or to `xcrun simctl launch`:

- `-demoScript tour` types, picks options, triggers and fixes an error, takes the landing page branch and comes back, gets the server error and submits. `-demoScript languages` switches to German and back.
- `-demoScript styles` fills part of the form, then shows the same values and step with the native set, the Kiln brand set and formhaus again.
- `-demoStyle system` or `-demoStyle brand` starts in another component set. `-demoStyle formhaus` is the default.
- `-demoLanguage de` starts in German.
- `-demoSpeed 2` plays twice as fast. `-demoStop <mark>` stops at a mark of the script, such as `error`, `branch`, `server` or `success`.

In script mode the iOS keyboard stays hidden. The timings are in `FormhausDemo/Resources/demo-timings.json`. `scripts/render-assets.sh` renders the app icon from the formhaus logo and draws the option pictures into the definition.

## Design tokens

The colours, type sizes, spacing, radii and control sizes come from the [DTCG design tokens](https://github.com/formhaus-dev/formhaus/tree/main/packages/core/tokens) of `@formhaus/core`. `scripts/sync-fixtures.sh` copies them into `Tests/FormhausUITests/Fixtures/tokens`, next to a `VERSION` file with the ref and sha. `tokens-build` resolves every context of `formhaus.resolver.json` with Style Dictionary and writes `Sources/FormhausUI/Theme/FormhausTokens.generated.swift`:

| Tokens | Swift |
|---|---|
| `theme` light and dark | `Palette.light`, `Palette.dark` |
| `theme` with `contrast: more` | the palettes under Increase Contrast |
| `pointer` fine and coarse | type sizes and star size of `.pointer` and `.touch` |
| `width` regular and compact | card padding of `.pointer` and `.touch` |

To regenerate after a sync:

```sh
npm ci --prefix tokens-build
npm --prefix tokens-build run build
```

`scripts/lint.sh tokens` fails when the generated file differs from the tokens. Values with no token, such as the 44 pt hit target, live in `Theme/NativeMetrics.swift`.

## Accessibility

- Increase Contrast maps to `contrast: more`. Input, card and secondary borders then use `color.input.border-strong`, about 3.7:1 against the background, and muted text, placeholders, errors and the primary colour are raised to the native targets.
- At standard contrast the input border is about 2.0:1 against the background, below the 3:1 of WCAG 1.4.11. This is a deliberate deviation that matches the web renderer. The hover border is about 3:1, and Increase Contrast restores 3:1.
- Sizes follow Dynamic Type, and motion stops with Reduce Motion.

## Status

- Definition corpus: passing. `checkDefinition` errors and warnings, overlays, text slots and value cases for the server and the browser engine.
- Answer recall: passing. Every `recall` case resolves its texts through `FormEngine.recallText` with the identity formatter.
- Engine scenarios: passing. Every scenario in `Fixtures/conformance/scenarios` runs through `FormEngine` as its own test, named `<file>: <scenario>`.

The conformance fixtures live in `Tests/FormhausCoreTests/Fixtures/conformance`. They are pinned to the formhaus tag `@formhaus/core@0.21.2`. `Fixtures/VERSION` records the ref and the resolved sha. To sync again:

```sh
scripts/sync-fixtures.sh <git-ref> [path-to-formhaus-repo]
```

## Differences from @formhaus/core

- Answer recall formats with Foundation format styles in UTC, as the specification lists for Swift. A locale that is not a well-formed BCP 47 tag, or whose language Foundation does not provide, falls back to `en`. A `RecallFormatFn` receives a `RecallAnswer` (`.text`, `.number` or `.list`), the field and the locale. `RecallAnswer.stored` writes the answer like the identity formatter.
- `FormEngine.recallText(_:options:)` stands for `recallText` with `engine` in TypeScript. It reads the engine's active path, and it takes `lang` and `formatRecall` from the engine options when `options` leaves them out. Both options are fixed for the lifetime of an engine.
- Patterns run on a native engine that follows `new RegExp(pattern).test(value)` in ECMAScript 2025 with no flags, including Annex B syntax, modifier groups such as `(?i:...)` and duplicate named groups. `Tests/FormhausCoreTests/Fixtures/regex/cases.json` holds the expected results, recorded with Node. To record them again, run `node scripts/regex-cases.mjs`.
- Node 24.15 folds case wrongly in some modifier groups. It returns `false` for `(?i:b|[ab])`, `(?i:x|[a-c])` and `(?i:((3|([a]))))` on `A`, and for `^(?i:\u0178)$` on `ÿ`, where the specification says `true`. It returns `true` for `(?i:(?=\W{2}|(W))(A|(?<![a])))` on `A😀`, where the specification says `false`. The native engine follows the specification. `scripts/regex-cases.mjs` leaves these cases out and checks every recorded case again in a new node process.
- Duplicate group names follow V8, which accepts some patterns that the specification rejects, such as `(?<a>a)(?:b|(?<a>c))`.
- A pattern with more than 100 nested groups counts as invalid. JavaScript accepts it.
- Values are at most 10,000 code units long, so a counted repeat is cut to the number of iterations such a value can use. `^.{0,50000}$` compiles like `^.{0,10000}$`. Such a pattern fails the rule for a longer value. A pattern that still compiles to more than 262,144 instructions fails the rule, unless the value is shorter than any match. A single character or class repeated in a pattern with backreferences, such as `\w{1,5000}`, takes one instruction. V8 rejects literals of 32,768 code units or more, and the native engine accepts them.
- Patterns with backreferences use a backtracking matcher. A match there that needs more than 10,000,000 steps fails the pattern rule. Clearing captures, copying them for a lookaround and comparing a backreference count as steps. Patterns that nest quantified groups which can match empty and also use backreferences, such as `(?:((\1?\1.?){2})*K?)+[ab]`, can run out of steps even on values of about 10 code units. `@formhaus/core` keeps matching until it finishes.
- All other patterns match in time proportional to the input length times the compiled pattern size. Such a match also stops after 10,000,000 steps and then fails the pattern rule.
- One `validateSubmission`, `validateFields`, `validateStep`, `validateFieldValue`, `FormEngine.validate()` or `FormEngine.validateField(_:)` call, or one step check on Continue, has 20,000,000 steps for all its patterns. Once they are spent, every further pattern rule in the call fails. The same call tests at most 10,000 values against patterns, as in `@formhaus/core`.
- The JSON parser rejects strings with unpaired surrogate escapes such as `"\uD800"`. Swift `String` cannot hold them, and replacing them with U+FFFD would change the value.
- The JSON parser rejects documents nested deeper than 512 levels (`JSONValue.maxNestingDepth`). Swift compares and frees nested values recursively, so deeper values could overflow the stack.
- `JSONValue` equality compares structure. A new array or object with the same contents counts as the same value, where JavaScript compares object identity. `FormEngine` keeps the JavaScript rule: every array or object passed to `setValue` or `setItemValue` counts as a change, and group items keep their identity across edits.
- Without `onWarning`, definition warnings go to `os.Logger` with subsystem `dev.formhaus`. `@formhaus/core` logs them with `console.warn`.
- Hooks are always `async`. A TypeScript hook can also return a plain value. The engine suspends after every hook call, as TypeScript does at each `await`, so main-actor tasks queued during an action run before it continues, even when the hook returns at once.
- `FieldErrors` holds strings. A TypeScript `onStepValidate` can return other values, which the engine keeps as they are.

## Performance

Patterns run on a native ECMAScript regex engine with `new RegExp(p).test(s)` semantics. Patterns without backreferences match in time linear in the input.

Limits:

- A match stops after 10,000,000 steps and fails the pattern rule. One validation call has 20,000,000 steps for all its patterns and tests at most 10,000 values.
- A pattern that compiles to more than 262,144 instructions fails the rule.
- Values are at most 10,000 code units long.
- The pattern cache keeps 256 patterns and 16 MB of compiled programs. Automaton states use at most 1 MB per copy and 32 MB in total.

Measured on an Apple M5 Pro with macOS 26.6 and Swift 6.4, in a release build, as the package-benchmark median of 2 runs. Each row is one `validateFieldValue` call with a `pattern` rule. It compares `new RegExp(p).test(s)` in JavaScriptCore, the engine the package used before, with the formhaus native engine, on the same patterns and inputs. Long inputs have 10,000 code units. To reproduce, run `cd Benchmarks && swift package benchmark --target RegexBenchmarks`.

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

`RecallBenchmarks` measures the renderer call that resolves the texts of one field. A label with four tokens (text, list, date and number) takes 3.7 µs with the identity formatter and 8.2 µs with the default formatter. A label without tokens takes 0.31 µs.

`RendererBenchmarks` hosts a form with 3,000 picture options offscreen on macOS. The first render takes 152 ms and a selection 3.5 ms.

To run the benchmarks:

```sh
cd Benchmarks && swift package benchmark
```

The benchmarks use jemalloc when it is installed. Without it, set `BENCHMARK_DISABLE_JEMALLOC=true`.

### Benchmarks and heavy tests

CI runs fast checks that count work, such as renders and matcher steps, and never measures time. The large cases (counted repeats up to 4,001, 10,000-character inputs with the full step budget, 200,000 nested arrays, the full fuzz set of the regex fixture and the thread stress) run only with `scripts/heavy-tests.sh`, together with the thread sanitizer and the benchmarks. `scripts/heavy-tests.sh tests`, `tsan` or `benchmarks` runs one part. Run it before a release and after changes to the renderer, the regex engine or the engine core. CI runs the thread sanitizer on pull requests that change `Sources/FormhausCore/Regex`, and the iOS Simulator accessibility audit of the demo on pushes to `main` and from the Actions tab.

## Scenario runner

`Tests/FormhausCoreTests/Scenarios` ports the TypeScript scenario runner. Each action runs as a main-actor task. Waiting "one macrotask" means yielding the main actor until every task that is not blocked on a `defer` reply has run. A `defer` reply is a continuation that the `resolve` step resumes. The runner fails on unknown action, hook and expectation names, on actions that never settle, and on `defer` replies that are never resolved.

## License

MIT
