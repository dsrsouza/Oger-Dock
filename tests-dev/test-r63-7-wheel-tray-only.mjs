import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(project,
    'contents/ui/components/TaskModelController.qml'), 'utf8');
function extract(name) {
    const matched = source.match(new RegExp(`function ${name}\\([^)]*\\) \\{`));
    assert.ok(matched, `${name} must exist`);
    let depth = 0;
    const start = matched.index;
    for (let i = source.indexOf('{', start); i < source.length; ++i) {
        if (source[i] === '{') depth++;
        if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
    }
    throw new Error(`${name} has unmatched braces`);
}

const windows = [
    {id: 'firefox', uuid: 'firefox-1', active: true, minimized: false},
    {id: 'dolphin', uuid: 'dolphin-1', active: false, minimized: false},
    {id: 'megasync', uuid: 'mega-1', active: false, minimized: false},
];
const idKey = id => String(id || '').toLowerCase().replace(/\.desktop$/, '');
const actions = [];
const tasksModel = {
    get count() { return windows.length; },
    index(row) { return {row, valid: row >= 0 && row < windows.length}; },
    data(index, role) {
        const w = windows[index.row];
        if (role === 'IsWindow') return true;
        if (role === 'SkipTaskbar') return false;
        if (role === 'IsActive') return w.active;
        if (role === 'IsMinimized') return w.minimized;
        if (role === 'IsMinimizable') return true;
        if (role === 'IsMaximized') return false;
        if (role === 'IsMaximizable') return true;
        return false;
    },
    requestActivate(index) {
        actions.push('activate:' + windows[index.row].id);
        windows.forEach(w => w.active = false);
        windows[index.row].active = true;
        windows[index.row].minimized = false;
    },
    requestToggleMinimized(index) {
        actions.push('minimize:' + windows[index.row].id);
        windows[index.row].minimized = true;
    }
};
const root = {
    dockItems: [{type:'dynamic-applications'}],
    visibleTaskRows: [{rows:[0,1]}], overflowTaskRows: [],
    trayAutostartPolicy: {userAutostartTrayOnly(id) {
        return ['megasync', 'telegramdesktop'].includes(idKey(id));
    }},
    temporarilyPromotedTrayIds: {},
    canonicalServiceId:idKey,
    isTrayTemporarilyPromoted(id) {return !!this.temporarilyPromotedTrayIds[idKey(id)];},
    trayOnlyIdentityForRow(row) {
        return this.trayAutostartPolicy && this.trayAutostartPolicy.userAutostartTrayOnly(windows[row].id)
            ? idKey(windows[row].id) : '';
    },
    trayIdentityKeys() {return ['megasync', 'telegramdesktop', 'qbittorrent'];},
    resolvedNotifierServiceId(id) {return idKey(id) === 'mega' ? 'megasync' : idKey(id);},
    taskWindowUuidForRow(row) {return windows[row].uuid;},
    taskAppIdForRow(row) {return windows[row].id;},
    normalizeApplicationId:idKey,
    dockItemMatchesTaskRow(item, row) {return idKey(item.appId) === idKey(windows[row].id);},
    dockItemMatchesNotifierId(item, id) {return idKey(item.appId) === this.resolvedNotifierServiceId(id);},
    dockItemApplicationId(item) {return item.appId || '';},
    trayActivator(id) {actions.push('sni:' + id); return true;},
    suppressTrayPromotionForWheel(id) { /* identity suppression tested separately in R63.4 */ },
    wheelCycleKeys: [], wheelCurrentKey: '',
};
const wheelCycleTimer = {running:false, restart() {this.running=true;}};
const roles = {
    IsWindow:'IsWindow',SkipTaskbar:'SkipTaskbar',IsActive:'IsActive',
    IsMinimized:'IsMinimized',IsMinimizable:'IsMinimizable',
    IsMaximized:'IsMaximized',IsMaximizable:'IsMaximizable'
};
const ctx = vm.createContext({root,tasksModel,wheelCycleTimer,
    taskWindowUuidForRow: row => root.taskWindowUuidForRow(row),
    taskAppIdForRow: row => root.taskAppIdForRow(row),
    TaskManager:{AbstractTasksModel:roles},
    WindowScrollNavigation:{
        planWindowTransition(candidates, previousKey, nextKey) {
            if (!candidates.some(c => c.key === nextKey)) return null;
            return {previousKey, targetKey:nextKey};
        },
        advanceCycle(keys, current, direction) {
            const pos = keys.indexOf(current);
            return keys[pos + direction] || '';
        },
        reconcileCycle(previous, known) {return known;},
    }
});
Object.defineProperty(ctx, 'wheelCycleKeys', {
    get(){return root.wheelCycleKeys;}, set(v){root.wheelCycleKeys=v;}, configurable:true
});
Object.defineProperty(ctx, 'wheelCurrentKey', {
    get(){return root.wheelCurrentKey;}, set(v){root.wheelCurrentKey=v;}, configurable:true
});
for (const name of ['excludeTrayOnlyFromWheel','wheelCandidates',
    'applyWheelWindowTransition','cycleOpenWindow']) {
    vm.runInContext(extract(name), ctx);
    root[name] = ctx[name];
}
const keys = () => Array.from(root.wheelCandidates(), c => c.key);

