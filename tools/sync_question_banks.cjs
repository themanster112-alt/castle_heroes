// Public reads first. Update only explicit difficulty on existing documents;
// create new questions without overwriting any existing text or answer.
const fs = require('node:fs');
const path = require('node:path');
const project = 'castle-heroes-20261014';
const root = `projects/${project}/databases/(default)/documents`;
const encode = value => value === null ? {nullValue:null} : Array.isArray(value) ? {arrayValue:{values:value.map(encode)}} : typeof value === 'number' ? {integerValue:String(value)} : {stringValue:value};
const decode = value => 'nullValue' in value ? null : 'integerValue' in value ? Number(value.integerValue) : 'arrayValue' in value ? (value.arrayValue.values || []).map(decode) : value.stringValue;
(async () => {
  const writes = [];
  for (const collection of ['children_questions','adults_questions']) {
    const remote = new Map(); let page;
    do {
      const url = new URL(`https://firestore.googleapis.com/v1/${root}/${collection}`);
      url.searchParams.set('pageSize','300'); if(page) url.searchParams.set('pageToken',page);
      const response = await fetch(url); const result = await response.json();
      if (!response.ok) throw Error(`Public bank read failed: ${response.status}`);
      for (const doc of result.documents || []) remote.set(doc.name.split('/').pop(),doc);
      page = result.nextPageToken;
    } while(page);
    let added = 0, updated = 0;
    const bank = JSON.parse(fs.readFileSync(path.join(__dirname,`../data/${collection}.json`),'utf8'));
    for (const question of bank) {
      const {id,...fields} = question;
      if (![1,2,3].includes(fields.level)) throw Error(`Missing explicit difficulty: ${collection}/${id}`);
      const doc = remote.get(id), name = `${root}/${collection}/${id}`;
      if (doc) {
        for (const key of ['question','options','correctOptionIndex','flagUrl']) {
          if (JSON.stringify(decode(doc.fields[key] || {nullValue:null})) !== JSON.stringify(fields[key])) throw Error(`Remote content differs: ${collection}/${id}/${key}; review before syncing`);
        }
        if (decode(doc.fields.level || {nullValue:null}) !== fields.level) {
          writes.push({update:{name,fields:{level:encode(fields.level)}},updateMask:{fieldPaths:['level']},currentDocument:{updateTime:doc.updateTime}}); updated++;
        }
      } else {
        writes.push({update:{name,fields:Object.fromEntries(Object.entries({...fields,questionNumber:Number(id)}).map(([key,value])=>[key,encode(value)]))},currentDocument:{exists:false}}); added++;
      }
    }
    console.log(`${collection}: ${added} additions, ${updated} difficulty updates; existing text and answers preserved.`);
  }
  if(!process.argv.includes('--write')) {console.log(`Dry run: ${writes.length} writes, no remote changes.`); return;}
  if(!writes.length) {console.log('Already synchronized.'); return;}
  const auth = require(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/auth.js'));
  const account = auth.getGlobalDefaultAccount(); if(!account) throw Error('Firebase login required');
  const token = await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
  for(let i=0;i<writes.length;i+=200) {
    const response = await fetch(`https://firestore.googleapis.com/v1/${root}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:JSON.stringify({writes:writes.slice(i,i+200)})});
    const result = await response.json(); if(!response.ok) throw Error(`Sync failed: ${response.status} ${result.error?.message}`);
  }
  console.log(`Synchronized ${writes.length} reviewed question changes.`);
})().catch(error=>{console.error(error.message);process.exitCode=1;});
