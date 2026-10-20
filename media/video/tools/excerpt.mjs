import { fieldByKey } from './definitions.mjs';

const q = JSON.stringify;

export const editLines = (definition, edit, before, after) => {
  const field = fieldByKey(definition, edit.field);
  const [, index, property] = edit.property.split('.');
  const condition = field.show[Number(index)];
  const rest = Object.entries(condition)
    .filter(([name]) => name !== property)
    .map(([name, value]) => `${q(name)}: ${q(value)}`)
    .join(', ');
  const list = (values) => `[${values.map((value) => q(value)).join(', ')}]`;
  const prefix = `"show": [{ ${rest}, ${q(property)}: `;
  return { key: `"key": ${q(field.key)},`, prefix, before: list(before), after: list(after), suffix: ' }],' };
};
