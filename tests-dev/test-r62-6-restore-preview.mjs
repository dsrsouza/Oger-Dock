// R62.6: regression test after R62.5 showed a BLANK Itens preview in Plasma.
// This is a JS + source contract test. Actual Qt/QML rendering needs a KDE test.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const itemsPage = read('contents/ui/config/ConfigItems.qml');
const preview = read('contents/ui/config/ConfigItemsMainView.qml');
const helper = read('contents/ui/config/code/configItemsFormHelper.js');
const workflow = read('contents/ui/config/code/configItemsWorkflowHelper.js');
const script = read('contents/ui/config/code/configItems.js');

assert.doesNotMatch(itemsPage, /initialPreviewBuildTimer|initialPreviewLoading|beginInitialPreviewBuild|appendInitialPreviewChunk/);
assert.doesNotMatch(helper, /initialPreviewBuildTimer|beginInitialPreviewBuild|cancelInitialPreviewBuild/);
assert.match(itemsPage, /Component\.onCompleted: Qt\.callLater\(loadItems\)/);
assert.match(workflow, /setItems\(result\.items, false\)/);
assert.match(itemsPage, /readonly property int previewModelTargetCount: items\.length/);
assert.match(preview, /root\.controller\.previewModelTargetCount/);
assert.match(preview, /configDockFolderStackLoader/);
assert.match(preview, /asynchronous:\s*true/, 'Async ONLY folder mosaic Loader');
assert.match(preview, /folderStackLoader.status !== Loader.Ready/, 'Folders remain visible during lazy mosaic creation');
assert.match(preview, /DockComponents\.FolderStackIcon/);
assert.match(helper, /itemModel\.append\(row\)/);
assert.match(helper, /row\.sourceIndex = index/);
assert.match(helper, /if \(markAsChanged !== false\)/);

// Execute production refresh helper with 35 items in its very first load.
// Under R62.5 this returned with zero visible rows awaiting a Timer.
const refreshSource = helper.slice(0, helper.indexOf('function refreshItemForm()'));
const list = [];
let changed = 0, formRefresh = 0, actionsRefresh = 0;
const ctx = vm.createContext({
  items: Array.from({length: 35}, (_, i) => ({type: 'app', name: `app-${i}`})),
  itemModel: {clear: () => {list.length = 0}, append: row => list.push(row)},
  ConfigItemsJS: {itemModelRow: item => ({title: item.name})},
  i18n: text => text, i18np: text => text, syncing: false,
  refreshItemForm: () => {formRefresh++}, refreshActions: () => {actionsRefresh++},
  markChanged: () => {changed++},
  StateHelper: {showSelectedItem: () => {}},
  Qt: {callLater: handler => handler()},
  console: {warn: () => {}},
});
vm.runInContext(refreshSource, ctx);
ctx.refreshFromItems(false);
assert.equal(list.length, 35, 'Initial full preview MUST exist before return');
assert.deepEqual(list.map(row => row.sourceIndex), Array.from({length: 35}, (_, i) => i));
assert.equal(changed, 0, 'Initial loading never writes the KCM configuration');
assert.equal(formRefresh, 1);
assert.equal(actionsRefresh, 1);
assert.equal(ctx.syncing, false);
ctx.refreshFromItems();
assert.equal(list.length, 35, 'Edits also have a complete projection');
assert.equal(changed, 1, 'Edits preserve Apply/Cancel behavior');
ctx.items = [];
ctx.refreshFromItems(false);
assert.equal(list.length, 0, 'A real empty configuration remains an empty configuration');
assert.equal(changed, 1);

// The byte-identical cache returns deep copies; draft mutations can't leak to
// later page visits, and changing the source bytes invalidates the cache.
const cleanJS = script.split('\n').filter(line => !/^\.pragma\b/.test(line) && !/^\.import\b/.test(line)).join('\n');
const jsContext = vm.createContext({console, Math, JSON, Number, String, Object, Array});
vm.runInContext(cleanJS, jsContext);
const jsonA = '[{"type":"app","name":"Firefox"}]';
const first = jsContext.parseJsonArrayForPreview(jsonA);
assert.equal(first.ok, true);
first.items[0].name = 'MUTATED';
const second = jsContext.parseJsonArrayForPreview(jsonA);
assert.equal(second.items[0].name, 'Firefox', 'Cached drafts must be isolated');
const third = jsContext.parseJsonArrayForPreview('[{"type":"app","name":"Brave"}]');
assert.equal(third.items[0].name, 'Brave');
assert.notEqual(second.items, third.items);

// Whole-KCM fades/transforms are not a cure for a slow category. They must
// never hide an empty model or introduce compositing latency.
for (const name of ['ConfigItems','ConfigGeneral','ConfigAspect','ConfigMouse',
                    'ConfigWindows','ConfigFiles','ConfigAdditionalShortcuts']) {
  const body = read(`contents/ui/config/${name}.qml`);
  assert.doesNotMatch(body, /ConfigPageEntrance\s*\{|kcmEntranceShift/);
  assert.match(body, /ConfigMaximizedWindowGuard/);
  assert.match(body, /diagnosticCategory:\s*"/);
}
const guard = read('contents/ui/config/components/ConfigMaximizedWindowGuard.qml');
assert.match(guard, /reportSlowPageSetup/);
assert.match(guard, /elapsed >= 75/);
assert.match(read('src/dockthemerepository.cpp'), /m_themeScanEpoch/,
  'Keep bounded async theme scan from R62.5');
assert.match(read('metadata.json'), /org\.kde\.plasma\.punchi-dock-remastered/,
  'Keep legacy plugin ID for existing installations');
console.log('R62.6 PASS: 35 first-load icons synchronous, isolated JSON cache, no whole-KCM animation, safe dirty flag and folder preview');
