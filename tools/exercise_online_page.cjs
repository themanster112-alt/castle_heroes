// Interacts only with the dedicated headless smoke-test profile on port 8791.
(async () => {
  const guest = process.argv[2].startsWith('guest:');
  const pages = await (await fetch(`http://localhost:${guest ? 8792 : 8791}/json/list`)).json();
  const page = pages.find(page => page.type === 'page' && page.url.includes('castle-heroes-online-20261021.web.app'));
  if (!page) throw new Error('Smoke-test page not found');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();
  socket.onmessage = message => { const item = JSON.parse(message.data); pending.get(item.id)?.(item); pending.delete(item.id); };
  const command = (method, params = {}) => new Promise(resolve => {const key = ++id; pending.set(key, resolve); socket.send(JSON.stringify({id: key, method, params}));});
  await new Promise(resolve => socket.onopen = resolve);
  const label = process.argv[2].replace(/^guest:/, '');
  if (label === 'scroll') await command('Input.dispatchMouseEvent', {type: 'mouseWheel', x: 400, y: 300, deltaX: 0, deltaY: 700});
  const click = await command('Runtime.evaluate', {expression: `(() => {const label=${JSON.stringify(label)}; if(label==='scroll')return {x:0,y:0}; const list=Array.from(document.querySelectorAll('[role="button"], [role="checkbox"], [role="textbox"]'));const text=e=>(e.innerText || e.getAttribute('aria-label') || ''); const e=label.startsWith('input:')?document.querySelectorAll('input')[Number(label.split(':')[1])]:label.startsWith('check:')?document.querySelectorAll('[role="checkbox"]')[Number(label.split(':')[1])]:list.find(e=>text(e)===label)||list.find(e=>text(e).includes(label)); if(!e)return 'not found'; e.scrollIntoView({block:'center'}); e.focus(); e.click(); return {x:0,y:0};})()`, returnByValue: true});
  const point = click.result?.result?.value;
  if (typeof point !== 'object') throw new Error(`Control not found: ${label}`);
  if (process.argv[3]) await command('Input.insertText', {text: process.argv[3]});
  await new Promise(resolve => setTimeout(resolve, 1200));
  const result = await command('Runtime.evaluate', {expression: 'JSON.stringify({text:document.body.innerText,controls:Array.from(document.querySelectorAll("[role=button],[role=checkbox],[role=textbox]")).map(e=>({role:e.getAttribute("role"),text:e.innerText,label:e.getAttribute("aria-label")})),inputs:Array.from(document.querySelectorAll("input")).map(e=>({placeholder:e.placeholder,value:e.value}))})', returnByValue: true});
  console.log(result.result?.result?.value);
  socket.close();
})().catch(error => {console.error(error.message); process.exitCode = 1;});
