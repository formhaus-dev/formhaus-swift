# Changelog

## 0.6.2

### FormhausUI

- File rows stack the name above the Remove button at accessibility text sizes.

## 0.6.1

### FormhausUI

- VoiceOver focus moves to the Remove button after a file is added to a full list or removed.
- Announcements are posted with high priority so a focus change does not drop them.
- A full file list tells VoiceOver the limit in the picker hint.
- File names in Remove labels and announcements are isolated for mixed-direction text.
- File names wrap to two lines, or four at accessibility text sizes.
- The file list limit message uses the helper style instead of the error style.

## 0.6.0

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.8.0.
- Format 1.7: `"multiple": true` on a `file` field keeps a list of files. Below 1.7 the field keeps one file.
- `[]` and `null` are empty for a file list.
- `""` and `null` entries of a file list are not files. They are not counted, and `validateSubmission` drops them.
- `minLength` and `maxLength` count the files of a list.
- A file list holds at most `maxLength` files, rounded down, 100 without it and never more than 1000.
- A number or an object without a string `name` in a file list fails with the `file` message.
- `validateSubmission` reads a file list as an array of string references, and a single string as a list of one.
- New `multiple-not-applicable` warning for `multiple` on a field other than `file`.
- `FormDefinition.supportedFormatVersion` is `"1.7"`.
- New `validateWithRules` option on `FormEngineOptions` runs `onValidate` even when the definition rules fail. The definition error wins on the same field.
- Fixed field errors from `onValidate` and `onStepValidate` staying on a step after its next Continue passed, and showing again after Back.

### FormhausUI

- A `file` field with `multiple` shows the chosen files below the picker, each with a Remove button.
- Picking adds files until the list is full. Extra files are dropped and the limit message shows under the list.
- The picker of a full file list is disabled.
- New `FormModel.pickedFiles(forKey:)` returns the picked files of a list.
- The `validateWithRules` engine option reaches `FormhausForm` and `FormModel`.
- Fixed `{{key}}` recall of a picked file showing its `file://` path instead of its name.
- Fixed the file list limit message staying after the app changed the field value with `setValue`.
- Fixed a `storedFileName` callback set on the engine being lost when a `FormModel` is created for it.

## 0.5.0

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.6.1.
- Fixed `validateSubmission` throwing `FormDefinitionError` for definitions with a `slow-pattern` pattern. Every pattern runs again, on values of up to 10,000 characters.
- The `slow-pattern` warning no longer covers repeated groups that start or end with a separator nothing else in the group matches, such as `^[A-Za-z]+([ '-][A-Za-z]+)*$`, or small bounded repeats, such as `^#(?:[0-9a-fA-F]{3}){1,2}$`.

### FormhausUI

- New `conditionalReveal` option on `FormBehavior` draws a field shown by a `radio` or `multiselect` answer under that option, indented with a line on its left. Off by default.
- With `conditionalReveal`, the error of a choice field that reveals fields shows above its options.
- The `.system` set reveals under inline choice lists. Menu and pushed pickers and custom field views keep the fields in place.
- New `revealLine` on `Controls` sets the width of the line beside revealed fields.
- The `.system` set draws a `radio` or `multiselect` list inside a section as rows, one per option.
- Fixed the error of an empty text or number field disappearing when the field takes focus after a failed submit on iOS.
- Fixed VoiceOver reading "Selected" on unchecked options of multiselect fields and `.system` choice lists.
- Fixed the large navigation title of the `.system` set covering the first rows after a failed submit scrolled to a field that was already on screen.
- Fixed a failed submit in the `.system` set not focusing a text field that was off screen.
- The `.system` set shows a field's error under its row instead of in the section footer.
- A failed submit in the `.system` set keeps the question of the invalid field on screen, and the field with its error above the keyboard.

## 0.4.0

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.6.0.
- New `revealTargets(_:)` returns, for each node of a list, the choice field and option that reveal it, following the Revealed fields rule of the specification.
- New type `RevealTarget`.

### FormhausUI

- `FieldContext` has `minLength` and `maxLength` of text fields, for character counters.
- Fixed VoiceOver focus landing on the first option of a `.system` radio list when another option is checked.

## 0.3.0

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.4.2.
- **Breaking:** `validateSubmission(_:_:options:)` with a `FormDefinition` now throws `FormDefinitionError`.
- `validateSubmission` refuses a definition with a `slow-pattern` pattern and reports each one as a `slow-pattern` error. A pattern with one overlapping repeat after `^`, such as `^\d+\.?\d*$`, still runs, on values of up to 1,000 characters. A longer value gets the pattern error without matching.
- The `slow-pattern` warning also covers backreferences, named backreferences and patterns longer than 1,000 characters.
- Fixed `slow-pattern` warnings for repeated groups split by a separator, such as `^([\w-]+\.)+[a-z]{2,}$`.

