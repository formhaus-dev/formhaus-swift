import { CONTROLS, MIXES, PALETTE, RADII, SHADOW, SPACING, STEPS, TYPOGRAPHY } from './mapping.mjs';

const meta = (token) => token.original.$extensions?.['dev.formhaus'] ?? {};

export function color(value) {
  if (value?.colorSpace !== 'srgb' || !/^#[0-9a-f]{6}$/i.test(value.hex)) throw new Error(`unsupported color ${JSON.stringify(value)}`);
  const hex = `Color(hex: 0x${value.hex.slice(1).toUpperCase()}`;
  return value.alpha === undefined || value.alpha === 1 ? `${hex})` : `${hex}, opacity: ${value.alpha})`;
}

export function dimension(value) {
  if (value?.unit !== 'px' || typeof value.value !== 'number') throw new Error(`unsupported dimension ${JSON.stringify(value)}`);
  return String(value.value);
}

const literal = (token) => (token.$type === 'color' ? color(token.$value) : dimension(token.$value));

function lookup(context, name) {
  const token = context.get(name);
  if (!token) throw new Error(`missing token ${name}`);
  return token;
}

const values = (context, fields) => fields.map(([field, name]) => [field, literal(lookup(context, name))]);
const call = (type, fields) => `${type}(${fields.map(([field, value]) => `${field}: ${value}`).join(', ')})`;

function variant(type, name, base, fields) {
  const changed = fields.filter(([field, value]) => base.find(([other]) => other === field)[1] !== value);
  const variable = type.charAt(0).toLowerCase() + type.slice(1);
  const lines = changed.map(([field, value]) => `${variable}.${field} = ${value}`);
  return `static let ${name}: ${type} = {\nvar ${variable} = ${base.name}\n${lines.join('\n')}\nreturn ${variable}\n}()`;
}

function family(type, contexts, fields, [first, ...rest], access = '') {
  const base = Object.assign(values(contexts[first], fields), { name: first });
  return [
    `${access}static let ${first} = ${call(type, base)}`,
    ...rest.map((name) => variant(type, name, base, values(contexts[name], fields))),
  ];
}

function mixes(context) {
  const fields = MIXES.flatMap(([field, name, from, onto]) => {
    const { mix } = meta(lookup(context, name));
    if (!mix || mix.color !== from || (onto && mix.with !== onto)) throw new Error(`${name} is not a supported mix`);
    if (onto) return [[field, String(mix.amount)]];
    const partner = context.paths.get(mix.with.slice(1, -1));
    if (!partner) throw new Error(`missing token ${mix.with}`);
    return [
      [field, String(mix.amount)],
      [`${field}With`, color(partner.$value)],
    ];
  });
  return call('ColorMixes', fields);
}

function steps(contexts) {
  return STEPS.map(([field, name]) => {
    const amounts = ['fine', 'coarse'].map((key) => {
      const { add } = meta(lookup(contexts[key], name));
      if (add?.base !== '{font-size.default}') throw new Error(`${name} is not a supported add`);
      return dimension(add.amount);
    });
    if (amounts[0] !== amounts[1]) throw new Error(`${name} adds a different amount per pointer`);
    return `static let ${field}: CGFloat = ${amounts[0]}`;
  });
}

function shadow(context) {
  const token = lookup(context, SHADOW);
  const { offsetX, offsetY, blur, spread } = token.$value;
  if (token.original.$value.color !== '{color.shadow}' || dimension(spread) !== '0') throw new Error(`${SHADOW} is not supported`);
  return [`static let x: CGFloat = ${dimension(offsetX)}`, `static let y: CGFloat = ${dimension(offsetY)}`, `static let blur: CGFloat = ${dimension(blur)}`];
}

const block = (head, lines) => `${head} {\n${lines.join('\n')}\n}`;

export function swiftSource(contexts) {
  return [
    'import SwiftUI',
    block('extension Palette', [
      ...family('Palette', contexts, PALETTE, ['light', 'lightIncreased'], 'public '),
      ...family('Palette', contexts, PALETTE, ['dark', 'darkIncreased'], 'public '),
    ]),
    block('extension ColorMixes', [
      `static let light = ${mixes(contexts.light)}`,
      `static let dark = ${mixes(contexts.dark)}`,
    ]),
    block('extension Typography', [...steps(contexts), ...family('Typography', contexts, TYPOGRAPHY, ['fine', 'coarse'])]),
    block('extension Spacing', family('Spacing', contexts, SPACING, ['regular', 'compact'])),
    block('extension Radii', family('Radii', contexts, RADII, ['standard'])),
    block('extension Controls', family('Controls', contexts, CONTROLS, ['fine', 'coarse'])),
    block('enum RaisedShadow', shadow(contexts.light)),
  ].join('\n\n') + '\n';
}
