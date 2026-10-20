# Changelog

## Unreleased

### FormhausUI

- Switching from the system set to another set inside a `NavigationStack` shows Back only in the navigation bar.

## 0.1.1

### FormhausCore

- `JSONValue` and `JSONObject` have `jsonData()` and `jsonString()` for request bodies, and `JSONValue` conforms to `Codable`.

### FormhausUI

- The system set shows the step counter, such as "Step 2 of 3", above the step title, like the formhaus set.

## 0.1.0

First release. Requires Swift 6.2, iOS 17 or macOS 14. Follows `@formhaus/core` 0.22.0 and definition format 1.5.

### FormhausCore

- `FormEngine` with the state, actions and hooks of the `FormEngine` class in `@formhaus/core`, as a `@MainActor` type with `async` actions.
- `goToStep(_:)` opens a step by id for deep links and state restoration. It returns a `GoToStepResult` and reports `.stepRedirected` when the step is not reachable.
- `checkDefinition` reports issues with the codes of `@formhaus/core`, including `.minGreaterThanMax`, `.defaultItemsGreaterThanMax`, `.groupItemLimit`, `.invalidColumns`, `.missingLabel` and `.i18nKeyWithoutText`.
- `validateSubmission` validates a submission on the server against the same definition.
- `validateFieldValue`, `validateFields` and `validateStep` take `options: ValidateOptions(validators:messages:)`.
- `localize` applies translation overlays, and `textSlots` lists the translatable texts.
- `recallText` resolves `{{key}}` answer recall with Foundation format styles.
- A submit handler returns `SubmitResult`. `SubmitResult(json:)` reads the `{ ok, errors, formErrors }` object of a formhaus endpoint. `AfterSubmitFn` types `onAfterSubmit`.
- `.formSubmitFailed(reason:)` reports `.validation`, `.rejected` or `.error(status:)`.
- Patterns run on a native ECMAScript 2025 regex engine. Patterns without backreferences match in linear time.

### FormhausUI

- `FormhausForm` renders a definition with SwiftUI on iOS and macOS. `FormModel` drives it and re-renders only the fields that change.
- The formhaus set matches the web renderers. `FormComponents.system` renders a native grouped `Form`.
- In the system set, steps swap in place on iOS and Back is a navigation bar item from the second step. The navigation title is the form title.
- `FormBehavior.inlineChoiceLimit` sets how many options a radio or multiselect field shows inline in the system set.
- `FormComponents` registers custom views per field type and container on top of a built-in set.
- The error summary shows by default. `FormBehavior(errorSummary: false)` hides it, and `FocusRequest.summary` tells a custom view that focus goes to the summary.
- `FormhausTheme` holds the formhaus design tokens, with Increase Contrast palettes, Dynamic Type and Reduce Motion.
- Answer recall in titles, labels, helper texts and placeholders of format 1.5 definitions.