## 0.2.0

### FormhausCore

- New `locale` option on `FormEngineOptions` takes a list of `LocaleCatalog`. Per key, `messages` wins over the definition's `messages`, which wins over the catalogs in list order, which win over the built-in English.
- A catalog text can be `PluralForms`, picked by the CLDR cardinal rules of the catalog locale on `{count}`, `{min}` or `{max}`. That number is formatted for the same locale.
- Plural rules cover the languages of the shipped catalogs. Other languages use the `other` form.
- Message and label catalogs for `es`, `fr`, `fr-CA`, `de`, `pt-BR`, `it`, `ja`, `zh-CN`, `ru`, `uk` and `en`, loaded with `LocaleCatalog.bundled(_:)`.
- `FormEngine.locale` replaces the catalogs of a running form. The next labels and messages use them.
- New `localeChain(_:)` and `checkCatalog(_:)`. `localeChain` adds the likely region, so `zh-Hans-CN` also tries `zh-CN`.
- New types `LocaleCatalog`, `LocaleText`, `PluralForms` and `CatalogIssues`.
- A multi-step overlay passed to `localize` also accepts `fields.<key>` at the top level. `steps.<id>.fields.<key>` wins when both are set.
- New `onValidate` engine option runs after the definition rules pass, on Continue after `onStepValidate` and on Submit before `onBeforeSubmit`. It gets the values and a `ValidateContext`, whose `fields` lists the visible field paths in scope, and returns errors keyed by field path.
- Keys of an `onValidate` result outside `fields` show as top-level errors.
- An `onValidate` error on another step opens that step on Submit.
- New types `ValidateFn` and `ValidateContext`.
- Form errors from `onStepValidate` and `onValidate` clear on the next Continue, Back, Skip or Submit. Form errors from the submit handler and from `setErrors` stay.
- New `errorSummary(_:options:)` returns the field errors grouped by step, the top-level errors and the field error count.
- New types `ErrorSummary` and `ErrorSummaryOptions`.
- **Breaking:** `ErrorEntry.id` is the element id from `idPrefix` and the field path, as in the web renderers, instead of the field key. Read the key from `ErrorEntry.key`.
- **Breaking:** `@_spi(Renderer) FormEngine.errorGroups(_:)` is removed. Use `errorSummary(_:options:)`.
- In debug builds, `missing-message-key` and `missing-label-key` are not reported for a text that a locale catalog supplies.

### FormhausUI

- `FormhausForm` and `FormModel` run `onValidate` and show its errors.
- Labels of the built-in components come from the `locale` catalogs.
- A changed `locale` in the options of `FormhausForm` relabels the open form, including the error summary.
- New `FormModel.locale`.

## 0.1.7

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.3.0.
- New `matrix-options-mismatch` warning for a row of a `layout: "matrix"` section whose option values differ from those of the first field. Rows that use `optionsFrom` are not checked.

## 0.1.6

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.2.2.
- `FormEngine` validation no longer checks the items of a group that has more items than its limit or an item that is not an object. Only the group error is reported.
- New `FormSnapshot` holds a form's values, current step, skipped steps and option order seed. It is `Codable` with the keys `version`, `definitionId`, `values`, `step`, `skipped` and `seed`.
- New `FormEngine.snapshot()`. It leaves out the values of `password` fields, also inside group items.
- New `restoring:` parameter on `FormEngine` restores a snapshot without walking the steps or validating.
- The fields of each skipped step in a restored snapshot are reset to their start values, as Skip resets them.
- A snapshot that does not match the definition starts the form fresh and reports `snapshot-mismatch` through `onWarning`.
- New `FormSnapshot.decode(_:options:)` returns `nil` for malformed JSON and reports `snapshot-mismatch`.

### FormhausUI

