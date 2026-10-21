const fs = require('node:fs');
const path = require('node:path');
const cliRoot = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const { configstore } = require(path.join(cliRoot, 'configstore.js'));
const { getAccessToken } = require(path.join(cliRoot, 'auth.js'));
const project = 'castle-heroes-20261014';
async function main() {
  const credentials = configstore.get('tokens');
  if (!credentials?.refresh_token) throw new Error('Firebase login required');
  const token = await getAccessToken(credentials.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function request(url, body) {
    const response = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const result = await response.json();
    if (!response.ok) throw new Error(JSON.stringify(result));
    return result;
  }
  if (process.argv.includes('--enable-api')) {
    const result = await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services/firestore.googleapis.com:enable`, {});
    console.log('Firestore API enable requested:', result.name);
    if (result.done || result.name === 'operations/noop.DONE_OPERATION') { console.log('Firestore API enabled'); return; }
    for (let attempt = 0; attempt < 24; attempt++) {
      const response = await fetch(`https://serviceusage.googleapis.com/v1/${result.name}`, { headers: { Authorization: `Bearer ${token.access_token}` } });
      const operation = await response.json();
      if (!response.ok || operation.error) throw new Error(JSON.stringify(operation));
      if (operation.done) { console.log('Firestore API enabled'); return; }
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    throw new Error('API activation still pending');
  }
  function value(input) {
    if (input === null) return { nullValue: null };
    if (Array.isArray(input)) return { arrayValue: { values: input.map(value) } };
    if (typeof input === 'number') return { integerValue: String(input) };
    return { stringValue: input };
  }
  if (process.argv.includes('--add-child-89')) {
    const questions = JSON.parse(fs.readFileSync(path.join(__dirname, '../data/children_questions.json'), 'utf8'));
    const question = questions.find(item => item.id === '89');
    if (!question) throw new Error('Question 89 missing from local data');
    const { id, ...fields } = question;
    await request(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`, { writes: [{ update: { name: `projects/${project}/databases/(default)/documents/children_questions/${id}`, fields: Object.fromEntries(Object.entries({ questionNumber: Number(id), ...fields }).map(([key, input]) => [key, value(input)])) }, currentDocument: { exists: false } }] });
    console.log('Added children question 89');
    return;
  }
  for (const collection of ['children_questions', 'adults_questions']) {
    const questions = JSON.parse(fs.readFileSync(path.join(__dirname, '../data', `${collection}.json`), 'utf8'));
    const writes = questions.map(({ id, ...question }) => ({ update: { name: `projects/${project}/databases/(default)/documents/${collection}/${id}`, fields: Object.fromEntries(Object.entries({ questionNumber: Number(id), ...question }).map(([key, input]) => [key, value(input)])) }, currentDocument: { exists: false } }));
    await request(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`, { writes });
    console.log(`${collection}: imported ${questions.length} questions`);
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
