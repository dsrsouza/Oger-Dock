// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QThreadPool>
#include <qqmlregistration.h>

class DockRuntimeService : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit DockRuntimeService(QObject *parent = nullptr);

    Q_INVOKABLE bool persistDockItemsJson(const QString &json, const QString &instanceId = QString());
    // R21: secondary backup writer used only for mouse reordering.
    // Never block plasmashell's rendering thread on QSaveFile::commit().
    Q_INVOKABLE void persistDockItemsJsonAsync(const QString &json, const QString &instanceId = QString());
    Q_INVOKABLE bool launchCommand(const QString &command);
    Q_INVOKABLE bool playSound(const QString &soundPath = QString(), const QString &eventId = QString());

private:
    QThreadPool m_reorderPersistencePool;

Q_SIGNALS:
    void operationFailed(const QString &operation, const QString &message);
};
