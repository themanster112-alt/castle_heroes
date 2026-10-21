// Read-only evidence that the proposed catalog is derived entirely from already-published assets.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
(async () => {
  const catalog = JSON.parse(fs.readFileSync('.dart_tool/online-catalog-v2.json', 'utf8'));
  let count = 0;
  for (const [age, name] of ['children_questions', 'adults_questions'].entries()) {
    const url = `https://castle-heroes-online-20261021.web.app/assets/data/${name}.json`;
    const response = await fetch(url);
    assert.equal(response.status, 200);
    const published = Buffer.from(await response.arrayBuffer());
    const local = fs.readFileSync(`data/${name}.json`);
    assert.equal(crypto.createHash('sha256').update(published).digest('hex'), crypto.createHash('sha256').update(local).digest('hex'));
    for (const item of JSON.parse(published.toString('utf8'))) {
      const row = catalog.questions[`${age}_${item.id}`];
      assert.equal(row.text, item.question.replace(/[\s\u064B-\u065F\u0640؟?!.,،]/g, '').toLowerCase());
      assert.equal(row.answer, item.correctOptionIndex);
      assert.deepEqual(Object.keys(row).sort(), ['age', 'answer', 'level', 'occurrences', 'text']);
      count++;
    }
    console.log(`MATCH ${url}: identical SHA-256 to local public asset; catalog texts/answer indices match.`);
  }
  assert.equal(Object.keys(catalog.questions).length, count);
  console.log(`Verified all ${count} catalog entries are derived from public assets already hosted on this same Firebase project. No credentials or player data are included.`);
})().catch(error => {console.error(error.message); process.exitCode = 1;});
