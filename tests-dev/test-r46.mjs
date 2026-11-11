// R46: icon source and native Kirigami sizing match the approved menu.
// Static + expression tests only: physical sharpness must be judged on KDE.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(base, name), 'utf8');
const fan = read('contents/ui/components/FolderFanView.qml');
const menu = read('contents/ui/components/punchimenu/PunchiMenuOverlay.qml');
const discovery = read('src/systemdiscovery.cpp');
const iconResolver = read('src/folderentryicon.h');
const task = read('contents/ui/components/TaskModelController.qml');
const main = read('contents/ui/main.qml');
const iconNameIndex = fan.indexOf('objectName: "folderFanIcon-"');
assert(iconNameIndex >= 0, 'must target app icon, not fan closing arrow');
const blockStart = fan.lastIndexOf('Kirigami.Icon {', iconNameIndex);
assert(blockStart >= 0);
const blockEnd = fan.indexOf('Accessible.ignored: true', blockStart);
assert(blockEnd > blockStart);
const icon = fan.slice(blockStart, blockEnd);
assert.match(icon, /width: root\.iconSize \* 2\s+height: width\s+scale: 0\.5/);
assert.match(icon, /roundToIconSize: false/);
assert.match(icon, /smooth: true/);
assert.doesNotMatch(icon, /layer\.enabled\s*:\s*true/);
assert.doesNotMatch(icon, /sourceSize|image:\/\//);
// Same exact-size, Qt-native theme-aware renderer as the menu.
const menuSourceIndex = menu.indexOf('source: String(appDelegate.modelData.appIcon');
assert(menuSourceIndex > 0);
const menuAppBlock = menu.slice(menu.lastIndexOf('Kirigami.Icon {', menuSourceIndex),
    menuSourceIndex + 160);
assert.match(menuAppBlock, /Kirigami\.Icon/);
assert.match(menuAppBlock, /roundToIconSize: false/);
assert.match(icon, /fanDelegate\.modelData\.appIcon/);
assert.match(icon, /fanDelegate\.modelData\.icon/);
// Run the exact QML JS icon selection expression against representative models.
const expression = icon.match(/source:\s*(fanDelegate\.modelData[\s\S]*?)\n\s*roundToIconSize:/);
assert(expression, 'the source binding must remain evaluable JS');
const select = new Function('fanDelegate', 'return (' + expression[1] + ')');
assert.equal(select({modelData:{appIcon:'photocraft-high-res',icon:'cached-low-res'}}), 'photocraft-high-res');
assert.equal(select({modelData:{icon:'/usr/share/icons/hicolor/128x128/apps/vectorcraft.png'}}),
 '/usr/share/icons/hicolor/128x128/apps/vectorcraft.png');
assert.equal(select({modelData:{icon:'application-x-executable'}}), 'application-x-executable');
assert.equal(select({modelData:{appIcon:'',icon:'effectcraft'}}), 'effectcraft');
assert.equal(select({modelData:{appIcon:'',icon:''}}), 'application-x-executable');
assert.equal(select({modelData:null}), 'application-x-executable');
// Input originates from the same KService icon entry as the menu for desktop links.
assert.match(discovery, /DesktopLauncherResolver::resolveLocalFile\(localPath\)/);
assert.match(discovery, /appIcon = launcher\.service->icon\(\)/);
assert.match(discovery, /iconName = appIcon/);
assert.match(discovery, /FolderEntryIcon::resolve\(entry, entryUrl\)/);
assert.match(iconResolver, /KFileItem\(resolvedEntry, url\)\.iconName\(\)/);
// Performance R45's pre-popup task visual hold must remain intact.
assert.match(main, /onFolderPopupOpening: function\(itemData\) \{[\s\S]*?taskController\.beginFanPresentationHold\(\)/);
assert.match(task, /enabled: root\.diagnosticTaskObservationEnabled && !root\.fanPresentationHold/);
assert.match(task, /fanPresentationFailSafe[\s\S]*interval: 2200/);
assert.match(fan, /revealProgressForDistance\(rowDistance, safeRevealProgress\)/);
console.log('R46 offline PASS: menu-quality Kirigami icon sizing, appIcon priority, KService and KIO fallback, no extra cache, R45 performance hold preserved.');
