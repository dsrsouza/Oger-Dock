// SPDX-License-Identifier: GPL-2.0-or-later
#include "vlcnotificationintegration.h"

#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
// Only the VLC Qt interface's option is edited; no global notifications.
constexpr auto key = "qt-notification";

struct VlcConfig {
    QList<QByteArray> lines;
    int section = -1;
    int entry = -1;
    int count = 0;
    bool disabled = false;
    QByteArray oldLine;
    QByteArray eol = "\n";
};

VlcConfig parse(const QByteArray &bytes)
{
    VlcConfig result;
    result.lines = bytes.split('\n');
    if (bytes.contains("\r\n")) result.eol = "\r\n";
    bool inQt = false;
    for (int i = 0; i < result.lines.size(); ++i) {
        const QByteArray trimmed = result.lines.at(i).trimmed();
        // VLC writes headers such as "[qt] # Qt interface", not just "[qt]".
        if (trimmed.startsWith('[') && trimmed.indexOf(']') > 1) {
            const int closing = trimmed.indexOf(']');
            const QByteArray group = trimmed.mid(1, closing - 1).trimmed();
            inQt = group == "qt";
            if (inQt) result.section = i;
            continue;
        }
        if (!inQt || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
        if (!trimmed.startsWith(key)) continue;
        const int eq = trimmed.indexOf('=');
        if (eq < 0 || trimmed.left(eq).trimmed() != key) continue;
        ++result.count;
        result.entry = i;
        result.oldLine = result.lines.at(i);
        result.disabled = trimmed.mid(eq + 1).trimmed() == "0";
    }
    return result;
}

bool writeAtomic(const QString &path, const QByteArray &data)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return false;
    if (file.write(data) != data.size()) { file.cancelWriting(); return false; }
    return file.commit();
}

QJsonObject readBackup(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object() : QJsonObject{};
}

// The VLC app may overwrite its config on exit; avoid conflicting writes.
bool vlcRunning()
{
#ifdef Q_OS_LINUX
    const QDir proc(QStringLiteral("/proc"));
    const auto entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        if (entry.isEmpty() || !entry.at(0).isDigit()) continue;
        QFile comm(proc.filePath(entry + QStringLiteral("/comm")));
        if (comm.open(QIODevice::ReadOnly)) {
            const QByteArray name = comm.readAll().trimmed();
            if (name == "vlc" || name == "vlc-bin") return true;
        }
    }
#endif
    return false;
}
}

VlcNotificationIntegration::VlcNotificationIntegration(QObject *parent)
    : QObject(parent)
{
    refresh();
}

QString VlcNotificationIntegration::configPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/vlc/vlcrc");
}

QString VlcNotificationIntegration::backupPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/punchi-dock/vlc-notification-backup.json");
}

void VlcNotificationIntegration::report(const QString &message)
{
    m_status = message;
    Q_EMIT stateChanged();
}

void VlcNotificationIntegration::refresh()
{
    const QFileInfo info(configPath());
    m_available = info.isFile() && info.isWritable() && !info.isSymLink();
    m_disabled = false;
    m_canRestore = false;
    if (!m_available) {
        report(i18n("VLC settings were not found or cannot be edited. Open VLC once and save its preferences. Flatpak VLC is not supported by this integration."));
        return;
    }
    QFile file(configPath());
    if (!file.open(QIODevice::ReadOnly)) {
        m_available = false;
        report(i18n("Cannot read VLC preferences."));
        return;
    }
    const VlcConfig cfg = parse(file.readAll());
    if (cfg.count > 1) {
        m_available = false;
        report(i18n("VLC has multiple active notification settings. Edit them in VLC to avoid ambiguity."));
        return;
    }
    m_disabled = cfg.disabled;
    const auto backup = readBackup(backupPath());
    m_canRestore = m_disabled && !backup.isEmpty()
        && backup.value(QStringLiteral("vlcPath")).toString() == configPath()
        && backup.value(QStringLiteral("owner")).toString() == QStringLiteral("punchi-dock-v1");
    report(m_canRestore
        ? i18n("Track notifications are off. Oger Dock can restore the previous VLC value.")
        : m_disabled
            ? i18n("Track notifications are already disabled in VLC. Your existing preference was preserved.")
            : i18n("VLC still shows track-change notifications. Enable the integration below to hide them."));
}

bool VlcNotificationIntegration::suppress() { return change(false); }
bool VlcNotificationIntegration::restore() { return change(true); }

bool VlcNotificationIntegration::change(bool restoreOriginal)
{
    refresh();
    if (!m_available || (restoreOriginal && !m_canRestore)) return false;
    if (!restoreOriginal && m_disabled) return true; // User already chose this in VLC.
    if (vlcRunning()) {
        report(i18n("Close VLC completely before applying this change, then try again. VLC may overwrite its preferences while running."));
        return false;
    }
    QFile file(configPath());
    if (!file.open(QIODevice::ReadOnly)) {
        report(i18n("Cannot read VLC preferences."));
        return false;
    }
    const QByteArray oldBytes = file.readAll();
    const VlcConfig cfg = parse(oldBytes);
    if (cfg.section < 0 || cfg.count > 1) {
        report(i18n("The VLC Qt settings section is missing or ambiguous. Save preferences in VLC first."));
        return false;
    }
    auto lines = cfg.lines;
    if (!restoreOriginal) {
        QJsonObject backup;
        backup.insert(QStringLiteral("owner"), QStringLiteral("punchi-dock-v1"));
        backup.insert(QStringLiteral("vlcPath"), configPath());
        backup.insert(QStringLiteral("hadEntry"), cfg.entry >= 0);
        backup.insert(QStringLiteral("previousLineBase64"), QString::fromLatin1(cfg.oldLine.toBase64()));
        if (!QDir().mkpath(QFileInfo(backupPath()).absolutePath())
            || !writeAtomic(backupPath(), QJsonDocument(backup).toJson(QJsonDocument::Compact))) {
            report(i18n("Cannot save a reversible backup of the VLC setting. No changes were made."));
            return false;
        }
        if (cfg.entry >= 0) {
            lines[cfg.entry] = QByteArray("qt-notification=0") + (cfg.oldLine.endsWith('\r') ? "\r" : "");
        } else {
            lines.insert(cfg.section + 1, QByteArray("qt-notification=0") + (cfg.eol == "\r\n" ? "\r" : ""));
        }
    } else {
        const QJsonObject backup = readBackup(backupPath());
        if (cfg.entry < 0 || !cfg.disabled
            || backup.value(QStringLiteral("owner")).toString() != QStringLiteral("punchi-dock-v1")
            || backup.value(QStringLiteral("vlcPath")).toString() != configPath()) {
            report(i18n("The VLC setting has changed outside Oger Dock. No restoration was performed."));
            return false;
        }
        if (backup.value(QStringLiteral("hadEntry")).toBool()) {
            lines[cfg.entry] = QByteArray::fromBase64(backup.value(QStringLiteral("previousLineBase64")).toString().toLatin1());
        } else {
            lines.removeAt(cfg.entry);
        }
    }
    QByteArray changed;
    for (qsizetype i = 0; i < lines.size(); ++i) {
        if (i > 0) changed.append('\n');
        changed.append(lines.at(i));
    }
    if (!writeAtomic(configPath(), changed)) {
        if (!restoreOriginal) QFile::remove(backupPath());
        report(i18n("Unable to save VLC preferences; the change was not applied."));
        return false;
    }
    if (restoreOriginal) QFile::remove(backupPath());
    refresh();
    return true;
}
