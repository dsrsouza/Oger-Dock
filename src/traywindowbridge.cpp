// SPDX-License-Identifier: GPL-2.0-or-later
#include "traywindowbridge.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusObjectPath>
#include <QIcon>
#include <QHash>
#include <QFileInfo>
#include <QFile>
#include <QDir>
#include <QElapsedTimer>
#include <QRegularExpression>
#include <QProcess>
#include <QStandardPaths>
#include <QDBusError>
#include <KService>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDebug>
#include <QVariantMap>
#include <algorithm>
#include <functional>
#include <limits>
#include <memory>
#include <utility>

namespace {
static const QString watcherService = QStringLiteral("org.kde.StatusNotifierWatcher");
static const QString watcherPath = QStringLiteral("/StatusNotifierWatcher");
static const QString notifierInterface = QStringLiteral("org.kde.StatusNotifierItem");
static const QString alternativeNotifierInterface = QStringLiteral("org.freedesktop.StatusNotifierItem");
static const QString propertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
static const QString dbusMenuInterface = QStringLiteral("com.canonical.dbusmenu");

// A tray exporter may publish only IconPixmap and a generated SNI Id.
// Resolve the *verified* observed desktop identity to the installed KDE
// service. Plasma's window AppId is sometimes case-folded while the actual
// Flatpak desktop filename is mixed-case (com.vendor.Discord.desktop).
// Cache expensive fallback catalog lookups: entries() is a QML property
// getter that may be evaluated during animations and must remain cheap.
QString desktopIcon(const QString &desktopId, const QString &fallback) {
    const QString id = desktopId.trimmed();
    const QString key = id.toCaseFolded();
    static QHash<QString, QString> resolvedIcons;
    if (!resolvedIcons.contains(key)) {
        KService::Ptr service;
        if (!id.isEmpty()) {
            service = KService::serviceByDesktopName(id);
            if (!service) service = KService::serviceByStorageId(id);
            if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop"));
            if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop.desktop"));
        }
        if (!service && !key.isEmpty()) {
            // Exact case-insensitive identity only. Never guess an installed
            // application from its display name, notification text or icon.
            for (const KService::Ptr &candidate : KService::allServices()) {
                if (!candidate || !candidate->isApplication()) continue;
                auto serviceId = candidate->storageId().toCaseFolded();
                if (serviceId.endsWith(QLatin1String(".desktop"))) serviceId.chop(8);
                const auto entryId = candidate->desktopEntryName().toCaseFolded();
                if (serviceId == key || entryId == key) {
                    service = candidate;
                    break;
                }
            }
        }
        resolvedIcons.insert(key, service ? service->icon() : QString());
    }
    const QString icon = resolvedIcons.value(key);
    if (!icon.isEmpty()) return icon;
    // Use only a real icon installed in the current theme when the KDE
    // service cannot be located; an IconPixmap-only SNI has no icon name.
    if (!id.isEmpty() && QIcon::hasThemeIcon(id)) return id;
    const QString shortId = id.section(QLatin1Char('.'), -1);
    if (!shortId.isEmpty() && QIcon::hasThemeIcon(shortId)) return shortId;
    // Preserve custom exporter IconName/absolute icon paths even when they
    // are not listed as a standard theme icon (R32 compatibility).
    if (!fallback.isEmpty()) return fallback;
    return QStringLiteral("application-x-executable");
}

// The menu for a PINNED app can be requested even if the app started before
// our observed-window baseline. This does NOT promote the tray-only app into
// the visible task list: discovery still uses observedDesktopId/eligible.
// Do not accidentally match a generic short service name.
// SNI DesktopEntry, Id and a dock launcher may use different qualified
// desktop IDs. Resolve them with KService so two unrelated apps with similar
// icon names are never merged. Only accept unique exact/suffix aliases or
// an identical KService desktop file; never use the displayed title/icon.
QString canonicalDesktopService(const QString &id) {
    if (id.isEmpty()) return {};
    // Lookup is used from several nested identity-matching loops.
    // Cache the actual service path (and an absent result) per exact spelling;
    // do not case-fold distinct KDE desktop files into one identity.
    static QHash<QString, QString> servicePaths;
    if (servicePaths.contains(id)) return servicePaths.value(id);
    KService::Ptr service = KService::serviceByDesktopName(id);
    if (!service) service = KService::serviceByStorageId(id);
    if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop"));
    // An XDG/Flatpak desktop ID can itself end in .desktop. The original
    // id (e.g. org.example.desktop) was normalized by the older bridge;
    // only try a doubly suffixed storage ID if no exact service exists.
    if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop.desktop"));
    const QString path = service ? QFileInfo(service->entryPath()).canonicalFilePath() : QString();
    if (servicePaths.size() >= 512) servicePaths.clear();
    servicePaths.insert(id, path);
    return path;
}

bool desktopIdentityMatches(const QString &first, const QString &second) {
    if (first.isEmpty() || second.isEmpty()) return false;
    if (first == second) return true;
    // A real desktop service is stronger than a reverse-DNS suffix:
    // never merge two DISTINCT installed applications just because they
    // share a short basename (or an icon/executable).
    const QString a = canonicalDesktopService(first);
    const QString b = canonicalDesktopService(second);
    if (!a.isEmpty() && !b.isEmpty()) return a == b;
    // Fallback for exporters with a short SNI Id and a qualified task AppId.
    // Require a delimited suffix, not an arbitrary substring.
    return first.size() >= 5 && second.size() >= 5
        && (first.endsWith(QLatin1Char('.') + second)
            || second.endsWith(QLatin1Char('.') + first));
}

// Only used as a SECONDARY hint after a real user-opened task has been
// observed. XEmbedSNIProxy exports the X11 tray window title as SNI Id and
// frequently has NO DesktopEntry at all; its D-Bus PID belongs to the proxy.
// Compare app-name identifiers, never a chat/window title from KWin.
QString desktopApplicationName(const QString &id) {
    // Name resolution was performed repeatedly inside SNI/task matching.
    // Cache positive and negative results, keyed by exact desktop spelling.
    static QHash<QString, QString> serviceNames;
    if (serviceNames.contains(id)) return serviceNames.value(id);
    KService::Ptr service = KService::serviceByDesktopName(id);
    if (!service) service = KService::serviceByStorageId(id);
    if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop"));
    if (!service) service = KService::serviceByStorageId(id + QStringLiteral(".desktop.desktop"));
    const QString name = service ? service->name() : QString();
    if (serviceNames.size() >= 512) serviceNames.clear();
    serviceNames.insert(id, name);
    return name;
}

QString comparableAppName(const QString &name) {
    QString simplified = name.toCaseFolded();
    simplified.remove(QRegularExpression(QStringLiteral("[^a-z0-9]")));
    return simplified;
}

bool sameObservedAppName(const QString &first, const QString &second) {
    const QString left = comparableAppName(first);
    const QString right = comparableAppName(second);
    if (left.size() < 4 || right.size() < 4) return false;
    if (left == right) return true;
    // e.g. TelegramDesktop versus Telegram. Nothing more permissive than
    // this narrow desktop suffix; it cannot turn an arbitrary chat title
    // into an application identity.
    const QString desktop = QStringLiteral("desktop");
    return left == right + desktop || right == left + desktop;
}

// An SNI may expose a generated identifier such as
// "application_status_icon_1" rather than its KWin appId or .desktop file.
// Extract ONLY the owner of a complete, well-formed status/tray icon ID;
// unlike a substring search this cannot match unrelated arbitrary titles.
// The owner is a candidate, NOT a visibility grant: observedDesktopId()
// additionally requires a previously observed real user-opened application
// and rejects matches to multiple distinct applications.
QString statusIconOwnerHint(const QString &notifierId) {
    static const QRegularExpression statusIconId(
        QStringLiteral("^(.+?)[_-](?:status|tray)[_-]icon(?:[_-][0-9]+)?$"),
        QRegularExpression::CaseInsensitiveOption);
    const auto match = statusIconId.match(notifierId.trimmed());
    if (!match.hasMatch()) return {};
    const QString owner = match.captured(1).trimmed();
    return owner.size() >= 4 && owner.size() <= 128 ? owner : QString();
}

// KWin's task name is the first choice; the terminal segment of a qualified
// desktop ID (e.g. org.vendor.application) is a strictly secondary stable
// identifier. This permits Electron/Flatpak builds with generic AppName,
// without matching arbitrary chat titles or matching on the tray icon image.
bool matchesStableObservedIdentity(const QString &appName,
                                   const QString &desktopId,
                                   const QString &ownerHint) {
    if (ownerHint.isEmpty()) return false;
    if (sameObservedAppName(appName, ownerHint)) return true;
    if (!desktopId.contains(QLatin1Char('.'))) return false;
    return sameObservedAppName(desktopId.section(QLatin1Char('.'), -1), ownerHint);
}

bool containsEquivalent(const QSet<QString> &known, const QString &key) {
    for (const QString &candidate : known) {
        if (desktopIdentityMatches(candidate, key)) return true;
    }
    return false;
}

bool notifierMatchesDesktopId(const QVariantMap &item, const QString &wanted) {
    if (wanted.isEmpty()) return false;
    for (const QString &keyName : {QStringLiteral("notifierDesktopEntry"),
                                   QStringLiteral("notifierId"),
                                   QStringLiteral("desktopId"),
                                   QStringLiteral("trayWindowClass"),
                                   QStringLiteral("trayWindowInstance")}) {
        QString value = item.value(keyName).toString().trimmed().toLower();
        for (int depth = 0; depth < 2 && value.endsWith(QLatin1String(".desktop")); ++depth)
            value.chop(8);
        if (desktopIdentityMatches(wanted, value)) return true;
    }
    return false;
}

QVariant propertyValue(const QVariantMap &properties, const QString &name) {
    QVariant value = properties.value(name);
    if (value.metaType() == QMetaType::fromType<QDBusVariant>())
        value = value.value<QDBusVariant>().variant();
    return value;
}

// The canonical DBusMenu tree is (ia{sv}av), with each child wrapped in
// a D-Bus variant. Keep parent IDs so QML can navigate actual submenus,
// rather than flattening every branch into clickable fake actions.
void readMenuLayout(const QDBusArgument &argument, QVariantList &actions,
                    int parentId = -1, int depth = 0) {
    if (depth > 8 || actions.size() >= 160) return;
    int id = 0;
    QVariantMap properties;
    argument.beginStructure();
    argument >> id >> properties;
    const bool visible = !properties.contains(QStringLiteral("visible"))
        || propertyValue(properties, QStringLiteral("visible")).toBool();
    const bool enabled = !properties.contains(QStringLiteral("enabled"))
        || propertyValue(properties, QStringLiteral("enabled")).toBool();
    const bool separator = propertyValue(properties, QStringLiteral("type"))
        .toString() == QLatin1String("separator");
    QString label = propertyValue(properties, QStringLiteral("label")).toString();
    label.remove(QLatin1Char('_')); // DBusMenu labels use '_' as mnemonic.
    const bool hasSubmenu = propertyValue(properties, QStringLiteral("children-display"))
        .toString() == QLatin1String("submenu");
    if (depth > 0 && visible && (separator || !label.isEmpty())) {
        QVariantMap entry;
        entry.insert(QStringLiteral("id"), id);
        entry.insert(QStringLiteral("parentId"), parentId);
        entry.insert(QStringLiteral("label"), label);
        entry.insert(QStringLiteral("enabled"), enabled && !separator);
        entry.insert(QStringLiteral("separator"), separator);
        entry.insert(QStringLiteral("depth"), depth - 1);
        entry.insert(QStringLiteral("hasChildren"), hasSubmenu);
        entry.insert(QStringLiteral("toggleType"), propertyValue(properties,
            QStringLiteral("toggle-type")).toString());
        entry.insert(QStringLiteral("toggleState"), propertyValue(properties,
            QStringLiteral("toggle-state")).toInt());
        entry.insert(QStringLiteral("iconName"), propertyValue(properties,
            QStringLiteral("icon-name")).toString());
        actions.append(entry);
    }
    argument.beginArray();
    while (!argument.atEnd() && actions.size() < 160) {
        QDBusVariant variant;
        argument >> variant;
        const QVariant child = variant.variant();
        if (child.metaType() == QMetaType::fromType<QDBusArgument>())
            readMenuLayout(child.value<QDBusArgument>(), actions, id, depth + 1);
    }
    argument.endArray();
    argument.endStructure();
}

}

int TrayIdentityModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_ids.size());
}

QVariant TrayIdentityModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_ids.size())
        return {};
    if (role == DesktopIdRole || role == Qt::DisplayRole)
        return m_ids.at(index.row());
    return {};
}

QHash<int, QByteArray> TrayIdentityModel::roleNames() const {
    return {{DesktopIdRole, QByteArrayLiteral("desktopId")}};
}

void TrayIdentityModel::synchronize(QStringList ids) {
    ids.removeAll(QString());
    ids.removeDuplicates();
    ids.sort(Qt::CaseInsensitive);
    if (m_ids == ids) return;
    // Preserve existing delegates/rows; never reset the model because a
    // notifier appeared or closed. No synchronous QML notifications unless
    // a genuine identity changed.
    QSet<QString> wanted;
    for (const QString &id : std::as_const(ids)) wanted.insert(id);
    for (int row = static_cast<int>(m_ids.size()) - 1; row >= 0; --row) {
        if (wanted.contains(m_ids.at(row))) continue;
        beginRemoveRows(QModelIndex(), row, row);
        m_ids.removeAt(row);
        endRemoveRows();
    }
    for (int row = 0; row < ids.size(); ++row) {
        if (row < m_ids.size() && m_ids.at(row) == ids.at(row)) continue;
        beginInsertRows(QModelIndex(), row, row);
        m_ids.insert(row, ids.at(row));
        endInsertRows();
    }
}

TrayWindowBridge::TrayWindowBridge(QObject *parent)
    : QObject(parent), m_identityModel(this) {
    // A/B diagnostics: a dedicated runtime directory avoids polling and
    // avoids watching a high-traffic directory shared by other programs.
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (!runtime.isEmpty()) {
        const QString directory = runtime + QStringLiteral("/punchi-dock-remastered");
        if (QDir().mkpath(directory) && m_diagnosticWatcher.addPath(directory)) {
            m_diagnosticMarkerPath = directory
                + QStringLiteral("/disable-tray-observation-r42");
            m_taskDiagnosticMarkerPath = directory
                + QStringLiteral("/disable-task-observation-r43");
            connect(&m_diagnosticWatcher, &QFileSystemWatcher::directoryChanged,
                    this, [this](const QString &) {
                        syncDiagnosticModeFromMarker();
                        syncDiagnosticTaskModeFromMarker();
                    });
        } else {
            qWarning() << "Punchi tray R42: A/B watcher unavailable; normal observation retained";
        }
    }
    m_diagnosticObservationEnabled = m_diagnosticMarkerPath.isEmpty()
        || !QFileInfo::exists(m_diagnosticMarkerPath);
    m_diagnosticTaskObservationEnabled = m_taskDiagnosticMarkerPath.isEmpty()
        || !QFileInfo::exists(m_taskDiagnosticMarkerPath);
    m_taskDiagnosticAutoRestore.setSingleShot(true);
    m_taskDiagnosticAutoRestore.setInterval(180000);
    connect(&m_taskDiagnosticAutoRestore, &QTimer::timeout, this, [this]() {
        if (!m_taskDiagnosticMarkerPath.isEmpty())
            QFile::remove(m_taskDiagnosticMarkerPath);
        setDiagnosticTaskObservationEnabled(true);
        qInfo() << "Punchi task R43 A/B auto-restored after safety timeout";
    });
    if (!m_diagnosticTaskObservationEnabled) {
        m_taskDiagnosticAutoRestore.start();
        qInfo() << "Punchi task R43 A/B mode suspended at start";
    }

    // R40/R41 event-driven discovery and bounded recovery, unchanged when
    // normal observation is active. The diagnostic switch never touches KDE.
    m_refreshTimer.setInterval(120000);
    connect(&m_refreshTimer, &QTimer::timeout, this, &TrayWindowBridge::refresh);
    m_deltaTimer.setSingleShot(true);
    m_deltaTimer.setInterval(60);
    connect(&m_deltaTimer, &QTimer::timeout,
            this, &TrayWindowBridge::applyQueuedNotifierChanges);
    setNotifierSubscriptions(m_diagnosticObservationEnabled);
    if (m_diagnosticObservationEnabled) {
        m_refreshTimer.start();
        QTimer::singleShot(0, this, &TrayWindowBridge::refresh);
    } else {
        qInfo() << "Punchi tray R42 A/B mode suspended at start";
    }
}

void TrayWindowBridge::setNotifierSubscriptions(bool enabled) {
    // Do not intercept the KDE native tray: disconnect only subscriptions
    // owned by this TrayWindowBridge. No service or global configuration changes.
    auto bus = QDBusConnection::sessionBus();
    if (enabled) {
        bus.connect(watcherService, watcherPath, watcherService,
                    QStringLiteral("StatusNotifierItemRegistered"), this,
                    SLOT(notifierRegistered(QString)));
        bus.connect(watcherService, watcherPath, watcherService,
                    QStringLiteral("StatusNotifierItemUnregistered"), this,
                    SLOT(notifierUnregistered(QString)));
        bus.connect(QString(), QString(), notifierInterface,
                    QStringLiteral("NewMenu"), this,
                    SLOT(notifierMenuChanged(QDBusMessage)));
        bus.connect(QString(), QString(), alternativeNotifierInterface,
                    QStringLiteral("NewMenu"), this,
                    SLOT(notifierMenuChanged(QDBusMessage)));
    } else {
        bus.disconnect(watcherService, watcherPath, watcherService,
                       QStringLiteral("StatusNotifierItemRegistered"), this,
                       SLOT(notifierRegistered(QString)));
        bus.disconnect(watcherService, watcherPath, watcherService,
                       QStringLiteral("StatusNotifierItemUnregistered"), this,
                       SLOT(notifierUnregistered(QString)));
        bus.disconnect(QString(), QString(), notifierInterface,
                       QStringLiteral("NewMenu"), this,
                       SLOT(notifierMenuChanged(QDBusMessage)));
        bus.disconnect(QString(), QString(), alternativeNotifierInterface,
                       QStringLiteral("NewMenu"), this,
                       SLOT(notifierMenuChanged(QDBusMessage)));
    }
}

