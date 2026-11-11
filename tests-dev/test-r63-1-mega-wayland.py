#!/usr/bin/env python3
"""Test isolated user-level MEGAsync overrides; never touches real XDG data."""
from pathlib import Path
import importlib.util
import os
import tempfile
from unittest import mock

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('mega_wayland', root / 'scripts-user/mega-wayland.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory(prefix='oger-mega-test-') as tmp:
    home = Path(tmp)
    sys_apps = home / 'system-apps'
    sys_autostart = home / 'system-autostart'
    sys_apps.mkdir()
    sys_autostart.mkdir()
    contents = ('[Desktop Entry]\nType=Application\nName=MEGAsync\n'
                'Exec=/usr/bin/megasync --autostart\nIcon=mega\n')
    (sys_apps/'megasync.desktop').write_text(contents)
    (sys_autostart/'megasync.desktop').write_text(contents)
    env = {
        'XDG_CONFIG_HOME': str(home/'config'),
        'XDG_DATA_HOME': str(home/'data'),
        'XDG_STATE_HOME': str(home/'state'),
        'XDG_CONFIG_DIRS': str(home/'system'),
        'XDG_DATA_DIRS': str(home),
        'XDG_SESSION_TYPE': 'wayland'
    }
    (home/'system/autostart').mkdir(parents=True)
    (home/'system/autostart/megasync.desktop').write_text(contents)
    (home/'applications').mkdir()
    (home/'applications/megasync.desktop').write_text(contents)
    with mock.patch.dict(os.environ,env,clear=True), mock.patch.object(module,'has_wayland_plugin', return_value=True):
        assert module.run('apply') == 0
        uapps = home/'data/applications/megasync.desktop'
        uauto = home/'config/autostart/megasync.desktop'
        assert uapps.is_file() and uauto.is_file()
        for p in (uapps,uauto):
            assert 'Exec=env QT_QPA_PLATFORM=wayland /usr/bin/megasync --autostart' in p.read_text()
        assert module.run('restore') == 0
        assert not uapps.exists() and not uauto.exists()
        # Pre-existing autostart entry must be restored byte-identically.
        uauto.parent.mkdir(parents=True,exist_ok=True)
        uauto.write_text(contents+'X-KDE-autostart-after=panel\n')
        assert module.run('apply') == 0
        assert module.run('restore') == 0
        assert uauto.read_text()==contents+'X-KDE-autostart-after=panel\n'
        # User edits made after installation must not be overwritten.
        assert module.run('apply') == 0
        uauto.write_text(uauto.read_text()+'# custom edit\n')
        assert module.run('restore') == 1
        assert '# custom edit' in uauto.read_text()
        assert module.state_path().exists()
print('R63.1 MEGA PASS: apply, restore, existing launcher, user edits protection')
