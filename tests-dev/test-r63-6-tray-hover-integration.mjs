import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

// Regression R63.6: exercise the *actual* QML data model -> projection ->
// dynamic-delegate guards/handlers. Older tests called the click helper in
// isolation, missing that taskDataForEntry() discarded temporaryTrayId.
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const load = file => fs.readFileSync(path.join(project, file), 'utf8');
const modelQml = load('contents/ui/components/TaskModelController.qml');
const mainQml = load('contents/ui/main.qml');
const begin = mainQml.indexOf('id: activeApplicationRepeater');
const end = mainQml.indexOf('// Overflow is a synthetic entry.', begin);
assert.ok(begin > 0 && end > begin);
const delegate = mainQml.slice(begin, end);

function balancedBody(code, openingBrace) {
    let depth = 0;
    for (let i = openingBrace; i < code.length; i++) {
        if (code[i] === '{') depth++;
        if (code[i] === '}' && --depth === 0) return i + 1;
    }
    throw new Error('unbalanced JS function');
}
function modelFunction(name) {
    const re = new RegExp(`\\bfunction ${name}\\([^)]*\\) \\{`);
    const match = re.exec(modelQml);
    assert.ok(match, `missing model function ${name}`);
    const brace = match.index + match[0].length - 1;
    return modelQml.slice(match.index, balancedBody(modelQml, brace));
}
function delegateHandler(name, signature) {
    const token = `${name}: function(${signature}) {`;
    const position = delegate.indexOf(token);
    assert.ok(position >= 0, `${name} not found in dynamic delegate`);
    const beginFn = position + name.length + 2;
    const brace = position + token.length - 1;
    return delegate.slice(beginFn, balancedBody(delegate, brace));
}
function delegateBinding(property, nextProperty) {
    const token = `readonly property ${property}:`;
    const start = delegate.indexOf(token);
    assert.ok(start >= 0, `${property} binding not found`);
    const end = delegate.indexOf(nextProperty, start + token.length);
    assert.ok(end > start, `missing boundary after ${property}`);
    return delegate.slice(start + token.length, end).trim();
}

const rows = [
    {appId:'megasync', name:'MEGAsync', active:true, minimized:false, maximized:false,
        icon:'mega', windowUuid:'win-mega', isWindow:true, skipTaskbar:true},
    {appId:'firefox', name:'Firefox', active:false, minimized:false, maximized:false,
        icon:'firefox', windowUuid:'win-firefox', isWindow:true, skipTaskbar:false}
];
const TaskManager = { AbstractTasksModel: {
    AppName: 'AppName', IsActive: 'IsActive', IsDemandingAttention: 'IsDemandingAttention',
    IsWindow: 'IsWindow', IsMinimized: 'IsMinimized', IsMaximized: 'IsMaximized'
}};
const tasksModel = {
    index(row) {return {row, valid: row >= 0 && row < rows.length};},
    data(index, role) {
        const item = rows[index.row];
        if (!item) return null;
        const values = {
            AppName:item.name, IsActive:item.active, IsDemandingAttention:false,
            IsWindow:item.isWindow, IsMinimized:item.minimized, IsMaximized:item.maximized
        };
        return values[role] ?? null;
    }
};
const modelContext = vm.createContext({
    Qt:{DisplayRole: 'DisplayRole'}, TaskManager, tasksModel,
    taskAppIdForRow: i => rows[i].appId,
    taskRawLauncherUrlForRow: i => `applications:${rows[i].appId}.desktop`,
    taskLauncherUrlForRow: i => `applications:${rows[i].appId}.desktop`,
    resolvedTaskServiceIdForRow: i => rows[i].appId,
    taskIconSourceForRow: i => rows[i].icon,
    taskWindowUuidForRow: i => rows[i].windowUuid,
    isTaskRowActive: i => rows[i].active,
    root: {
        trayOnlyIdentityForRow: i => i === 0 ? 'megasync' : '',
        isTrayTemporarilyPromoted: id => id === 'megasync'
    }
});
for (const name of ['buildVisibleTaskEntryForRow', 'taskDataForEntry']) {
    vm.runInContext(modelFunction(name), modelContext);
}
const rawMega = modelContext.buildVisibleTaskEntryForRow(0);
const projectedMega = modelContext.taskDataForEntry(rawMega);
assert.equal(rawMega.temporaryTrayId, 'megasync', 'SNI identity discovered for promoted task');
assert.equal(projectedMega.temporaryTrayId, 'megasync',
    'SNI identity must reach delegate after model projection (R63.5 regression)');
assert.equal(projectedMega.count, 1);
assert.equal(projectedMega.name, 'MEGAsync');
const rawBrowser = modelContext.buildVisibleTaskEntryForRow(1);
const projectedBrowser = modelContext.taskDataForEntry(rawBrowser);
assert.equal(projectedBrowser.temporaryTrayId, '', 'ordinary app is never treated as SNI');
assert.equal(modelContext.taskDataForEntry({...rawMega, firstRow:999}).temporaryTrayId,
    'megasync', 'invalidated row must not erase identity while entry remains');
