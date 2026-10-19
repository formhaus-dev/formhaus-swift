#!/usr/bin/env node
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const output = join(root, 'Tests/FormhausCoreTests/Fixtures/regex/cases.json')
const seed = Number(process.env.REGEX_SEED ?? 20261019)
const fuzzPatterns = Number(process.env.REGEX_FUZZ ?? 1500)
const inputsPerPattern = 4
const inputLength = Number(process.env.REGEX_INPUT ?? 9)

const words = ['', 'a', 'A', 'aa', 'ab', 'abc', 'aab', 'abab', 'ba', 'b\na', 'a\rb', '\u2028', 'x y', '1', '123', 'a_1',
  '-', '.', 'é', 'É', 'ß', 'ſ', 'K', '\u212a', 'é', '😀', '😀😁', 'a😀b', '\u0000', '\u0008', '\t', '\u00a0', '\ufeff',
  '\u3000', 'k', '\\', '\\c', 'aaaa', 'abcabc', '{', '}', ']', 'a{', 'a{1', 'ı', 'İ']

const curated = [
  ['', words],
  ['^[\\w-.]+$', ['a.b-c', 'a b', '-', '']],
  ['(?<=a+)b', ['aab', 'b', 'ab']],
  ['^\\1$', ['\u0001', '1', '']],
  ['^\\8$', ['8', '\\8']],
  ['^\\9\\8$', ['98']],
  ['^\\101$', ['A', 'e']],
  ['^\\k$', ['k', '\\k']],
  ['^\\01$', ['\u0001']],
  ['^\\0$', ['\u0000', '0']],
  ['^\\08$', ['\u00008']],
  ['^\\377$', ['\u00ff']],
  ['^\\400$', ['\u00200', ' 0']],
  ['^\\18$', ['\u00018']],
  ['(a)\\18', ['a\u00018', 'aa8']],
  ['(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\\10', ['abcdefghijj', 'abcdefghija0']],
  ['(a)\\10', ['a\u0008', 'aa0']],
  ['^[\u093e\u093f\u0940\u0941]+$', ['\u093e\u093f', '\u093e\u0915']],
  ['^.{1,3}$', ['😀😀', '😀', 'abc', 'abcd']],
  ['^[:digit:]$', ['5', ':', 'd']],
  ['a++', ['a']], ['a**', ['a']], ['a{1}+', ['a']], ['*a', ['a']], ['+', ['+']], ['?', ['']],
  ['(?i)abc', ['ABC']], ['(?i:abc)', ['ABC', 'abc', 'aBc', 'abd']], ['(?i-:a)', ['A']], ['(?-:a)', ['a']],
  ['(?ii:a)', ['a']], ['(?i-i:a)', ['a']], ['(?im-s:^a.)', ['b\nA\n', 'b\nAx']], ['(?s:.)', ['\n', '\u2028']],
  ['(?m:^b$)', ['a\nb\nc', 'ab']], ['(?i:[a-z]+)', ['ABC', '123']], ['(?i:[^a])', ['A', 'a', 'b']],
  ['(?i:\\W)', ['k', '\u212a', ' ']], ['(?i:ſ)', ['s', 'S', 'ſ']], ['(?i:ß)', ['SS', 'ß', 'ẞ']], ['(?i:\u212a)', ['k', 'K']],
  ['(?i:k)', ['\u212a', 'K']], ['(?i:ı)', ['i', 'I']], ['(?i:İ)', ['i', 'I']], ['(?i:é)', ['É']], ['(?i:µ)', ['Μ', 'μ']],
  ['(?i:(a)\\1)', ['aA', 'ab']], ['(a)(?i:\\1)', ['aA']], ['(?i:\\b)', ['a']],
  ['[😀-😂]', ['😁']], ['[😀]', ['😀']], ['^[😀]$', ['😀']], ['^[😀]{2}$', ['😀']], ['😀+', ['😀😀']], ['^.$', ['😀', 'a']],
  ['(?=a)*a', ['a', 'b']], ['(?=a)+', ['a', 'b']], ['(?!a)?b', ['b']], ['(?=a){2}a', ['a']], ['(?:(?=a)){2}', ['a', 'b']],
  ['(?<=a)*', ['a']], ['(?<!a)+', ['a']], ['^*', ['']], ['$+', ['']], ['\\b*', ['']], ['\\B{2}', ['']],
  ['^\\d+$', ['123', '123\n', '\u0663', '']], ['^\\w$', ['é', '_', 'a']], ['^\\s+$', [' \t\n\r\u000b\f\u00a0\ufeff\u2028\u2029\u1680\u2000\u200a\u202f\u205f\u3000', '\u180e', '\u200b']],
  ['^a{$', ['a{']], ['^a{1$', ['a{1']], ['^a{1,$', ['a{1,']], ['^a{,5}$', ['a{,5}']], ['^x{2}{$', ['xx{']], ['x{2}{3}', ['xx']],
  ['{1}', ['{1}']], ['a|{1}', ['']], ['{', ['{']], ['}', ['}']], [']', [']']], ['a]', ['a]']], ['{}', ['{}']], ['{1,2', ['{1,2']],
  ['a{3,2}', ['a']], ['a{2,2}', ['aa', 'a']], ['a{0}', ['', 'b']], ['^a{0}$', ['', 'a']], ['a{99999999999,99999999998}', ['a']],
  ['^a{2147483648}$', ['a']], ['^a{0,99999999999}$', ['aaaa']], ['^(?:a{2}){2}$', ['aaaa', 'aaa']],
  ['^[^]$', ['\n', 'a', '']], ['^[]$', ['', 'a']], ['[]', ['a']], ['^.$', ['\n', '\r', '\u2028', '\u2029', '\u0085']],
  ['^\\a$', ['a']], ['^\\e\\g\\h$', ['egh']], ['^\\p{L}$', ['p{L}', 'a']], ['^\\P$', ['P']], ['^\\-$', ['-']], ['^\\/$', ['/']],
  ['[(a+)]+', ['+', 'x']], ['[invalid(', ['x']], ['(a', ['a']], ['a)', ['a)']], [')', [')']], ['\\', ['\\']], ['[a', ['a']],
  ['[\\]', [']']], ['[\\]]', [']']], ['[]]', [']']], ['[a-]', ['-', 'a']], ['[-a]', ['-']], ['[--a]', ['0']], ['[a-z-0]', ['-', '0', '5']],
  ['[z-a]', ['a']], ['[a-a]', ['a']], ['[\\d-a]', ['-', '5', 'b']], ['[a-\\d]', ['b', '-']], ['[\\w-.]', ['.', '-', ',']],
  ['[\\s-\\d]', ['-', ' ']], ['[%-\\w]', ['%', '&']], ['[\\b]', ['\u0008', 'b']], ['[\\B]', ['B']], ['[\\-]', ['-']],
  ['\\c1', ['\\c1']], ['[\\c1]', ['\u0011']], ['[\\c_]', ['\u001f']], ['[\\c*]', ['\\', 'c', '*']], ['\\c', ['\\c']],
  ['\\cA', ['\u0001']], ['\\ca', ['\u0001']], ['\\cz\\cZ', ['\u001a\u001a']], ['\\c0', ['\\c0']], ['[\\c]', ['\\', 'c']],
  ['^\\c$', ['\\c']], ['\\c$', ['\\c']], ['[\\cA]', ['\u0001']],
  ['\\x41', ['A']], ['\\x4', ['x4']], ['\\xZZ', ['xZZ']], ['\\u0041', ['A']], ['\\u004', ['u004']], ['^\\u{41}$', ['u'.repeat(41), 'A']],
  ['\\uD83D\\uDE00', ['😀']], ['^[\\uD83D\\uDE00]$', ['😀']], ['[\\u0041-\\u005A]', ['M', 'm']], ['[\\x00-\\x1f]', ['\t']],
  ['\\k<a>(?<a>b)', ['b']], ['(?<a>.)\\k<a>', ['xx', 'xy']], ['(?<a>.)\\k', ['xk']], ['(?<a>.)[\\k]', ['xk']], ['[\\k]', ['k']],
  ['(?<a>.)\\k<b>', ['aa']], ['(?<a>.)\\k<a', ['aa']], ['\\k<a>', ['k<a>']], ['(?<a>x)|(?<a>y)', ['y', 'x', 'z']],
  ['(?<a>x)(?<a>y)', ['xy']], ['(?:(?<a>x)|(?<a>y))\\k<a>', ['xx', 'yy', 'xy']], ['((?<a>x)|(?<a>y))(?<a>z)', ['xz']],
  ['(?:(?<a>x)|(?<a>y))+\\k<a>', ['xyy', 'xyx']], ['(?<a>x)|(?:(?<a>y)|(?<a>z))', ['z']], ['(?<a>(?<a>x))', ['x']],
  ['(?<𝒜>.)', ['a']], ['(?<\\u{1d49c}>.)\\k<𝒜>', ['aa']], ['(?<a\\u0062>.)\\k<ab>', ['xx']], ['(?<$_>.)', ['a']],
  ['(?<n>(?<n>x)|y)\\k<n>', ['xxx', 'yy', 'xx']], ['(?<n>y|(?<n>x))', ['x']], ['(?<n>a)(?:b|(?<n>c))\\k<n>', ['acca', 'aca', 'aba']],
  ['(?<n>a)(?:b|(?<n>c))', ['ac', 'ab']], ['(?<n>x)|(?:(?<n>y)(?:z|(?<n>w)))', ['w', 'yz', 'x']],
  ['(?<n>)(?:(x)|y)(?:z|(?<n>a))', ['a']], ['((?<n>a)|(?<n>b))(?:c|(?<n>d))', ['ac']],
  ['(?<n>a)(?<x>(?:b|(?<n>c)))', ['a']], ['(?<n>a)(?:(?:b|(?<n>c)))', ['ac']], ['(?<n>a)(?=b|(?<n>c))', ['ac']],
  ['(?:(?<n>a)|b)(?:c|(?<n>d))\\k<n>', ['ada', 'bdd', 'aca']], ['(?<n>a)|b|(?<n>c)', ['c']], ['(?<n>a)(?:b|c)(?<n>d)', ['abd']],
  ['(?<n>a)(?:b|(?:c|(?<n>d)))', ['ad']], ['((?<n>a)|b)|(?<n>c)', ['c']], ['(?<=(?<n>a)(?:b|(?<n>c)))\\k<n>', ['acc']],
  ['(?<1a>.)', ['a']], ['(?<>a)', ['a']], ['(?<a-b>.)', ['a']], ['(?<é>.)', ['a']], ['(?<a\u200c>.)', ['a']],
  ['(?<\\uD835\\uDC9C>.)', ['a']], ['(?<\\u{110000}>.)', ['a']], ['(?<a>a)\\1', ['aa']], ['(?<a>a)(?<b>b)\\2\\1', ['abba']],
  ['^(a)|\\1b$', ['b', 'ab']], ['(a)|\\1b', ['b']], ['^\\1(a)$', ['a']], ['^(a\\1)$', ['a']], ['^(a\\1)+$', ['aaa', 'aa']],
  ['((a)|b)+\\2', ['aba', 'abb']], ['^(?:(a)|b)*\\1$', ['aba', 'abb', 'ab']], ['^(a*)*\\1$', ['aaa', 'b']],
  ['^(a+)\\1$', ['aaaa', 'aaa']], ['^(\\w+)\\s\\1$', ['hello hello', 'hello world']], ['^([\'"]).*\\1$', ['"a"', '"a\'']],
  ['(?=(a+))a*b\\1', ['baaabac', 'aab']], ['(?=(a+?))(\\1ab)', ['aaab']], ['(?!(a))\\1b', ['b', 'ab']],
  ['(?<=(\\d+)(\\d+))$', ['1053']], ['(?<=\\1(a))b', ['aab', 'ab']], ['(?<=(a)\\1)b', ['aab']], ['(?<!(a)\\1)b', ['aab', 'b']],
  ['(?<=^a*)b', ['aab', 'cab']], ['(?<=a|bc)d', ['bcd', 'cd']], ['(?<=a(?=b)b)c', ['abc']], ['(?<=(?<=a)b)c', ['abc', 'bc']],
  ['(?<=$x)', ['x']], ['(?<=\\b)a', ['a']], ['(?<!\\d)\\d{3}(?!\\d)', ['a123b', '1234']], ['(?<=a{2,3})b', ['aab', 'ab']],
  ['(?<=(a|ab))c', ['abc']], ['(?<=([ab])+)c\\1', ['abca', 'abcb']], ['(?<=([ab]+?))c\\1', ['abcb', 'abca']],
  ['^(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).{8,}$', ['Passw0rd', 'password', 'PASSW0RD', 'Pw0', 'Pässw0rd']],
  ['^(?=.*[!@#$%^&*])(?!.*\\s).{6,20}$', ['abc!def', 'abc def!', 'abcdef']],
  ['^[^\\s@]+@[^\\s@.]+(?:\\.[^\\s@.]+)+$', ['ada@example.com', 'ada@example', 'a b@c.d', 'ada@ex..com', 'é@ü.de']],
  ['^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', ['john.doe+x@mail.co.uk', 'john@mail', '@mail.com']],
  ['^\\+?[1-9]\\d{1,14}$', ['+447911123456', '0123', '+1']], ['^\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}$', ['(555) 123-4567', '555.123.4567', '55-123-4567']],
  ['^[A-Z]{1,2}\\d[A-Z\\d]? ?\\d[A-Z]{2}$', ['SW1A 1AA', 'M1 1AE', 'W1A0AX', 'SW1A1A']], ['^\\d{5}(-\\d{4})?$', ['12345', '12345-6789', '1234']],
  ['^[A-Z]{2}\\d{2}[A-Z0-9]{11,30}$', ['GB82WEST12345698765432', 'GB82', 'DE89370400440532013000']],
  ['^[0-9]{3}-[0-9]{2}-[0-9]{4}$', ['123-45-6789', '123456789']], ['^#?([a-f0-9]{6}|[a-f0-9]{3})$', ['#a3c113', 'fff', '#ggg']],
  ['^\\d{4}-\\d{2}-\\d{2}$', ['2026-10-19', '2026-1-19']], ['^https?:\\/\\/[^\\s/$.?#].[^\\s]*$', ['https://example.com/a', 'ftp://x']],
  ['^(?:[01]\\d|2[0-3]):[0-5]\\d$', ['23:59', '24:00']], ['^[1-9]\\d*(\\.\\d+)?$', ['1.2', '01']],
  ['^\\p{Lu}', ['p{Lu}']], ['^[À-ÿ]+$', ['éàü', 'abc']], ['^[\\u0400-\\u04FF]+$', ['Привет', 'Hello']],
  ['^(?:[\\uD800-\\uDBFF][\\uDC00-\\uDFFF])+$', ['😀😁', 'a😀']], ['e\u0301', ['e\u0301', 'é']], ['^.\u0301$', ['e\u0301', 'é']],
  ['^\\S+$', ['😀', 'a b']], ['\\bfoo\\b', ['a foo b', 'afoo', 'éfooé']], ['\\Bfoo', ['afoo', 'foo']], ['^\\b$', ['']], ['^\\B$', ['']],
  ['(a+)+$', ['aaaaaaaaaaaaaaaaaaaaaaaa!', 'aaa']], ['(a|aa)+$', ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaa!']], ['(x+x+)+y', ['xxxxxxxxxxxxxxxxxxxxxxxxx', 'xxy']],
  ['^(a+)+$', ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaa!']], ['(.*a){12}', ['aaaaaaaaaaaaaaaaaaaaaaaaaaaab']],
  ['a*?b', ['aaab']], ['a+?$', ['aa']], ['a??b', ['b']], ['a{2,}?', ['aaa']], ['(a|ab)(c|bcd)(d*)', ['abcd']],
  ['(?:)', ['', 'x']], ['()', ['']], ['(|a)+', ['a']], ['(?:a|)*b', ['aab']], ['(a*)*b', ['aaab', 'aaa']], ['(a*)+b', ['b']],
  ['(?:a*?)*?b', ['ab']], ['(a?)*?b', ['ab']], ['(?:(a)|b)*c\\1', ['abca', 'abc', 'bac']], ['(?:(a)|(b))+\\1\\2', ['abb', 'aba', 'ab']],
  ['(z)((a+)?(b+)?(c))*', ['zaacbbbcac']], ['^(?:(\\d+)|x)+\\1$', ['12x', '12x12', '1x1']],
  ['(?:x|(?=a)){3}', ['xxx', 'a']], ['^(?!a)\\w', ['b', 'a']], ['(?=(?!a))b', ['b']], ['(?!(?=a))a', ['a']],
  ['a(?=b)', ['ab', 'ac']], ['a(?!b)', ['ab', 'ac']], ['(?<=\\$)\\d+(\\.\\d\\d)?', ['$10.50', '10']],
  ['[\\d]+', ['12']], ['[^\\d\\s]', ['1 ', 'a']], ['[\\D]', ['1']], ['[\\S\\s]', ['\n']], ['[^\\S\\s]', ['\n', 'a']], ['[\\W\\w]', ['é']],
  ['[.]', ['.', 'a']], ['[$^]', ['$', '^']], ['[\\^a]', ['^']], ['[^^]', ['^', 'a']], ['[|]', ['|']], ['[*+?{}()]', ['{']],
  ['a|b|c', ['c', 'd']], ['|', ['']], ['a|', ['b']], ['(a|b)c|d', ['bc', 'd', 'c']], ['^a|b$', ['xb', 'xa']],
  ['\\0', ['\u0000']], ['[\\0]', ['\u0000']], ['[\\01]', ['\u0001']], ['[\\1]', ['\u0001', '1']], ['[\\8]', ['8']], ['[\\08]', ['8', '\u0000']],
  ['[\\377]', ['\u00ff']], ['[\\400]', ['0', ' ']], ['(?<a>.)[\\1]', ['a\u0001']],
  ['\\n\\r\\t\\v\\f', ['\n\r\t\u000b\f']], ['[\\n-\\r]', ['\u000b']], ['\\/\\.\\*', ['/.*']],
  ['(?', ['']], ['(?:', ['']], ['(?=', ['']], ['(?<', ['']], ['(?<a', ['']], ['(?<a>', ['']], ['(?x)', ['']], ['(?x:a)', ['a']],
  ['(?i', ['']], ['(?i:', ['']], ['(?-i:a)', ['a', 'A']], ['(?i:(?-i:a))', ['A', 'a']], ['(?i:a(?-i:b)c)', ['AbC', 'ABC']],
  ['(?m:$)\\n', ['\n']], ['(?m:a$)', ['a\nb', 'ab']], ['(?s-s:.)', ['\n']], ['(?ms:^.$)', ['\n\n\n']], ['(?i:[\\u212a])', ['k']],
  ['(?i:[^k])', ['\u212a', 'K']], ['(?i:\\u212a)', ['K']], ['(?i:[a-f]+)', ['ABCDEF']], ['(?i:[À-Þ])', ['é']], ['(?i:Σ)', ['ς', 'σ']],
  ['^.{0,16384}$', ['hello world', '\n']], ['^[\\s\\S]{0,65535}$', ['hello world']], ['^[^<>]{0,20000}$', ['hello world', 'a<b']],
  ['^.{1,50000}$', ['hello world', '']], ['^(?:[a-z]{2,8}-){0,4000}$', ['hello world', 'ab-cd-', 'a-']],
  ['^(\\w{1,200} ?){1,200}$', ['hello world', 'hello  world']], ['^(?:[a-z0-9]{1,63}\\.){1,127}[a-z]{2,63}$', ['mail.example.com', 'x.y']],
  ['^.{0,16383}$', ['hello world']], ['^[a-z]{0,10000}$', ['hello', 'hello world']], ['(?:a{1000}){1000}', ['aaaa']],
  ['(?:x?){20000}y', ['xay', 'xxy']], ['^(?:(?=\\w)(?<=\\b)\\w+\\b ?){1,500}$', ['hello world', 'hello  world']],
  ['(?i:b|[ab])', ['A', 'b']], ['(?i:x|[a-c])', ['A', 'x']], ['(?i:ǅ)', ['Ǆ', 'ǆ']], ['(?i:ﬀ)', ['FF']], ['(?i:ΐ)', ['ΐ']], ['(?i:[\\w])', ['\u017f']],
]

function random(seedValue) {
  let state = seedValue >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const next = random(seed)
const pick = (items) => items[Math.floor(next() * items.length)]

const atoms = ['a', 'b', 'c', 'A', '.', '\\d', '\\w', '\\s', '\\W', '[ab]', '[^a]', '[a-c]', '[\\w-.]', '\\b', '\\B', '^', '$',
  '\\1', '\\2', '\\3', '\\k<n>', '\\k<m>', '(?<m>a|b)', 'ſ', 'σ', '[^\\W]', '[\\s\\d]', '\\0', '\\101', '\\c1',
  '\\8', '\\01', '\\x41', '\\u0061', '\\ca', '\\c', '{', '}', ']', '\\-', 'é', '😀', '\\n', '[^]', '[]', '|', ')']
const quantifiers = ['', '', '', '*', '+', '?', '*?', '+?', '??', '{2}', '{1,2}', '{0,}', '{2,1}', '{', '**']
const alphabet = ['a', 'a', 'b', 'c', 'A', '1', ' ', '_', '-', '.', '\n', 'é', '😀', 'k', '\u212a', 'S', 's', 'ſ', 'Σ', 'ς', '\r', '😁']

function term(depth) {
  const roll = next()
  if (depth < 3 && roll < 0.3) {
    const open = pick(['(', '(?:', '(?=', '(?!', '(?<=', '(?<!', '(?<n>', '(?i:', '(?m:', '(?s:', '('])
    return open + disjunction(depth + 1) + (next() < 0.97 ? ')' : '') + pick(quantifiers)
  }
  return pick(atoms) + pick(quantifiers)
}

function alternative(depth) {
  let text = ''
  const count = 1 + Math.floor(next() * 4)
  for (let index = 0; index < count; index += 1) text += term(depth)
  return text
}

function disjunction(depth) {
  let text = alternative(depth)
  while (next() < 0.2) text += '|' + alternative(depth)
  return text
}

function input() {
  const length = Math.floor(next() * inputLength)
  let text = ''
  for (let index = 0; index < length; index += 1) text += pick(alphabet)
  return text
}

function outcome(pattern, text) {
  let regex
  try {
    regex = new RegExp(pattern)
  } catch (error) {
    if (error instanceof SyntaxError) return 'SyntaxError'
    throw error
  }
  const started = performance.now()
  const result = regex.test(text)
  return performance.now() - started < 20 ? result : undefined
}

const nodeBugs = new Set(
  [['(?i:b|[ab])', 'A'], ['(?i:x|[a-c])', 'A'], ['^(?i:\\u0178)$', '\u00ff'], ['(?i:((3|([a]))))', 'A'],
  ['(?i:(?=\\W{2}|(W))(A|(?<![a])))', 'A\ud83d\ude00']].map((item) => JSON.stringify(item)),
)

if (process.argv[2] === '--verify') {
  const { cases } = JSON.parse(readFileSync(output, 'utf8'))
  const differing = cases.filter((item) => {
    const result = outcome(item.pattern, item.input)
    return result !== undefined && result !== item.result
  })
  for (const item of differing.slice(0, 20)) console.error(`differs: ${JSON.stringify(item)}`)
  console.log(`verified ${cases.length} cases in a fresh node ${process.version}, ${differing.length} differ`)
  process.exit(differing.length === 0 ? 0 : 1)
}

const cases = []
const seen = new Set()
function add(pattern, text, kind) {
  const key = JSON.stringify([pattern, text])
  if (seen.has(key) || nodeBugs.has(key)) return
  seen.add(key)
  const result = outcome(pattern, text)
  if (result === undefined) return
  cases.push({ pattern, input: text, result, kind })
}

for (const [pattern, inputs] of curated) for (const text of inputs) add(pattern, text, 'curated')
for (let unit = 0; unit < 0x10000; unit += 1) {
  if (unit >= 0xd800 && unit <= 0xdfff) continue
  const text = String.fromCharCode(unit)
  const partners = new Set([text.toUpperCase(), text.toLowerCase()].filter((item) => item !== text && item.length === 1))
  const escaped = '\\u' + unit.toString(16).padStart(4, '0')
  for (const partner of partners) add(`^(?i:${escaped})$`, partner, 'curated')
  if (partners.size > 0) add(`^(?i:[^${escaped}])$`, [...partners][0], 'curated')
}
for (let index = 0; index < fuzzPatterns; index += 1) {
  const pattern = disjunction(0)
  for (let count = 0; count < inputsPerPattern; count += 1) add(pattern, input(), 'fuzz')
}

const counts = { curated: cases.filter((item) => item.kind === 'curated').length, fuzz: cases.filter((item) => item.kind === 'fuzz').length }
writeFileSync(output, JSON.stringify({ node: process.version, seed, counts, cases }, null, 1) + '\n')
console.log(`wrote ${cases.length} cases (${counts.curated} curated, ${counts.fuzz} fuzz) with node ${process.version}`)
execFileSync(process.execPath, [fileURLToPath(import.meta.url), '--verify'], { stdio: 'inherit' })
