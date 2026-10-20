# Formhaus design tokens

The source of every `--fh-*` custom property in `style.css`, in the [W3C Design Tokens Format](https://www.designtokens.org/tr/2025.10/) (2025.10). Native ports read these files from the npm package (`@formhaus/core/tokens/*`) or from the release tag.

## Files

| File | Layer | Contents |
|---|---|---|
| `primitive.tokens.json` | primitive | `palette.*` colors and the `size.*` scale. Not emitted as CSS variables. |
| `semantic.tokens.json` | semantic | Values that are the same in every mode: `space.*`, `gap`, `radius`, `control.height`, `shadow.raised`, `color.border.focus` |
| `component.tokens.json` | component | `input.padding`, `icon-button.size`, `option-image.width`, `option-card.border`, `option-card.border-hover` |
| `modes/theme-light.tokens.json`, `modes/theme-dark.tokens.json` | semantic | All `color.*` tokens per theme |
| `modes/pointer-fine.tokens.json`, `modes/pointer-coarse.tokens.json` | semantic, component | `font-size.*`, `star.size` |
| `modes/width-regular.tokens.json`, `modes/width-compact.tokens.json` | component | `card.padding` |
| `modes/contrast-standard.tokens.json`, `modes/contrast-more.tokens.json` | semantic | Input and border overrides for increased contrast |
| `formhaus.resolver.json` | | The sets, modifiers and resolution order |

Semantic and component tokens alias primitives (`{palette.zinc.450}`, `{size.10}`) or other semantic tokens (`{color.input.border}`).

## Modes

`formhaus.resolver.json` follows the DTCG resolver module. It has one set, `foundation` (the three layer files), and four modifiers. Pick one context per modifier, then merge the files in `resolutionOrder`: foundation, theme, pointer, width, contrast. The last file that defines a token wins, and aliases resolve after the merge.

| Modifier | Contexts (default first) | Web condition |
|---|---|---|
| `theme` | `light`, `dark` | `data-fh-theme="dark"` on the form or an ancestor |
| `pointer` | `fine`, `coarse` | `@media (pointer: coarse)` |
| `width` | `regular`, `compact` | `@media (max-width: 480px)` |
| `contrast` | `standard`, `more` | `@media (prefers-contrast: more)` |

Contexts combine freely, for example `{ "theme": "dark", "pointer": "coarse", "contrast": "more" }`. `contrast.more` only aliases semantic colors, so it gives dark values under `theme.dark`. A color that needs its own value under increased contrast gets a second token in each theme file, and `contrast.more` points at it: `color.input.border` becomes `{color.input.border-strong}`.

Forced colors and reduced motion have no token values. The stylesheet switches to system colors under `forced-colors: active` and turns transitions off under `prefers-reduced-motion: reduce`. Ports use the platform equivalents.

## Values

- Colors are objects with `colorSpace: "srgb"`, `components` in 0 to 1, an optional `alpha` and `hex`. `hex` is exact; `components` are rounded to 4 decimals. The build checks that they agree.
- Dimensions are objects with `value` and `unit` (`px`). Ports read `px` as points (iOS) or dp (Android).
- `shadow.raised` is a DTCG shadow.

## CSS names

The CSS name is `--fh-` plus the token path joined with `-`, without `default` segments: `color.text.default` is `--fh-color-text`, `color.input.border-hover` is `--fh-color-input-border-hover`, `space.4` is `--fh-space-4`.

## Extensions

Tokens can carry `$extensions["dev.formhaus"]`:

| Key | Meaning |
|---|---|
| `mix` | The token is a mix of two colors. See below. |
| `add` | The token is `base + amount`. `font-size.heading` is `{font-size.default}` + 2px, `font-size.title` + 5px. |
| `fallback` | CSS value for browsers without `color-mix()`. Ports ignore it. |
| `auto` | The CSS variable is set on standalone forms only. Inside `.fh-cloud` the stylesheet reads `--fhi-auto-<name>` as the fallback. |
| `shorthand` | On a group: the child tokens are written as one CSS value in this order. `input.padding` is `block inline`. |

The `$value` of a derived token is the result of its rule in that mode. The build fails if it does not match.

### Color mix rule

`mix: { color, with, amount }` gives, for each of the red, green and blue channels in gamma-encoded sRGB, scaled 0 to 1:

```
result = color × amount + with × (1 − amount)
```

Both inputs are opaque. Resolve `color` and `with` in the current mode first. The 8-bit channel is `round(result × 255)`. This is what browsers compute for `color-mix(in srgb, <color> <amount × 100>%, <with>)`.

| Token | `color` | `with` | `amount` | Light | Dark |
|---|---|---|---|---|---|
| `color.primary.hover` | `color.primary.default` | black (light), white (dark) | 0.82 (light), 0.85 (dark) | `#4602ce` | `#9068ff` |
| `color.primary.soft` | `color.primary.default` | `color.bg.default` | 0.09 | `#f0e8ff` | `#211d30` |
| `color.error.soft` | `color.error.default` | `color.bg.default` | 0.08 | `#faefee` | `#291f22` |

In CSS these tokens are `color-mix()` expressions on the variables, so overriding `--fh-color-primary`, `--fh-color-error` or `--fh-color-bg` also changes them. Ports recompute the rule when the app overrides a base color.

## Input border contrast

`color.input.border` marks text inputs, textarea, select, date and time, file fields, scale boxes and the switch track, whose fill is the page color. By default it is a soft slate tint at about 2:1 against `color.bg.default`, and the hover border is about 3:1. Under `contrast.more` both alias `color.input.border-strong` and `color.input.border-strong-hover`, which are at least 3:1 (WCAG 1.4.11).

| | Light on `#ffffff` | Dark on `#18181c` |
|---|---|---|
| `color.input.border` | `#b1b8c2`, 2.00:1 | `#444b53`, 2.00:1 |
| `color.input.border-hover` | `#8e959f`, 3.02:1 | `#5e656d`, 3.00:1 |
| `color.input.border-strong` | `#84848d`, 3.71:1 | `#73737d`, 3.77:1 |
| `color.input.border-strong-hover` | `#5f5f68`, 6.32:1 | `#9a9aa5`, 6.36:1 |

Radio and multiselect option cards, including picture cards, use it through `option-card.border` and `option-card.border-hover`. Group cards, dividers, matrix rows, the picture Enlarge button and dialogs keep `color.border.default`.

## Build

```sh
pnpm -C packages/core tokens          # rewrite the token blocks in style.css
pnpm -C packages/core tokens --check  # fail if style.css is out of date
```

The build runs Style Dictionary (`style-dictionary.config.mjs`) once per context and writes only the part of `style.css` between the `fh-tokens:start` and `fh-tokens:end` markers. The rest of `style.css` is written by hand.
