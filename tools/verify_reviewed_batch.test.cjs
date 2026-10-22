const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {verify,calculate}=require('./verify_reviewed_batch.cjs');
test('reviewed batches preserve medium/hard religion and their evidence',()=>{
  for(const age of ['children','adults']) {
    const batch=JSON.parse(fs.readFileSync(`data/imports/verified_60_2026-10-22_${age}.json`,'utf8'));
    assert.equal(batch.questions.length,30);
    assert.equal(verify(batch).religious,15);
    const easy=structuredClone(batch);
    easy.questions.find(q=>q.quranEvidence).level=1;
    assert.throws(()=>verify(easy));
    const wrong=structuredClone(batch);
    wrong.questions.find(q=>q.calculation).calculation.result++;
    assert.throws(()=>verify(wrong));
    const badVerse=structuredClone(batch);
    badVerse.questions.find(q=>q.quranEvidence).quranEvidence[0].anchor='عبارة غير موجودة بالمصدر';
    assert.throws(()=>verify(badVerse));
  }
});
test('calculation interpreter rejects unknown operations and division by zero',()=>{
  assert.throws(()=>calculate({operator:'eval',args:[]}));
  assert.throws(()=>calculate({operator:'/',args:[1,0]}));
});
