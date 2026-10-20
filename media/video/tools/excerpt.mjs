import { fieldByKey } from './definitions.mjs';

const q = JSON.stringify;

export const editLines = (definition, edit, before, after) => {
  const field = fieldByKey(definition, edit.field);
  const [, , property] = edit.property.split('.');
  const list = (values) => `[${values.map((value) => q(value)).join(', ')}]`;
  const prefix = `"show": [{ …, ${q(property)}: `;
  return { key: `"key": ${q(field.key)},`, prefix, before: list(before), after: list(after), suffix: ' }],' };
};
