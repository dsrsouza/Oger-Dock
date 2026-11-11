// R48/49: cached ready rows retained, shorter hover dwell in R49.
// Executes unmodified JS function bodies extracted from PunchiMenuNormal.qml
// against a small mocked QML context. This is NOT a QtQuick FPS benchmark.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(project,
    'contents/ui/components/punchimenu/PunchiMenuNormal.qml'), 'utf8');
const fan = fs.readFileSync(path.join(project,
    'contents/ui/components/FolderFanView.qml'), 'utf8');
const main = fs.readFileSync(path.join(project,
    'contents/ui/main.qml'), 'utf8');
const task = fs.readFileSync(path.join(project,
    'contents/ui/components/TaskModelController.qml'), 'utf8');

function extractFunction(name) {
    const start = source.indexOf(`    function ${name}(`);
    assert.ok(start >= 0, `missing ${name}`);
    const bodyStart = source.indexOf('{', start);
    let depth = 0;
    for (let i = bodyStart; i < source.length; ++i) {
        if (source[i] === '{') ++depth;
        if (source[i] === '}' && --depth === 0) return source.slice(start, i+1);
    }
    throw new Error(`Unbalanced function ${name}`);
}
assert.match(source,/id:\s*categoryHoverDelay[\s\S]{0,220}interval:\s*35/);
assert.match(source,/onHoveredChanged:[\s\S]{0,350}categoryHoverDelay\.restart\(\)/);
assert.match(source,/onClicked:[\s\S]{0,140}categoryHoverDelay\.stop\(\)/);
assert.doesNotMatch(source,/interval:\s*85\b/);
assert.match(source,/property var cachedCategoryRows:\s*\(\{\}\)/);
assert.match(source,/onHiddenApplicationIdsChanged:\s*\{\s*cachedCategoryRows = \(\{\}\)/);
assert.match(source,/onRevealHiddenApplicationsChanged:\s*\{\s*cachedCategoryRows = \(\{\}\)/);
assert.match(source,/onApplicationCatalogChanged:[\s\S]{0,250}cachedCategories = \(\{\}\)\s*cachedCategoryRows = \(\{\}\)/);
assert.match(source,/function openMenu\(\) \{[\s\S]{0,390}cachedCategories = \(\{\}\)\s*cachedCategoryRows = \(\{\}\)/);

const catalog = {
    '': [
        {name:'PhotoCraft',storageId:'photo.desktop',command:'photo',icon:'photo-icon'},
        {name:'FilmCraft',storageId:'film.desktop',command:'film',icon:'film-icon'},
        {name:'Secret app',storageId:'secret.desktop',command:'secret',icon:'secret-icon'}
    ],
    Graphics: [
        {name:'PhotoCraft',storageId:'photo.desktop',command:'photo',icon:'photo-icon'},
        {name:'Secret app',storageId:'secret.desktop',command:'secret',icon:'secret-icon'}
    ],
    AudioVideo: [
        {name:'FilmCraft',storageId:'film.desktop',command:'film',icon:'film-icon'}
    ],
    Office: [],
};
const calls = {native:0, normalize:0, publish:0, cancel:0};
const hidden = new Set(['secret.desktop']);
const context = vm.createContext({
    cachedCategories: {}, cachedCategoryRows: {},
    visibleCategoryApplications: [], allCachedApplications: [],
    activeCategoryKey:'All',activeCategoryTitle:'All',revealHiddenApplications:false,
    applicationErrorMessage:'',applicationLaunchPending:false,
    pendingCategoryKey:'',applicationsLoading:false, suppressSearchChange:false,
    searchField:{ text:'', clear() { this.text=''; } },
    systemDiscovery: { applicationsForCategory(key) {
        calls.native++;
        return catalog[key] || [];
    } },
    isApplicationHidden(id) { return hidden.has(id); },
    applicationShouldBeVisible(id) { return context.revealHiddenApplications || !hidden.has(id); },
    cancelInternalLayoutDrag() { calls.cancel++; },
    restorePreferredApplicationIndex() { calls.publish++; },
    console,
});
for (const fn of [
    'normalizedApplication','requestAllApplications','publishCategoryRows',
    'populateCachedCategory','selectCategory'
]) vm.runInContext(extractFunction(fn),context);
// Replace countable wrapper on actual function to measure normalization.
const normalizer = context.normalizedApplication;
context.normalizedApplication = (...args)=>{
    calls.normalize++;
    return normalizer(...args);
};

context.requestAllApplications();
assert.equal(calls.native,1);
assert.equal(calls.normalize,3);
assert.deepEqual(Array.from(context.visibleCategoryApplications, x=>x.appStorageId),
    ['photo.desktop','film.desktop']);
assert.equal(context.cachedCategoryRows.All.length,2);

context.selectCategory('Graphics','Gráficos',true);
assert.equal(calls.native,2);
assert.equal(context.visibleCategoryApplications.length,1);
const firstGraphics = context.visibleCategoryApplications;
const normalCountAfterFirstGraphics = calls.normalize;
context.selectCategory('AudioVideo','Multimídia',true);
assert.equal(calls.native,3);
context.selectCategory('Graphics','Gráficos',true);
assert.strictEqual(context.visibleCategoryApplications,firstGraphics);
assert.equal(calls.native,3,'no further native call for Graphics');
assert.equal(calls.normalize,normalCountAfterFirstGraphics + 1,
    'AudioVideo normalized once, Graphics not normalized twice');
const priorPublish = calls.publish;
context.selectCategory('Graphics','Gráficos',true);
assert.equal(calls.publish,priorPublish,'same-category hover should not reset model');

context.selectCategory('Office','Escritório',true);
assert.equal(context.visibleCategoryApplications.length,0);
const firstEmpty = context.visibleCategoryApplications;
context.selectCategory('Graphics','Gráficos',true);
context.selectCategory('Office','Escritório',true);
assert.strictEqual(context.visibleCategoryApplications,firstEmpty,
    'empty cached list is a valid cache hit');

// A hidden-apps change invalidates only normalized rows, not KService data.
context.cachedCategoryRows={};
hidden.delete('secret.desktop');
const callsBeforeHiddenRefresh=calls.native;
context.selectCategory('Graphics','Gráficos',false);
assert.equal(calls.native,callsBeforeHiddenRefresh);
assert.equal(context.visibleCategoryApplications.length,2);

// Revealing hidden apps must recompute rows while keeping the same icon source.
hidden.add('secret.desktop');
context.cachedCategoryRows={};
context.revealHiddenApplications=true;
context.selectCategory('Graphics','Gráficos',false);
assert.equal(context.visibleCategoryApplications.length,2);
assert.equal(context.visibleCategoryApplications[1].appHidden,true);
context.revealHiddenApplications=false;
context.cachedCategoryRows={};
context.selectCategory('Graphics','Gráficos',false);
assert.equal(context.visibleCategoryApplications.length,1);

// Search -> category resets search and still takes its cached native path.
context.searchField.text='special query';
const nativeBeforeSearch=calls.native;
context.selectCategory('AudioVideo','Multimídia',true);
assert.equal(context.searchField.text,'');
assert.equal(calls.native,nativeBeforeSearch);

// Regression scenario: an updated catalog while a non-All category is shown
// must not seed the currently selected category with All's applications.
context.selectCategory('Graphics','Gráficos',true);
context.cachedCategories={};
context.cachedCategoryRows={};
context.requestAllApplications();
assert.equal(context.cachedCategoryRows.Graphics,undefined);
context.selectCategory('Graphics','Gráficos',false);
assert.equal(context.visibleCategoryApplications.length,1);
assert.equal(context.cachedCategoryRows.All.length,2);

// R45 pre-popup freeze and R47 high-definition fan remain in place.
assert.match(main,/onFolderPopupOpening: function\(itemData\) \{[\s\S]*?taskController.beginFanPresentationHold\(\)/);
assert.match(task,/enabled: root.diagnosticTaskObservationEnabled && !root.fanPresentationHold/);
assert.match(fan,/objectName: "folderFanIconViewport-"/);
assert.match(fan,/width: root.iconSize \* 2\s+height: width\s+scale: 0\.5/);
assert.match(fan,/angle: -fanDelegate.rowLean/);
console.log('R49 offline PASS: 35ms hover, cached normalized category rows, invalidation, search, empty categories, no duplicate GridView resets, R45/R47 guards');
