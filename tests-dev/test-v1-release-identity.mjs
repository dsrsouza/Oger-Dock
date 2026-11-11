import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFileSync(join(root, name), 'utf8');
const meta = JSON.parse(read('metadata.json'));
assert.equal(meta.KPlugin.Version, '1.0.0');
assert.equal(meta.KPlugin.Name, 'Oger Dock');
assert.equal(meta.KPlugin.Id, 'org.kde.plasma.punchi-dock-remastered', 'Existing Plasma applet ID must not change');
assert.deepEqual(meta.KPlugin.Authors.map(a => a.Name), ['Diego Souza.R', 'Punchisoft']);
assert.equal(meta.KPlugin.Website, 'https://github.com/dsrsouza/Oger-Dock');
assert.equal(meta.KPlugin.BugReportUrl, 'https://github.com/dsrsouza/Oger-Dock/discussions');
assert.match(read('CMakeLists.txt'), /^project\(oger-dock VERSION 1\.0\.0 LANGUAGES CXX\)/m);
assert.match(read('CMakeLists.txt'), /set\(PUNCHI_PLUGIN_ID "org\.kde\.plasma\.punchi-dock-remastered"\)/);
assert.match(read('CMakeLists.txt'), /plasma_applet_org\.kde\.plasma\.punchi-dock-remastered/);
assert.match(read('src/CMakeLists.txt'), /URI org\.punchi\.dock/);
const installer=read('scripts-user/setup.sh');
assert.match(installer, /package_file="\$PROJECT_ROOT\/dist\/oger-dock-\$\{package_version\}-\$\{platform_label\}-local-build\.plasmoid"/);
assert.match(installer, /PLUGIN_ID="org\.kde\.plasma\.punchi-dock-remastered"/);
assert.match(read('NOTICE'), /Based on Punchi Dock Remastered/);
assert.match(read('NOTICE'), /GPL-3\.0-or-later/);
for (const file of ['README.md','CHANGELOG.md','LEIA-ME-1.0.0.md']) {
  assert.ok(existsSync(join(root,file)), `Missing release document ${file}`);
}
for (const locale of ['en','pt_BR','de','es']) {
  const po=read(`po/${locale}.po`);
  assert.match(po, /Project-Id-Version: Oger Dock 1\.0\.0/);
}
// The R63.7 tray/scroll logic must remain present; this is a branding release.
const wheel=read('contents/ui/components/TaskModelController.qml');
assert.match(wheel,/wheelCandidates/);
assert.match(wheel,/temporarilyPromotedTrayIds/);
console.log('PASS Oger Dock 1.0.0: public metadata, authors, packaging, translations, attribution, and legacy compatibility identifiers');
