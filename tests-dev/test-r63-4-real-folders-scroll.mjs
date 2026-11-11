import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const rootPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(rootPath, p), 'utf8');
const model = read('contents/ui/components/TaskModelController.qml');
const form = read('contents/ui/config/ConfigFolderPopups.qml');
const wrapper = read('contents/ui/config/ConfigFolderAppearance.qml');
const main = read('contents/ui/main.qml');
const registry = read('contents/ui/config/code/configFolderRegistry.js');

// Use the actual folder registry functions with the supplied dockItemsJson.
const registryContext = vm.createContext({});
vm.runInContext(registry.replace(/^\.pragma library\s*$/m, ''), registryContext);
const items = [
 {type:'app',name:'Firefox',icon:'firefox'},
 {type:'folder',name:'ArtCraft',sourceType:'manual', folderAccentColor:'#a060db',apps:[{name:'PhotoCraft'}]},
 {type:'folder',name:'Jogos',sourceType:'category',sourceCategory:'Game',folderAccentColor:'#27c35e'},
 {type:'folder',name:'ArtCraft',sourceType:'manual',folderAccentColor:'#114477'},
 {type:'app',name:'Dolphin',icon:'system-file-manager'},
];
const json=JSON.stringify(items);
const rows = registryContext.collectFolders(json);
assert.equal(rows.length,3);
assert.deepEqual(Array.from(rows,r=>r.name),['ArtCraft','Jogos','ArtCraft']);
assert.deepEqual(Array.from(rows,r=>r.folderIndex),[1,2,3]);
assert.deepEqual(Array.from(rows,r=>r.explicitColor),['#a060db','#27c35e','#114477']);
assert.equal(registryContext.collectFolders('broken-json').length,0);
const edited = registryContext.updateFolderColor(json,3,'ArtCraft','#ABCDEF');
assert.equal(edited.ok,true);
assert.equal(edited.changed,true);
assert.equal(JSON.parse(edited.json)[1].folderAccentColor,'#a060db','first duplicate-named folder untouched');
assert.equal(JSON.parse(edited.json)[3].folderAccentColor,'#ABCDEF');
assert.deepEqual(JSON.parse(edited.json)[1].apps,items[1].apps,'folder application contents preserved');
assert.equal(registryContext.updateFolderColor(edited.json,3,'Renamed','#112233').ok,false,'stale folder edit rejected');
assert.equal(registryContext.updateFolderColor(json,3,'ArtCraft','not-a-color').ok,false);
const reset = registryContext.updateFolderColor(edited.json,3,'ArtCraft','');
assert.equal(reset.ok,true);
assert.ok(!Object.hasOwn(JSON.parse(reset.json)[3],'folderAccentColor'),'reset inherits defaults');
assert.ok(!Object.hasOwn(items[3],'changed'),'original caller array unmodified');
assert.match(wrapper,/property alias cfg_dockItemsJson: settings\.cfg_dockItemsJson/);
assert.match(form,/FolderRegistry\.collectFolders\(cfg_dockItemsJson\)/);
assert.match(form,/FolderRegistry\.updateFolderColor\(/);
assert.match(form,/page\.userFolderRows\.length > 0/);
assert.match(form,/page\.showCategoryDefaults/);
assert.match(main,/taskController\.isTrayTemporarilyPromoted/);

function extract(name) {
 const m = model.match(new RegExp(`function ${name}\\([^)]*\\) \\{`));
 assert.ok(m,name);
 let start=m.index, depth=0, opened=false;
 for(let i=m.index+m[0].length-1;i<model.length;i++) {
   if(model[i]==='{') {depth++;opened=true;}
   if(model[i]==='}') {depth--;if(opened && depth===0) return model.slice(start,i+1);}
 }
 throw Error('unbalanced function '+name);
}
const rowsTask=[{id:'megasync',active:false,minimized:false}];
let refreshCount=0, activations=0;
const tasksModel={
 count:rowsTask.length,
 index(row){return {row,valid:row>=0 && row<rowsTask.length};},
 data(index, role){
   const v=rowsTask[index.row];
   if(role==='IsWindow')return true;
   if(role==='IsActive')return v.active;
   if(role==='IsMinimizable')return true;
   if(role==='IsMinimized')return v.minimized;
   return false;
 },
 requestActivate(index){rowsTask[index.row].active=true;activations++;},
 requestToggleMinimized(index){rowsTask[index.row].minimized=true;}
};
const mock={
  trayPromotionArmed:true, temporarilyPromotedTrayIds:{},
  wheelSuppressedTrayPromotions:{},lastTrayFocusId:'',
  canonicalServiceId(x){return String(x||'').toLowerCase().replace(/\.desktop$/,'');},
  currentActiveTrayIdentity(){return rowsTask[0].active?'megasync':'';},
  trayOnlyIdentityForRow(i){return rowsTask[i]?.id||'';},
  dockItems:[],scheduleRefresh(){refreshCount++;},
  resolvedNotifierServiceId(id){return id==='mega'?'megasync':id;},
  trayActivator(id){return id==='mega';}
};
const wheelCycleTimer={running:false};
const ctx=vm.createContext({
 root:mock, tasksModel, wheelCycleTimer,
 TaskManager:{AbstractTasksModel:{IsWindow:'IsWindow',IsActive:'IsActive',IsMinimizable:'IsMinimizable',IsMinimized:'IsMinimized'}},
 WindowScrollNavigation:{planWindowTransition(candidates,_prev,next){return {targetKey:next,previousKey:''};}},
});
for(const name of ['isTrayTemporarilyPromoted','suppressTrayPromotionForWheel','pruneWheelSuppressionWhenIdle','observeTrayFocusChange','applyWheelWindowTransition']){
 vm.runInContext(extract(name),ctx);
 mock[name]=ctx[name];
}
const windowCandidate={row:0,key:'tray:megasync',desktopId:'megasync'};
assert.equal(mock.applyWheelWindowTransition([windowCandidate],'','tray:megasync'),true);
assert.equal(activations,1);
mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false,'wheel focus must not promote a tray app');
mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false,'repeat task notifications must not promote');
// A new explicit tray focus transition should still work after wheel has ended.
rowsTask[0].active=false;
mock.observeTrayFocusChange();
assert.ok(!Object.hasOwn(mock.wheelSuppressedTrayPromotions,'megasync'));
rowsTask[0].active=true;
mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),true,'explicit later activation can promote');
// SNI-only wheel selection must be protected, including a verified alias.
mock.temporarilyPromotedTrayIds={};
rowsTask[0].active=false;
mock.observeTrayFocusChange();
assert.equal(mock.applyWheelWindowTransition([{row:-1,key:'tray:mega',desktopId:'mega'}],'','tray:mega'),true);
assert.equal(mock.wheelSuppressedTrayPromotions.megasync,true);
rowsTask[0].active=true;
mock.observeTrayFocusChange();
assert.equal(mock.isTrayTemporarilyPromoted('megasync'),false,'SNI scroll alias is also suppressed');
assert.ok(refreshCount>=1);
console.log('R63.4 PASS: user-created folders/duplicate names/persistence and wheel-only tray suppression without preventing later manual focus.');
