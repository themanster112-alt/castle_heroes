const fs = require('node:fs');
(async () => {
  const pages = await (await fetch(`http://localhost:${Number(process.argv[2] || 8791)}/json/list`)).json();
  const page = pages.find(page => page.type === 'page' && page.url.includes('castle-heroes-online-20261021.web.app'));
  if (!page) throw new Error('Online test page not found');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();
  socket.onmessage = message => { const item = JSON.parse(message.data); if (pending.has(item.id)) { pending.get(item.id)(item); pending.delete(item.id); } };
  const command = (method, params = {}) => new Promise(resolve => { const key = ++id; pending.set(key, resolve); socket.send(JSON.stringify({id: key, method, params})); });
  await new Promise(resolve => socket.onopen = resolve);
  if (process.argv[3] === '--close') {
    const cleanup = await command('Runtime.evaluate', {expression: '(async()=>{const app=window.firebase_core?.getApp("online");if(!app)return "No temporary player";const auth=window.firebase_auth.getAuth(app);if(auth.currentUser)await window.firebase_auth.deleteUser(auth.currentUser);return "Temporary Firebase player removed";})()', awaitPromise: true, returnByValue: true});
    console.log(cleanup.result?.result?.value || 'Smoke-test profile closed');
    await command('Browser.close');
    socket.close();
    return;
  }
  await command('Runtime.evaluate', {expression: 'document.querySelector("flt-semantics-placeholder")?.click()'});
  await new Promise(resolve => setTimeout(resolve, 1000));
  const result = await command('Runtime.evaluate', {expression: 'JSON.stringify({text:document.body.innerText,buttons:Array.from(document.querySelectorAll("[role=button]")).map(e=>({text:e.innerText,label:e.getAttribute("aria-label"),rect:e.getBoundingClientRect().toJSON()})),inputs:Array.from(document.querySelectorAll("input")).map(e=>({placeholder:e.placeholder,value:e.value,rect:e.getBoundingClientRect().toJSON()}))})', returnByValue: true});
  console.log(result.result?.result?.value || JSON.stringify(result));
  const screenshot = await command('Page.captureScreenshot', {format: 'png'});
  if (screenshot.result?.data) fs.writeFileSync('.dart_tool/online-smoke.png', Buffer.from(screenshot.result.data, 'base64'));
  socket.close();
})().catch(error => {console.error(error.message); process.exitCode = 1;});
