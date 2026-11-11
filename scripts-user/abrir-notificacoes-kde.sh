#!/usr/bin/env bash
# Safely open KDE Notifications configuration; changes are made by the user.
set -eu
if command -v kcmshell6 >/dev/null 2>&1; then
    exec kcmshell6 kcm_notifications
elif command -v systemsettings >/dev/null 2>&1; then
    exec systemsettings kcm_notifications
fi
printf 'Abra Configurações do Sistema > Notificações > Progresso dos aplicativos.\n' >&2
exit 1
