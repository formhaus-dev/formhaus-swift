# Engine scenarios

Each file holds a `definition` and a list of scenarios that drive `FormEngine` through its public API. `scenario.schema.json` describes the shape. The TypeScript runner is `packages/core/__tests__/conformance/scenarios.ts`; any other engine implementation runs the same files.

```json
{
  "name": "publishes validating state during the request",
  "values": { "name": "John" },
  "hooks": { "onStepValidate": [{ "defer": "check", "return": null }] },
  "steps": [
    { "do": "next", "await": false, "returns": true },
    { "expect": { "stepValidating": true, "step": "personal" } },
    { "do": "resolve", "deferred": "check" },
    { "do": "settle" },
    { "expect": { "stepValidating": false, "step": "payment" } }
  ]
}
```

## Running a scenario

1. Take the scenario's own `definition` if it has one, and the file's `definition` otherwise. Apply the file's `overlay` to it, if set. Create the engine with `values` and the options the scenario lists.
2. If `throws` is set, the constructor must throw an error with that name. Such a scenario has no steps and no options.
3. Run `steps` in order. An action step calls the engine method named in `do` and awaits it. `returns` is compared with the result. `throws` is compared with the `name` of the error the action throws or rejects with, and with its `phase` and `message` if the expectation lists them.
4. With `"await": false`, the action starts, the runner waits one macrotask, and moves on. `settle` awaits every started action and checks its `returns` or `throws`. Outside JavaScript, waiting one macrotask means letting every started action run until it finishes or waits on an unresolved `defer` reply.
5. An `expect` step reads only the properties it lists. All other state is not checked. `items` counts the items of each listed group, and `distinctItemIds` counts the different `id` values among them.
6. At the end, the scenario fails if an action started with `"await": false` is still pending or a `defer` reply was never resolved. An awaited action or `settle` that waits on a reply no later step resolves fails too. Unused replies are not an error.

## Hooks and validators

- `hooks` installs only the listed hooks. Each call takes the next reply from its list. An exhausted list replies with nothing (`undefined`).
- A reply returns `return`, or throws an `Error` with the message `throw`, synchronously. The thrown error has the name `Error`. A reply with `defer` returns a promise instead, and each `defer` name appears once in a scenario. It stays pending until a `resolve` step names it, and then resolves with `return` or rejects with `throw`. After `resolve`, the runner waits one macrotask. Resolving an unknown or already resolved name is an error.
- `onStepValidate` always returns a promise of its reply.
- Only a `false` reply from `onBeforeStepChange` or `onBeforeSubmit` cancels. Any other reply, such as `null`, `0` or nothing, lets the action continue.
- `submit` always passes a handler, which takes its replies from the action's `handler` list. `skip` passes a handler only when the action has a `handler` key, so on the last step `"handler": []` submits and a missing `handler` does not.
- `validators` maps a validator name to a list of values it rejects with `error`. Values are compared as JSON.
- `messages` is a message catalog.

## The log

The runner records, in order:

- `{ "event": FormEvent }` for every `onFormEvent` call. The handler is always installed.
- `{ "warning": { "code", "path" } }` for every `onWarning` call. Without `onWarning`, an implementation reports warnings to its platform log, which scenarios do not check.
- `{ "call": "<hook>", ... }` for every installed hook and handler call, with its arguments: `context` for step hooks, `values` and `skippedSteps` for submit hooks and handlers, `stepId` and `values` for `onStepValidate`.

Every `expect` step clears the log. `"log": [...]` compares the entries recorded since the previous `expect`. Entries recorded after the last `expect` are not checked.

## Comparison

Values are arbitrary JSON, whatever the field type: a scenario may put a number or an array in a `text` field to test conditions and validation on unexpected input. An implementation must keep such values as given.

Actual and expected values are compared as JSON, with object keys in any order. A property with value `undefined` counts as absent, and a top-level `undefined` counts as `null`.

## Not covered

Scenarios do not cover:

- hooks that call back into the engine;
- `subscribe` listeners and snapshot counters;
- options changed after construction;
- DOM focus and renderer behaviour;
- field keys that look like array indexes, such as `"1"`, which JavaScript lists before other keys;
- whether a write of an equal but new array or object counts as a change. The TypeScript engine compares such values by reference.

These stay in the TypeScript tests.
