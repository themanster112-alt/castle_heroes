// Evidence checks support editorial review; they do not determine difficulty.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const normalize = text => text.normalize('NFKD').replace(/\p{M}/gu,'').replace(/ٱ/g,'ا').replace(/ى/g,'ي').replace(/ـ/g,'').replace(/[^ء-ي0-9]/g,'');
function calculate(node) {
  if (typeof node === 'number' && Number.isFinite(node)) return node;
  const args = node.args.map(calculate);
  switch(node.operator) {
    case '+': return args.reduce((a,b)=>a+b,0);
    case '-': assert.equal(args.length,2); return args[0]-args[1];
    case '*': return args.reduce((a,b)=>a*b,1);
    case '/': assert.equal(args.length,2); assert.notEqual(args[1],0); return args[0]/args[1];
    case 'pow': assert.equal(args.length,2); return Math.pow(...args);
    case 'abs': assert.equal(args.length,1); return Math.abs(args[0]);
    default: throw Error('Unsupported calculation operator');
  }
}
function verify(batch, verses) {
  const counts={religious:0,calculations:0};
  const texts=new Set();
  for (const row of batch.questions) {
    assert.ok(!texts.has(normalize(row.question)),'Duplicate question'); texts.add(normalize(row.question));
    assert.equal(row.options.length,3); assert.equal(new Set(row.options.map(normalize)).size,3);
    assert.ok([0,1,2].includes(row.correctOptionIndex)); assert.ok([1,2,3].includes(row.level));
    assert.ok(row.explanation?.trim()); assert.ok(row.sources?.length);
    if (row.quranEvidence) {
      counts.religious++;
      assert.ok([2,3].includes(row.level),'Religious additions must be medium/hard');
      for (const evidence of row.quranEvidence) {
        const text = verses ? verses.get(evidence.key) : evidence.text;
        assert.ok(text,`Missing verse ${evidence.key}`);
        assert.equal(text,evidence.text,`Source snapshot differs at ${evidence.key}`);
        assert.ok(normalize(text).includes(normalize(evidence.anchor)),`Verse anchor mismatch ${evidence.key}`);
        assert.ok(row.sources.includes(`https://quran.com/${evidence.key.replace(':','/')}`));
      }
    }
    if(row.calculation) {
      counts.calculations++;
      const result=calculate(row.calculation.expression);
      assert.equal(result,row.calculation.result,`Wrong calculation ${row.source}`);
      const answer=row.calculation.format==='time'
        ? `${Math.floor(result/60)}:${String(result%60).padStart(2,'0')}` : String(result);
      assert.equal(row.options[row.correctOptionIndex],answer);
    }
    if(row.primeChoices) {
      const prime=n=>Number.isInteger(n)&&n>=2&&Array.from({length:Math.max(0,Math.floor(Math.sqrt(n))-1)},(_,i)=>i+2).every(d=>n%d!==0);
      assert.deepEqual(row.options.map(value=>prime(Number(value))),row.options.map((_,i)=>i===row.correctOptionIndex));
    }
  }
  return counts;
}
if(require.main===module) {
  const files=process.argv.slice(2).filter(arg=>!arg.startsWith('--quran='));
  const source=process.argv.find(arg=>arg.startsWith('--quran='))?.slice('--quran='.length);
  const verses=source?new Map(JSON.parse(fs.readFileSync(source,'utf8')).verses.map(v=>[v.verse_key,v.text_imlaei])):null;
  for(const file of files) {
    const batch=JSON.parse(fs.readFileSync(file,'utf8'));
    console.log(`${file}: ${batch.questions.length} validated, ${JSON.stringify(verify(batch,verses))}${source?' against live-source snapshot':''}`);
  }
}
module.exports={verify,calculate};