void TrayWindowBridge::syncDiagnosticTaskModeFromMarker() {
    if (m_taskDiagnosticMarkerPath.isEmpty()) return;
    setDiagnosticTaskObservationEnabled(!QFileInfo::exists(m_taskDiagnosticMarkerPath));
}

void TrayWindowBridge::setDiagnosticTaskObservationEnabled(bool enabled) {
    if (enabled == m_diagnosticTaskObservationEnabled) return;
    m_diagnosticTaskObservationEnabled = enabled;
    if (enabled)
        m_taskDiagnosticAutoRestore.stop();
    else
        m_taskDiagnosticAutoRestore.start();
    qInfo() << "Punchi task R43 A/B mode" << (enabled ? "enabled" : "suspended")
            << "task-presentation-updates-only";
    Q_EMIT diagnosticTaskObservationEnabledChanged();
}

void TrayWindowBridge::syncDiagnosticModeFromMarker() {
    if (m_diagnosticMarkerPath.isEmpty()) return;
    setDiagnosticObservationEnabled(!QFileInfo::exists(m_diagnosticMarkerPath));
}

void TrayWindowBridge::setDiagnosticObservationEnabled(bool enabled) {
    if (enabled == m_diagnosticObservationEnabled) return;
    m_diagnosticObservationEnabled = enabled;
    // All outstanding asynchronous replies from the previous mode become
    // stale. Their callbacks may run, but may not publish or overwrite state.
    ++m_observationEpoch;
    setNotifierSubscriptions(enabled);
    m_deltaTimer.stop();
    m_pendingNotifierChanges.clear();
    m_refreshAgain = false;
    m_refreshInFlight = false;
    m_pendingItemReads = 0;
    m_scannedEntries.clear();
    m_scannedServices.clear();
    m_fanPublicationDeferred = false;
    m_deferredWindowTaskSnapshots.clear();
    m_observationArmed = false;
    m_recentlyActiveWindowApps.clear();
    if (enabled) {
        m_refreshTimer.start();
        // Initial window snapshot is a baseline, not proof that an autostart
        // notifier was explicitly activated while diagnostics were suspended.
        QTimer::singleShot(0, this, &TrayWindowBridge::refresh);
    } else {
        m_refreshTimer.stop();
    }
    qInfo() << "Punchi tray R42 A/B mode"
            << (enabled ? "enabled" : "suspended")
            << "cached-entries" << m_allEntries.size()
            << "epoch" << m_observationEpoch;
    Q_EMIT diagnosticObservationEnabledChanged();
}

void TrayWindowBridge::notifierRegistered(const QString &address) {
    if (!m_diagnosticObservationEnabled) return;
    queueNotifierChange(address, true);
}

void TrayWindowBridge::notifierUnregistered(const QString &address) {
    if (!m_diagnosticObservationEnabled) return;
    queueNotifierChange(address, false);
}

void TrayWindowBridge::notifierMenuChanged(const QDBusMessage &message) {
    if (!m_diagnosticObservationEnabled) return;
    // No untrusted name/title matching. Match the bus sender and exported
    // object path of an existing notifier only; an unknown NewMenu cannot
    // force an N-item reconciliation of the entire desktop.
    const QString service = message.service();
    const QString path = message.path();
    if (service.isEmpty() || path.isEmpty()) return;
    const QString key = service + path;
    for (const QVariant &candidate : m_allEntries) {
        const QVariantMap entry = candidate.toMap();
        if (entry.value(QStringLiteral("service")).toString()
                    + entry.value(QStringLiteral("path")).toString() == key) {
            queueNotifierChange(key, true);
            return;
        }
    }
}

void TrayWindowBridge::queueNotifierChange(const QString &address, bool present) {
    if (!m_diagnosticObservationEnabled) return;
    const int slash = address.indexOf(QLatin1Char('/'));
    const QString service = slash >= 0 ? address.left(slash) : address;
    const QString path = slash >= 0 ? address.mid(slash)
        : QStringLiteral("/StatusNotifierItem");
    if (service.isEmpty() || !path.startsWith(QLatin1Char('/'))
            || service.contains(QLatin1Char('/'))) {
        // Malformed notifications are handled by the next reconciliation.
        return;
    }
    m_pendingNotifierChanges.insert(service + path, present);
    // A burst of many registrations is reduced to one bounded publication.
    if (m_pendingNotifierChanges.size() > 128) {
        m_pendingNotifierChanges.clear();
        m_refreshAgain = true;
        if (!m_refreshInFlight && !m_fanRevealActive)
            QTimer::singleShot(0, this, &TrayWindowBridge::refresh);
        return;
    }
    // Do not postpone delivery indefinitely if exporters generate a stream
    // of NewMenu/registration signals. The batch latency is bounded by the
    // first event, not reset on every subsequent event.
    if (!m_deltaTimer.isActive()) m_deltaTimer.start();
}

void TrayWindowBridge::applyQueuedNotifierChanges() {
    if (!m_diagnosticObservationEnabled) return;
    if (m_pendingNotifierChanges.isEmpty()) return;
    if (m_refreshInFlight || m_fanRevealActive) return;

    QHash<QString, bool> updates;
    updates.swap(m_pendingNotifierChanges);
    // Reuse the proven asynchronous GetAll -> PID -> XEmbed pipeline, but
    // pass it only affected addresses and merge with existing SNI state.
    m_refreshInFlight = true;
    m_scannedEntries = m_allEntries;
    m_pendingItemReads = 0;
    ++m_deltaBatches;
    m_lastBatchSize = updates.size();
    QStringList keys = updates.keys();
    keys.sort();
    for (const QString &key : std::as_const(keys)) {
        for (qsizetype i = m_scannedEntries.size(); i > 0; --i) {
            const QVariantMap entry = m_scannedEntries.at(i - 1).toMap();
            if (entry.value(QStringLiteral("service")).toString()
                    + entry.value(QStringLiteral("path")).toString() == key)
                m_scannedEntries.removeAt(i - 1);
        }
        if (!updates.value(key)) continue;
        const int slash = key.indexOf(QLatin1Char('/'));
        if (slash <= 0) continue;
        ++m_pendingItemReads;
        ++m_deltaReads;
        requestNotifierProperties(key.left(slash), key.mid(slash));
    }
    qInfo() << "Punchi tray R40 delta-batch items" << m_lastBatchSize
            << "reads" << m_pendingItemReads;
    if (!m_pendingItemReads) finishRefresh();
}

QVariantMap TrayWindowBridge::performanceCounters() const {
    return QVariantMap{
        {QStringLiteral("fullScans"), QVariant::fromValue(m_fullScans)},
        {QStringLiteral("deltaBatches"), QVariant::fromValue(m_deltaBatches)},
        {QStringLiteral("deltaReads"), QVariant::fromValue(m_deltaReads)},
        {QStringLiteral("registered"), m_allEntries.size()},
        {QStringLiteral("queuedChanges"), m_pendingNotifierChanges.size()},
        {QStringLiteral("lastBatchSize"), m_lastBatchSize},
        {QStringLiteral("diagnosticObservationEnabled"), m_diagnosticObservationEnabled}
    };
}

QString TrayWindowBridge::normalized(const QString &value) {
    QString key = value.trimmed().toLower();
    if (key.startsWith(QLatin1String("applications:"))) key.remove(0, 13);
    if (key.contains(QLatin1Char('/'))) key = key.section(QLatin1Char('/'), -1);
    // Some packages use an XDG app ID that itself ends with ".desktop".
    // Their desktop filename then ends with ".desktop.desktop"; compare
    // all such aliases consistently instead of dropping the task-to-SNI link.
    for (int depth = 0; depth < 2 && key.endsWith(QLatin1String(".desktop")); ++depth)
        key.chop(8);
    return key;
}

void TrayWindowBridge::setFanRevealActive(bool active) {
    if (m_fanRevealActive == active) return;
    m_fanRevealActive = active;
    Q_EMIT fanRevealActiveChanged();
    ++m_fanGuardGeneration;
    if (active) {
        // Recover even if a future QML regression leaves a popup stuck in its
        // opening state; ordinary animation speeds complete well before 4s.
        const quint64 generation = m_fanGuardGeneration;
        QTimer::singleShot(4000, this, [this, generation]() {
            if (m_fanRevealActive && m_fanGuardGeneration == generation) {
                qWarning() << "Punchi tray R36 fan-guard timeout: releasing delayed work";
                setFanRevealActive(false);
            }
        });
    }
    if (!active && !m_fanFlushScheduled) {
        m_fanFlushScheduled = true;
        // Exit the animation's bindings before recomputing any SNI model.
        QTimer::singleShot(0, this, &TrayWindowBridge::flushDeferredFanWork);
    }
}