assert.equal(modelContext.taskDataForEntry({...rawMega, rows:[]}).temporaryTrayId,
    'megasync', 'temporary row disappearance does not erase entry identity');
assert.equal(modelContext.taskDataForEntry(null).temporaryTrayId, '',
    'invalid entry cannot create a phantom promotion');

// Compute the exact two QML bindings on the two actual projections.
const effectiveExpr = delegateBinding('string effectiveTemporaryTrayId',
    'readonly property bool temporaryTrayPresentation:');
const presentationLine = delegate.match(/readonly property bool temporaryTrayPresentation:\s*([^\n]+)/);
assert.ok(presentationLine, 'presentation must depend on effective ID');
function presentation(modelData, taskData) {
    const ctx = vm.createContext({modelData, taskData});
    const effectiveTemporaryTrayId = vm.runInContext(effectiveExpr, ctx);
    ctx.effectiveTemporaryTrayId = effectiveTemporaryTrayId;
    return {
        id: effectiveTemporaryTrayId,
        isTemporary: vm.runInContext(presentationLine[1], ctx)
    };
}
assert.deepEqual(presentation(rawMega, projectedMega), {id:'megasync', isTemporary:true});
assert.deepEqual(presentation(rawBrowser, projectedBrowser), {id:'', isTemporary:false});
assert.equal(presentation(rawMega, {...projectedMega, temporaryTrayId:''}).isTemporary, true,
    'independent guard reads original model even if the projection drops the ID again');

let previews = 0, mediaPreviews = 0, toggles = 0, nativeActivation = 0;
let regularActivations = 0, closeCalls = 0;
const handlerContext = vm.createContext({
    modelData:rawMega, taskData:projectedMega, effectiveTemporaryTrayId:'megasync',
    temporaryTrayPresentation:true, itemName:'MEGAsync', taskDockItemDelegate:{},
    dockConfig:{mediaControlsOnHover:true, windowPreviewStyle:'full'},
    popupCoordinator:{
        closeAllPopups() {closeCalls++;},
        scheduleTaskWindowsPopup(name, taskRows, parent, media) {
            if (media) mediaPreviews++; else previews++;
        }
    },
    root:{
        trayDesktopIdForItem() {return 'megasync';},
        activateTrayDesktopEntry(id) {assert.equal(id,'megasync'); nativeActivation++; return true;}
    },
    trayWindowBridge:{noteUserInteraction() {}},
    taskController:{
        isTrayTemporarilyPromoted(id) {return id==='megasync';},
        togglePromotedTrayApplication(id, entries, callback) {
            assert.equal(id,'megasync');
            assert.equal(entries.length,1);
            toggles++;
            callback();
        },
        activateTaskRow() {regularActivations++;},
        activatePreferredTaskRow() {regularActivations++;}
    }
});
const hover = vm.runInContext(`(${delegateHandler('onHoverEntered', 'visualParent')})`, handlerContext);
const mediaHover = vm.runInContext(`(${delegateHandler('onMediaControlsRequested', 'visualParent')})`, handlerContext);
const click = vm.runInContext(`(${delegateHandler('onItemClicked', '')})`, handlerContext);
hover({}); mediaHover({});
assert.equal(previews,0,'hover must not open window preview for promoted MEGA');
assert.equal(mediaPreviews,0,'hover must not show media overlay for promoted MEGA');
click();
assert.equal(toggles,1,'click must reach promoted SNI path');
assert.equal(nativeActivation,1,'SNI activation must be used, not normal TaskManager click');
assert.equal(regularActivations,0);
assert.equal(closeCalls,1);
assert.match(delegate, /suppressTooltip:\s*temporaryTrayPresentation/);
assert.match(delegate, /mediaHoverControlsEnabled:\s*!temporaryTrayPresentation/);
assert.match(delegate, /onTemporaryTrayPresentationChanged:\s*\{[\s\S]*?cancelPendingTaskWindowsPopup/);
assert.match(delegate, /root\.openPinnedTrayActions\(desktopId, visualParent,\s*effectiveTemporaryTrayId\)/);

handlerContext.modelData = rawBrowser;
handlerContext.taskData = projectedBrowser;
handlerContext.effectiveTemporaryTrayId = '';
handlerContext.temporaryTrayPresentation = false;
handlerContext.itemName = 'Firefox';
hover({}); mediaHover({}); click();
assert.equal(previews,1,'normal app hover preview still functions');
assert.equal(mediaPreviews,1,'normal app media hover still functions');
assert.equal(regularActivations,1,'normal app click still uses TaskManager');
assert.equal(nativeActivation,1,'normal app must not activate MEGA SNI');
console.log('R63.6 PASS: real TasksModel entry -> projected data -> delegate hover/click, invalid-row fallback, no regressions to normal app.');
