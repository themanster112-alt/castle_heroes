// Production smoke test, restricted to the dedicated Edge profiles on ports 8791/8792.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
class Browser {
  pending = new Map(); id = 0;
  static async connect(port) {
    const pages = await (await fetch(`http://localhost:${port}/json/list`)).json();
    const page = pages.find(page => page.type === 'page' && page.url.startsWith('https://castle-heroes-online-20261021.web.app'));
    assert.ok(page, 'Dedicated online test page not found');
    const browser = new Browser(); browser.socket = new WebSocket(page.webSocketDebuggerUrl);
    browser.socket.onmessage = message => {
      const result = JSON.parse(message.data), callback = browser.pending.get(result.id);
      if (callback) { browser.pending.delete(result.id); callback(result); }
    };
    await new Promise(resolve => browser.socket.onopen = resolve);
    return browser;
  }
  command(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timeout = setTimeout(() => { this.pending.delete(id); reject(new Error(`Browser command timed out: ${method}`)); }, 10000);
      this.pending.set(id, result => {clearTimeout(timeout); if (result.error) reject(new Error(result.error.message)); else resolve(result.result);});
      this.socket.send(JSON.stringify({id, method, params}));
    });
  }
  async evaluate(expression) {
    const result = await this.command('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result?.value;
  }
  async waitFor(check, label, timeout = 30000) {
    const start = performance.now();
    while (performance.now() - start < timeout) {
      const value = await check(); if (value) return value;
      await delay(200);
    }
    throw new Error(`Timed out: ${label}`);
  }
  text() { return this.evaluate('document.body.innerText'); }
  async click(label) {
    await this.command('Page.bringToFront');
    await this.waitFor(() => this.evaluate(`(() => {document.querySelector('flt-semantics-placeholder')?.click();const e=Array.from(document.querySelectorAll('[role=button]')).find(e=>(e.innerText||e.getAttribute('aria-label'))===${JSON.stringify(label)});if(!e)return false;e.scrollIntoView({block:'center'});e.click();return true;})()`), label, label === 'ابدأ التحدي' ? 90000 : 30000);
    await delay(600);
  }
  async input(index, value) {
    await this.command('Page.bringToFront');
    await this.evaluate(`(()=>{const e=document.querySelectorAll('input')[${index}];e.scrollIntoView({block:'center'});e.focus();e.click();})()`);
    await delay(200);
    await this.command('Input.insertText', {text: value}); await delay(200);
    assert.equal(await this.evaluate(`document.querySelectorAll('input')[${index}].value`), value, 'Test input did not reach the active form');
  }
  async enter(join, name, code) {
    await this.click('ابدأ التحدي'); await this.click('تحدي 1×1'); await this.click('اللعب أونلاين');
    await this.click(join ? 'الدخول إلى غرفة' : 'فتح غرفة'); await this.input(0, name);
    await this.evaluate(`document.querySelectorAll('[role=checkbox]')[${join ? 1 : 0}].click()`);
    if (join) await this.input(1, code);
    await this.click(join ? 'انضمام' : 'إنشاء غرفة');
  }
  async offline(value) {
    await this.command('Network.enable');
    await this.command('Network.emulateNetworkConditions', {offline: value, latency: 0, downloadThroughput: -1, uploadThroughput: -1});
  }
  async screenshot(name) {
    const result = await this.command('Page.captureScreenshot', {format: 'png'});
    fs.writeFileSync(`.dart_tool/${name}.png`, Buffer.from(result.data, 'base64'));
  }
  async close() {
    try {
      await this.offline(false);
      if (this.roomCode) {
        await this.evaluate(`(async()=>{try{const f=window.firebase_firestore,app=window.firebase_core?.getApp('online'),auth=window.firebase_auth?.getAuth(app);if(f&&auth?.currentUser)await f.updateDoc(f.doc(f.getFirestore(app),'rooms',${JSON.stringify(this.roomCode)}),{status:'closed',leftBy:auth.currentUser.uid,updatedAt:f.serverTimestamp()});}catch(_){}})()`);
      }
      await this.evaluate('(async()=>{if(!window.firebase_core||!window.firebase_auth)return;let app;try{app=window.firebase_core.getApp("online");}catch(_){return;}const auth=window.firebase_auth.getAuth(app);if(auth.currentUser)await window.firebase_auth.deleteUser(auth.currentUser);})()');
    } finally { await this.command('Browser.close'); this.socket.close(); }
  }
}
const browsers = [];
(async () => {
  const host = await Browser.connect(8791); browsers.push(host);
  const guest = await Browser.connect(8792); browsers.push(guest);
  for (const browser of browsers) {
    await browser.command('Emulation.setDeviceMetricsOverride', {width: 390, height: 1000, deviceScaleFactor: 1, mobile: true});
  }
  await host.enter(false, 'فحص الحماية');
  const code = await host.waitFor(async () => (await host.text()).match(/غرفة\s+(\d{5})/)?.[1], 'room creation', 90000);
  host.roomCode = code;
  await host.waitFor(async () => (await host.text()).includes('بانتظار اللاعب الثاني'), 'waiting-room snapshot');
  console.log('PASS production host creates a five-digit waiting room');
  await host.screenshot('online-v2-waiting');
  await guest.enter(true, 'ضيف الحماية', code);
  await guest.waitFor(async () => (await guest.text()).includes('مهلة اختيار المستوى'), 'guest joining', 90000);
  await host.waitFor(async () => (await host.text()).includes('مهلة اختيار المستوى'), 'host starts automatically');
  console.log('PASS independent guest joins and both clients show the selection deadline');
  const difficultyState = `(() => Array.from(document.querySelectorAll('[role=button]')).filter(e => /^(سهل|متوسط|صعب)/.test((e.innerText||e.getAttribute('aria-label')||'').trim())).map(e => ({label:(e.innerText||e.getAttribute('aria-label')||'').trim(), disabled:e.getAttribute('aria-disabled')==='true'})))()`;
  const hostChoices = await host.evaluate(difficultyState);
  const guestChoices = await guest.evaluate(difficultyState);
  assert.equal(hostChoices.length, 3);
  assert.deepEqual(hostChoices.map(choice => choice.disabled), [false, true, true]);
  assert.equal(guestChoices.length, 3);
  assert.ok(guestChoices.every(choice => choice.disabled));
  await host.evaluate(`Array.from(document.querySelectorAll('[role=button]')).find(e => (e.innerText||e.getAttribute('aria-label')||'').trim().startsWith('سهل')).scrollIntoView({block:'center'})`);
  await delay(4000); // Allow map/helper images to decode before the visual capture.
  await host.screenshot('map-controls-selection');
  await host.evaluate(`(() => {const e=Array.from(document.querySelectorAll('[role=button]')).find(e => (e.innerText||e.getAttribute('aria-label')||'').trim().startsWith('سهل'));e.scrollIntoView({block:'center'});e.click();})()`);
  await host.waitFor(async () => host.evaluate(`(async()=>{const f=window.firebase_firestore,app=window.firebase_core.getApp('online');const d=(await f.getDoc(f.doc(f.getFirestore(app),'rooms',${JSON.stringify(code)}))).data();return d.phase==='answer'&&d.state.level===1&&d.phaseSeconds===20;})()`), 'easy button starts synchronized question');
  console.log('PASS difficulty buttons enforce turn and locks and start a validated easy question');
  await host.offline(true);
  await host.click('Back');
  const start = performance.now();
  await host.click('مغادرة');
  await host.waitFor(async () => (await host.text()).includes('الفريق الأحمر'), 'immediate offline departure', 2500);
  assert.ok(performance.now() - start < 2500);
  console.log('PASS host returns immediately while network is offline');
  await host.offline(false);
  await guest.waitFor(async () => (await guest.text()).includes('أُغلقت الغرفة'), 'queued departure delivery', 30000);
  await guest.screenshot('online-v2-offline-departure');
  console.log('PASS queued departure closes the remote room after reconnection');
  console.log('All production browser checks passed.');
})().catch(async error => {
  console.error(error.message);
  for (let index = 0; index < browsers.length; index++) {
    try { console.error(`Test profile ${index}:`, await browsers[index].text()); await browsers[index].screenshot(`online-v2-failure-${index}`); } catch (_) {}
  }
  process.exitCode = 1;
}).finally(async () => {
  for (const browser of browsers) {
    try { await browser.close(); } catch (_) { browser.socket?.close(); }
  }
});