void TrayWindowBridge::flushDeferredFanWork() {
    if (!m_diagnosticObservationEnabled) return;
    m_fanFlushScheduled = false;
    if (m_fanRevealActive) return; // A new reveal already started.
    const bool publishPending = m_fanPublicationDeferred;
    m_fanPublicationDeferred = false;
    if (publishPending) finishRefresh();
    // The order matters: open-then-close of a window must grant the same
    // explicitly observed app identity as it would without the guard.
    const auto snapshots = std::move(m_deferredWindowTaskSnapshots);
    m_deferredWindowTaskSnapshots.clear();
    for (const QVariantList &snapshot : snapshots) {
        if (m_fanRevealActive) {
            m_deferredWindowTaskSnapshots.append(snapshot);
        } else {
            observeWindowTasks(snapshot);
        }
    }
    // A timeout, NewMenu or registered/unregistered notification that arrived
    // while protected is serviced once as soon as the animation completes.
    if (m_refreshAgain && !m_refreshInFlight && !m_fanRevealActive) {
        m_refreshAgain = false;
        QTimer::singleShot(0, this, &TrayWindowBridge::refresh);
    } else if (!m_pendingNotifierChanges.isEmpty() && !m_refreshInFlight) {
        QTimer::singleShot(0, this, &TrayWindowBridge::applyQueuedNotifierChanges);
    }
}

void TrayWindowBridge::observeWindowApps(const QStringList &desktopIds) {
    QVariantList windows;
    for (const QString &desktopId : desktopIds)
        windows.append(QVariantMap{{QStringLiteral("desktopId"), desktopId}});
    observeWindowTasks(windows);
}

void TrayWindowBridge::observeWindowTasks(const QVariantList &tasks) {
    if (!m_diagnosticObservationEnabled) return;
    // The fan's opening lasts only a few hundred milliseconds. Do not walk
    // TaskManager/KService or notify its QML delegates mid-reveal. Retain ALL
    // distinct snapshots in order: keeping only the final one would lose a
    // user-opened app that closed into the tray during the reveal.
    if (m_fanRevealActive) {
        if (m_deferredWindowTaskSnapshots.isEmpty()
                || m_deferredWindowTaskSnapshots.constLast() != tasks)
            m_deferredWindowTaskSnapshots.append(tasks);
        return;
    }
    QElapsedTimer work; work.start();
    const QVariantList oldObserved = m_cachedObservedValid
        ? m_cachedObservedEntries : observedEntries();
    const QVariantList oldDynamic = m_cachedDynamicValid
        ? m_cachedDynamicEntries : entries();
    QSet<QString> current;
    QSet<quint32> currentPids;
    QHash<quint32, QString> pidOwners;
    QSet<quint32> ambiguousPids;
    QHash<QString, QString> currentNames;
    QSet<QString> currentPrimaries;
    struct WindowTask {
        QString primary;
        QString appName;
        bool active = false;
        QSet<QString> aliases;
        quint32 pid = 0;
    };
    QList<WindowTask> observed;

    for (const QVariant &value : tasks) {
        const QVariantMap task = value.toMap();
        WindowTask window;
        window.appName = task.value(QStringLiteral("appName")).toString();
        window.active = task.value(QStringLiteral("isActive")).toBool();
        for (const QString &field : {QStringLiteral("desktopId"),
                                     QStringLiteral("launcherId"),
                                     QStringLiteral("resolvedId")}) {
            const QString id = normalized(task.value(field).toString());
            if (id.isEmpty()) continue;
            if (window.primary.isEmpty()) window.primary = id;
            window.aliases.insert(id);
            current.insert(id);
        }
        // AppPid may be inaccurate on Wayland (the window can be attributed
        // to KWin), so NEVER use a PID shared by different desktop identities.
        bool pidOk = false;
        const qulonglong rawPid = task.value(QStringLiteral("pid")).toULongLong(&pidOk);
        if (pidOk && rawPid > 1 && rawPid <= std::numeric_limits<quint32>::max()) {
            window.pid = static_cast<quint32>(rawPid);
            currentPids.insert(window.pid);
            const auto known = pidOwners.constFind(window.pid);
            if (known != pidOwners.cend()
                    && !desktopIdentityMatches(known.value(), window.primary)) {
                ambiguousPids.insert(window.pid);
            } else if (known == pidOwners.cend()) {
                pidOwners.insert(window.pid, window.primary);
            }
        }
        if (!window.primary.isEmpty()) {
            currentPrimaries.insert(window.primary);
            if (!window.appName.isEmpty())
                currentNames.insert(window.primary, window.appName);
            observed.append(window);
        }
    }
    for (quint32 pid : ambiguousPids) pidOwners.remove(pid);

    if (m_observationArmed) {
        for (const WindowTask &window : observed) {
            if (window.active) m_recentlyActiveWindowApps.insert(window.primary);
            if (containsEquivalent(m_currentWindowApps, window.primary)) continue;
            for (const QString &alias : window.aliases)
                m_seenForegroundApps.insert(alias);
            const QString resolvedName = window.appName.isEmpty()
                ? desktopApplicationName(window.primary) : window.appName;
            if (!resolvedName.isEmpty())
                m_seenForegroundAppNames.insert(window.primary, resolvedName);
            // Only observed, newly opened windows can grant their process a
            // dynamic tray entry. Existing autostart programs are not promoted.
            if (window.pid && pidOwners.contains(window.pid))
                m_seenForegroundAppByPid.insert(window.pid, window.primary);
            qInfo().noquote() << "Punchi tray: observed task opened after baseline"
                              << window.primary << "process-match"
                              << (window.pid && pidOwners.contains(window.pid));
        }
        // An app can already have a visible window when the plasmoid starts.
        // After that window has been active in the session and then disappears
        // (typical X/close-to-tray), remember its REAL TaskManager identity.
        // Pure autostart SNIs without a window never enter this path.
        for (const QString &prior : m_currentWindowPrimaryApps) {
            if (containsEquivalent(currentPrimaries, prior)) continue;
            if (!containsEquivalent(m_recentlyActiveWindowApps, prior)) continue;
            m_seenForegroundApps.insert(prior);
            const QString oldName = m_currentWindowAppNames.value(prior);
            const QString appName = oldName.isEmpty()
                ? desktopApplicationName(prior) : oldName;
            if (!appName.isEmpty()) m_seenForegroundAppNames.insert(prior, appName);
            // Debug IDs only, not private window titles or notification text.
            // This makes future field diagnostics distinguish an SNI identity
            // mismatch from a missing/unregistered notifier.
            QStringList matchedNotifierIds;
            for (const QVariant &candidate : m_allEntries) {
                const QVariantMap notifier = candidate.toMap();
                if (desktopIdentityMatches(observedDesktopId(notifier), prior))
                    matchedNotifierIds.append(
                        notifier.value(QStringLiteral("notifierId")).toString());
            }
            qInfo().noquote() << "Punchi tray: recently active window closed"
                              << prior << "notifier-required-for-visibility"
                              << "matched-notifier-ids" << matchedNotifierIds;
        }
    } else {
        // Initial snapshot is a baseline. Record active windows solely so
        // their later close-to-tray transition counts as an interaction;
        // neither a current window nor a pure startup SNI is promoted now.
        for (const WindowTask &window : observed) {
            if (window.active) m_recentlyActiveWindowApps.insert(window.primary);
        }
        m_observationArmed = true;
    }
    for (auto it = m_recentlyActiveWindowApps.begin();
         it != m_recentlyActiveWindowApps.end();) {
        if (!containsEquivalent(currentPrimaries, *it))
            it = m_recentlyActiveWindowApps.erase(it);
        else ++it;
    }
    // Never keep a PID association that is ambiguous or has been recycled
    // by a different observed application (potential PID reuse).
    for (quint32 pid : ambiguousPids) m_seenForegroundAppByPid.remove(pid);
    for (auto it = pidOwners.cbegin(); it != pidOwners.cend(); ++it) {
        if (m_seenForegroundAppByPid.contains(it.key())
                && !desktopIdentityMatches(m_seenForegroundAppByPid.value(it.key()),
                                            it.value()))
            m_seenForegroundAppByPid.remove(it.key());
    }
    const bool changed = current != m_currentWindowApps
        || currentPids != m_currentWindowPids
        || pidOwners != m_currentWindowAppByPid
        || currentNames != m_currentWindowAppNames
        || currentPrimaries != m_currentWindowPrimaryApps;
    m_currentWindowApps = current;
    m_currentWindowPids = currentPids;
    m_currentWindowAppByPid = pidOwners;
    m_currentWindowAppNames = currentNames;
    m_currentWindowPrimaryApps = currentPrimaries;
    if (changed) {
        // Window revisions with no change in the resulting SNI items must not
        // rerun every QML task/dock binding. That synchronous signal used to
        // consume tens or hundreds of milliseconds in plasmashell. The old
        // derived snapshots are already cached by the two QML properties.
        // A change of window focus / PID must not invalidate the entire dock
        // when the *effective* observed and dynamic tray models stay equal.
        // Each QML property now has its own notify signal (R37).
        publishEffectiveModelChanges(oldObserved, oldDynamic, "observeWindowTasks");
    }
    if (work.elapsed() > 20)
        qInfo() << "Punchi tray R36 ui-work observeWindowTasks-total-ms" << work.elapsed();
}

