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
5. `texts`: if set, apply `overlay` to the definition, list its text slots, and compare the text at each listed address. Do this even when step 1 rejected the definition: text slots do not depend on validation.
6. If `issues` is empty, run each case.

## Cases

A case has `name`, `input` (`values` and `skippedSteps`), `expected` (`values` and `errors`), `canSubmit` and an optional `serverValues`.

- Server: validating `input.values` with `input.skippedSteps` returns `expected`. The returned values are a plain object.
- Browser engine: creating the engine with `input.values`, then `validate()` returns `expected.errors`, and the submit values equal `expected.values`. `canSubmit` says whether stepping through every step and submitting is allowed: on each step before the last, `next.disabled` does not match the submit values and `next()` succeeds; on the last, `validate()` returns no errors and `submit.disabled` does not match.
- A payload the browser accepts passes server validation without errors.
- `serverValues` is optional. When set, the server returns it in place of `expected.values`. The server drops an invalid group item value, and the browser engine keeps it.

## Semantics

The corpus and the scenarios assume the ECMAScript semantics of the TypeScript implementation. A port matches these even where its language differs:

- Strings are sequences of UTF-16 code units. `minLength`, `maxLength` and the character caps count code units. Keys, `eq`, option membership and sorting compare code units, without Unicode normalization, so `"café"` and `"cafe\u0301"` are different keys.
- `pattern` is an ECMAScript regular expression compiled with `new RegExp(pattern)` and no flags. Without the `u` flag, `.` and character classes match one code unit, and Annex B syntax such as `\8`, `a{` or `]` is valid. Any other dialect accepts or rejects different patterns.
- Trimming removes the ECMAScript whitespace set of `String.prototype.trim`, which includes U+FEFF and excludes U+200B.
- Numeric conditions convert strings with `Number()`. It accepts surrounding whitespace, hexadecimal and `Infinity`, and rejects `1_0`.
- `pattern` tests non-string values through `String(value)`. Message parameters are formatted like JavaScript numbers, so `5` and not `5.0`.
- Properties such as `skip`, `optionsFrom` and a string `required` follow JavaScript truthiness: `"skip": "x"` is set and `"required": ""` is not.
- `matchField` compares arrays and objects by reference, so two such values never match.
- `reserved-key` covers the own property names of `Object.prototype` and `prototype`: `__defineGetter__`, `__defineSetter__`, `__lookupGetter__`, `__lookupSetter__`, `__proto__`, `constructor`, `hasOwnProperty`, `isPrototypeOf`, `propertyIsEnumerable`, `prototype`, `toLocaleString`, `toString` and `valueOf`.

## Versions

The corpus and the scenarios change with `@formhaus/core`. An implementation pins them to a release tag of this repository, such as `@formhaus/core@0.18.0`, and states which tag it passes.

## Not covered

The corpus does not check issue messages, hints, fixes, translation checks, the translate function, the JSON Schema or the order of issues. These stay in the TypeScript tests.
