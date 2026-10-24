#!/usr/bin/env node
import { createWriteStream } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const [corePath, output, countText = '50000', seedText = '20261025'] = process.argv.slice(2)
if (!corePath || !output) {
  console.error('usage: reveal-fuzz.mjs <@formhaus/core entry> <output.jsonl> [count] [seed]')
  process.exit(1)
}

const { revealTargets } = await import(pathToFileURL(resolve(corePath)).href)
let state = Number(seedText) >>> 0

function random() {
  state = (state + 0x6d2b79f5) >>> 0
  let t = state
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

const chance = (p) => random() < p
const int = (n) => Math.floor(random() * n)
const pick = (list) => list[int(list.length)]

const raw = (text) => ({ raw: text })
const values = ['a', 'b', 'c', 'd', '1', '', 'é', 'é', 1, 2, 0, true, false, raw('1.0'), raw('1e0'), raw('-0'), raw('0.0'), raw('2.00')]
const operands = [...values, null, ['a'], { a: 1 }, 'zz', 3]
const operators = ['eq', 'eq', 'eq', 'contains', 'contains', 'contains', 'neq', 'in', 'notContains', 'notEmpty', 'gt']
const childTypes = ['text', 'text', 'email', 'textarea', 'number', 'hidden', 'radio', 'multiselect', 'select', 'checkbox', 'group', 'section']

function emit(value) {
  if (value && typeof value === 'object' && 'raw' in value && Object.keys(value).length === 1) return value.raw
  if (Array.isArray(value)) return `[${value.map(emit).join(',')}]`
  if (value && typeof value === 'object')
    return `{${Object.entries(value)
      .filter(([, item]) => item !== undefined)
      .map(([key, item]) => `${JSON.stringify(key)}:${emit(item)}`)
      .join(',')}}`
  return JSON.stringify(value)
}

function option(index) {
  const result = { value: chance(0.5) ? pick(['a', 'b', 'c', 'd']) : pick(values), label: `o${index}` }
  if (chance(0.04)) result.image = pick(['x.png', '', true, 0, 1, null])
  if (chance(0.05)) result.exclusive = true
  if (chance(0.02)) result.value = null
  if (chance(0.02)) delete result.value
  return chance(0.01) ? pick(['a', 1]) : result
}

function choice(key) {
  const result = { key, type: chance(0.5) ? 'radio' : 'multiselect', label: key }
  if (!chance(0.04)) result.options = Array.from({ length: int(5) }, (_, index) => option(index))
  else if (chance(0.5)) result.options = []
  if (chance(0.05)) result.optionsFrom = pick(['', 'source', null, 0, { url: 'x' }])
  if (chance(0.08)) result.layout = pick(['inline', 'grid', 'cards', null])
  if (chance(0.25)) result.randomize = pick([true, true, false, 1, 0, ''])
  if (chance(0.03)) result.type = pick(['select', 'checkbox', 'Radio'])
  return result
}

function condition(parents) {
  const parent = parents.length && chance(0.9) ? pick(parents) : null
  const field = parent ? parent.key : pick(['k0', 'k1', 'missing'])
  const result = { field }
  const operator = parent && chance(0.8) ? (parent.type === 'multiselect' ? 'contains' : 'eq') : pick(operators)
  const known = parent?.options?.length && chance(0.85) ? parent.options[int(parent.options.length)].value : pick(operands)
  result[operator] = operator === 'in' ? [known] : operator === 'notEmpty' ? true : known
  if (chance(0.06)) result[pick(operators)] = pick(operands)
  if (chance(0.03)) result.eq = null
  return result
}

function child(key, parents, depth) {
  const type = pick(childTypes)
  const result =
    type === 'radio' || type === 'multiselect' ? choice(key) : { key, type: type === 'section' && depth > 1 ? 'text' : type, label: key }
  if (result.type === 'section') {
    result.title = key
    delete result.label
    if (chance(0.15)) result.layout = 'matrix'
    result.fields = nodes(`${key}_`, depth + 1)
  }
  if (result.type === 'group') result.fields = [{ key: `${key}_i`, type: 'text', label: 'i' }]
  const count = chance(0.8) ? 1 : int(3)
  const conditions = Array.from({ length: count }, () => condition(parents))
  if (count === 0) return result
  if (chance(0.15)) {
    const split = int(conditions.length + 1)
    if (split > 0) result.show = conditions.slice(0, split)
    if (split < conditions.length) result.showAny = conditions.slice(split)
    if (chance(0.1)) result.show = result.show ?? []
  } else if (chance(0.75)) result.show = conditions
  else result.showAny = conditions
  return result
}

function nodes(prefix, depth) {
  const list = []
  const parents = []
  const length = int(depth > 1 ? 7 : 13)
  for (let index = 0; index < length; index++) {
    const key = chance(0.04) && list.length ? pick(list).key : `${prefix}k${index}`
    let node
    if (chance(0.25)) {
      node = choice(key)
      if (chance(0.5) && parents.length) node.show = [condition(parents)]
    } else if (chance(0.15)) node = { key, type: 'text', label: key }
    else node = child(key, parents, depth)
    list.push(node)
    if (node.type !== 'radio' && node.type !== 'multiselect') continue
    parents.push(node)
    if (parents.length > 3) parents.shift()
    if (!chance(0.6)) continue
    for (let run = 1 + int(4); run > 0 && index < length; run--) {
      index++
      const item = chance(0.7) ? { key: `${prefix}k${index}`, type: 'text', label: 'r' } : child(`${prefix}k${index}`, [node], depth)
      if (item.type === 'radio' || item.type === 'multiselect') parents.push(item)
      if (!item.show && !item.showAny) item.show = [condition([node])]
      list.push(item)
    }
  }
  return list
}

function definition() {
  const result = { formatVersion: '1.6', id: 'fuzz', title: 'Fuzz', submit: { label: 'Submit' } }
  const shape = int(10)
  if (shape < 4) result.fields = nodes('', 1)
  else if (shape < 9) result.steps = Array.from({ length: 1 + int(3) }, (_, index) => ({ id: `s${index}`, title: 'S', fields: nodes(`s${index}`, 1) }))
  else {
    result.steps = chance(0.5) ? [] : [{ id: 's0', title: 'S', fields: nodes('s0', 1) }]
    result.fields = nodes('', 1)
  }
  return result
}

const isSection = (node) => node.type === 'section'

function pointers(parsed) {
  const tops = parsed.steps?.length
    ? parsed.steps.map((step, index) => [`/steps/${index}/fields`, step.fields])
    : [['/fields', parsed.fields ?? []]]
  const lists = tops.flatMap(([path, list]) => [
    [path, list],
    ...list.flatMap((node, index) => (isSection(node) && node.layout !== 'matrix' ? [[`${path}/${index}/fields`, node.fields]] : [])),
  ])
  const found = {}
  for (const [path, list] of lists)
    revealTargets(list).forEach((target, index) => {
      if (target) found[`${path}/${index}`] = { parent: `${path}/${target.parent}`, option: target.option }
    })
  return found
}

const count = Number(countText)
const stream = createWriteStream(output)
let revealed = 0
let nested = 0
for (let index = 0; index < count; index++) {
  const text = emit(definition())
  const reveals = pointers(JSON.parse(text))
  const entries = Object.values(reveals)
  revealed += entries.length
  if (entries.some(({ parent }) => parent in reveals)) nested++
  if (!stream.write(`{"definition":${text},"reveals":${JSON.stringify(reveals)}}\n`))
    await new Promise((done) => stream.once('drain', done))
}
stream.end()
console.error(`${count} definitions, ${revealed} revealed nodes, ${nested} with nested reveals`)
