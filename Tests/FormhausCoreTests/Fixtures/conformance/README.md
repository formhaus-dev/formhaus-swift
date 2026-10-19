# Definition corpus

Each file holds one `definition`, the issues `checkDefinition` reports for it, and value cases. The TypeScript runner is `packages/core/__tests__/conformance/conformance.test.ts`; any other implementation runs the same files. Engine action scripts are in `scenarios/`.

```json
{
  "name": "check-field-rules",
  "covers": ["rejects impossible ranges"],
  "issues": [{ "code": "invalid-range", "path": "/fields/1/validation/minLength" }],
  "warnings": [{ "code": "rule-not-applicable", "path": "/fields/3/validation/min" }],
  "definition": { "id": "f", "title": "F", "submit": { "label": "Submit" }, "fields": [] },
  "cases": []
}
```

## Fields

- `name` is the file name without `.json`. Files named `check-*` test definition checks: their definitions may use unusual shapes, such as `null` lists or escaped keys, and are not meant as example forms.
- `covers` lists the titles of the TypeScript tests the file replaced. Runners ignore it.
- `definition` is the form definition. It may be malformed.
- `issues` lists the issues with severity `error` that `checkDefinition` reports, as `{ code, path }`. Use `[]` for none.
- `warnings` lists the issues with severity `warning`, as `{ code, path }`. When the key is missing, warnings are not checked. `[]` means there must be none.
- `overlay` is an optional i18n overlay. Apply it to the definition with `localize` before running `cases`, as described in the specification under Translations.
- `texts` maps text slot addresses to the text they hold after the overlay is applied, such as `"steps.account.fields.email.label": "Почта"`. Addresses are those of the specification under Translations, Addresses. Only the listed addresses are checked; an address with no text slot fails.
- `cases` lists value cases. It may be empty or missing.

## Checks

1. `issues`: take the `error` issues from `checkDefinition(definition)`. Compare their `code` and `path` with `issues`. Other fields of an issue (`message`, `hint`) are not part of the corpus.
2. `warnings`: if set, take the `warning` issues and compare them the same way.
3. Both lists are compared as lists of entries after sorting by `path` and then by `code`, with plain code-unit string order. An entry may appear more than once, and the count must match. The order in the file does not matter.
4. If `issues` is not empty, creating the engine with no values and running the server validation with `{}` must both fail with a definition error.

The checks run on the definition as written, without `overlay`. A structural error (wrong type, missing required property) stops the checks below it in the same node, so a condition without `field` reports only `missing-property`.
5. `texts`: if set, apply `overlay` to the definition, list its text slots, and compare the text at each listed address.
6. If `issues` is empty, run each case.

## Cases

A case has `name`, `input` (`values` and `skippedSteps`), `expected` (`values` and `errors`) and `canSubmit`.

- Server: validating `input.values` with `input.skippedSteps` returns `expected`. The returned values are a plain object.
- Browser engine: creating the engine with `input.values`, then `validate()` returns `expected.errors`, and the submit values equal `expected.values`. `canSubmit` says whether stepping through every step and submitting is allowed.
- A payload the browser accepts passes server validation without errors.

## Versions

The corpus and the scenarios change with `@formhaus/core`. An implementation pins them to a release tag of this repository, such as `@formhaus/core@0.18.0`, and states which tag it passes.

## Not covered

The corpus does not check issue messages, hints, fixes, translation checks, the translate function, the JSON Schema or the order of issues. These stay in the TypeScript tests.