- A file picked in a field that a condition hides and shows again is kept.
- A picked file whose copy no longer exists shows as an empty file field instead of the raw path.
- Submit and Skip send `null` for a picked file whose copy no longer exists, so a required file field reports its error. Other values, including `file:` URLs outside the picked files folder, are sent unchanged.
- Fixed `onAfterSubmit` not running when an owned `FormhausForm` is torn down while the submit handler runs. Step validation and a submit that has not started sending are still cancelled.
- Option cards, picture cards, scale boxes, rating stars, the checkbox, the switch and matrix cells show the error colour when their field is invalid.
- Option cards, picture cards and the checkbox show a focus ring when they have keyboard focus. The switch shows one around its track.
- The rating row shrinks its stars to fit narrow widths and wraps into balanced rows when a star would be smaller than the hit target.
- On iOS 26 and later, the Back button of a step in the navigation bar shows only the chevron. VoiceOver still reads the back label.
- New `restoring:` parameter on `FormhausForm(definition:)`, `FormModel(definition:)` and `FormModel(localized:)`.
- New `FormRendererOptions.onSnapshotChange` reports a new snapshot after a change of values, step or skipped steps, at most once per run loop turn.
- `onSnapshotChange` reports `nil` after a successful submit, including a Skip that submits and a submit that finishes after the form view is gone.
- A restored file value in the picked files folder is picked again while its copy exists and becomes `null` when it does not. Other `file:` values are left unchanged.

## 0.1.5

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.2.0.
- New `FormEngineOptions.hiddenValues`, `.clear` (default) or `.keep`. With `.keep`, fields hidden by conditions keep their values in `engine.values` and in submitted values.
- With `.keep`, conditions, validation and recall still treat hidden fields as unanswered, and hidden fields never block Continue or Submit.
- With `.keep`, submitted values also hold the answers on steps off the active path. Fields of skipped steps stay out.
- `SubmissionOptions.hiddenValues` takes the same option. With `.keep`, `validateSubmission` checks hidden values like visible ones except `required` and drops one that fails without an error.
- New `missingKeys(messages:labels:)` lists the built-in message and label keys a catalog lacks.
- In debug builds, a `messages` or `labels` catalog reports `missing-message-key` or `missing-label-key` through `onWarning` when a shown text is in neither the catalog nor the definition's `messages` or `labels`. Each key is reported once per process.
- New `TestIdTarget` type.

### FormhausUI

- **Breaking:** the `.system` set no longer applies the Formhaus primary as tint. Its built-in controls use the tint of your app: Continue and Back, checkmarks, scale dots, stars, picture selection and the date row. Controls in custom field views follow it too. Apply `.tint(...)` around the form to keep the previous look. The Formhaus set still uses the theme primary.
- The `.system` set no longer forces a large navigation title. New `FormBehavior.titleDisplayMode`: `.automatic` (default) leaves the mode to the host, `.inline` and `.large` set it, and `.off` sets no title. Pass `.large` to keep the previous large title.
- New `FormRendererOptions.testIds` adds accessibility identifiers for UI tests. It is `.off` by default. `.automatic` names elements after the definition id: `signup.form`, `signup.email`, `signup.plan.pro`, `signup.people.0.name`, `signup.submit`, `signup.next`, `signup.back`, `signup.cancel` and `signup.summary`. `.custom` names them with a closure.
- With test ids on, field rows of the `.system` set are accessibility containers that hold the id. Query inputs with descendant queries.
- `FieldContext` has `testId` and `optionTestId(_:)`, and `ActionsContext` has `testIds`, for custom components.

## 0.1.4

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.1.1.
- Format 1.6: `"randomize": true` on a `radio`, `multiselect` or `select` field shows its options in a random order per respondent. Options with `"pinned": true` and exclusive options keep their written position.
- New `FormEngineOptions.seed` and `FormEngineOptions.research`. The same seed shows the same order. `engine.seed` returns it.
- New `engine.orderOptions(_:options:)` returns the options of a field in shown order.
- New `FormResearch` protocol for the option order.
- Without `research`, options show in written order, and debug builds report `missing-research` once per process through `onWarning`.
- `checkDefinition()` reports `randomize-not-applicable`, and `outdated-format-version` for `randomize` or `pinned` below format 1.6.

### FormhausResearch

- New product with `Research`, the option order of `@formhaus/core/research`. Pass `Research()` as `research` to apply it.

### FormhausUI

- Fields with `randomize` show their options in the order of `engine.orderOptions(_:options:)`, including options from a provider.

## 0.1.3

### FormhausCore

- Passes the conformance suite of `@formhaus/core` 1.0.0.

### FormhausUI

- The formhaus set colors the step title red and announces the error count when the current step has errors, as in the web renderers.
- `ProgressContext` has `errorCount` and `errorLabel` for the current step, independent of `stepErrorMarks`.
- The focused field keeps focus and the keyboard while a submit or async step validation runs. Text typed meanwhile applies once the form unlocks.
- Fixed the step counter and description clipping at the left edge in the system set on iOS.

## 0.1.2

### FormhausUI

- Switching from the system set to another set inside a `NavigationStack` shows Back only in the navigation bar.
- Focusing the error summary scrolls only as far as needed to show it, in every component set. A summary that is already on screen no longer moves the page.
- The formhaus set shows the error summary below the fields, before the actions, as in the web renderers.

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
