// SPDX-License-Identifier: GPL-3.0-or-later

#include "dockruntimeservice.h"

#include <KLocalizedString>

#include <QDir>
#include <QFileInfo>
#include <QMetaObject>
#include <QPointer>
#include <QThreadPool>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

namespace
{
constexpr auto TranslationDomain = "plasma_applet_org.kde.plasma.punchi-dock-remastered";
constexpr qsizetype maximumDockItemsJsonSize = 1024 * 1024;

QString sanitizedInstanceId(QString instanceId)
{
    instanceId = instanceId.trimmed();
    instanceId.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_.-]")), QStringLiteral("_"));
    if (instanceId.isEmpty() || instanceId == QLatin1String("undefined") || instanceId == QLatin1String("null")) {
        return QStringLiteral("default");
    }
    return instanceId;
}

QString dockItemsFileNameForInstance(const QString &instanceId)
{
    const QString normalizedInstanceId = sanitizedInstanceId(instanceId);
    if (normalizedInstanceId == QLatin1String("default")) {
        return QStringLiteral("dock_items.json");
    }
    return QStringLiteral("dock_items_%1.json").arg(normalizedInstanceId);
}
}

DockRuntimeService::DockRuntimeService(QObject *parent)
    : QObject(parent)
{
    // A single FIFO worker prevents a late older snapshot overwriting the
    // latest order when the user drags several icons in succession.
    m_reorderPersistencePool.setMaxThreadCount(1);
}

bool DockRuntimeService::persistDockItemsJson(const QString &json, const QString &instanceId)
{
    const QByteArray data = (json.trimmed().isEmpty() ? QStringLiteral("[]") : json).toUtf8();
    if (data.size() > maximumDockItemsJsonSize) {
        Q_EMIT operationFailed(QStringLiteral("persist"),
            i18nd(TranslationDomain, "The dock configuration is too large."));
        return false;
    }

    const QString configRoot = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    if (configRoot.isEmpty()) {
        Q_EMIT operationFailed(QStringLiteral("persist"), i18nd(TranslationDomain, "The configuration directory is unavailable."));
        return false;
    }

    QDir configDirectory(configRoot);
    if (!configDirectory.mkpath(QStringLiteral("punchi-dock"))) {
        Q_EMIT operationFailed(QStringLiteral("persist"), i18nd(TranslationDomain, "The configuration directory could not be created."));
        return false;
    }

    const QString filePath = configDirectory.filePath(QStringLiteral("punchi-dock/%1").arg(dockItemsFileNameForInstance(instanceId)));
    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        Q_EMIT operationFailed(QStringLiteral("persist"), file.errorString());
        return false;
    }

    if (file.write(data) != data.size() || !file.commit()) {
        Q_EMIT operationFailed(QStringLiteral("persist"), file.errorString());
        return false;
    }

    return true;
}

void DockRuntimeService::persistDockItemsJsonAsync(const QString &json, const QString &instanceId)
{
    const QByteArray data = (json.trimmed().isEmpty() ? QStringLiteral("[]") : json).toUtf8();
    if (data.size() > maximumDockItemsJsonSize) {
        Q_EMIT operationFailed(QStringLiteral("persist"),
            i18nd(TranslationDomain, "The dock configuration is too large."));
        return;
    }
    const QString fileName = dockItemsFileNameForInstance(instanceId);
    const QPointer<DockRuntimeService> target(this);
    m_reorderPersistencePool.start([target, data, fileName]() {
        QString error;
        const QString configRoot = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        if (configRoot.isEmpty()) {
            error = QStringLiteral("Configuration directory unavailable");
        } else {
            QDir directory(configRoot);
            if (!directory.mkpath(QStringLiteral("punchi-dock"))) {
                error = QStringLiteral("Cannot create Oger Dock configuration directory");
            } else {
                QSaveFile file(directory.filePath(QStringLiteral("punchi-dock/%1").arg(fileName)));
                if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                    error = file.errorString();
                } else if (file.write(data) != data.size() || !file.commit()) {
                    error = file.errorString();
                }
            }
        }
        if (!error.isEmpty() && target) {
            QMetaObject::invokeMethod(target, [target, error]() {
                if (target) Q_EMIT target->operationFailed(QStringLiteral("persist"), error);
            }, Qt::QueuedConnection);
        }
    });
}

bool DockRuntimeService::launchCommand(const QString &command)
{
    const QString normalizedCommand = command.trimmed();
    if (normalizedCommand.isEmpty()) {
        return false;
    }

    if (!QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), normalizedCommand})) {
        Q_EMIT operationFailed(QStringLiteral("launch"), i18nd(TranslationDomain, "The command could not be started."));
        return false;
    }

    return true;
}

bool DockRuntimeService::playSound(const QString &soundPath, const QString &eventId)
{
    QString localPath = soundPath.trimmed();
    const QUrl soundUrl(localPath);
    if (soundUrl.isLocalFile()) {
        localPath = soundUrl.toLocalFile();
    }

    if (!localPath.isEmpty() && QFileInfo::exists(localPath)) {
        const QStringList players = {QStringLiteral("paplay"), QStringLiteral("pw-play")};
        for (const QString &player : players) {
            const QString executable = QStandardPaths::findExecutable(player);
            if (!executable.isEmpty() && QProcess::startDetached(executable, {localPath})) {
                return true;
            }
        }
    }

    const QString normalizedEventId = eventId.trimmed();
    const QString canberraExecutable = QStandardPaths::findExecutable(QStringLiteral("canberra-gtk-play"));
    if (!normalizedEventId.isEmpty() && !canberraExecutable.isEmpty()
        && QProcess::startDetached(canberraExecutable,
            {QStringLiteral("-i"), normalizedEventId, QStringLiteral("-d"), QStringLiteral("Oger Dock")})) {
        return true;
    }

    Q_EMIT operationFailed(QStringLiteral("playSound"), i18nd(TranslationDomain, "No sound player or usable sound was found."));
    return false;
}
