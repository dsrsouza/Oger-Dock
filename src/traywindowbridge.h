// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QByteArray>
#include <QModelIndex>
#include <QDBusMessage>
#include <QHash>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <qqmlregistration.h>

// R41: Native Qt model with stable roles and incremental row notifications.
// Task/wheel navigation consults only these identities on demand instead of
// binding a repeatedly reconstructed QVariantList to its QML controller.
class TrayIdentityModel final : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { DesktopIdRole = Qt::UserRole + 1 };
    explicit TrayIdentityModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QStringList desktopIds() const { return m_ids; }
    void synchronize(QStringList ids);
private:
    QStringList m_ids;
};

// StatusNotifierItem helper. All remote D-Bus operations are asynchronous:
// a slow notifier must never stall plasmashell's GUI thread.
class TrayWindowBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    // R36: defer potentially expensive model refresh during the short fan
    // opening, without dropping any window transition or changing SNI identity.
    Q_PROPERTY(bool fanRevealActive READ fanRevealActive WRITE setFanRevealActive NOTIFY fanRevealActiveChanged)
    // Diagnostic only: suspends Punchi SNI subscription/observation, not KDE tray.
    Q_PROPERTY(bool diagnosticObservationEnabled READ diagnosticObservationEnabled NOTIFY diagnosticObservationEnabledChanged)
    // R43: independent switch for Punchi's QML TaskManager presentation
    // callbacks. The native KDE TasksModel and all its windows remain live.
    Q_PROPERTY(bool diagnosticTaskObservationEnabled READ diagnosticTaskObservationEnabled NOTIFY diagnosticTaskObservationEnabledChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    // Full SNI registry is for resolving menus on PINNED launchers only.
    // It must never drive the dynamic tray model (entries is filtered).
    Q_PROPERTY(QVariantList registeredEntries READ registeredEntries NOTIFY registeredEntriesChanged)
    // Pinned launcher indicators need only identities, never menu paths.
    Q_PROPERTY(QStringList registeredDesktopIds READ registeredDesktopIds NOTIFY registeredDesktopIdsChanged)
    Q_PROPERTY(QVariantList observedEntries READ observedEntries NOTIFY observedEntriesChanged)
    // Stable QAbstractListModel: only row insert/remove for real observed IDs.
    Q_PROPERTY(QAbstractItemModel* identityModel READ identityModel CONSTANT)
    Q_PROPERTY(QVariantList contextActions READ contextActions NOTIFY contextActionsChanged)
    Q_PROPERTY(QString contextMenuDesktopId READ contextMenuDesktopId NOTIFY contextActionsChanged)
public:
    explicit TrayWindowBridge(QObject *parent = nullptr);
    bool fanRevealActive() const { return m_fanRevealActive; }
    bool diagnosticObservationEnabled() const { return m_diagnosticObservationEnabled; }
    bool diagnosticTaskObservationEnabled() const { return m_diagnosticTaskObservationEnabled; }
    void setFanRevealActive(bool active);
    QVariantList entries() const;
    QVariantList registeredEntries() const;
    QStringList registeredDesktopIds() const;
    QVariantList observedEntries() const;
    QAbstractItemModel *identityModel() { return &m_identityModel; }
    // Explicit accessor also works on Qt builds that expose only the base
    // QAbstractItemModel methods when the pointer is passed through QML.
    Q_INVOKABLE QStringList observedIdentityKeys() const {
        return m_identityModel.desktopIds();
    }
    QVariantList contextActions() const;
    QString contextMenuDesktopId() const;
    Q_INVOKABLE bool containsDesktopEntry(const QString &desktopId) const;
    // Local diagnostics only; does not read window content or log private data.
    Q_INVOKABLE QVariantList notifierDiagnostics() const;
    Q_INVOKABLE QVariantMap performanceCounters() const;
    Q_INVOKABLE bool activateDesktopEntry(const QString &desktopId, int globalX = -1, int globalY = -1);
    Q_INVOKABLE bool openNotifierMenu(const QString &desktopId, int globalX, int globalY);
    // Import an exported DBusMenu asynchronously, just as Plasma's tray host
    // does. A simple SNI ContextMenu call is ignored by many KDE applications.
    Q_INVOKABLE bool requestNotifierActions(const QString &desktopId);
    Q_INVOKABLE bool triggerNotifierAction(const QString &desktopId, int actionId);
    Q_INVOKABLE void observeWindowApps(const QStringList &desktopIds);
    // Snapshot includes TaskManager AppId, verified desktop service and
    // best-effort AppPid. A process match is permitted only for an app the
    // user really opened, never merely for an SNI registered at login.
    Q_INVOKABLE void observeWindowTasks(const QVariantList &tasks);
    // Call only from explicit dock click/context-menu activation.
    // Merely discovering an SNI at KDE login never grants visibility.
    Q_INVOKABLE void noteUserInteraction(const QString &desktopId);

public Q_SLOTS:
    void refresh();
    // Delta notifications from the KDE watcher; no whole-registry scan for
    // each application starting or closing.
    void notifierRegistered(const QString &address);
    void notifierUnregistered(const QString &address);
    void notifierMenuChanged(const QDBusMessage &message);

Q_SIGNALS:
    void fanRevealActiveChanged();
    void diagnosticObservationEnabledChanged();
    void diagnosticTaskObservationEnabledChanged();
    void entriesChanged();
    void registeredEntriesChanged();
    void registeredDesktopIdsChanged();
    void observedEntriesChanged();
    void contextActionsChanged();
    void notifierActionsUnavailable(const QString &desktopId);

private:
    void setNotifierSubscriptions(bool enabled);
    void syncDiagnosticModeFromMarker();
    void syncDiagnosticTaskModeFromMarker();
    void setDiagnosticTaskObservationEnabled(bool enabled);
    void setDiagnosticObservationEnabled(bool enabled);
    static QString normalized(const QString &value);
    bool eligible(const QVariantMap &item) const;
    bool matchesDesktopId(const QVariantMap &item, const QString &desktopId) const;
    void requestNotifierPid(QVariantMap entry);
    void requestTrayWindowIdentity(QVariantMap entry);
    QString observedDesktopId(const QVariantMap &item) const;
    void finishRefresh();
    void queueNotifierChange(const QString &address, bool present);
    void applyQueuedNotifierChanges();
    void flushDeferredFanWork();
    // Expensive KService/SNI matching is recomputed only after an actual
    // notifier/window change, never on each QML binding read.
    void invalidateEntryCaches();
    void publishEffectiveModelChanges(const QVariantList &oldObserved,
                                     const QVariantList &oldDynamic,
                                     const char *origin);
    void requestNotifierProperties(const QString &service, const QString &path,
                                   const QString &interfaceName = QStringLiteral("org.kde.StatusNotifierItem"));
    void fetchNotifierActions(const QString &service, const QString &menuPath,
                              const QString &desktopId, quint64 generation);

    // A/B switch is a file in a private, per-session directory; the watcher
    // sleeps until a file change, with no polling and no system settings.
    QFileSystemWatcher m_diagnosticWatcher;
    QString m_diagnosticMarkerPath;
    QString m_taskDiagnosticMarkerPath;
    bool m_diagnosticObservationEnabled = true;
    bool m_diagnosticTaskObservationEnabled = true;
    // R43: automatically resume after 180 s even if the operator forgets on.
    QTimer m_taskDiagnosticAutoRestore;

    quint64 m_observationEpoch = 0;
    TrayIdentityModel m_identityModel;
    QVariantList m_allEntries;
    mutable QVariantList m_cachedObservedEntries;
    mutable QVariantList m_cachedDynamicEntries;
    mutable QVariantList m_cachedRegisteredEntries;
    mutable QStringList m_cachedRegisteredDesktopIds;
    mutable QHash<QString, bool> m_cachedNotifierPresence;
    mutable bool m_cachedObservedValid = false;
    mutable bool m_cachedDynamicValid = false;
    mutable bool m_cachedRegisteredValid = false;
    mutable bool m_cachedRegisteredDesktopIdsValid = false;
    QVariantList m_contextActions;
    QString m_contextMenuDesktopId;
    QString m_contextMenuService;
    QString m_contextMenuPath;
    quint64 m_menuRequestGeneration = 0;
    QVariantList m_scannedEntries;
    QSet<QString> m_currentWindowApps;
    QSet<quint32> m_currentWindowPids;
    QHash<quint32, QString> m_currentWindowAppByPid;
    QHash<quint32, QString> m_seenForegroundAppByPid;
    // KWin AppId can differ from SNI Id and XEmbed WM_CLASS. Only verified
    // task windows seen after user interaction populate these name hints.
    QHash<QString, QString> m_seenForegroundAppNames;
    QHash<QString, QString> m_currentWindowAppNames;
    QSet<QString> m_currentWindowPrimaryApps;
    QSet<QString> m_recentlyActiveWindowApps;
    QSet<QString> m_seenForegroundApps;
    QSet<QString> m_scannedServices;
    // Only the initial/health-check scan reads the complete SNI registry.
    // Subsequent watcher notifications update the affected notifier(s).
    QTimer m_refreshTimer;
    QTimer m_deltaTimer;
    QHash<QString, bool> m_pendingNotifierChanges;
    quint64 m_fullScans = 0;
    quint64 m_deltaBatches = 0;
    quint64 m_deltaReads = 0;
    int m_lastBatchSize = 0;
    // Snapshots are replayed in original order, preserving open-then-close
    // transitions that grant an SNI a user-observed application identity.
    QVector<QVariantList> m_deferredWindowTaskSnapshots;
    bool m_fanRevealActive = false;
    bool m_fanPublicationDeferred = false;
    bool m_fanFlushScheduled = false;
    quint64 m_fanGuardGeneration = 0;
    bool m_observationArmed = false;
    bool m_refreshInFlight = false;
    bool m_refreshAgain = false;
    int m_pendingItemReads = 0;
};