void TrayWindowBridge::invalidateEntryCaches() {
    m_cachedObservedValid = false;
    m_cachedDynamicValid = false;
    m_cachedRegisteredValid = false;
    m_cachedRegisteredDesktopIdsValid = false;
    // Include negative results: an absent SNI must be rechecked after refresh.
    m_cachedNotifierPresence.clear();
    m_cachedObservedEntries.clear();
    m_cachedDynamicEntries.clear();
    m_cachedRegisteredEntries.clear();
    m_cachedRegisteredDesktopIds.clear();
}

void TrayWindowBridge::publishEffectiveModelChanges(const QVariantList &oldObserved,
                                                    const QVariantList &oldDynamic,
                                                    const char *origin) {
    invalidateEntryCaches();
    // Compare actual QML-facing snapshots, not internal SNI metadata.
    // A changing icon pixmap/status cannot trigger a full TaskModel rebuild
    // unless the *observed desktop IDs* have genuinely changed.
    const QVariantList newObserved = observedEntries();
    const QVariantList newDynamic = entries();
    if (oldObserved != newObserved) {
        QStringList keys;
        for (const QVariant &candidate : newObserved)
            keys.append(candidate.toMap().value(QStringLiteral("desktopId")).toString());
        m_identityModel.synchronize(keys);
    }
    QElapsedTimer signalTimer;
    if (oldObserved != newObserved) {
        signalTimer.start();
        Q_EMIT observedEntriesChanged();
        if (signalTimer.elapsed() > 20)
            qInfo() << "Punchi tray R38 qml-notify observed-ms" << signalTimer.elapsed()
                    << origin;
    }
    if (oldDynamic != newDynamic) {
        signalTimer.start();
        Q_EMIT entriesChanged();
        if (signalTimer.elapsed() > 20)
            qInfo() << "Punchi tray R38 qml-notify dynamic-ms" << signalTimer.elapsed()
                    << origin;
    }
}

void TrayWindowBridge::noteUserInteraction(const QString &desktopId) {
    if (!m_diagnosticObservationEnabled) return;
    const QString key = normalized(desktopId);
    if (key.isEmpty() || containsEquivalent(m_seenForegroundApps, key)) return;
    // This API is only used on real user input. An autostart SNI is not
    // promoted by refresh, discovery, or model initialization.
    // Capture old models BEFORE changing visibility eligibility.
    const QVariantList oldObserved = m_cachedObservedValid
        ? m_cachedObservedEntries : observedEntries();
    const QVariantList oldDynamic = m_cachedDynamicValid
        ? m_cachedDynamicEntries : entries();
    m_seenForegroundApps.insert(key);
    for (auto itName = m_currentWindowAppNames.cbegin();
         itName != m_currentWindowAppNames.cend(); ++itName) {
        if (desktopIdentityMatches(key, itName.key()))
            m_seenForegroundAppNames.insert(itName.key(), itName.value());
    }
    for (auto it = m_currentWindowAppByPid.cbegin();
         it != m_currentWindowAppByPid.cend(); ++it) {
        if (desktopIdentityMatches(key, it.value()))
            m_seenForegroundAppByPid.insert(it.key(), it.value());
    }
    publishEffectiveModelChanges(oldObserved, oldDynamic, "noteUserInteraction");
}

// Resolve the notifier against the app which actually had a real window
// after the initial taskbar snapshot. DesktopEntry and Id may differ from the
// task manager appId (e.g. org.kde.zapzap vs zapzap). Only accept an exact
// match or a uniquely qualified suffix; never promote a notifier just because
// it exists in the system tray.
QString TrayWindowBridge::observedDesktopId(const QVariantMap &item) const {
    QStringList keys;
    for (const QString &field : {QStringLiteral("notifierDesktopEntry"),
                                 QStringLiteral("notifierId"),
                                 QStringLiteral("desktopId"),
                                 QStringLiteral("trayWindowClass"),
                                 QStringLiteral("trayWindowInstance")}) {
        const QString key = normalized(item.value(field).toString());
        if (!key.isEmpty() && !keys.contains(key)) keys.append(key);
    }
    // The same KDE application can be observed as both a short name and a
    // reverse-DNS desktop ID; that is ONE identity, not an ambiguity.
    // Different resolved services remain strictly separate.
    QString found;
    QStringList observed = m_seenForegroundApps.values();
    observed.sort();  // QSet iteration order is undefined.
    for (const QString &seen : observed) {
        bool matches = false;
        for (const QString &key : keys) {
            if (desktopIdentityMatches(seen, key)) {
                matches = true;
                break;
            }
        }
        if (!matches) continue;
        if (!found.isEmpty() && !desktopIdentityMatches(found, seen))
            return QString();  // Ambiguous: do not promote a wrong SNI.
        if (found.isEmpty() || m_currentWindowApps.contains(seen)) found = seen;
    }
    if (!found.isEmpty()) return found;
    // XEmbedSNIProxy is a KDE-owned process, NOT the application. The
    // embedded X11 tray window has a separate real PID when available.
    for (const QString &field : {QStringLiteral("trayWindowPid"),
                                 QStringLiteral("appPid")}) {
        const quint32 pid = item.value(field).toUInt();
        if (pid && m_seenForegroundAppByPid.contains(pid))
            return m_seenForegroundAppByPid.value(pid);
    }
    // If DesktopEntry resolves to a different installed application, its
    // declared service wins over any generic label/WM_CLASS fallback.
    const QString declaredDesktop = normalized(
        item.value(QStringLiteral("notifierDesktopEntry")).toString());
    if (!declaredDesktop.isEmpty()
            && !canonicalDesktopService(declaredDesktop).isEmpty())
        return {};

    // The XEmbed proxy supplies Id=Title and WindowId, not a trustworthy
    // desktop service. Match ONLY unique names from user-opened real tasks.
    // This allows Discord, Telegram, and future Electron/legacy tray apps
    // without any per-app names or a false app PID from xembedsniproxy.
    // Missing DesktopEntry and WindowId=0 is legitimate for StatusNotifier
    // exporters. For generated SNI Ids, prefer its stable owner token rather
    // than querying an unavailable X11 tray window or guessing its bus PID.
    const QString statusIconOwner = statusIconOwnerHint(
        item.value(QStringLiteral("notifierId")).toString());
    QString matched;
    for (auto it = m_seenForegroundAppNames.cbegin();
         it != m_seenForegroundAppNames.cend(); ++it) {
        bool accepts = false;
        for (const QString &hintField : {QStringLiteral("trayWindowClass"),
                                        QStringLiteral("trayWindowInstance"),
                                        QStringLiteral("notifierId")}) {
            if (sameObservedAppName(it.value(), item.value(hintField).toString())) {
                accepts = true;
                break;
            }
        }
        if (!accepts && !statusIconOwner.isEmpty())
            accepts = matchesStableObservedIdentity(it.value(), it.key(), statusIconOwner);
        if (!accepts) continue;
        if (!matched.isEmpty() && !desktopIdentityMatches(matched, it.key()))
            return {}; // Two distinct task applications claimed this label.
        matched = it.key();
    }
    return matched;
}

bool TrayWindowBridge::matchesDesktopId(const QVariantMap &item,
                                         const QString &desktopId) const {
    const QString wanted = normalized(desktopId);
    if (notifierMatchesDesktopId(item, wanted)) return true;
    const QString observed = observedDesktopId(item);
    if (!observed.isEmpty()) return desktopIdentityMatches(wanted, observed);
    // A permanently pinned launcher must also restore an already-running
    // XEmbed app started at KDE login. This is an explicit lookup, not a
    // dynamic-entry visibility grant. Require a real installed desktop
    // service and a matching stable app name/WM_CLASS, never an icon guess.
    const QString declared = normalized(
        item.value(QStringLiteral("notifierDesktopEntry")).toString());
    if (!declared.isEmpty() && !canonicalDesktopService(declared).isEmpty())
        return false;
    const QString appName = desktopApplicationName(wanted);
    if (appName.isEmpty()) return false;
    for (const QString &field : {QStringLiteral("trayWindowClass"),
                                 QStringLiteral("trayWindowInstance"),
                                 QStringLiteral("notifierId")}) {
        if (sameObservedAppName(appName, item.value(field).toString()))
            return true;
    }
    // A pinned item is an explicit user choice. The generic generated-ID
    // fallback works even if this tray exporter was present at login, but it
    // never creates a dynamic entry without a task observed in this session.
    const QString statusIconOwner = statusIconOwnerHint(
        item.value(QStringLiteral("notifierId")).toString());
    return matchesStableObservedIdentity(appName, wanted, statusIconOwner);
}