// Both the visible MEGA window and SNI-only Telegram are excluded before scroll.
assert.deepEqual(keys(), ['window:firefox-1','window:dolphin-1','tray:qbittorrent']);
assert.equal(root.cycleOpenWindow(1), true);
assert.ok(actions.includes('activate:dolphin'));
assert.ok(!actions.some(a => a.includes('mega') || a.includes('telegram')),
    'scroll from Firefox must not activate tray-only autostart apps');
assert.equal(root.cycleOpenWindow(1), true, 'non-autostart SNI keeps existing wheel behavior');
assert.ok(actions.includes('sni:qbittorrent'));
assert.equal(root.cycleOpenWindow(-1), true, 'reverse scrolling restores the preceding window');
assert.equal(actions.at(-1), 'activate:dolphin');
assert.ok(!actions.some(a => a.includes('mega') || a.includes('telegram')));

// If a previously eligible tray item disappears from the candidate list
// during a wheel gesture, the frozen cursor must reconcile without SNI click.
root.wheelCycleKeys = ['window:firefox-1', 'tray:megasync', 'window:dolphin-1'];
root.wheelCurrentKey = 'window:firefox-1';
wheelCycleTimer.running = true;
const beforeReconciliation = actions.length;
assert.equal(root.cycleOpenWindow(1), true);
assert.ok(actions.length > beforeReconciliation, 'reconciled scroll must still activate a window');
assert.equal(actions.at(-1), 'activate:dolphin');
assert.ok(!root.wheelCycleKeys.includes('tray:megasync'));
assert.ok(!actions.some(a => a === 'sni:megasync'));

// Explicitly promoted tray apps become valid wheel candidates again.
root.temporarilyPromotedTrayIds = {megasync:true,telegramdesktop:true};
assert.ok(keys().includes('tray:megasync'));
assert.ok(keys().includes('tray:telegramdesktop'));
root.temporarilyPromotedTrayIds = {};

// Pinning a tray app keeps its existing wheel behavior, with or without a window.
root.dockItems = [{type:'app',appId:'megasync'}, {type:'app',appId:'telegramdesktop'},
                  {type:'dynamic-applications'}];
assert.ok(keys().includes('tray:megasync'));
assert.ok(keys().includes('tray:telegramdesktop'));
root.dockItems = [{type:'dynamic-applications'}];

// A verified alias must not bypass the autostart-only filter.
root.trayIdentityKeys = () => ['mega','qbittorrent'];
assert.ok(!keys().includes('tray:mega'));
root.trayIdentityKeys = () => ['megasync','telegramdesktop','qbittorrent'];

// Without an autostart rule, legacy SNI navigation remains possible.
root.trayAutostartPolicy = null;
assert.ok(keys().includes('tray:megasync'));
assert.ok(keys().includes('tray:telegramdesktop'));
root.trayAutostartPolicy = {userAutostartTrayOnly(id) {
    return ['megasync','telegramdesktop'].includes(idKey(id));
}};

// An explicitly running non-autostart app remains available on the wheel.
assert.ok(keys().includes('tray:qbittorrent'));
// Reaching an edge must not wrap or activate an excluded app.
root.wheelCycleKeys = [];
root.wheelCurrentKey = 'tray:qbittorrent';
wheelCycleTimer.running = false;
const before = actions.length;
assert.equal(root.cycleOpenWindow(1), false);
assert.equal(actions.length, before);

console.log('R63.7 PASS: scroll excludes unpromoted autostart SNI (windows + no-window); promoted/pinned/ordinary tray remain eligible; no unwanted MEGA activation or wrap.');
