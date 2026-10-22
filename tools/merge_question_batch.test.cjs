const {test} = require('node:test');
const assert = require('node:assert/strict');
const {merge} = require('./merge_question_batch.cjs');
const {categoryFor} = require('./question_categories.cjs');
const question = {question:'A new question?', options:['one','two','three'],correctOptionIndex:1,level:3};
test('merge preserves existing IDs, skips normalized duplicates and is repeatable',()=>{
  const bank=[{...question,id:'42',question:'Existing question'}];
  const batch={collection:'adults_questions',questions:[question,{...question,question:'Existing question?'}]};
  const first=merge(bank,batch);
  assert.equal(bank.length,1);
  assert.equal(first.bank[0].id,'42');
  assert.equal(first.bank[1].id,'43');
  assert.equal(first.added.length,1);
  assert.equal(first.skipped.length,1);
  assert.equal(merge(first.bank,batch).added.length,0);
});
test('invalid options or answer reject the entire batch without mutating the bank',()=>{
  const bank=[];
  for(const invalid of [{...question,options:['a','a','b']},{...question,correctOptionIndex:3},{...question,level:null}]) {
    assert.throws(()=>merge(bank,{collection:'adults_questions',questions:[question,invalid]}));
    assert.equal(bank.length,0);
  }
});
test('reviewed categories and photo topics survive imports',()=>{
  const result=merge([],{collection:'adults_questions',questions:[{...question,category:'الدين الإسلامي والقرآن'}]});
  assert.equal(result.bank[0].category,'الدين والقرآن');
  assert.equal(categoryFor({question:'من اللاعب؟',flagUrl:'https://img.btolat.com/photo.jpg'}),'الرياضة');
});
