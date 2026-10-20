import { fieldByKey } from './definitions.mjs';

const q = JSON.stringify;

export const editLines = (definition, edit) => {
  const field = fieldByKey(definition, edit.field);
  const [list, index, property] = edit.property.split('.');
  const condition = field[list][Number(index)];
  const rest = Object.entries(condition)
    .filter(([name]) => name !== property)
    .map(([name, value]) => `${q(name)}: ${q(value)}, `)
    .join('');
  return {
    key: `"key": ${q(field.key)},`,
    prefix: `${q(list)}: [{ ${rest}${q(property)}: `,
    before: q(condition[property]),
    after: q(edit.value),
    suffix: ' }]',
  };
};
