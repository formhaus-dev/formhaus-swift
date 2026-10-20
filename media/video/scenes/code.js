const escape = (text) => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const span = (kind, text) => `<span class="code-${kind}">${escape(text)}</span>`;

export const json = (text) =>
  text.replace(/("(?:[^"\\]|\\.)*")(\s*:)?|([{}[\],])|([^"{}[\],]+)/g, (match, string, colon, punct, rest) => {
    if (string) return colon ? span('key', string) + escape(colon) : span('string', string);
    if (punct) return span('punct', punct);
    return /^\s*-?\d/.test(rest) ? span('number', rest) : escape(rest);
  });

export const swift = (text) =>
  text.replace(/(\.\w+)(\()|(\.\w+|\b[a-z]\w*\b)(?=\))|([A-Z]\w*)|([^.A-Za-z]+|\w+)/g, (match, method, paren, value, type, rest) => {
    if (method) return span('method', method) + span('punct', paren);
    if (value) return span('string', value);
    if (type) return span('type', type);
    return escape(rest);
  });

const keywords = {
  tsx: ['export', 'function', 'if', 'return', 'null', 'const'],
  swift: ['func', 'if', 'return', 'nil', 'let', 'guard', 'else'],
  kotlin: ['fun', 'if', 'return', 'null', 'val'],
};

export const source = (text, language) => {
  const words = new Set(keywords[language]);
  return text.replace(/("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)|([^"\w]+)/g, (match, string, number, word, rest) => {
    if (string) return span('string', string);
    if (number) return span('number', number);
    if (word && words.has(word)) return span('method', word);
    if (word && /^[A-Z]/.test(word)) return span('type', word);
    if (word) return escape(word);
    return span('punct', rest);
  });
};