bool TrayWindowBridge::eligible(const QVariantMap &item) const {
    const QString observed = observedDesktopId(item);
    // A visible window with a different KService alias already owns the
    // dynamic task delegate. Never draw an additional tray-only icon.
    if (observed.isEmpty() || containsEquivalent(m_currentWindowApps, observed))
        return false;
    const quint32 pid = item.value(QStringLiteral("trayWindowPid")).toUInt();
    const quint32 ownerPid = item.value(QStringLiteral("appPid")).toUInt();
    return (!pid || !m_currentWindowPids.contains(pid))
        && (!ownerPid || !m_currentWindowPids.contains(ownerPid));
}

QVariantList TrayWindowBridge::contextActions() const { return m_contextActions; }
QString TrayWindowBridge::contextMenuDesktopId() const { return m_contextMenuDesktopId; }

// All notifiers that were previously seen with a user-opened taskbar window,
// including when they currently have a window. Wheel navigation uses this
// stable identity across the transition from visible window to tray-only.
QVariantList TrayWindowBridge::observedEntries() const {
    if (m_cachedObservedValid) return m_cachedObservedEntries;
    QElapsedTimer work; work.start();
    // The wheel controller only needs stable desktop IDs, NOT SNI pixmaps,
    // status strings, menu metadata or DBus paths. Those fields can churn
    // without any change to the user's task/window identity.
    QStringList identities;
    for (const auto &candidate : m_allEntries) {
        const QString observed = observedDesktopId(candidate.toMap());
        if (!observed.isEmpty() && !identities.contains(observed))
            identities.append(observed);
    }
    identities.sort(Qt::CaseInsensitive);
    QVariantList tracked;
    for (const QString &observed : std::as_const(identities))
        tracked.append(QVariantMap{{QStringLiteral("desktopId"), observed}});
    m_cachedObservedEntries = tracked;
    m_cachedObservedValid = true;
    if (work.elapsed() > 20)
        qInfo() << "Punchi tray R36 ui-work observedEntries-ms" << work.elapsed();
    return m_cachedObservedEntries;
}

QVariantList TrayWindowBridge::registeredEntries() const {
    if (m_cachedRegisteredValid) return m_cachedRegisteredEntries;
    // QML only needs registered desktop identity for pinned launchers.
    // Keep the service/path/menu identity so an exported DBusMenu replacement
    // still notifies pending native menus. Never publish SNI status, title,
    // mutable pixmaps or application PIDs through this binding.
    QVariantList registered;
    for (const QVariant &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        registered.append(QVariantMap{
            {QStringLiteral("desktopId"), item.value(QStringLiteral("desktopId"))},
            {QStringLiteral("service"), item.value(QStringLiteral("service"))},
            {QStringLiteral("path"), item.value(QStringLiteral("path"))},
            {QStringLiteral("menuPath"), item.value(QStringLiteral("menuPath"))}
        });
    }
    m_cachedRegisteredEntries = registered;
    m_cachedRegisteredValid = true;
    return m_cachedRegisteredEntries;
}

QStringList TrayWindowBridge::registeredDesktopIds() const {
    if (m_cachedRegisteredDesktopIdsValid) return m_cachedRegisteredDesktopIds;
    QStringList ids;
    for (const QVariant &candidate : m_allEntries) {
        const QString desktop = normalized(candidate.toMap()
            .value(QStringLiteral("desktopId")).toString());
        if (!desktop.isEmpty() && !ids.contains(desktop)) ids.append(desktop);
    }
    ids.sort(Qt::CaseInsensitive);
    m_cachedRegisteredDesktopIds = ids;
    m_cachedRegisteredDesktopIdsValid = true;
    return m_cachedRegisteredDesktopIds;
}

QVariantList TrayWindowBridge::entries() const {
    if (m_cachedDynamicValid) return m_cachedDynamicEntries;
    QElapsedTimer work; work.start();
    QVariantList filtered;
    QSet<QString> emitted;
    for (const auto &candidate : m_allEntries) {
        QVariantMap item = candidate.toMap();
        if (!eligible(item)) continue;
        const QString matchedId = observedDesktopId(item);
        if (emitted.contains(matchedId)) continue;
        emitted.insert(matchedId);
        // Only publish data consumed by DockItem. SNI Status, PID, category,
        // menu paths and icon pixmaps may change frequently yet do not affect
        // this delegate: retaining them would recreate the dynamic dock row.
        // Keep the correct installed app icon (R33) and its visible tooltip.
        filtered.append(QVariantMap{
            {QStringLiteral("desktopId"), matchedId},
            {QStringLiteral("icon"), desktopIcon(matchedId,
                item.value(QStringLiteral("icon")).toString())},
            {QStringLiteral("title"), item.value(QStringLiteral("title"))}
        });
    }
    m_cachedDynamicEntries = filtered;
    m_cachedDynamicValid = true;
    if (work.elapsed() > 20)
        qInfo() << "Punchi tray R36 ui-work dynamicEntries-ms" << work.elapsed();
    return m_cachedDynamicEntries;
}

void TrayWindowBridge::refresh() {
    if (!m_diagnosticObservationEnabled) return;
    const quint64 epoch = m_observationEpoch;
    // Registration changes are never lost: a single refresh after the fan
    // opens fetches the final SNI state. Avoid flooding async GetAll/PID/xprop
    // requests while the QML scene graph is animating.
    if (m_fanRevealActive) { m_refreshAgain = true; return; }
    if (m_refreshInFlight) { m_refreshAgain = true; return; }
    m_refreshInFlight = true;
    ++m_fullScans;
    qInfo() << "Punchi tray R40 reconciliation" << m_fullScans;
    m_scannedEntries.clear();
    m_scannedServices.clear();
    m_pendingItemReads = 0;

    auto message = QDBusMessage::createMethodCall(watcherService, watcherPath,
        propertiesInterface, QStringLiteral("Get"));
    message.setArguments({watcherService, QStringLiteral("RegisteredStatusNotifierItems")});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch]() {
        const QDBusPendingReply<QDBusVariant> reply = *watcher;
        watcher->deleteLater();
        if (!m_diagnosticObservationEnabled || epoch != m_observationEpoch) return;
        if (reply.isError()) {
            // Watcher may be restarting. Keep the last known state rather
            // than suddenly removing every tray-only launcher on a timeout.
            qWarning() << "Punchi tray R40 watcher reconciliation failed:"
                       << reply.error().message();
            m_scannedEntries = m_allEntries;
            finishRefresh();
            return;
        }
        const QStringList registered = reply.value().variant().toStringList();
        for (const QString &registeredItem : registered.mid(0, 128)) {
            const int separator = registeredItem.indexOf(QLatin1Char('/'));
            const QString service = separator >= 0 ? registeredItem.left(separator) : registeredItem;
            const QString path = separator >= 0 ? registeredItem.mid(separator)
                : QStringLiteral("/StatusNotifierItem");
            if (!service.isEmpty() && path.startsWith(QLatin1Char('/'))
                    && !m_scannedServices.contains(service + path)) {
                m_scannedServices.insert(service + path);
                ++m_pendingItemReads;
                requestNotifierProperties(service, path);
            }
        }
        if (!m_pendingItemReads) finishRefresh();
    });
}

void TrayWindowBridge::requestNotifierProperties(const QString &service, const QString &path,
                                                 const QString &interfaceName) {
    if (!m_diagnosticObservationEnabled) return;
    const quint64 epoch = m_observationEpoch;
    auto message = QDBusMessage::createMethodCall(service, path,
        propertiesInterface, QStringLiteral("GetAll"));
    message.setArguments({interfaceName});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [this, watcher, service, path, interfaceName, epoch]() {
            const QDBusPendingReply<QVariantMap> reply = *watcher;
            watcher->deleteLater();
            if (!m_diagnosticObservationEnabled || epoch != m_observationEpoch) return;
            if (reply.isError() && interfaceName == notifierInterface) {
                // Some SNI exporters implement the freedesktop spelling.
                requestNotifierProperties(service, path, alternativeNotifierInterface);
                return;  // the second attempt owns the pending read counter.
            }
            if (reply.isError()) {
                qWarning().noquote() << "Punchi tray: GetAll failed for notifier" << service
                                     << path << reply.error().message();
                // A temporary GetAll error does not mean this registered SNI
                // vanished. Preserve its previously verified identity until
                // an actual Unregistered event or the next health scan.
                for (const QVariant &previous : std::as_const(m_allEntries)) {
                    const QVariantMap old = previous.toMap();
                    if (old.value(QStringLiteral("service")).toString() == service
                            && old.value(QStringLiteral("path")).toString() == path) {
                        m_scannedEntries.append(previous);
                        break;
                    }
                }
            } else {
                const QVariantMap properties = reply.value();
                const auto textProperty = [&properties](const QString &name) {
                    const QVariant value = propertyValue(properties, name);
                    if (value.metaType() == QMetaType::fromType<QDBusObjectPath>())
                        return value.value<QDBusObjectPath>().path();
                    return value.toString();
                };
                const QString desktop = normalized(textProperty(QStringLiteral("DesktopEntry")));
                const QString id = normalized(textProperty(QStringLiteral("Id")));
                const QString key = !desktop.isEmpty() ? desktop : id;
                const quint32 windowId = propertyValue(properties,
                    QStringLiteral("WindowId")).toUInt();
                // KDE 6.8.2's systemtraymodel publishes Category for these
                // values. Never promote hardware/session services into dock
                // apps even if they briefly own a visible settings window.
                const QString category = textProperty(QStringLiteral("Category"));
                if (category.compare(QLatin1String("SystemServices"), Qt::CaseInsensitive) == 0
                        || category.compare(QLatin1String("Hardware"), Qt::CaseInsensitive) == 0)
                {
                    // intentionally excluded from dynamic application dock
                } else if (!key.isEmpty() || windowId != 0) {
                    // DesktopEntry can differ from Id (flatpak/XDG wrappers).
                    // The item must match a window the user actually opened;
                    // never admit a pure startup notifier by its mere presence.
                    const QString observed = key;
                    QVariantMap entry;
                    entry.insert(QStringLiteral("notifierDesktopEntry"), desktop);
                    entry.insert(QStringLiteral("notifierId"), id);
                    if (windowId) entry.insert(QStringLiteral("trayWindowId"), windowId);
                    entry.insert(QStringLiteral("category"), category);
                    entry.insert(QStringLiteral("status"), textProperty(QStringLiteral("Status")));
                    entry.insert(QStringLiteral("desktopId"), observed);
                    entry.insert(QStringLiteral("icon"), textProperty(QStringLiteral("IconName")));
                    entry.insert(QStringLiteral("title"), textProperty(QStringLiteral("Title")));
                    entry.insert(QStringLiteral("service"), service);
                    entry.insert(QStringLiteral("notifierInterface"), interfaceName);
                    entry.insert(QStringLiteral("path"), path);
                    entry.insert(QStringLiteral("menuPath"),
                        textProperty(QStringLiteral("Menu")));
                    requestNotifierPid(entry);
                    return; // async PID query now owns this pending read
                }
            }
            if (--m_pendingItemReads == 0) finishRefresh();
        });
}

