import { fieldByKey } from './definitions.mjs';

const q = JSON.stringify;
const inline = (value) => q(value).replace(/([,:{])/g, '$1 ').replace(/\}/g, ' }').replace(/"\s*:\s+/g, '": ');

export const excerpt = (definition, key) => {
  const step = definition.steps.find((item) => item.fields.some((field) => field.key === key));
  const field = fieldByKey(definition, key);
  const options = field.options.map((option, index) => {
    const image = option.image ? ', "image": "data:…"' : '';
    const comma = index < field.options.length - 1 ? ',' : '';
    return { text: `        { "value": ${q(option.value)}, "label": ${q(option.label)}${image} }${comma}`, target: `option:${index}` };
  });
  return [
    { text: '{' },
    { text: `  "title": ${q(definition.title)},`, target: 'title' },
    { text: `  "description": ${q(definition.description)},`, target: 'description' },
    { text: '  "steps": [{' },
    { text: `    "title": ${q(step.title)},`, target: 'step' },
    { text: '    "fields": [{' },
    { text: `      "key": ${q(field.key)},` },
    { text: `      "type": ${q(field.type)},` },
    { text: `      "label": ${q(field.label)},`, target: 'label' },
    { text: '      "options": [' },
    ...options,
    { text: '      ],' },
    { text: `      "validation": ${inline(field.validation)}`, target: 'actions' },
    { text: '    }]' },
    { text: '  }]' },
    { text: '}' },
  ];
};

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
