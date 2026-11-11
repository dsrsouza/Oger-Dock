import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const task = fs.readFileSync(path.join(root, 'contents/ui/components/TaskModelController.qml'), 'utf8');
const main = fs.readFileSync(path.join(root, 'contents/ui/main.qml'), 'utf8');
function extractFunction(code, name) {
    const match = new RegExp(`function ${name}\\([^)]*\\) \\{`).exec(code);
    assert.ok(match, `${name} exists`);
    const opening = match.index + match[0].length - 1;
    let depth = 0;
    for (let idx = opening; idx < code.length; ++idx) {
        if (code[idx] === '{') depth++;
        if (code[idx] === '}' && --depth === 0) return code.slice(match.index, idx + 1);
    }
    throw new Error('unbalanced function ' + name);
}
const fn = extractFunction(task, 'togglePromotedTrayApplication');
const rows = [
    {id: 'megasync', isWindow: true, isActive: true, isMinimized: false, isMinimizable: true},
    {id: 'other', isWindow: true, isActive: true, isMinimized: false, isMinimizable: true},
    {id: 'megasync', isWindow: true, isActive: false, isMinimized: false, isMinimizable: false},
    {id: 'syncthing', isWindow: true, isActive: true, isMinimized: false, isMinimizable: true},
];
let toggles = 0, restores = 0, native = 0;
let popupVisible = true;
const tasksModel = {
    count: rows.length,
    index(i) {return {valid: i >= 0 && i < rows.length, row: i};},
    data(idx, role) {return rows[idx.row][role[0].toLowerCase() + role.slice(1)];},
    requestToggleMinimized(idx) {toggles++; rows[idx.row].isMinimized = true; rows[idx.row].isActive = false;},
    requestActivate(idx) {restores++; rows[idx.row].isMinimized = false; rows[idx.row].isActive = true;},
};
const obj = {
    canonicalServiceId(id) {return String(id || '').toLowerCase();},
    isTrayTemporarilyPromoted(id) {return id === 'megasync' || id === 'syncthing';},
    trayOnlyIdentityForRow(row) {return rows[row].id;},
};
const ctx = vm.createContext({root:obj, tasksModel,
    TaskManager: {AbstractTasksModel: {
        IsWindow:'IsWindow', IsActive:'IsActive', IsMinimizable:'IsMinimizable', IsMinimized:'IsMinimized'
    }}});
vm.runInContext(fn, ctx);
obj.togglePromotedTrayApplication = ctx.togglePromotedTrayApplication;
const megaSni = () => {native++; popupVisible = !popupVisible; return true;};
assert.equal(obj.togglePromotedTrayApplication('other', [1], megaSni), false, 'unpromoted task not intercepted');
assert.equal(toggles + restores + native, 0);
// MEGAsync always receives the same native activation as a real KDE tray click,
// independent of TasksModel focus changing when the pointer moves over the dock.
assert.equal(obj.togglePromotedTrayApplication('megasync', [0], megaSni), true);
assert.equal(popupVisible, false, 'first dock click hides MEGA popup');
assert.equal(obj.togglePromotedTrayApplication('megasync', [0], megaSni), true);
assert.equal(popupVisible, true, 'next dock click shows same MEGA popup');
assert.equal(toggles + restores, 0, 'MEGA popup not force-minimized or duplicated');
assert.equal(native, 2);
assert.equal(obj.togglePromotedTrayApplication('megasync', [], megaSni), true);
assert.equal(native, 3, 'SNI-only state remains usable with no TaskManager window');
assert.equal(obj.togglePromotedTrayApplication('megasync', [1], megaSni), true);
assert.equal(native, 4, 'MEGA click never modifies an unrelated task row');
// When an SNI exporter is missing, a verified already-open window can still
// be toggled safely; no executable is launched.
assert.equal(obj.togglePromotedTrayApplication('megasync', [0], () => false), true);
assert.equal(toggles, 1);
assert.equal(obj.togglePromotedTrayApplication('megasync', [0], () => false), true);
assert.equal(restores, 1);
assert.equal(obj.togglePromotedTrayApplication('syncthing', [3], megaSni), true);
assert.equal(toggles, 2, 'other tray applications prefer the normal TaskManager toggle');
assert.equal(obj.togglePromotedTrayApplication('syncthing', [3], megaSni), true);
assert.equal(restores, 2);
assert.equal(native, 4, 'other managed apps did not trigger MEGA SNI');
assert.equal(obj.togglePromotedTrayApplication('megasync', [], () => false), false,
    'missing SNI and no managed row is a safe no-op');
// The dynamic delegate suppresses ALL hover popup surfaces for temporary SNI items.
const dynamicSection = main.slice(main.indexOf('id: activeApplicationRepeater'),
    main.indexOf('// Overflow is a synthetic entry.'));
assert.match(dynamicSection, /suppressTooltip: temporaryTrayPresentation/);
assert.match(dynamicSection, /mediaHoverControlsEnabled: !temporaryTrayPresentation/);
assert.match(dynamicSection, /onHoverEntered: function\(visualParent\) \{[\s\S]*?if \(temporaryTrayPresentation\) return[\s\S]*?scheduleTaskWindowsPopup/);
assert.match(dynamicSection, /onMediaControlsRequested: function\(visualParent\) \{\s*if \(temporaryTrayPresentation\) return/);
assert.match(dynamicSection, /onTemporaryTrayPresentationChanged: \{[\s\S]*?cancelPendingTaskWindowsPopup\(taskDockItemDelegate\)/);
assert.match(dynamicSection, /Component\.onCompleted: \{[\s\S]*?if \(!temporaryTrayPresentation\)/);
assert.match(dynamicSection, /onItemClicked: function\(\) \{[\s\S]*?togglePromotedTrayApplication\([\s\S]*?root\.activateTrayDesktopEntry/);
assert.match(main, /id: trayApplicationRepeater[\s\S]*?togglePromotedTrayApplication\([\s\S]*?activateTrayDesktopEntry/);
assert.match(dynamicSection, /root\.openPinnedTrayActions\(desktopId, visualParent,[\s\S]*?effectiveTemporaryTrayId/);
assert.doesNotMatch(fn, /requestNewInstance|requestClose|closeTaskRow|removeItem|kill/i);
console.log('R63.5 PASS: hover does not request popups/tooltips, click toggles existing MEGA task or native SNI without launching a duplicate, and context action preserved.');
