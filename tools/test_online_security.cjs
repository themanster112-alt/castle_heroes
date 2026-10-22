// Tests actual Firebase rules using the Dart engine's transition fixtures.
// Administrative setup/cleanup is restricted to newly-created random test rooms.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const project = 'castle-heroes-online-20261021';
const key = 'AIzaSyBYSKPsrLoL7hoJeDQmq-111CZtB42C5zM';
const root = `projects/${project}/databases/(default)/documents`;
const base = `https://firestore.googleapis.com/v1/${root}`;
const collection = process.argv.includes('--staging') ? 'room_security_tests' : 'rooms';
const fixtures = JSON.parse(fs.readFileSync('.dart_tool/online-rule-fixtures.json', 'utf8'));
const catalog = JSON.parse(fs.readFileSync('.dart_tool/online-catalog-v2.json', 'utf8'));
const users = [], rooms = [];
let administrator;
let serverTime;
let synchronizedAt;
const clone = object => structuredClone(object);
const encode = value => {
  if (value === null) return {nullValue: null};
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (value && typeof value === 'object' && Object.hasOwn(value, '__double')) return {doubleValue: value.__double};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'number') return {integerValue: String(value)};
  if (typeof value === 'string') return {stringValue: value};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([field, item]) => [field, encode(item)]))}};
};
async function request(url, token, method, body) {
  const response = await fetch(url, {method, headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'}, body: body === undefined ? undefined : JSON.stringify(body)});
  const data = await response.json();
  return {status: response.status, data, date: response.headers.get('date')};
}
async function signup() {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${key}`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({returnSecureToken: true})});
  const user = await response.json();
  assert.equal(response.status, 200, user.error?.message);
  users.push(user); return user;
}
function personalize(data) {
  if (data === 'host') return users[0].localId;
  if (data === 'guest') return users[1].localId;
  if (Array.isArray(data)) return data.map(personalize);
  if (data && typeof data === 'object' && !(data instanceof Date)) return Object.fromEntries(Object.entries(data).map(([field, value]) => [field, personalize(value)]));
  return data;
}
async function commit(token, code, data, currentDocument, transforms = []) {
  const fields = encode(data).mapValue.fields;
  for (const transform of transforms) delete fields[transform.fieldPath];
  return request(`${base}:commit`, token, 'POST', {writes: [{update: {name: `${root}/${collection}/${code}`, fields}, currentDocument, ...(transforms.length ? {updateTransforms: transforms} : {})}]});
}
const stamp = fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'});
async function seed(data, expired) {
  const d = personalize(clone(data));
  const reference = serverTime.getTime() + performance.now() - synchronizedAt;
  d.createdAt = new Date(reference - 120000);
  d.startedAt = new Date(reference - 90000);
  d.updatedAt = new Date(reference - 1000);
  d.phaseStartedAt = new Date(reference - (expired ? (d.phaseSeconds + 2) * 1000 : 1000));
  for (let attempt = 0; attempt < 20; attempt++) {
    const code = String(crypto.randomInt(10000, 100000));
    const result = await commit(administrator, code, d, {exists: false});
    if (result.status === 409) continue;
    assert.equal(result.status, 200, `Test setup failed: ${result.data.error?.message}`);
    rooms.push(code);
    return {code, before: d, updateTime: result.data.writeResults[0].updateTime};
  }
  throw new Error('Could not allocate a test room');
}
async function check(label, before, after, allowed, options = {}) {
  const last = after.events[String(before.revision)];
  const automatic = ['next', 'timeout', 'forfeit'].includes(last.kind);
  const setup = await seed(before, options.expired ?? automatic);
  const candidate = {...personalize(clone(after)), createdAt: setup.before.createdAt, startedAt: setup.before.startedAt, phaseStartedAt: setup.before.phaseStartedAt};
  if (options.phaseStartedAt) candidate.phaseStartedAt = options.phaseStartedAt;
  const transforms = [stamp('updatedAt')];
  if (last.kind !== 'cannon' && !options.phaseStartedAt) transforms.push(stamp('phaseStartedAt'));
  const actor = users[options.user ?? last.actor];
  const result = await commit(actor.idToken, setup.code, candidate, {updateTime: setup.updateTime}, transforms);
  assert.equal(result.status, allowed ? 200 : 403, `${label}: ${result.status} ${result.data.error?.message || ''}`);
  console.log(`PASS ${allowed ? 'allow' : 'deny'}: ${label}`);
}
function action(before, kind, overrides = {}) {
  const d = clone(before);
  const actor = d.phase === 'loot' ? 1 - d.state.team : d.state.team;
  d.events[String(d.revision)] = {kind, value: null, actor}; d.revision++;
  Object.assign(d, overrides);
  return d;
}
(async () => {
  const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first');
  administrator = (await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform'])).access_token;
  const meta = await request(`${base}/online_catalog/${fixtures.version}`, administrator, 'GET');
  assert.equal(meta.status, 200); assert.ok(meta.date);
  assert.equal(fixtures.version, catalog.version);
  serverTime = new Date(meta.date);
  synchronizedAt = performance.now();
  await signup(); await signup(); await signup();
  const first = fixtures.cases.find(item => item.label === 'choose easy question');
  // Exercise real creation/joining in addition to seeded state-transition cases.
  const code = String(crypto.randomInt(10000, 100000));
  const waiting = {protocol: fixtures.initial.protocol, version: fixtures.version, seed: 7, players: [personalize(fixtures.initial.players[0])], status: 'waiting', phase: 'waiting', turnUid: users[0].localId, revision: 0, events: {}, state: null, startedAt: null, phaseStartedAt: null, phaseSeconds: 0};
  const created = await commit(users[0].idToken, code, waiting, {exists: false}, [stamp('createdAt'), stamp('updatedAt')]);
  assert.equal(created.status, 200, `Create: ${created.data.error?.message}`); rooms.push(code);
  const hostDoc = await request(`${base}/${collection}/${code}`, administrator, 'GET');
  const createdAt = new Date(hostDoc.data.fields.createdAt.timestampValue);
  const joined = {...personalize(fixtures.initial), createdAt};
  const claimed = await commit(users[1].idToken, code, joined, {updateTime: created.data.writeResults[0].updateTime}, [stamp('updatedAt'), stamp('startedAt'), stamp('phaseStartedAt')]);
  assert.equal(claimed.status, 200, `Join: ${claimed.data.error?.message}`);
  console.log('PASS create and join with server timestamps and canonical initial state');
  for (const fixture of fixtures.cases) await check(fixture.label, fixture.before, fixture.after, true);
  const initial = clone(fixtures.initial);
  const cannon = action(initial, 'cannon'); cannon.state.cannonUsed[0] = true; cannon.state.cannonArmed = true;
  await check('cannon before 150 points', initial, cannon, false);
  const cannonFixture = fixtures.cases.find(item => item.label === 'activate cannon');
  const invalidCannonValue = clone(cannonFixture.after);
  invalidCannonValue.events[String(cannonFixture.before.revision)].value = 'not-an-integer';
  await check('non-null helper command payload cannot poison replay', cannonFixture.before, invalidCannonValue, false);
  const floatActor = clone(first.after); floatActor.events['0'].actor = {__double: 0};
  await check('floating-point actor cannot poison native clients', first.before, floatActor, false, {user: 0});
  const repeat = action(cannonFixture.after, 'cannon');
  await check('cannon cannot be activated twice or extend the turn', cannonFixture.after, repeat, false);
  const forgedScore = clone(first.after); forgedScore.state.scores[0] = 999;
  await check('forged scores on question selection', first.before, forgedScore, false);
  const correct = fixtures.cases.find(item => item.label === 'correct normal answer');
  const inflated = clone(correct.after); inflated.state.scores[0] += 100;
  await check('inflated answer reward', correct.before, inflated, false);
  const floatScore = clone(correct.after); floatScore.state.scores[0] = {__double: 10};
  await check('floating-point state cannot poison replay', correct.before, floatScore, false);
  const floatDuration = clone(correct.after); floatDuration.phaseSeconds = {__double: 3};
  await check('floating-point duration cannot poison timers', correct.before, floatDuration, false);
  const edited = clone(correct.after); edited.events['0'].value = 14;
  await check('rewriting an earlier command', correct.before, edited, false);
  const turn = clone(first.after); turn.turnUid = 'guest';
  await check('arbitrary turn owner', first.before, turn, false);
  await check('outsider writing a move', first.before, first.after, false, {user: 2});
  const wrongActor = clone(first.after); wrongActor.events['0'].actor = 1;
  await check('guest acting during host turn', first.before, wrongActor, false, {user: 1});
  const longTimer = clone(first.after); longTimer.phaseSeconds = 3600;
  await check('extending the answer timer', first.before, longTimer, false);
  const shortTimer = clone(first.after); shortTimer.phaseSeconds = 15;
  await check('protocol 3 rejects the obsolete fifteen-second question timer', first.before, shortTimer, false);
  const legacyBefore = clone(first.before), legacyAfter = clone(first.after);
  legacyBefore.protocol = 2; legacyAfter.protocol = 2; legacyAfter.phaseSeconds = 15;
  await check('legacy protocol 2 rooms retain their original timer', legacyBefore, legacyAfter, true);
  await check('forged future phase timestamp', first.before, first.after, false, {phaseStartedAt: new Date('2040-01-01T00:00:00Z')});
  const forfeit = fixtures.cases.find(item => item.label === 'selection deadline forfeit');
  await check('selection forfeit before 60 seconds', forfeit.before, forfeit.after, false, {expired: false});
  await check('answer after server deadline', correct.before, correct.after, false, {expired: true});
  const skip = action(initial, 'skip', {turnUid: 'guest'}); skip.state.team = 1;
  await check('skipping a playable turn', initial, skip, false);
  const locked = clone(first.after);
  const [hardKey, hardQuestion] = Object.entries(catalog.questions).find(([, q]) => q.age === 0 && q.level === 3);
  locked.events['0'].value = 10; locked.events['0'].question = hardKey;
  locked.state.question = hardKey; locked.state.level = 3; locked.state.usedTexts = [hardQuestion.text];
  for (const [field, difficulty] of [['remEasy', 'easy'], ['remMedium', 'medium'], ['remHard', 'hard']]) locked.state[field] = initial.state[field].map((value, lane) => value - hardQuestion.occurrences[String(initial.players[lane].age)][difficulty]);
  locked.state.surpriseQuestion = false;
  await check('choosing locked hard questions', initial, locked, false);
  const fixture = await seed(initial, false);
  const guestProfile = {...fixture.before, players: [...fixture.before.players, {uid: users[2].localId, name: 'ثالث', age: 0, character: 0}]};
  const third = await commit(users[2].idToken, fixture.code, guestProfile, {updateTime: fixture.updateTime}, [stamp('updatedAt')]);
  assert.equal(third.status, 403); console.log('PASS deny: third player');
  const closed = {...fixture.before, status: 'closed', leftBy: users[0].localId};
  const exit = await commit(users[0].idToken, fixture.code, closed, {updateTime: fixture.updateTime}, [stamp('updatedAt')]);
  assert.equal(exit.status, 200, `Leave: ${exit.data.error?.message}`); console.log('PASS allow: direct queued leave write');
  const clockWrite = await request(`${base}:commit`, users[0].idToken, 'POST', {writes: [{update: {name: `${root}/clocks/${users[0].localId}`, fields: {}}, updateTransforms: [stamp('at')]}]});
  assert.equal(clockWrite.status, 200); console.log('PASS allow: server clock calibration');
  const forgedClock = await request(`${base}:commit`, users[0].idToken, 'POST', {writes: [{update: {name: `${root}/clocks/${users[0].localId}`, fields: {at: encode(new Date('2040-01-01'))}}}]});
  assert.equal(forgedClock.status, 403); console.log('PASS deny: forged clock');
  console.log('All online security and server-time checks passed.');
})().catch(error => {console.error(error.message); process.exitCode = 1;}).finally(async () => {
  if (administrator && rooms.length) {
    const result = await request(`${base}:commit`, administrator, 'POST', {writes: [...rooms.map(code => ({delete: `${root}/${collection}/${code}`})), ...users.map(user => ({delete: `${root}/clocks/${user.localId}`}))]});
    if (result.status !== 200) console.error('Test room cleanup requires attention.');
  }
  for (const user of users) await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${key}`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({idToken: user.idToken})});
});