void TrayWindowBridge::requestNotifierPid(QVariantMap entry) {
    if (!m_diagnosticObservationEnabled) return;
    const quint64 epoch = m_observationEpoch;
    const QString service = entry.value(QStringLiteral("service")).toString();
    // The SNI specification permits a unique service name embedding the PID.
    // Do not trust unrelated digits from arbitrary D-Bus service names.
    static const QRegularExpression itemPidPattern(
        QStringLiteral("(?:^|\\.)StatusNotifierItem-(\\d+)-\\d+$"));
    const auto match = itemPidPattern.match(service);
    if (match.hasMatch()) {
        bool ok = false;
        const uint pid = match.captured(1).toUInt(&ok);
        if (ok && pid > 1) entry.insert(QStringLiteral("appPid"), pid);
        requestTrayWindowIdentity(entry);
        return;
    }

    // Many Electron/Qt exporters register as a D-Bus unique name (":1.123")
    // rather than a name containing the process ID. Resolve the real owner.
    auto message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("GetConnectionUnixProcessID"));
    message.setArguments({service});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, entry, epoch]() mutable {
        const QDBusPendingReply<uint> reply = *watcher;
        watcher->deleteLater();
        if (!m_diagnosticObservationEnabled || epoch != m_observationEpoch) return;
        if (!reply.isError() && reply.value() > 1)
            entry.insert(QStringLiteral("appPid"), reply.value());
        requestTrayWindowIdentity(entry);
    });
}

void TrayWindowBridge::requestTrayWindowIdentity(QVariantMap entry) {
    if (!m_diagnosticObservationEnabled) return;
    const quint64 epoch = m_observationEpoch;
    // Optional xprop lookup for the real embedded X11 tray window. The
    // GetConnectionUnixProcessID result above is the *proxy* PID on KDE
    // XEmbedSNIProxy, so do not depend on it for matching.
    const quint32 windowId = entry.value(QStringLiteral("trayWindowId")).toUInt();
    static const QString xprop = QStandardPaths::findExecutable(QStringLiteral("xprop"));
    if (!windowId || !entry.value(QStringLiteral("notifierDesktopEntry")).toString().isEmpty()
            || xprop.isEmpty()) {
        m_scannedEntries.append(entry);
        if (--m_pendingItemReads == 0) finishRefresh();
        return;
    }
    auto *process = new QProcess(this);
    // Exactly one of finished or FailedToStart completes this pending read.
    const auto completed = std::make_shared<bool>(false);
    auto finish = [this, process, completed, entry, epoch](QByteArray output) mutable {
        if (*completed) return;
        *completed = true;
        if (!m_diagnosticObservationEnabled || epoch != m_observationEpoch) {
            process->deleteLater();
            return;
        }
        const QString props = QString::fromLocal8Bit(output);
        static const QRegularExpression klass(
            QStringLiteral("WM_CLASS[^\n]*=\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\""));
        static const QRegularExpression pid(
            QStringLiteral("_NET_WM_PID[^\n]*=\\s*(\\d+)"));
        const auto classMatch = klass.match(props);
        if (classMatch.hasMatch()) {
            entry.insert(QStringLiteral("trayWindowInstance"), classMatch.captured(1));
            entry.insert(QStringLiteral("trayWindowClass"), classMatch.captured(2));
        }
        const auto pidMatch = pid.match(props);
        if (pidMatch.hasMatch()) {
            bool ok = false;
            const quint32 owner = pidMatch.captured(1).toUInt(&ok);
            if (ok && owner > 1) entry.insert(QStringLiteral("trayWindowPid"), owner);
        }
        process->deleteLater();
        m_scannedEntries.append(entry);
        if (--m_pendingItemReads == 0) finishRefresh();
    };
    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, [process, finish](int, QProcess::ExitStatus) mutable {
        finish(process->readAllStandardOutput());
    });
    connect(process, &QProcess::errorOccurred, this,
            [finish](QProcess::ProcessError error) mutable {
        if (error == QProcess::FailedToStart) finish({});
    });
    QTimer::singleShot(1200, process, [process]() {
        if (process->state() != QProcess::NotRunning) process->kill();
    });
    process->start(xprop, {QStringLiteral("-id"), QString::number(windowId),
        QStringLiteral("WM_CLASS"), QStringLiteral("_NET_WM_PID")});
}

void TrayWindowBridge::finishRefresh() {
    if (!m_diagnosticObservationEnabled) return;
    // Async responses arriving mid-reveal are kept in m_scannedEntries and
    // published after the animation; the SNI is not discarded or unregistered.
    if (m_fanRevealActive) { m_fanPublicationDeferred = true; return; }
    QElapsedTimer work; work.start();
    // Asynchronous replies may arrive in arbitrary order. Keep the published
    // model stable to avoid recreating delegates and resetting animations.
    std::sort(m_scannedEntries.begin(), m_scannedEntries.end(),
              [](const QVariant &left, const QVariant &right) {
        const QVariantMap a = left.toMap();
        const QVariantMap b = right.toMap();
        const QString aKey = a.value(QStringLiteral("service")).toString()
            + a.value(QStringLiteral("path")).toString();
        const QString bKey = b.value(QStringLiteral("service")).toString()
            + b.value(QStringLiteral("path")).toString();
        return aKey < bKey;
    });
    m_refreshInFlight = false;
    if (m_allEntries != m_scannedEntries) {
        const QVariantList oldRegistered = registeredEntries();
        const QStringList oldRegisteredDesktopIds = registeredDesktopIds();
        const QVariantList oldObserved = m_cachedObservedValid
            ? m_cachedObservedEntries : observedEntries();
        const QVariantList oldDynamic = m_cachedDynamicValid
            ? m_cachedDynamicEntries : entries();
        m_allEntries = m_scannedEntries;
        publishEffectiveModelChanges(oldObserved, oldDynamic, "finishRefresh");
        // An SNI menu path update must not force all pinned indicators to
        // perform desktop-file matching again.
        if (oldRegisteredDesktopIds != registeredDesktopIds())
            Q_EMIT registeredDesktopIdsChanged();
        // The complete native registry is used for pinned menus, but changes
        // here must NOT invalidate the dynamic tray list when it is identical.
        if (oldRegistered != registeredEntries()) {
            const qint64 beforeRegisteredSignal = work.elapsed();
            Q_EMIT registeredEntriesChanged();
            if (work.elapsed() - beforeRegisteredSignal > 20)
                qInfo() << "Punchi tray R38 qml-notify registered-ms"
                        << work.elapsed() - beforeRegisteredSignal;
        }
    }
    if (m_refreshAgain) {
        m_refreshAgain = false;
        QTimer::singleShot(0, this, &TrayWindowBridge::refresh);
    } else if (!m_pendingNotifierChanges.isEmpty() && !m_fanRevealActive) {
        QTimer::singleShot(0, this, &TrayWindowBridge::applyQueuedNotifierChanges);
    }
    if (work.elapsed() > 20)
        qInfo() << "Punchi tray R36 ui-work finishRefresh-total-ms" << work.elapsed();
}

