import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const rootPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(rootPath, name), 'utf8');
const task = read('contents/ui/components/TaskModelController.qml');
const main = read('contents/ui/main.qml');
const actions = read('contents/ui/components/DockContextActionsController.qml');
const setup = read('scripts-user/setup.sh');
assert.match(task, /property var temporarilyPromotedTrayIds: \(\{\}\)/);
assert.match(task, /function returnTemporaryTrayAppToTray\(desktopId\)/);
assert.match(task, /trayPromotionStartupGuard\.start\(\)/);
assert.match(task, /if \(focusChanged\) root\.observeTrayFocusChange\(\)/);
assert.match(task, /function onActiveTaskChanged\(\) \{[\s\S]*?root\.observeTrayFocusChange\(\)/);
assert.match(task, /SkipTaskbar\)\)\s*return !!trayId && root\.isTrayTemporarilyPromoted\(trayId\)/);
assert.match(main, /"id": -8, "label": i18nc\("@action:inmenu", "Return to system tray"\)/);
assert.match(main, /root\.openPinnedTrayActions\(desktopId, visualParent,\s*effectiveTemporaryTrayId\)/);
assert.match(main, /"id": -9, "label": i18nc\("@action:inmenu", "Native application menu…"\)/);
assert.match(actions, /"kind": "returnToTray"/);
assert.match(setup, /punchi_remove_obsolete_mega_kwin_integration/);
assert.doesNotMatch(setup, /punchi_maybe_enable_mega_kwin_integration|mega-popup-kwin\.sh/);
assert.ok(!fs.existsSync(path.join(rootPath, 'scripts-user/mega-popup-kwin.sh')));
assert.ok(!fs.existsSync(path.join(rootPath, 'kwin-scripts/org.oger.dock.mega-tray-popup')));
// Execute the real QML JS function bodies against an isolated TasksModel stub.
function extract(name) {
  const re = new RegExp(`function ${name}\\([^)]*\\) \\{`);
  const m = task.match(re); assert.ok(m, name);
  let start = m.index, depth=0, opened=false, end=-1;
  for(let i=m.index+m[0].length-1;i<task.length;i++) {
    if(task[i]==='{') {++depth;opened=true;}
    if(task[i]==='}') {--depth;if(opened&&depth===0){end=i+1;break;}}
  }
  assert.ok(end>start,name);
  return task.slice(start,end);
}
let taskActive='megasync';
const rows=[{id:'megasync',active:true,minimized:false}];
const fakeTaskModel={
  count:rows.length,
  index(i){return {valid:i>=0&&i<rows.length,i};},
  data(idx, role) {
    const row=rows[idx.i];
    if(role==='IsWindow')return true;
    if(role==='IsActive')return row.active;
    if(role==='IsMinimizable')return true;
    if(role==='IsMinimized')return row.minimized;
    return false;
  },
  requestToggleMinimized(idx){rows[idx.i].minimized=true;}
};
let refreshes=0;
const mock={
 temporarilyPromotedTrayIds:{},trayPromotionArmed:false,lastTrayFocusId:'',
 wheelSuppressedTrayPromotions:{}, pruneWheelSuppressionWhenIdle(){},
 canonicalServiceId(x){return String(x||'').toLowerCase();},
 trayOnlyIdentityForRow(i){return rows[i]?.id||'';},
 dockItems:[], dockItemMatchesTaskRow(){return false;},
 scheduleRefresh(){++refreshes;}
};
const ctx=vm.createContext({root:mock,tasksModel:fakeTaskModel,TaskManager:{AbstractTasksModel:{IsWindow:'IsWindow',IsActive:'IsActive',IsMinimizable:'IsMinimizable',IsMinimized:'IsMinimized'}}});
for(const name of ['isTrayTemporarilyPromoted','currentActiveTrayIdentity','observeTrayFocusChange','returnTemporaryTrayAppToTray']) {
  vm.runInContext(extract(name),ctx);
  mock[name]=ctx[name];
}
// Never promote merely because a task is active at startup.
mock.lastTrayFocusId=mock.currentActiveTrayIdentity();mock.trayPromotionArmed=true;
mock.observeTrayFocusChange();assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false);
rows[0].active=false;mock.observeTrayFocusChange();
rows[0].active=true;mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),true);
assert.equal(mock.returnTemporaryTrayAppToTray('unknown'),false);
assert.equal(mock.returnTemporaryTrayAppToTray('megasync'),true);
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false);
assert.equal(rows[0].minimized,true,'existing window should be minimized, not killed');
mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false,'no immediate re-promotion on redundant active event');
rows[0].active=false;mock.observeTrayFocusChange();
rows[0].active=true;mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),true,'a later restore is a new interaction');
assert.ok(refreshes>=3);
mock.dockItems=[{type:'app'}];
mock.dockItemMatchesTaskRow=()=>true;
assert.equal(mock.currentActiveTrayIdentity(),'', 'pinned items must not be promoted again');
mock.dockItems=[];
mock.trayOnlyIdentityForRow=()=>'';
assert.equal(mock.currentActiveTrayIdentity(),'', 'apps without verified SNI+user autostart are ineligible');
console.log('R63.3 PASS: verified focus transitions, reversible tray state, guarded minimization, native menu and obsolete KWin integration removal.');
