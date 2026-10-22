// Immutable, versioned question metadata used by Firestore's transition validator.
const fs = require('node:fs');
const path = require('node:path');
const project = 'castle-heroes-online-20261021';
const names = ['children_questions', 'adults_questions'];
const normalized = text => text.replace(/[\s\u064B-\u065F\u0640؟?!.,،]/g, '').toLowerCase();
let hash = 0x811c9dc5;
const rows = [];
const counts = {'0': {easy: 0, medium: 0, hard: 0}, '1': {easy: 0, medium: 0, hard: 0}};
const fields = ['easy', 'medium', 'hard'];
for (let age = 0; age < names.length; age++) {
  const content = fs.readFileSync(`data/${names[age]}.json`, 'utf8');
  for (const byte of Buffer.from(content)) hash = (hash * 31 + byte) % 2147483647;
  const bank = JSON.parse(content).sort((a, b) => Number(a.questionNumber ?? a.id) - Number(b.questionNumber ?? b.id));
  bank.forEach((item, index) => {
    if (item.options.length !== 3 || ![0, 1, 2].includes(item.correctOptionIndex)) throw new Error('Invalid question options');
    if (![1, 2, 3].includes(item.level)) throw new Error(`Explicit reviewed difficulty required: ${names[age]}/${item.id}`);
    const level = item.level;
    rows.push({key: `${age}_${item.id}`, age, level, text: normalized(item.question), answer: item.correctOptionIndex});
    counts[age][fields[level - 1]]++;
  });
}
const version = `2-${hash.toString(16)}`;
const occurrences = new Map();
for (const row of rows) {
  if (!occurrences.has(row.text)) occurrences.set(row.text, {'0': {easy: 0, medium: 0, hard: 0}, '1': {easy: 0, medium: 0, hard: 0}});
  occurrences.get(row.text)[row.age][fields[row.level - 1]]++;
}
const catalog = {version, counts, questions: Object.fromEntries(rows.map(({key, ...row}) => [key, {...row, occurrences: occurrences.get(row.text)}]))};
fs.mkdirSync('.dart_tool', {recursive: true});
fs.writeFileSync('.dart_tool/online-catalog-v2.json', JSON.stringify(catalog));
const encode = value => typeof value === 'string' ? {stringValue: value} : typeof value === 'number' ? {integerValue: String(value)} :
  {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item)]))}};
(async () => {
  if (process.argv.includes('--dry-run')) { console.log(`Validated ${rows.length} questions, version ${version}.`); return; }
  const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  const root = `projects/${project}/databases/(default)/documents`;
  const writes = Object.entries(catalog.questions).map(([key, row]) => ({update: {name: `${root}/online_catalog/${version}/questions/${key}`, fields: encode(row).mapValue.fields}}));
  // Publish the version marker last, so rooms cannot reference a partial catalog.
  writes.push({update: {name: `${root}/online_catalog/${version}`, fields: encode({version, counts}).mapValue.fields}});
  for (let offset = 0; offset < writes.length; offset += 200) {
    const response = await fetch(`https://firestore.googleapis.com/v1/${root}:commit`, {
      method: 'POST', headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({writes: writes.slice(offset, offset + 200)}),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`${response.status}: ${result.error?.message}`);
  }
  console.log(`Published ${rows.length} immutable questions and version ${version}.`);
})().catch(error => {console.error(error.message); process.exitCode = 1;});
