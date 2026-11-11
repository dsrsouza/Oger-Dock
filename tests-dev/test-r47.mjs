// R47: actual per-item app icon source + 2x QSG sampling / upright art.
// This is a structural test, not a hardware pixel-accuracy test.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read=p=>fs.readFileSync(path.join(base,p),'utf8');
const fan=read('contents/ui/components/FolderFanView.qml');
const menu=read('contents/ui/components/punchimenu/PunchiMenuOverlay.qml');
const sys=read('src/systemdiscovery.cpp');
const main=read('contents/ui/main.qml');
const task=read('contents/ui/components/TaskModelController.qml');
const bridge=read('src/traywindowbridge.cpp');
const mark=fan.indexOf('objectName: "folderFanIconViewport-"');
assert(mark>0,'app icon viewport exists');
const start=fan.lastIndexOf('Item {',mark);
const end=fan.indexOf('Accessible.ignored: true',mark);
assert(start>=0 && end>start);
const block=fan.slice(start,end);
assert.match(block,/x: fanContent.iconX\s+anchors.verticalCenter: parent.verticalCenter/);
assert.match(block,/width: root.iconSize\s+height: root.iconSize/);
assert.match(block,/angle: -fanDelegate.rowLean/);
assert.match(block,/origin.x: fanIconViewport.width \/ 2/);
assert.match(block,/origin.y: fanIconViewport.height \/ 2/);
assert.match(block,/Kirigami\.Icon \{/);
assert.match(block,/width: root.iconSize \* 2\s+height: width\s+scale: 0\.5/);
assert.match(block,/anchors.centerIn: parent/);
assert.match(block,/roundToIconSize: false/);
assert.match(block,/smooth: true/);
assert.match(block,/fanDelegate.modelData.appIcon/);
assert.match(block,/fanDelegate.modelData.icon/);
assert.doesNotMatch(block,/layer.enabled\s*:\s*true|ShaderEffect|ShaderEffectSource|QQuickPaintedItem|onFrameSwapped/);
// Keep the label pill and the macOS fan arc lean; only the icon is counter-rotated.
assert.match(fan,/id: rowContent[\s\S]*?angle: fanDelegate.rowLean[\s\S]*?id: labelPill/);
assert.match(fan,/root.revealProgressForDistance\(rowDistance, safeRevealProgress\)/);
assert.match(fan,/itemHighlight.visualScale[\s\S]*?fanDelegate.revealScale/);
// Demonstrate exact 2x sampling math, independent of geometry/UI.
for(const size of [16, 32, 42, 48, 64, 96]){
 const rendered=2*size;
 assert.equal(rendered*0.5,size);
 assert.equal((-rendered/2 + size/2) + (rendered/2)*(1-0.5),0);
}
// Desktop launcher already KService-resolved; new appIcon supplied in real folder rows.
assert.match(sys,/DesktopLauncherResolver::resolveLocalFile\(localPath\)/);
assert.match(sys,/appIcon = launcher.service->icon\(\)/);
assert.match(sys,/itemMap.insert\(QStringLiteral\("appIcon"\), appIcon\)/);
assert.match(sys,/FolderEntryIcon::resolve\(entry, entryUrl\)/);
assert.match(sys,/if \(!appIcon.isEmpty\(\)\)/);
assert.match(menu,/source: String\(appDelegate.modelData.appIcon/);
// Critical R45 full functionality and performance protection intact.
assert.match(main,/onFolderPopupOpening: function\(itemData\) \{[\s\S]*?taskController.beginFanPresentationHold\(\)/);
assert.match(task,/enabled: root.diagnosticTaskObservationEnabled && !root.fanPresentationHold/);
assert.match(task,/fanPresentationFailSafe[\s\S]*interval: 2200/);
assert.match(bridge,/StatusNotifier/);
console.log('R47 offline PASS: 2x source sampling, exact viewport size, counter-rotation, KService appIcon, R45 protections');
