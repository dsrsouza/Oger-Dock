// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <qqmlregistration.h>

// Opt-in per-user VLC Qt preference integration. Never changes Plasma's
// notification service, MPRIS or third-party applications without a click.
class VlcNotificationIntegration : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool disabled READ disabled NOTIFY stateChanged)
    Q_PROPERTY(bool canRestore READ canRestore NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)

public:
    explicit VlcNotificationIntegration(QObject *parent = nullptr);
    bool available() const { return m_available; }
    bool disabled() const { return m_disabled; }
    bool canRestore() const { return m_canRestore; }
    QString status() const { return m_status; }

    Q_INVOKABLE bool suppress();
    Q_INVOKABLE bool restore();
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void stateChanged();

private:
    QString configPath() const;
    QString backupPath() const;
    bool change(bool restoreOriginal);
    void report(const QString &message);
    bool m_available = false;
    bool m_disabled = false;
    bool m_canRestore = false;
    QString m_status;
};
