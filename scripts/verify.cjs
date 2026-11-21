const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const legacy = require('../reference/legacy-review.js');
const swift = read('ios/PandaWord/WordModel.swift');
const ark = read('harmony/entry/src/main/ets/model/Api.ets');
const swiftIntervals = JSON.parse(swift.match(/let intervals = (\[[^\]]+\])/)[1]);
const arkIntervals = JSON.parse(ark.match(/intervals: number\[\] = (\[[^\]]+\])/)[1]);
assert.deepEqual(swiftIntervals, arkIntervals);
const dueFunction = ark.slice(ark.indexOf('export function due('), ark.indexOf('export function definition('))
  .replace('export ', '').replace('item: Word, now: number', 'item, now').replace('): boolean', ')');
const context = { intervals: arkIntervals }; vm.createContext(context);
vm.runInContext(dueFunction, context);
let cases = 0;
for (let level = 0; level < 20; level++) {
  for (const elapsed of [0, 0.5, 1, swiftIntervals[level] - 0.00001, swiftIntervals[level], swiftIntervals[level] + 1]) {
    const now = Date.now(), record = { word: 'sample', level, reviewTime: now - elapsed * 86400000 };
    const expected = legacy([record]).length > 0;
    assert.equal(context.due(record, now), expected, 'ArkUI legacy parity, level ' + level);
    const swiftResult = now - record.reviewTime >= swiftIntervals[level] * 86400000;
    assert.equal(swiftResult, expected, 'Swift interval parity, level ' + level);
    cases++;
  }
}
for (const vector of JSON.parse(read('reference/aes-vectors.json'))) {
  const input = Buffer.from(vector.plain, 'utf8');
  const padded = Buffer.alloc(Math.ceil(input.length / 16) * 16); input.copy(padded);
  const key = Buffer.from('gww417038_x8888x');
  const cipher = crypto.createCipheriv('aes-128-cbc', key, key); cipher.setAutoPadding(false);
  assert.equal(Buffer.concat([cipher.update(padded), cipher.final()]).toString('base64'), vector.base64);
}
function walk(p) { return fs.readdirSync(p, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(p, e.name)) : [path.join(p, e.name)]); }
const files = walk(root); let configs = 0;
for (const file of files) {
  const text = fs.readFileSync(file, 'utf8');
  if (/\.(json|json5)$/.test(file)) { JSON.parse(text); configs++; }
  if (/\.(swift|ets|yml|json5)$/.test(file)) { assert(!text.includes('???'), 'Damaged text: ' + file); }
}
const project = read('ios/PandaWord.xcodeproj/project.pbxproj');
const declared = new Set([...project.matchAll(/^([A-F0-9]{24}) = /gm)].map(m => m[1]));
for (const ref of project.match(/\b[A-F0-9]{24}\b/g)) { assert(declared.has(ref), 'Broken Xcode object reference: ' + ref); }
for (const source of project.matchAll(/path = ([A-Za-z]+\.swift);/g)) { assert(fs.existsSync(path.join(root, 'ios/PandaWord', source[1]))); }
const moduleConfig = JSON.parse(read('harmony/entry/src/main/module.json5'));
assert.equal(moduleConfig.module.abilities[0].srcEntry, './ets/entryability/EntryAbility.ets');
for (const page of JSON.parse(read('harmony/entry/src/main/resources/base/profile/main_pages.json')).src) { assert(fs.existsSync(path.join(root, 'harmony/entry/src/main/ets', page + '.ets'))); }
assert(read('ios/PandaWord/Privacy.swift').includes('2024'));
assert(read('harmony/entry/src/main/ets/model/Privacy.ets').includes('2024'));
console.log('PASS: ' + cases + ' review boundary cases; 5 legacy CryptoJS AES vectors; ' + configs + ' JSON configs; Xcode references; ArkUI page entry; UTF-8 integrity.');
console.log('Native compilation, encryption execution on-device, signing and backend integration are not covered by this check.');
