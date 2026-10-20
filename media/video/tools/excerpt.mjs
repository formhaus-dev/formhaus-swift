const q = JSON.stringify;
const inline = (value) =>
  q(value).replace(/":/g, '": ').replace(/,"/g, ', "').replace(/\{"/g, '{ "').replace(/"\}/g, '" }');

export const editLines = (definition, edit) => {
  const step = definition.steps.find((item) => item.id === edit.step);
  const [list, index, property] = edit.property.split('.');
  const entry = step[list][Number(index)];
  const rest = Object.entries(entry).filter(([name]) => name !== property);
  return {
    open: `${q(list)}: [{`,
    key: `  ${q(property)}: `,
    before: q(entry[property]),
    after: q(edit.value),
    rest: rest.map(([name, value]) => `  ${q(name)}: ${inline(value)}`),
    close: '}]',
  };
};