bool TrayWindowBridge::containsDesktopEntry(const QString &desktopId) const {
    const QString wanted = normalized(desktopId);
    if (wanted.isEmpty()) return false;
    // A pinned delegate may request the same match many times while focus or
    // a popup changes. KDE service matching is only needed on cache misses.
    const auto cached = m_cachedNotifierPresence.constFind(wanted);
    if (cached != m_cachedNotifierPresence.cend()) return cached.value();
    QElapsedTimer work;
    work.start();
    bool present = false;
    for (const auto &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        // Preserve native menus for a real SNI even with an open window.
        if (matchesDesktopId(item, wanted)) { present = true; break; }
    }
    m_cachedNotifierPresence.insert(wanted, present);
    if (work.elapsed() > 15)
        qInfo() << "Punchi tray R38 presence-cache-miss-ms" << work.elapsed();
    return present;
}

QVariantList TrayWindowBridge::notifierDiagnostics() const {
    QVariantList diagnostics;
    for (const auto &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        QVariantMap details;
        for (const QString &field : {QStringLiteral("notifierDesktopEntry"),
                QStringLiteral("notifierId"), QStringLiteral("desktopId"),
                QStringLiteral("menuPath"), QStringLiteral("notifierInterface"),
                QStringLiteral("appPid"), QStringLiteral("trayWindowId"),
                QStringLiteral("trayWindowClass"), QStringLiteral("trayWindowInstance"),
                QStringLiteral("trayWindowPid")})
            details.insert(field, item.value(field));
        diagnostics.push_back(details);
    }
    return diagnostics;
}

bool TrayWindowBridge::activateDesktopEntry(const QString &desktopId, int globalX, int globalY) {
    const QString wanted = normalized(desktopId);
    for (const auto &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        // A pinned application may have started before our window baseline.
        // Activation is explicitly requested by the user, unlike discovery.
        if (!matchesDesktopId(item, wanted)) continue;
        auto message = QDBusMessage::createMethodCall(
            item.value(QStringLiteral("service")).toString(),
            item.value(QStringLiteral("path")).toString(),
            item.value(QStringLiteral("notifierInterface"), notifierInterface).toString(),
            QStringLiteral("Activate"));
        const int safeX = globalX >= 0 ? globalX : 0;
        const int safeY = globalY >= 0 ? globalY : 0;
        message.setArguments({safeX, safeY});
        QDBusConnection::sessionBus().asyncCall(message, 1500);
        return true;
    }
    return false;
}

// SNI provides an application-owned context menu command; opening it is
// preferable to forcing termination of an unidentified background process.
// Like KDE's own StatusNotifierItemHost, never block the GUI on D-Bus.
bool TrayWindowBridge::openNotifierMenu(const QString &desktopId, int globalX, int globalY) {
    const QString wanted = normalized(desktopId);
    for (const auto &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        if (!matchesDesktopId(item, wanted)) continue;
        auto message = QDBusMessage::createMethodCall(
            item.value(QStringLiteral("service")).toString(),
            item.value(QStringLiteral("path")).toString(),
            item.value(QStringLiteral("notifierInterface"), notifierInterface).toString(),
            QStringLiteral("ContextMenu"));
        message.setArguments({globalX, globalY});
        QDBusConnection::sessionBus().asyncCall(message, 1500);
        return true;
    }
    return false;
}


bool TrayWindowBridge::requestNotifierActions(const QString &desktopId) {
    const QString wanted = normalized(desktopId);
    for (const auto &candidate : m_allEntries) {
        const QVariantMap item = candidate.toMap();
        if (!matchesDesktopId(item, wanted)) continue;
        const QString service = item.value(QStringLiteral("service")).toString();
        const QString menuPath = item.value(QStringLiteral("menuPath")).toString();
        if (menuPath.isEmpty() || menuPath == QLatin1String("/NO_DBUSMENU")
                || !menuPath.startsWith(QLatin1Char('/'))) {
            qWarning().noquote() << "Punchi tray: no exported DBusMenu for" << wanted
                                 << "interface" << item.value(QStringLiteral("notifierInterface"));
            return false;
        }
        ++m_menuRequestGeneration;
        const quint64 generation = m_menuRequestGeneration;
        m_contextActions.clear();
        m_contextMenuDesktopId = wanted;
        m_contextMenuService = service;
        m_contextMenuPath = menuPath;
        qInfo().noquote() << "Punchi tray: DBusMenu requested for" << wanted
                          << "path" << menuPath;
        Q_EMIT contextActionsChanged();
        // Let the app update any dynamic menu first. Always asynchronous.
        auto request = QDBusMessage::createMethodCall(service, menuPath,
            dbusMenuInterface, QStringLiteral("AboutToShow"));
        request.setArguments({0});
        auto *watcher = new QDBusPendingCallWatcher(
            QDBusConnection::sessionBus().asyncCall(request, 1000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, menuPath, wanted, generation]() {
                const QDBusMessage answer = watcher->reply();
                if (answer.type() == QDBusMessage::ErrorMessage)
                    qWarning().noquote() << "Punchi tray: AboutToShow failed for"
                                         << wanted << answer.errorMessage();
                watcher->deleteLater();
                fetchNotifierActions(service, menuPath, wanted, generation);
            });
        return true;
    }
    qWarning().noquote() << "Punchi tray: no registered SNI for" << wanted;
    return false;
}

void TrayWindowBridge::fetchNotifierActions(const QString &service,
                                             const QString &menuPath,
                                             const QString &desktopId,
                                             quint64 generation) {
    if (generation != m_menuRequestGeneration) return;
    auto request = QDBusMessage::createMethodCall(service, menuPath,
        dbusMenuInterface, QStringLiteral("GetLayout"));
    request.setArguments({0, -1, QStringList{}});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(request, 1800), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [this, watcher, desktopId, generation]() {
            const QDBusMessage reply = watcher->reply();
            watcher->deleteLater();
            if (generation != m_menuRequestGeneration) return;
            if (reply.type() == QDBusMessage::ErrorMessage
                    || reply.arguments().size() < 2) {
                qWarning().noquote() << "Punchi tray: GetLayout failed for"
                                     << desktopId << reply.errorMessage();
                Q_EMIT notifierActionsUnavailable(desktopId);
                return;
            }
            const QVariant layout = reply.arguments().at(1);
            if (layout.metaType() != QMetaType::fromType<QDBusArgument>()) {
                qWarning().noquote() << "Punchi tray: unexpected DBusMenu layout type for"
                                     << desktopId;
                Q_EMIT notifierActionsUnavailable(desktopId);
                return;
            }
            QVariantList actions;
            readMenuLayout(layout.value<QDBusArgument>(), actions);
            if (actions.isEmpty()) {
                qWarning().noquote() << "Punchi tray: exported menu is empty for"
                                     << desktopId;
                Q_EMIT notifierActionsUnavailable(desktopId);
                return;
            }
            // Some exporters omit children-display=submenu. Infer it from
            // the actual tree and never turn a parent into a fake clicked
            // action that could trigger unintended app behavior.
            QSet<int> parents;
            for (const QVariant &candidate : actions) {
                const int parent = candidate.toMap().value(QStringLiteral("parentId")).toInt();
                if (parent > 0) parents.insert(parent);
            }
            for (QVariant &candidate : actions) {
                QVariantMap item = candidate.toMap();
                const int id = item.value(QStringLiteral("id")).toInt();
                if (parents.contains(id)) item.insert(QStringLiteral("hasChildren"), true);
                candidate = item;
            }
            qInfo().noquote() << "Punchi tray: DBusMenu actions ready for"
                              << desktopId << "count" << actions.size();
            m_contextMenuDesktopId = desktopId;
            m_contextActions = actions;
            Q_EMIT contextActionsChanged();
        });
}

bool TrayWindowBridge::triggerNotifierAction(const QString &desktopId, int actionId) {
    if (normalized(desktopId) != m_contextMenuDesktopId || actionId <= 0)
        return false;
    bool allowed = false;
    for (const QVariant &candidate : m_contextActions) {
        const QVariantMap action = candidate.toMap();
        if (action.value(QStringLiteral("id")).toInt() == actionId
                && action.value(QStringLiteral("enabled")).toBool()
                && !action.value(QStringLiteral("separator")).toBool()
                && !action.value(QStringLiteral("hasChildren")).toBool()) {
            allowed = true;
            break;
        }
    }
    if (!allowed || m_contextMenuService.isEmpty() || m_contextMenuPath.isEmpty())
        return false;
    auto message = QDBusMessage::createMethodCall(m_contextMenuService,
        m_contextMenuPath, dbusMenuInterface, QStringLiteral("Event"));
    message.setArguments({actionId, QStringLiteral("clicked"),
                          QVariant::fromValue(QDBusVariant(QVariant(0))),
                          static_cast<uint>(0)});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message, 1500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
        [watcher, desktopId, actionId]() {
            const QDBusMessage response = watcher->reply();
            if (response.type() == QDBusMessage::ErrorMessage)
                qWarning().noquote() << "Punchi tray: action failed for"
                                     << desktopId << "id" << actionId
                                     << response.errorMessage();
            watcher->deleteLater();
        });
    return true;
}
