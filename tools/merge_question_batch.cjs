// Merge a reviewed batch. Default is a dry run; --write saves validated additions.
const fs = require('node:fs');
const path = require('node:path');
const normalized = text => text.replace(/[\s\u064B-\u065F\u0640؟?!.,،]/g, '').toLowerCase();

function merge(bank, batch) {
  if (!['children_questions', 'adults_questions'].includes(batch.collection)) throw Error('Invalid collection');
  const result = bank.map(question => ({...question}));
  const ids = new Set(result.map(question => String(question.id)));
  if (ids.size !== result.length) throw Error('Duplicate bank IDs');
  const texts = new Set(result.map(question => normalized(question.question)));
  let nextId = Math.max(0, ...result.map(question => Number(question.id)));
  if (!Number.isSafeInteger(nextId)) throw Error('Bank IDs must be numeric');
  const added = [], skipped = [];
  for (const item of batch.questions) {
    const question = item.question?.trim();
    const options = item.options?.map(option => option.trim());
    if (!question || !Array.isArray(options) || options.length !== 3 ||
        options.some(option => !option) || new Set(options.map(normalized)).size !== 3 ||
        !Number.isInteger(item.correctOptionIndex) || item.correctOptionIndex < 0 || item.correctOptionIndex > 2 ||
        ![1, 2, 3].includes(item.level)) throw Error(`Invalid reviewed row: ${item.source || question}`);
    if (item.flagUrl && !/^https:\/\//.test(item.flagUrl)) throw Error('Invalid image URL');
    if (texts.has(normalized(question))) { skipped.push(item.source || question); continue; }
    texts.add(normalized(question));
    const record = {id: String(++nextId), question, options, correctOptionIndex: item.correctOptionIndex, flagUrl: item.flagUrl || null, level: item.level};
    result.push(record);
    added.push({id: record.id, source: item.source, question});
  }
  return {bank: result, added, skipped};
}

if (require.main === module) {
  const file = process.argv[2];
  if (!file) throw Error('Usage: node tools/merge_question_batch.cjs reviewed-batch.json [--write]');
  const batch = JSON.parse(fs.readFileSync(file, 'utf8'));
  const target = path.join(__dirname, '../data', `${batch.collection}.json`);
  const result = merge(JSON.parse(fs.readFileSync(target, 'utf8')), batch);
  if (process.argv.includes('--write')) fs.writeFileSync(target, JSON.stringify(result.bank, null, 2) + '\n');
  console.log(JSON.stringify({mode: process.argv.includes('--write') ? 'saved' : 'dry-run', collection: batch.collection, total: result.bank.length, added: result.added, skipped: result.skipped, pending: batch.pending?.length || 0}, null, 2));
}
module.exports = {merge};
