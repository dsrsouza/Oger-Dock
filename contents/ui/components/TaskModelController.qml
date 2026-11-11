import QtQuick
import org.kde.taskmanager as TaskManager
import "TaskManagerCompatibility.js" as TaskManagerCompatibility
import "../../code/windowScrollNavigation.js" as WindowScrollNavigation

Item {
    id: root

    signal structureChanged()
    // Real TaskManager window/activity changes, not every presentation revision.
    signal windowObservationRequested()
    signal maximizedObservationRequested()

    property var dockItems: []
    // R23: resolve differing task AppId / launcher menu-id aliases to their
    // KDE desktop service identity. Memoize service lookups so repaints do not
    // repeatedly enumerate KService entries (especially command launchers).
    property var serviceIdentityCache: ({})
    property bool showActiveTasks: true
    property bool currentDesktopOnly: true
    property string windowGroupingMode: "application"
    property int maxDynamicGroups: 8
    // Flexible panel mode can derive the direct group limit from its visual
    // capacity without overwriting the user's manual limit for other modes.
    property bool automaticDynamicGroups: false
    // Number of visual slots available for dynamic groups, including the
    // overflow item. A negative value preserves the configured-only limit.
    property int dynamicGroupCapacity: -1
    property var systemDiscovery: null
    property var trayAutostartPolicy: null

    // R63.3: temporary visibility is SESSION-ONLY. Never write it into the
    // user's pinned-items JSON and never promote an SNI just for registering.
    property var temporarilyPromotedTrayIds: ({})
    property bool trayPromotionArmed: false
    property string lastTrayFocusId: ""
    // A scroll activation is navigation, not a click on the native tray.
    // Hold these identities for the gesture and while they remain active, so
    // delayed KDE IsActive updates cannot promote them accidentally.
    property var wheelSuppressedTrayPromotions: ({})
    function suppressTrayPromotionForWheel(desktopId) {
        const id = root.canonicalServiceId(desktopId)
        if (!id) return
        const updated = Object.assign({}, root.wheelSuppressedTrayPromotions)
        if (updated[id]) return
        updated[id] = true
        root.wheelSuppressedTrayPromotions = updated
    }
    function pruneWheelSuppressionWhenIdle() {
        if (wheelCycleTimer.running) return
        const current = root.currentActiveTrayIdentity()
        const updated = Object.assign({}, root.wheelSuppressedTrayPromotions)
        let changed = false
        for (const id of Object.keys(updated)) {
            if (id !== current) {
                delete updated[id]
                changed = true
            }
        }
        if (changed) root.wheelSuppressedTrayPromotions = updated
    }

    // Only verified user XDG autostart + a live matching StatusNotifierItem.
    // System/global autostart items keep their original behavior.
    function trayOnlyIdentityForRow(row) {
        if (!root.trayAutostartPolicy || !root.trayIdentityBridge
                || typeof root.trayAutostartPolicy.userAutostartTrayOnly !== "function")
            return ""
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid
                || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow))
            return ""
        const serviceId = root.resolvedTaskServiceIdForRow(row)
        const appId = root.taskAppIdForRow(row)
        for (const candidate of [serviceId, appId]) {
            if (candidate && root.trayAutostartPolicy.userAutostartTrayOnly(candidate)
                    && root.trayIdentityBridge.containsDesktopEntry(candidate))
                return root.canonicalServiceId(candidate)
        }
        return ""
    }
    function isAutostartTrayOnlyRow(row) {
        return root.trayOnlyIdentityForRow(row).length > 0
    }
    function isTrayTemporarilyPromoted(desktopId) {
        const id = root.canonicalServiceId(desktopId)
        return !!id && root.temporarilyPromotedTrayIds[id] === true
    }
    function currentActiveTrayIdentity() {
        for (let row = 0; row < tasksModel.count; ++row) {
            const idx = tasksModel.index(row, 0)
            if (!idx.valid
                    || !tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                    || !tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive))
                continue
            // Pinned launchers remain pinned; never offer return-to-tray there.
            if (root.dockItems.some(function(item) {
                return item && item.type === "app"
                    && root.dockItemMatchesTaskRow(item, row)
            })) return ""
            return root.trayOnlyIdentityForRow(row)
        }
        return ""
    }
    function observeTrayFocusChange() {
        if (!root.trayPromotionArmed) return
        const current = root.currentActiveTrayIdentity()
        if (current && root.wheelSuppressedTrayPromotions[current]) {
            // The app may stay active after the wheel gesture; a redundant
            // model repaint must not promote it either.
            root.lastTrayFocusId = current
            return
        }
        root.pruneWheelSuppressionWhenIdle()
        // Comparing transitions avoids promoting on idle model repaints.
        if (current && current !== root.lastTrayFocusId
                && !root.isTrayTemporarilyPromoted(current)) {
            const updated = Object.assign({}, root.temporarilyPromotedTrayIds)
            updated[current] = true
            root.temporarilyPromotedTrayIds = updated
            console.info("OgerDock Tray R63.3: promoted", current)
            root.scheduleRefresh(true)
        }
        root.lastTrayFocusId = current
    }
    function pruneTrayPromotions() {
        const updated = Object.assign({}, root.temporarilyPromotedTrayIds)
        let changed = false
        for (const id of Object.keys(updated)) {
            if (!root.trayIdentityBridge
                    || !root.trayIdentityBridge.containsDesktopEntry(id)) {
                delete updated[id]
                changed = true
            }
        }
        if (changed) root.temporarilyPromotedTrayIds = updated
        return changed
    }
    function returnTemporaryTrayAppToTray(desktopId) {
        const id = root.canonicalServiceId(desktopId)
        if (!root.isTrayTemporarilyPromoted(id)) return false
        const updated = Object.assign({}, root.temporarilyPromotedTrayIds)
        delete updated[id]
        root.temporarilyPromotedTrayIds = updated
        console.info("OgerDock Tray R63.3: returned to tray", id)
        // Do not close/kill the application. Minimize only its existing
        // minimizable, non-minimized windows. Some popups are not minimizable;
        // in that case only the temporary dock entry is removed.
        for (let row = 0; row < tasksModel.count; ++row) {
            if (root.trayOnlyIdentityForRow(row) !== id) continue
            const idx = tasksModel.index(row, 0)
            if (idx.valid && tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimizable)
                    && !tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized))
                tasksModel.requestToggleMinimized(idx)
        }
        root.scheduleRefresh(true)
        return true
    }
    Timer {
        id: trayPromotionStartupGuard
        interval: 1200
        repeat: false
        onTriggered: {
            // The already-active window is a baseline, not a tray click.
            root.lastTrayFocusId = root.currentActiveTrayIdentity()
            root.trayPromotionArmed = true
        }
    }

    Connections {
        target: root.trayAutostartPolicy
        ignoreUnknownSignals: true
        function onAutostartRuleRevisionChanged() { root.scheduleRefresh(true) }
    }

    // Re-evaluate the exclusion when the actual SNI appears/disappears,
    // rather than leaving a stale hidden/visible task after D-Bus updates.
    Connections {
        target: root.trayIdentityBridge
        ignoreUnknownSignals: true
        function onRegisteredDesktopIdsChanged() {
            root.pruneTrayPromotions()
            root.scheduleRefresh(true)
        }
    }

    property var visibleTaskRows: []
    property var overflowTaskRows: []
    property int totalDynamicGroups: 0
    property int visualRevision: 0
    property int structureRevision: 0
    // R43 diagnostic only: suspend automatic TasksModel -> Punchi QML
    // visual publication. Never change KDE TasksModel or its global state.
    property bool diagnosticTaskObservationEnabled: true
    // R44: keep the actual KDE TasksModel live, but do not publish broad
    // presentation changes on the GUI thread during the critical fan reveal.
    // Unlike the R43 A/B test, this is automatic, short-lived and reversible.
    property bool fanRevealActive: false
    // R45: disconnect only Punchi's presentation callbacks BEFORE creating
    // a fan popup. R43 B proved this is substantially cheaper than listening
    // continuously. KDE TasksModel, SNI, processes and native menus stay live.
    property bool fanPresentationHold: false
    property bool fanRevealSeenDuringHold: false
    property int fanPresentationHoldCount: 0
    property int fanPresentationReleaseCount: 0
    property double fanPresentationHoldStartedAt: 0
    property bool fanUpdatesDeferred: false
    property bool pendingVisualRefresh: false
    property bool pendingWheelReconcile: false
    property int fanDeferredEventCount: 0
    property int fanReconciliations: 0
    property bool pendingStructureRefresh: false
    property bool pendingWindowObservation: false
    property bool pendingMaximizedObservation: false
    property bool useLegacyCurrentDesktopFilter: false
    property string pendingMinimizeApplicationId: ""
    property string pendingMinimizeStorageId: ""

    // Alt-Tab-style wheel navigation. Capture a stable order for the duration
    // of a scroll gesture; otherwise asynchronous activeTaskChanged signals
    // would reorder the list after every step and bounce between two windows.
    property bool wheelMaximizeActivated: false
    property var wheelRecentWindows: []
    property var wheelCycleKeys: []
    property string wheelCurrentKey: ""
    // Live SNI list, including pinned applications that have no taskbar window.
    // A tray entry is an existing process, never a launcher to start again.
    // R41 uses a native QAbstractListModel; a legacy list remains supported
    // for compatibility with development and testing harnesses.
    property var trayEntries: null
    property var trayIdentityBridge: null
    function trayIdentityKeys() {
        if (root.trayEntries && typeof root.trayEntries.desktopIds === "function")
            return root.trayEntries.desktopIds()
        if (root.trayIdentityBridge
                && typeof root.trayIdentityBridge.observedIdentityKeys === "function")
            return root.trayIdentityBridge.observedIdentityKeys()
        if (root.trayEntries instanceof Array)
            return root.trayEntries.map(function(item) {
                return String(item && item.desktopId || "")
            })
        return []
    }
    property var trayActivator: null

    Timer {
        id: wheelCycleTimer
        interval: 1400
        repeat: false
        // A short gesture timeout must NOT discard the selected position.
        // It caused an edge reversal to jump to the opposite side when the
        // active window changed asynchronously during minimize/restore.
        onTriggered: {
            // The non-repeating Timer has finished by the next Qt turn;
            // keep the selected tray identity suppressed if still in focus.
            Qt.callLater(root.pruneWheelSuppressionWhenIdle)
            if (root.fanRevealActive || root.fanPresentationHold) {
                root.pendingWheelReconcile = true
                root.fanUpdatesDeferred = true
                return
            }
            root.observeActiveWheelWindow()
            root.syncWheelCursorFromActive()
        }
    }

    // Consolidate all task notifications received during a folder reveal.
    // QtQuick animation retains the GUI frame budget while the KDE model,
    // windows and native SNI menus continue functioning as normal.
    Timer {
        id: fanDeferredReleaseTimer
        interval: 90
        repeat: false
        onTriggered: root.releaseFanDeferredWork()
    }

    // A missing/unmapped dialog or a no-animation mode must never leave the
    // dock disconnected. The timer protects only the QML callbacks, never KDE.
    Timer {
        id: fanPresentationFailSafe
        interval: 2200
        repeat: false
        onTriggered: root.endFanPresentationHold("failsafe")
    }

    function beginFanPresentationHold() {
        if (!root.diagnosticTaskObservationEnabled) return
        if (root.fanPresentationHold) {
            fanPresentationFailSafe.restart()
            return
        }
        root.fanPresentationHold = true
        root.fanRevealSeenDuringHold = false
        root.fanPresentationHoldCount += 1
        root.fanPresentationHoldStartedAt = Date.now()
        // Disconnect Connections before popup geometry/visibility changes.
        // Events can be missed deliberately, so one authoritative resync
        // follows on release even when no dataChanged signal is received.
        root.fanUpdatesDeferred = true
        root.pendingVisualRefresh = true
        root.pendingStructureRefresh = true
        root.pendingWindowObservation = true
        root.pendingMaximizedObservation = true
        root.pendingWheelReconcile = true
        refreshTimer.stop()
        fanDeferredReleaseTimer.stop()
        fanPresentationFailSafe.restart()
    }

    function endFanPresentationHold(reason) {
        if (!root.fanPresentationHold) return
        root.fanPresentationHold = false
        root.fanRevealSeenDuringHold = false
        fanPresentationFailSafe.stop()
        root.fanPresentationReleaseCount += 1
        console.info("Punchi task R45 presentation-hold end",
            "reason", String(reason || "finished"),
            "elapsed-ms", Date.now() - root.fanPresentationHoldStartedAt,
            "session", root.fanPresentationHoldCount)
        if (root.diagnosticTaskObservationEnabled) {
            // If a new reveal has already begun, wait for its end.
            if (!root.fanRevealActive) fanDeferredReleaseTimer.restart()
        }
    }

    function deferTaskEventDuringFan(structure, windows, maximized, wheel) {
        if ((!root.fanRevealActive && !root.fanPresentationHold)
                || !root.diagnosticTaskObservationEnabled)
            return false
        root.fanUpdatesDeferred = true
        root.fanDeferredEventCount += 1
        root.pendingVisualRefresh = true
        root.pendingStructureRefresh = root.pendingStructureRefresh || !!structure
        root.pendingWindowObservation = root.pendingWindowObservation || !!windows
        root.pendingMaximizedObservation = root.pendingMaximizedObservation || !!maximized
        root.pendingWheelReconcile = root.pendingWheelReconcile || !!wheel
        return true
    }

    function releaseFanDeferredWork() {
        if (root.fanRevealActive || root.fanPresentationHold
                || !root.diagnosticTaskObservationEnabled) return
        if (!root.fanUpdatesDeferred) return
        root.fanUpdatesDeferred = false
        // A single delayed flush replaces the entire stream accumulated
        // during the fan animation. Preserve all structural/identity changes.
        root.fanReconciliations += 1
        console.info("Punchi task R44 batch-release", "batches", root.fanReconciliations,
            "total-deferred-events", root.fanDeferredEventCount,
            "structure", root.pendingStructureRefresh,
            "windows", root.pendingWindowObservation,
            "maximized", root.pendingMaximizedObservation)
        if (root.pendingVisualRefresh || root.pendingStructureRefresh
                || root.pendingWindowObservation || root.pendingMaximizedObservation)
            refreshTimer.restart()
        if (root.pendingWheelReconcile) {
            root.pendingWheelReconcile = false
            Qt.callLater(function() {
                if (root.fanRevealActive || root.fanPresentationHold
                        || !root.diagnosticTaskObservationEnabled) {
                    root.pendingWheelReconcile = true
                    root.fanUpdatesDeferred = true
                    return
                }
                if (typeof root.observeTrayFocusChange === "function")
                    root.observeTrayFocusChange()
                root.observeActiveWheelWindow()
                root.syncWheelCursorFromActive()
            })
        }
        if (root.pendingMinimizeApplicationId.length > 0
                || root.pendingMinimizeStorageId.length > 0)
            Qt.callLater(root.tryPendingMediaWindowMinimize)
    }

    onFanRevealActiveChanged: {
        if (fanRevealActive) {
            if (fanPresentationHold) fanRevealSeenDuringHold = true
            // A pending timer may have been scheduled before opening began.
            // Keep its flags; finish() will publish them once, after the arc.
            if (refreshTimer.running) {
                refreshTimer.stop()
                fanUpdatesDeferred = true
            }
            fanDeferredReleaseTimer.stop()
        } else {
            if (fanPresentationHold && fanRevealSeenDuringHold)
                endFanPresentationHold("reveal-finished")
            else if (fanUpdatesDeferred && diagnosticTaskObservationEnabled
                    && !fanPresentationHold)
                fanDeferredReleaseTimer.restart()
        }
    }

    function syncWheelCursorFromActive() {
        if (wheelCycleTimer.running) return
        const candidates = wheelCandidates()
        // Keep the last explicitly selected key. On Wayland the IsActive role
        // may arrive after a scroll timer, so snapping to it is not reliable.
        if (candidates.some(function(item) { return item.key === wheelCurrentKey }))
            return
        const active = candidates.find(function(item) { return item.active })
        wheelCurrentKey = active ? active.key
            : (candidates.length ? candidates[0].key : "")
    }

    // Keep history in sync even when the user switches windows with Alt+Tab,
    // a taskbar click or other applications instead of scrolling the dock.
    // All taskbar windows, including those belonging to pinned applications.
    // The tray bridge uses this snapshot to distinguish an app the user opened
    // from notifier icons that started with the desktop session.
    function allWindowApplicationIds() {
        const identities = []
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(index, TaskManager.AbstractTasksModel.SkipTaskbar))
                continue
            const id = String(taskAppIdForRow(row) || "").trim()
            if (id.length > 0 && identities.indexOf(id) < 0) identities.push(id)
        }
        return identities
    }

    // R41: one KDE TasksModel traversal per observation, instead of three
    // scans with redundant AppId/desktop service lookups on the QML thread.
    // There is no SNI/DBus work here: window identity is native TaskManager.
    function allWindowObservationSnapshot() {
        const applications = []
        const windows = []
        const maximized = []
        let maximizedCount = 0
        let activeMaximizedCount = 0
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow))
                continue
            const appId = String(taskAppIdForRow(row) || "").trim()
            const active = !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive)
            const isMaximized = !!tasksModel.data(index,
                TaskManager.AbstractTasksModel.IsMaximized)
            if (isMaximized) {
                ++maximizedCount
                if (active) ++activeMaximizedCount
                if (active && appId && maximized.indexOf(appId) < 0)
                    maximized.push(appId)
            }
            if (tasksModel.data(index, TaskManager.AbstractTasksModel.SkipTaskbar))
                continue
            if (appId && applications.indexOf(appId) < 0)
                applications.push(appId)
            windows.push({
                desktopId: appId,
                launcherId: String(taskLauncherUrlForRow(row) || ""),
                resolvedId: String(resolvedTaskServiceIdForRow(row) || ""),
                appName: String(tasksModel.data(index,
                    TaskManager.AbstractTasksModel.AppName) || ""),
                isActive: active,
                pid: Number(tasksModel.data(index,
                    TaskManager.AbstractTasksModel.AppPid) || 0)
            })
        }
        return { applications: applications, windows: windows, maximized: maximized,
            maximizedCount: maximizedCount,
            activeMaximizedCount: activeMaximizedCount }
    }

    // Only maximization changed: this lightweight pass does not resolve
    // KService, process identities, SNI exporters or window wheel state.
    function maximizedWindowSnapshot() {
        const ids = []
        let total = 0
        let activeCount = 0
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow)
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsMaximized))
                continue
            ++total
            if (!tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive))
                continue
            ++activeCount
            const id = String(taskAppIdForRow(row) || "")
            if (id && ids.indexOf(id) < 0) ids.push(id)
        }
        return {ids: ids, total: total, active: activeCount}
    }

    // R30: each real TaskManager window contributes its appId, launcher,
    // resolved KService identity and best-effort PID.  This captures app
    // aliases without relying on private/window titles or hardcoded names.
    function allWindowTaskSnapshots() {
        const windows = []
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(index, TaskManager.AbstractTasksModel.SkipTaskbar))
                continue
            windows.push({
                desktopId: String(taskAppIdForRow(row) || ""),
                launcherId: String(taskLauncherUrlForRow(row) || ""),
                resolvedId: String(resolvedTaskServiceIdForRow(row) || ""),
                // Stable KDE application name, never the window title.
                appName: String(tasksModel.data(index,
                    TaskManager.AbstractTasksModel.AppName) || ""),
                isActive: !!tasksModel.data(index,
                    TaskManager.AbstractTasksModel.IsActive),
                pid: Number(tasksModel.data(index,
                    TaskManager.AbstractTasksModel.AppPid) || 0)
            })
        }
        return windows
    }

    // R21: active/maximized is observed via the same Wayland-aware KDE
    // TasksModel used for dock indicators; no X11-only window queries.
    function activeMaximizedApplicationIds() {
        const ids = []
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow)
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive)
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsMaximized))
                continue
            const id = String(taskAppIdForRow(row) || "")
            if (id && ids.indexOf(id) < 0) ids.push(id)
        }
        return ids
    }

    // R63.7: the scroll navigates the dock, not every SNI registered in
    // Plasma. A verified user-autostart app with a live notifier stays out
    // until explicitly promoted (or pinned). Check window rows AND SNI-only
    // candidates; suppressing promotion after activation is too late because
    // SNI Activate has already opened the application's popup.
    function excludeTrayOnlyFromWheel(desktopId, taskRow, pinned) {
        if (pinned) return false
        let trayOnlyId = ""
        if (taskRow >= 0) {
            trayOnlyId = root.trayOnlyIdentityForRow(taskRow)
        } else if (root.trayAutostartPolicy
                && typeof root.trayAutostartPolicy.userAutostartTrayOnly === "function") {
            // This path is reached only for IDs enumerated by a live SNI.
            // KDE sometimes exposes different SNI and KService aliases.
            const serviceId = root.resolvedNotifierServiceId(desktopId)
            for (const candidate of [desktopId, serviceId]) {
                if (candidate && root.trayAutostartPolicy.userAutostartTrayOnly(candidate)) {
                    trayOnlyId = root.canonicalServiceId(candidate)
                    break
                }
            }
        }
        if (!trayOnlyId) return false
        // A previously promoted window may have a different SNI desktop ID.
        const resolved = root.resolvedNotifierServiceId(desktopId)
        return !root.isTrayTemporarilyPromoted(trayOnlyId)
            && !root.isTrayTemporarilyPromoted(desktopId)
            && !root.isTrayTemporarilyPromoted(resolved)
    }

    function wheelCandidates() {
        const candidates = []
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            if (!index.valid
                    || !tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(index, TaskManager.AbstractTasksModel.SkipTaskbar)) {
                continue
            }
            // Do not activate third-party user-autostart tray windows unless
            // they are pinned or explicitly promoted into the dock.
            const pinned = (root.dockItems || []).some(function(item) {
                return item && item.type === "app"
                    && root.dockItemMatchesTaskRow(item, row)
            })
            if (root.excludeTrayOnlyFromWheel(root.taskAppIdForRow(row), row, pinned))
                continue
            const uuid = taskWindowUuidForRow(row)
            // On some backends a window ID can be absent; the row fallback
            // stays valid for the lifetime of this TasksModel model layout.
            const key = uuid.length > 0 ? ("window:" + uuid) : ("row:" + row)
            candidates.push({ "row": row, "key": key,
                "active": !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive),
                "minimized": !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsMinimized),
                "minimizable": !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsMinimizable),
                "maximized": !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsMaximized),
                "maximizable": !!tasksModel.data(index, TaskManager.AbstractTasksModel.IsMaximizable) })
        }
        // Map one-window tray applications to the SAME stable app key before
        // and after restoring their windows. This prevents the tray item
        // disappearing from the wheel sequence during SNI activation.
        function canonical(value) {
            return String(value || "").toLowerCase().replace(/\.desktop$/, "")
                .split("/").pop()
        }
        const trayById = ({})
        for (const key of root.trayIdentityKeys()) {
            const id = canonical(key)
            if (id && !trayById[id]) trayById[id] = true
        }
        const windowIdCounts = ({})
        for (const candidate of candidates) {
            candidate.desktopId = canonical(root.taskAppIdForRow(candidate.row))
            if (candidate.desktopId)
                windowIdCounts[candidate.desktopId] = (windowIdCounts[candidate.desktopId] || 0) + 1
        }
        for (const candidate of candidates) {
            if (trayById[candidate.desktopId] && windowIdCounts[candidate.desktopId] === 1)
                candidate.key = "tray:" + candidate.desktopId
        }
        // Match the dock's visible left-to-right order. TaskManager's raw
        // row order is not a visual-order contract and can change after
        // minimize/activation, which made scroll direction feel random.
        const items = root.dockItems || []
        let dynamicIndex = items.length
        for (let i = 0; i < items.length; ++i) {
            if (items[i] && items[i].type === "dynamic-applications") {
                dynamicIndex = i
                break
            }
        }
        const dynamicRows = []
        const dynamicGroups = (root.visibleTaskRows || []).concat(
            root.overflowTaskRows || [])
        for (const group of dynamicGroups) {
            for (const row of group.rows || []) {
                if (dynamicRows.indexOf(row) < 0) dynamicRows.push(row)
            }
        }
        function keyFor(value) {
            return root.normalizeApplicationId(value).toLocaleLowerCase()
        }
        for (const candidate of candidates) {
            let pinnedIndex = -1
            for (let i = 0; i < items.length; ++i) {
                if (items[i] && items[i].type === "app"
                        && root.dockItemMatchesTaskRow(items[i], candidate.row)) {
                    pinnedIndex = i
                    break
                }
            }
            const dynamicRow = dynamicRows.indexOf(candidate.row)
            candidate.visualRank = pinnedIndex >= 0
                ? pinnedIndex * 10000 + candidate.row
                : dynamicIndex * 10000 + 100 + (dynamicRow >= 0
                    ? dynamicRow : candidate.row) * 10
        }
        // Include hidden-to-tray programs which have no TaskManager window.
        // Their rank follows the pinned slot, then dynamic windows, then the
        // visible standalone tray group, precisely as drawn in the dock.
        let extraIndex = 0
        const existingIds = new Set(candidates.map(function(c) { return c.desktopId }))
        for (const key of root.trayIdentityKeys()) {
            const desktopId = canonical(key)
            if (!desktopId || existingIds.has(desktopId)) continue
            existingIds.add(desktopId)
            let pinnedIndex = -1
            for (let i = 0; i < items.length; ++i) {
                if (items[i] && items[i].type === "app"
                        && (canonical(root.dockItemApplicationId(items[i])) === desktopId
                            || root.dockItemMatchesNotifierId(items[i], key))) {
                    pinnedIndex = i
                    break
                }
            }
            if (root.excludeTrayOnlyFromWheel(desktopId, -1, pinnedIndex >= 0))
                continue
            candidates.push({ row: -1, key: "tray:" + desktopId,
                desktopId: desktopId, tray: true, active: false,
                minimized: true, minimizable: false,
                visualRank: pinnedIndex >= 0
                    ? pinnedIndex * 10000 + 500
                    : dynamicIndex * 10000 + 100 + dynamicRows.length * 10
                        + (extraIndex++) * 10 })
        }
        candidates.sort(function(left, right) {
            return left.visualRank - right.visualRank || left.key.localeCompare(right.key)
        })
        return candidates
    }

    function observeActiveWheelWindow() {
        if (wheelCycleTimer.running) return
        const candidates = wheelCandidates()
        let activeKey = ""
        const available = []
        for (let i = 0; i < candidates.length; ++i) {
            available.push(candidates[i].key)
            if (candidates[i].active) activeKey = candidates[i].key
        }
        wheelRecentWindows = WindowScrollNavigation.recordActive(
            wheelRecentWindows, activeKey, available)
    }

    // Allow restoring the only minimized window, without hiding the only
    // visible window when the user scrolls on an otherwise empty desktop.
    function canCycleOpenWindow() {
        const candidates = wheelCandidates()
        return candidates.length > 1
            || (candidates.length === 1 && !candidates[0].active)
    }

    // Scroll selection is transactional at the task-model level: first hide
    // the outgoing window if permitted, then restore/activate the incoming
    // window. Never toggle the incoming window's minimized state (which could
    // accidentally hide it). A maximize request is only sent if supported.
    function applyWheelWindowTransition(candidates, previousKey, nextKey) {
        const action = WindowScrollNavigation.planWindowTransition(
            candidates, previousKey, nextKey, false)
        if (!action) return false

        let incoming = null
        let outgoing = null
        for (let i = 0; i < candidates.length; ++i) {
            if (candidates[i].key === action.targetKey) incoming = candidates[i]
            if (action.previousKey.length > 0
                    && candidates[i].key === action.previousKey) outgoing = candidates[i]
        }
        if (!incoming) return false
        const target = incoming.row >= 0 ? tasksModel.index(incoming.row, 0) : null
        if (incoming.row >= 0 && (!target || !target.valid)) return false

        // If the notifier cannot activate an existing tray process, retain
        // the current foreground window instead of minimizing it to nowhere.
        if (incoming.row < 0) {
            if (!root.trayActivator || !root.trayActivator(incoming.desktopId))
                return false
            // SNI Activate is async: record the target before focus arrives.
            root.suppressTrayPromotionForWheel(incoming.desktopId)
            // Desktop IDs in KDE SNI and TaskManager can be two names for
            // the same KService. Cover the resolved stable identity as well.
            root.suppressTrayPromotionForWheel(
                root.resolvedNotifierServiceId(incoming.desktopId))
        } else {
            // TaskManager activation can emit IsActive synchronously.
            const trayOnlyId = root.trayOnlyIdentityForRow(incoming.row)
            if (trayOnlyId) root.suppressTrayPromotionForWheel(trayOnlyId)
        }
        if (outgoing && outgoing.row >= 0) {
            const previous = tasksModel.index(outgoing.row, 0)
            if (previous.valid
                    && tasksModel.data(previous, TaskManager.AbstractTasksModel.IsWindow)
                    && tasksModel.data(previous, TaskManager.AbstractTasksModel.IsMinimizable)
                    && !tasksModel.data(previous, TaskManager.AbstractTasksModel.IsMinimized)) {
                tasksModel.requestToggleMinimized(previous)
            }
        }
        if (incoming.row >= 0)
            tasksModel.requestActivate(target)
        // Do not alter geometry: the window reopens in its previous state.
        return true
    }

    // direction +1 next, -1 previous. The last selected key, rather than the
    // asynchronous IsActive role, is used during one wheel gesture: rapid
    // scrolling then minimizes the *previous selection*, not some old window.
    function cycleOpenWindow(direction) {
        const candidates = wheelCandidates()
        if (candidates.length === 0) return false
        if (candidates.length === 1) {
            if (candidates[0].active) return false
            return applyWheelWindowTransition(candidates, "", candidates[0].key)
        }

        let activeKey = ""
        for (let i = 0; i < candidates.length; ++i) {
            if (candidates[i].active) {
                activeKey = candidates[i].key
                break
            }
        }
        const known = candidates.map(function(item) { return item.key })
        // Keep a frozen visual order (window IDs, never active/MRU order).
        // Only membership changes may rebuild it. Do not snap to the
        // asynchronous IsActive role after a gesture ends or reaches an edge.
        const membershipChanged = wheelCycleKeys.length !== known.length
            || wheelCycleKeys.some(function(key) { return known.indexOf(key) < 0 })
        if (membershipChanged || wheelCycleKeys.length === 0
                || (!wheelCycleTimer.running
                    && wheelCycleKeys.some(function(key, i) { return key !== known[i] }))) {
            wheelCycleKeys = wheelCycleTimer.running
                ? WindowScrollNavigation.reconcileCycle(wheelCycleKeys, known)
                : known.slice()
            if (wheelCycleKeys.indexOf(wheelCurrentKey) < 0)
                wheelCurrentKey = activeKey || wheelCycleKeys[0]
        }
        const previousKey = wheelCurrentKey
        const nextKey = WindowScrollNavigation.advanceCycle(
            wheelCycleKeys, previousKey, direction)
        // Reaching either edge does not wrap or minimize the current window.
        if (!nextKey || nextKey === previousKey) return false
        if (!applyWheelWindowTransition(candidates, previousKey, nextKey)) return false
        wheelCurrentKey = nextKey
        wheelCycleTimer.restart()
        return true
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByVirtualDesktop: root.useLegacyCurrentDesktopFilter

        Component.onCompleted: root.updateCurrentDesktopFilter()
    }

    Timer {
        id: refreshTimer
        interval: 50
        repeat: false
        onTriggered: root.flushRefresh()
    }

    Timer {
        id: mediaLaunchMinimizeTimer

        interval: 8000
        repeat: false
        onTriggered: root.cancelPendingMediaWindowMinimize()
    }

    Connections {
        target: tasksModel
        enabled: root.diagnosticTaskObservationEnabled && !root.fanPresentationHold

        function onCountChanged() {
            if (root.deferTaskEventDuringFan(true, true, true, true)) return
            root.scheduleWindowObservation()
            root.scheduleRefresh(true)
        }

        function onDataChanged(_topLeft, _bottomRight, roles) {
            const identityChanged = root.dataChangeNeedsWindowObservation(roles)
            const maximizedChanged = root.dataChangeNeedsMaximizedObservation(roles)
            const structureChanged = root.dataChangeNeedsStructureRefresh(roles)
            const visualChanged = root.dataChangeNeedsVisualRefresh(roles)
            const focusChanged = !roles || roles.length === 0
                || roles.indexOf(TaskManager.AbstractTasksModel.IsActive) >= 0
            const mediaMinimizePending = root.pendingMinimizeApplicationId.length > 0
                || root.pendingMinimizeStorageId.length > 0
            if (!identityChanged && !maximizedChanged && !structureChanged
                    && !visualChanged && !focusChanged && !mediaMinimizePending)
                return
            if (root.deferTaskEventDuringFan(structureChanged, identityChanged,
                    maximizedChanged, focusChanged)) return
            if (identityChanged)
                root.scheduleWindowObservation()
            else if (maximizedChanged)
                root.scheduleMaximizedObservation()
            // Pure metadata/geometry notifications must NOT invalidate every
            // dock delegate; this previously ran even for irrelevant roles.
            if (visualChanged) root.scheduleRefresh(structureChanged)
            if (focusChanged) root.observeTrayFocusChange()
            if (focusChanged) root.observeActiveWheelWindow()
            if (root.pendingMinimizeApplicationId.length > 0
                    || root.pendingMinimizeStorageId.length > 0)
                Qt.callLater(root.tryPendingMediaWindowMinimize)
        }

        function onActiveTaskChanged() {
            if (root.deferTaskEventDuringFan(false, true, true, true)) return
            root.observeTrayFocusChange()
            root.scheduleWindowObservation()
            root.scheduleRefresh(false)
            root.observeActiveWheelWindow()
            root.syncWheelCursorFromActive()
        }

        function onRowsInserted() {
            if (root.deferTaskEventDuringFan(true, true, true, true)) return
            root.observeTrayFocusChange()
            root.scheduleWindowObservation()
            root.scheduleRefresh(true)
            Qt.callLater(root.observeActiveWheelWindow)
            if (root.pendingMinimizeApplicationId.length > 0
                    || root.pendingMinimizeStorageId.length > 0)
                Qt.callLater(root.tryPendingMediaWindowMinimize)
        }

        function onRowsRemoved() {
            if (root.deferTaskEventDuringFan(true, true, true, true)) return
            root.lastTrayFocusId = root.currentActiveTrayIdentity()
            root.scheduleWindowObservation()
            root.scheduleRefresh(true)
            Qt.callLater(root.observeActiveWheelWindow)
        }

        function onModelReset() {
            if (root.deferTaskEventDuringFan(true, true, true, true)) return
            root.observeTrayFocusChange()
            root.scheduleWindowObservation()
            root.scheduleRefresh(true)
            Qt.callLater(root.observeActiveWheelWindow)
        }
    }

    onDiagnosticTaskObservationEnabledChanged: {
        if (!diagnosticTaskObservationEnabled) {
            // Ignore callbacks already queued before off and retain the
            // current dock rows/indicators for a controlled A/B comparison.
            refreshTimer.stop()
            fanDeferredReleaseTimer.stop()
            fanPresentationFailSafe.stop()
            fanPresentationHold = false
            fanRevealSeenDuringHold = false
            fanUpdatesDeferred = false
            pendingVisualRefresh = false
            pendingWheelReconcile = false
            pendingStructureRefresh = false
            pendingWindowObservation = false
            pendingMaximizedObservation = false
            wheelCycleTimer.stop()
            console.info("Punchi task R43 QML callbacks frozen")
        } else {
            // Rows may have changed while paused. One fresh reconciliation
            // avoids restoring obsolete row indices or stale app identities.
            Qt.callLater(function() {
                if (!root.diagnosticTaskObservationEnabled) return
                if (root.deferTaskEventDuringFan(true, true, true, true)) return
                root.scheduleWindowObservation()
                root.scheduleRefresh(true)
                root.observeActiveWheelWindow()
                root.syncWheelCursorFromActive()
            })
            console.info("Punchi task R43 QML callbacks resumed")
        }
    }

    onDockItemsChanged: {
        serviceIdentityCache = ({})
        scheduleRefresh(true)
    }
    onShowActiveTasksChanged: {
        updateCurrentDesktopFilter()
        scheduleRefresh(true)
    }
    onCurrentDesktopOnlyChanged: {
        updateCurrentDesktopFilter()
        scheduleRefresh(true)
    }
    onWindowGroupingModeChanged: scheduleRefresh(true)
    onMaxDynamicGroupsChanged: scheduleRefresh(true)
    onAutomaticDynamicGroupsChanged: scheduleRefresh(true)
    onDynamicGroupCapacityChanged: scheduleRefresh(true)

    Component.onCompleted: {
        updateCurrentDesktopFilter()
        trayPromotionStartupGuard.start()
        observeActiveWheelWindow()
        refreshVisibleRows()
        bumpStructureRevision()
        bumpVisualRevision()
    }

    function updateCurrentDesktopFilter() {
        const enabled = root.showActiveTasks && root.currentDesktopOnly
        const nativeFilterApplied = TaskManagerCompatibility.setOptionalProperty(
            tasksModel, "filterByCurrentVirtualDesktop", enabled)
        root.useLegacyCurrentDesktopFilter = enabled && !nativeFilterApplied
    }

    function normalizeApplicationId(value) {
        let text = String(value || "").trim()
        if (text.endsWith(".desktop")) {
            text = text.slice(0, -8)
        }
        return text
    }

    function dockItemApplicationId(item) {
        if (!item || item.type !== "app") {
            return ""
        }

        const storageId = normalizeApplicationId(item.storageId || "")
        if (storageId.length > 0) {
            return storageId
        }

        const appId = normalizeApplicationId(item.appId || "")
        if (appId.length > 0) {
            return appId
        }

        return root.systemDiscovery
            ? normalizeApplicationId(root.systemDiscovery.applicationIdForCommand(item.command || ""))
            : ""
    }

    function normalizeLauncherUrl(value) {
        let text = String(value || "").trim()
        if (text.indexOf("applications:") === 0) {
            text = text.slice("applications:".length)
            if (text.endsWith(".desktop")) {
                text = text.slice(0, -8)
            }
            return text.length > 0 ? ("applications:" + text) : ""
        }
        return text
    }

    function dockItemLauncherUrl(item) {
        if (!item || item.type !== "app") {
            return ""
        }

        const storageId = normalizeApplicationId(item.storageId || "")
        return storageId.length > 0 ? ("applications:" + storageId) : ""
    }

    function taskAppIdForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        return normalizeApplicationId(tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppId))
    }

    function taskLauncherUrlForRow(row) {
        return normalizeLauncherUrl(taskRawLauncherUrlForRow(row))
    }

    function taskRawLauncherUrlForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        return String(tasksModel.data(
            taskIndex, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "").trim()
    }

    function taskMatchesApplicationIdentity(row, applicationId, storageId) {
        const expectedApplicationId = normalizeApplicationId(applicationId).toLowerCase()
        const expectedStorageId = normalizeApplicationId(storageId).toLowerCase()
        const taskApplicationId = taskAppIdForRow(row).toLowerCase()
        const taskLauncherUrl = taskLauncherUrlForRow(row).toLowerCase()

        if ((expectedApplicationId.length > 0 && (taskApplicationId === expectedApplicationId
                    || sameKnownKdeDesktopId(taskApplicationId, expectedApplicationId)))
                || (expectedStorageId.length > 0 && (taskApplicationId === expectedStorageId
                    || sameKnownKdeDesktopId(taskApplicationId, expectedStorageId)))
                || (expectedApplicationId.length > 0
                    && taskLauncherUrl === "applications:" + expectedApplicationId)
                || (expectedStorageId.length > 0
                    && taskLauncherUrl === "applications:" + expectedStorageId)) {
            return true
        }

        if (!root.systemDiscovery) {
            return false
        }
        const resolved = root.systemDiscovery.applicationForLauncher(
            taskAppIdForRow(row), taskRawLauncherUrlForRow(row))
        const resolvedStorageId = normalizeApplicationId(
            resolved && resolved.storageId || "").toLowerCase()
        const resolvedApplicationId = normalizeApplicationId(
            resolved && resolved.appId || "").toLowerCase()
        return (expectedApplicationId.length > 0
                && (resolvedApplicationId === expectedApplicationId
                    || resolvedStorageId === expectedApplicationId))
            || (expectedStorageId.length > 0
                && (resolvedApplicationId === expectedStorageId
                    || resolvedStorageId === expectedStorageId))
    }

    function matchingApplicationWindowExists(applicationId, storageId) {
        for (let row = 0; row < tasksModel.count; row++) {
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid
                    || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar)) {
                continue
            }
            if (taskMatchesApplicationIdentity(row, applicationId, storageId)) {
                return true
            }
        }
        return false
    }

    function cancelPendingMediaWindowMinimize() {
        mediaLaunchMinimizeTimer.stop()
        pendingMinimizeApplicationId = ""
        pendingMinimizeStorageId = ""
    }

    function requestMinimizeNextApplicationWindow(applicationId, storageId) {
        cancelPendingMediaWindowMinimize()
        const expectedApplicationId = normalizeApplicationId(applicationId)
        const expectedStorageId = normalizeApplicationId(storageId)
        if (expectedApplicationId.length === 0 && expectedStorageId.length === 0) {
            return false
        }
        if (matchingApplicationWindowExists(expectedApplicationId, expectedStorageId)) {
            return false
        }

        pendingMinimizeApplicationId = expectedApplicationId
        pendingMinimizeStorageId = expectedStorageId
        mediaLaunchMinimizeTimer.restart()
        return true
    }

    function tryPendingMediaWindowMinimize() {
        if (pendingMinimizeApplicationId.length === 0
                && pendingMinimizeStorageId.length === 0) {
            return false
        }

        for (let row = 0; row < tasksModel.count; row++) {
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid
                    || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar)
                    || !taskMatchesApplicationIdentity(row,
                        pendingMinimizeApplicationId, pendingMinimizeStorageId)) {
                continue
            }
            if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
                cancelPendingMediaWindowMinimize()
                return true
            }
            if (!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimizable)) {
                continue
            }

            tasksModel.requestToggleMinimized(taskIndex)
            cancelPendingMediaWindowMinimize()
            return true
        }
        return false
    }

    function canonicalServiceId(value) {
        let id = String(value || "").trim().toLowerCase()
        if (id.startsWith("applications:")) id = id.slice(13)
        if (id.endsWith(".desktop")) id = id.slice(0, -8)
        return id
    }

    // TaskManager can report KDE windows as org.kde.konsole while an
    // existing pinned launcher uses konsole.desktop. Recognize *only*
    // well-known KDE desktop-file aliases, never fuzzy icon/title matches.
    function sameKnownKdeDesktopId(left, right) {
        const a = canonicalServiceId(left)
        const b = canonicalServiceId(right)
        const aliases = ["konsole", "dolphin", "kcalc", "kate", "kwrite",
            "okular", "gwenview", "konqueror", "ark", "spectacle"]
        for (let i = 0; i < aliases.length; ++i) {
            const shortId = aliases[i]
            if ((a === shortId && b === "org.kde." + shortId)
                    || (b === shortId && a === "org.kde." + shortId))
                return true
        }
        // R28: use the actual installed desktop services to validate more
        // aliases than the fixed KDE list.  No icon/title/substring heuristics:
        // two identifiers are aliases ONLY if KService resolves them to the
        // same .desktop file. This also supports third-party/Flatpak apps.
        if (!a || !b || !root.systemDiscovery) return false
        const cacheKey = "alias|" + [a, b].sort().join("|")
        if (root.serviceIdentityCache[cacheKey] !== undefined)
            return root.serviceIdentityCache[cacheKey]
        const leftService = root.systemDiscovery.resolveApplication(a, "", "")
        const rightService = root.systemDiscovery.resolveApplication(b, "", "")
        const leftId = leftService && leftService.resolved === true
            ? canonicalServiceId(leftService.storageId || leftService.appId) : ""
        const rightId = rightService && rightService.resolved === true
            ? canonicalServiceId(rightService.storageId || rightService.appId) : ""
        const matched = !!leftId && leftId === rightId
        root.serviceIdentityCache[cacheKey] = matched
        return matched
    }

    function resolvedDockServiceId(item) {
        if (!item || String(item.type || "app") !== "app"
                || !root.systemDiscovery) return ""
        const storage = String(item.storageId || item.appId || "")
        const command = String(item.command || "")
        const launcher = String(item.launcherUrl || "")
        const key = "pin|" + storage + "|" + command + "|" + launcher
        if (root.serviceIdentityCache[key] !== undefined)
            return root.serviceIdentityCache[key]
        // A menu ID such as 'konsole' and the TaskManager AppId
        // 'org.kde.konsole' may both refer to one KService desktop file.
        // Never equate apps merely because their icon or display name matches.
        const result = root.systemDiscovery.resolveApplication(storage, command, launcher)
        const identity = result && result.resolved === true
            ? canonicalServiceId(result.storageId || result.appId) : ""
        root.serviceIdentityCache[key] = identity
        return identity
    }

    function resolvedTaskExecutableForRow(row) {
        if (!root.systemDiscovery) return ""
        const appId = taskAppIdForRow(row)
        const launcher = taskRawLauncherUrlForRow(row)
        const key = "task-executable|" + appId + "|" + launcher
        if (root.serviceIdentityCache[key] !== undefined)
            return root.serviceIdentityCache[key]
        // A task launcher can be a KDE KService even when AppId is not the
        // desktop-file ID (Konsole and command-only legacy pins are examples).
        const service = root.systemDiscovery.applicationForLauncher(appId, launcher)
        const executable = String(service && service.executable || "").toLowerCase()
        root.serviceIdentityCache[key] = executable
        return executable
    }

    function commandOnlyDockItemMatchesTaskRow(item, row) {
        if (!item || String(item.type || "") !== "app" || !root.systemDiscovery)
            return false
        // NEVER override an explicit pinned desktop identity on the strength
        // of an executable alone: Kate/KWrite and profiles can share one.
        if (String(item.storageId || item.appId || item.launcherUrl || "").trim())
            return false
        const command = String(item.command || "").trim()
        if (!command) return false
        const executable = String(root.systemDiscovery.executableForCommand(command)
            || "").toLowerCase()
        if (!executable || ["env", "sh", "bash", "python", "python3",
            "xterm", "gio", "xdg-open"].indexOf(executable) >= 0)
            return false
        const taskId = canonicalServiceId(taskAppIdForRow(row))
        const taskServiceId = resolvedTaskServiceIdForRow(row)
        const taskExecutable = resolvedTaskExecutableForRow(row)
        // A launcher such as 'flatpak run org.example.Player' or
        // 'gtk-launch org.example.Player' yields an explicit desktop ID from
        // the command parser. Match the actual KDE task ID, never the generic
        // wrapper binary; require exactly one matching command-only pin.
        const wrapper = /(?:^|\s)(?:flatpak\s+run|gtk-launch)(?:\s|$)/.test(command)
        const directDesktopMatch = wrapper && (taskId === executable
            || taskServiceId === executable
            || sameKnownKdeDesktopId(taskId, executable)
            || sameKnownKdeDesktopId(taskServiceId, executable))
        // Executable equality alone is unsafe: Kate and KWrite, for example,
        // can share a binary while remaining distinct desktop applications.
        // Require the desktop entry identity to agree with the executable,
        // either directly or as the last segment of a reverse-DNS desktop ID.
        const taskIdentityAgrees = (taskId === executable
                || taskId.endsWith("." + executable)
                || taskServiceId === executable
                || taskServiceId.endsWith("." + executable))
        if (!taskIdentityAgrees && !directDesktopMatch) return false
        if (!directDesktopMatch && taskExecutable && taskExecutable !== executable)
            return false
        // Two command-only pins for the same executable are ambiguous. Leave
        // them separate rather than arbitrarily assigning their windows.
        for (const other of root.dockItems || []) {
            if (other === item || !other || String(other.type || "") !== "app"
                    || String(other.storageId || other.appId || other.launcherUrl || "").trim())
                continue
            const otherCommand = String(other.command || "").trim()
            if (otherCommand && String(root.systemDiscovery.executableForCommand(otherCommand)
                    || "").toLowerCase() === executable)
                return false
        }
        return true
    }

    function resolvedTaskServiceIdForRow(row) {
        if (!root.systemDiscovery) return ""
        const appId = taskAppIdForRow(row)
        const launcher = taskRawLauncherUrlForRow(row)
        const key = "task|" + appId + "|" + launcher
        if (root.serviceIdentityCache[key] !== undefined)
            return root.serviceIdentityCache[key]
        const result = root.systemDiscovery.applicationForLauncher(appId, launcher)
        const identity = result && (result.storageId || result.appId)
            ? canonicalServiceId(result.storageId || result.appId) : ""
        root.serviceIdentityCache[key] = identity
        return identity
    }

    function dockItemMatchesTaskRow(item, row) {
        if (!item || String(item.type || "app") !== "app") return false
        const dockAppId = canonicalServiceId(dockItemApplicationId(item))
        const taskAppId = canonicalServiceId(taskAppIdForRow(row))
        if (dockAppId.length > 0 && (dockAppId === taskAppId
                || sameKnownKdeDesktopId(dockAppId, taskAppId))) return true

        const dockLauncherUrl = canonicalServiceId(dockItemLauncherUrl(item))
        const taskLauncherUrl = canonicalServiceId(taskLauncherUrlForRow(row))
        if (dockLauncherUrl.length > 0 && (dockLauncherUrl === taskLauncherUrl
                || sameKnownKdeDesktopId(dockLauncherUrl, taskLauncherUrl)))
            return true

        // Resolve only authentic KDE desktop services on BOTH sides.
        // This excludes generic terminal icons, names, and process guesses
        // which might accidentally merge different applications.
        const pinnedService = resolvedDockServiceId(item)
        const taskService = resolvedTaskServiceIdForRow(row)
        if (pinnedService.length > 0 && (pinnedService === taskService
                || sameKnownKdeDesktopId(pinnedService, taskService)))
            return true
        // R27: legacy pins created with just {command:"konsole"} have no
        // stored desktop identity. Detect these by the verified task executable
        // rather than showing a second dynamic app delegate.
        return commandOnlyDockItemMatchesTaskRow(item, row)
    }

    // A native notifier must share the SAME stable desktop identity with a
    // pinned launcher; otherwise it remains a separate tray-only item.
    // Using this function for both the tray exclusion and pinned SNI lookup
    // prevents the status badge disappearing when a program hides its window.
    function resolvedNotifierServiceId(desktopId) {
        if (!root.systemDiscovery) return ""
        const id = canonicalServiceId(desktopId)
        if (!id) return ""
        const key = "notifier|" + id
        if (root.serviceIdentityCache[key] !== undefined)
            return root.serviceIdentityCache[key]
        // Some Flatpak IDs (e.g. reverse-DNS names ending in `.desktop`)
        // become ambiguous when a filename suffix is stripped. Probe actual
        // KDE storage IDs, never match by displayed name or icon.
        const probes = [id, id + ".desktop", id + ".desktop.desktop"]
        let service = ""
        for (const probe of probes) {
            const result = root.systemDiscovery.resolveApplication(probe, "", "")
            if (result && result.resolved === true) {
                service = canonicalServiceId(result.storageId || result.appId)
                break
            }
        }
        root.serviceIdentityCache[key] = service
        return service
    }

    // Compare a dynamic task group with a real SNI without relying on names
    // or icons. Several window AppIds can belong to the same KDE service.
    function taskEntryMatchesNotifierId(entry, desktopId) {
        if (!entry) return false
        const notifierId = canonicalServiceId(desktopId)
        if (!notifierId) return false
        const notifierService = resolvedNotifierServiceId(notifierId)
        const ids = (entry.appIds instanceof Array ? entry.appIds : [])
            .concat([entry.appId, entry.resolvedApplicationId])
        for (const candidate of ids) {
            const id = canonicalServiceId(candidate)
            if (id && (id === notifierId || sameKnownKdeDesktopId(id, notifierId)))
                return true
            const resolved = resolvedNotifierServiceId(id)
            if (notifierService && resolved && notifierService === resolved)
                return true
        }
        return false
    }

    function dockItemMatchesNotifierId(item, desktopId) {
        if (!item || String(item.type || "app") !== "app") return false
        const notifierId = canonicalServiceId(desktopId)
        if (!notifierId) return false
        const pinnedId = canonicalServiceId(dockItemApplicationId(item))
        if (pinnedId && (pinnedId === notifierId
                || sameKnownKdeDesktopId(pinnedId, notifierId))) return true
        const pinnedService = resolvedDockServiceId(item)
        const notifierService = resolvedNotifierServiceId(notifierId)
        if (pinnedService && notifierService && pinnedService === notifierService)
            return true
        // Legacy command-only pins can own a genuine StatusNotifierItem.
        // Verify a desktop identity, rather than guessing from the icon/title.
        if (String(item.storageId || item.appId || item.launcherUrl || "").trim()
                || !root.systemDiscovery) return false
        const command = String(item.command || "").trim()
        if (!command) return false
        const commandKey = canonicalServiceId(root.systemDiscovery.executableForCommand(command))
        if (!commandKey || ["sh", "bash", "env", "python", "python3", "gio",
                "xdg-open", "xterm"].indexOf(commandKey) >= 0) return false
        if (commandKey !== notifierId && commandKey !== notifierService
                && !sameKnownKdeDesktopId(commandKey, notifierId)) return false
        for (const other of root.dockItems || []) {
            if (!other || other === item || String(other.type || "") !== "app") continue
            if (String(other.storageId || other.appId || other.launcherUrl || "").trim()) continue
            if (canonicalServiceId(root.systemDiscovery.executableForCommand(
                    String(other.command || ""))) === commandKey) return false
        }
        return true
    }

    function taskEntriesMatch(entry, nextEntry) {
        if (!entry || !nextEntry) {
            return false
        }
        if (nextEntry.appId.length > 0 && (entry.appIds.indexOf(nextEntry.appId) >= 0
                || entry.appIds.some(function(id) {
                    return sameKnownKdeDesktopId(id, nextEntry.appId)
                }))) {
            return true
        }
        if (nextEntry.launcherUrl.length > 0
                && entry.launcherUrls.indexOf(nextEntry.launcherUrl) >= 0) return true
        return !!entry.resolvedApplicationId && !!nextEntry.resolvedApplicationId
            && (entry.resolvedApplicationId === nextEntry.resolvedApplicationId
                || sameKnownKdeDesktopId(entry.resolvedApplicationId,
                    nextEntry.resolvedApplicationId))
    }

    function appendEntryIdentity(entry, nextEntry) {
        if (nextEntry.appId.length > 0 && entry.appIds.indexOf(nextEntry.appId) < 0) {
            entry.appIds.push(nextEntry.appId)
        }
        if (nextEntry.launcherUrl.length > 0
                && entry.launcherUrls.indexOf(nextEntry.launcherUrl) < 0) {
            entry.launcherUrls.push(nextEntry.launcherUrl)
        }
        if (!entry.resolvedApplicationId && nextEntry.resolvedApplicationId)
            entry.resolvedApplicationId = nextEntry.resolvedApplicationId
    }

    function groupingEnabled() {
        return root.windowGroupingMode !== "window"
    }

    function dataChangeNeedsWindowObservation(roles) {
        // Empty role lists mean any role may have changed. Ignore changes to
        // icon, progress, tooltips and other presentation-only roles.
        if (!roles || roles.length === 0) return true
        const observedRoles = [
            TaskManager.AbstractTasksModel.AppId,
            TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon,
            TaskManager.AbstractTasksModel.IsWindow,
            TaskManager.AbstractTasksModel.SkipTaskbar,
            TaskManager.AbstractTasksModel.AppName,
            TaskManager.AbstractTasksModel.IsActive,
            TaskManager.AbstractTasksModel.AppPid
        ]
        return observedRoles.some(function(role) { return roles.indexOf(role) >= 0 })
    }

    function scheduleWindowObservation() {
        if (!root.diagnosticTaskObservationEnabled) return
        root.pendingWindowObservation = true
        if (root.fanRevealActive || root.fanPresentationHold) {
            root.fanUpdatesDeferred = true
            return
        }
        if (!refreshTimer.running) refreshTimer.start()
    }

    function scheduleMaximizedObservation() {
        if (!root.diagnosticTaskObservationEnabled) return
        root.pendingMaximizedObservation = true
        if (root.fanRevealActive || root.fanPresentationHold) {
            root.fanUpdatesDeferred = true
            return
        }
        if (!refreshTimer.running) refreshTimer.start()
    }

    function dataChangeNeedsMaximizedObservation(roles) {
        return !roles || roles.length === 0
            || roles.indexOf(TaskManager.AbstractTasksModel.IsMaximized) >= 0
    }

    // Only properties that affect the displayed task indicators, icons,
    // grouping and counts may trigger a visual revision. Empty role lists
    // are conservative because Qt means "unknown roles changed".
    function dataChangeNeedsVisualRefresh(roles) {
        if (!roles || roles.length === 0) return true
        const relevant = [
            TaskManager.AbstractTasksModel.AppId,
            TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon,
            TaskManager.AbstractTasksModel.IsWindow,
            TaskManager.AbstractTasksModel.SkipTaskbar,
            TaskManager.AbstractTasksModel.AppName,
            TaskManager.AbstractTasksModel.IsActive,
            TaskManager.AbstractTasksModel.IsMinimized,
            TaskManager.AbstractTasksModel.IsMaximized,
            TaskManager.AbstractTasksModel.IsDemandingAttention,
            Qt.DisplayRole,
            Qt.DecorationRole
        ]
        return relevant.some(function(role) { return roles.indexOf(role) >= 0 })
    }

    function dataChangeNeedsStructureRefresh(roles) {
        if (!roles || roles.length === 0) {
            return true
        }

        return roles.indexOf(TaskManager.AbstractTasksModel.AppId) >= 0
            || roles.indexOf(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) >= 0
            || roles.indexOf(TaskManager.AbstractTasksModel.IsWindow) >= 0
            || roles.indexOf(TaskManager.AbstractTasksModel.SkipTaskbar) >= 0
    }

    function taskIconSourceForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        const taskAppId = taskAppIdForRow(row)
        let iconName = root.systemDiscovery && taskAppId.length > 0
            ? root.systemDiscovery.iconForApplication(taskAppId)
            : ""
        if (iconName.length > 0) {
            return iconName
        }

        const launcherUrl = taskLauncherUrlForRow(row)
        if (root.systemDiscovery && launcherUrl.indexOf("applications:") === 0) {
            iconName = root.systemDiscovery.iconForApplication(launcherUrl.slice("applications:".length))
            if (iconName.length > 0) {
                return iconName
            }
        }

        const windowIcon = tasksModel.data(taskIndex, Qt.DecorationRole)
        if (windowIcon) {
            return windowIcon
        }

        return "application-x-executable"
    }

    function taskWindowUuidForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid) {
            return ""
        }

        const winIds = tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.WinIdList) || []
        return winIds.length > 0 ? String(winIds[0]) : ""
    }

    function taskWinIdForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid) {
            return 0
        }

        const winIds = tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.WinIdList) || []
        if (winIds.length > 0) {
            const parsed = Number(winIds[0])
            return !isNaN(parsed) && parsed > 0 ? parsed : 0
        }
        return 0
    }

    function taskRowsForEntries(entries) {
        const sourceEntries = entries instanceof Array ? entries : []
        const rows = []
        const seenRows = ({})

        for (let entryIndex = 0; entryIndex < sourceEntries.length; entryIndex++) {
            const entryRows = sourceEntries[entryIndex]
                && sourceEntries[entryIndex].rows instanceof Array
                ? sourceEntries[entryIndex].rows
                : []
            for (let rowIndex = 0; rowIndex < entryRows.length; rowIndex++) {
                const row = Number(entryRows[rowIndex])
                if (isNaN(row) || row < 0) {
                    continue
                }
                const rowKey = String(row)
                if (!seenRows[rowKey]) {
                    seenRows[rowKey] = true
                    rows.push(row)
                }
            }
        }

        return rows
    }

    function publishDelegateGeometry(taskRows, visualDelegate) {
        const sourceRows = taskRows instanceof Array ? taskRows : []
        if (!visualDelegate || !visualDelegate.visible
                || visualDelegate.width <= 0 || visualDelegate.height <= 0) {
            return
        }

        const globalPosition = visualDelegate.mapToGlobal(0, 0)
        const geometry = Qt.rect(
            Math.round(globalPosition.x),
            Math.round(globalPosition.y),
            Math.round(visualDelegate.width),
            Math.round(visualDelegate.height)
        )
        const publishedRows = ({})

        for (let rowIndex = 0; rowIndex < sourceRows.length; rowIndex++) {
            const row = Number(sourceRows[rowIndex])
            if (isNaN(row) || row < 0) {
                continue
            }
            const rowKey = String(row)
            if (publishedRows[rowKey]) {
                continue
            }

            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid
                    || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)) {
                continue
            }

            publishedRows[rowKey] = true
            tasksModel.requestPublishDelegateGeometry(taskIndex, geometry, visualDelegate)
        }
    }

    function isTaskRowActive(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid) {
            return false
        }
        return !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsActive)
    }

    function isTaskRowVisible(row) {
        if (!root.showActiveTasks) {
            return false
        }

        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid
                || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow))
            return false
        for (let index = 0; index < root.dockItems.length; index++) {
            if (dockItemMatchesTaskRow(root.dockItems[index], row)) return false
        }
        const trayId = root.trayOnlyIdentityForRow(row)
        // Even skip-taskbar windows may be shown if *this exact verified*
        // app has been explicitly promoted by a foreground transition.
        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar))
            return !!trayId && root.isTrayTemporarilyPromoted(trayId)
        return !trayId || root.isTrayTemporarilyPromoted(trayId)
    }

    function buildVisibleTaskEntryForRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        const appId = taskAppIdForRow(row)
        const rawLauncherUrl = taskRawLauncherUrlForRow(row)
        const launcherUrl = taskLauncherUrlForRow(row)
        const trayId = root.trayOnlyIdentityForRow(row)
        return {
            "key": appId.length > 0
                ? ("app:" + appId)
                : (launcherUrl.length > 0 ? ("launcher:" + launcherUrl) : ("row:" + row)),
            "appId": appId,
            "appIds": appId.length > 0 ? [appId] : [],
            "resolvedApplicationId": resolvedTaskServiceIdForRow(row),
            "launcherUrl": launcherUrl,
            "rawLauncherUrl": rawLauncherUrl,
            "launcherUrls": launcherUrl.length > 0 ? [launcherUrl] : [],
            "rows": [row],
            "firstRow": row,
            "count": 1,
            "name": String(tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppName)
                || tasksModel.data(taskIndex, Qt.DisplayRole)
                || ""),
            "icon": taskIconSourceForRow(row),
            "active": isTaskRowActive(row),
            "demandsAttention": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsDemandingAttention),
            "windowUuid": taskWindowUuidForRow(row),
            "temporaryTrayId": trayId && root.isTrayTemporarilyPromoted(trayId)
                ? trayId : ""
        }
    }

    function pinDescriptorForEntry(entry) {
        if (!entry || !root.systemDiscovery) {
            return null
        }

        const resolved = root.systemDiscovery.applicationForLauncher(
            String(entry.appId || ""),
            String(entry.rawLauncherUrl || entry.launcherUrl || ""))
        const storageId = String(resolved && resolved.storageId || "").trim()
        if (storageId.length === 0) {
            return null
        }

        const descriptor = {
            "type": "app",
            "name": String(resolved.name || entry.name || ""),
            "icon": String(resolved.icon || "application-x-executable"),
            "storageId": storageId,
            "appId": String(resolved.appId || normalizeApplicationId(storageId))
        }
        const command = String(resolved.command || "").trim()
        if (command.length > 0) {
            descriptor.command = command
        }
        return descriptor
    }

    function dockContainsPinDescriptor(descriptor) {
        if (!descriptor) {
            return false
        }

        const descriptorAppId = normalizeApplicationId(
            descriptor.appId || descriptor.storageId || "")
        const descriptorLauncherUrl = normalizeLauncherUrl(
            descriptor.launcherUrl || (descriptor.storageId
                ? ("applications:" + descriptor.storageId)
                : ""))
        const resolution = root.systemDiscovery
            ? root.systemDiscovery.resolveApplication(
                String(descriptor.storageId || descriptor.appId || ""),
                String(descriptor.command || ""),
                String(descriptor.launcherUrl || "")) : null
        const descriptorService = resolution && resolution.resolved === true
            ? canonicalServiceId(resolution.storageId || resolution.appId) : ""
        for (let index = 0; index < root.dockItems.length; index++) {
            const item = root.dockItems[index]
            if (!item || (item.type || "app") !== "app") {
                continue
            }
            if (descriptorAppId.length > 0
                    && (dockItemApplicationId(item) === descriptorAppId
                        || sameKnownKdeDesktopId(dockItemApplicationId(item), descriptorAppId))) {
                return true
            }
            if (descriptorLauncherUrl.length > 0
                    && dockItemLauncherUrl(item) === descriptorLauncherUrl) {
                return true
            }
            if (descriptorService && descriptorService === resolvedDockServiceId(item))
                return true
            // A 'Pin to Dock' action on a dynamic task must not create a
            // second persistent launcher when the existing pin was a safe,
            // command-only legacy entry (Konsole, Firefox, VLC, etc.).
            if (descriptorService && root.dockItemMatchesNotifierId(item,
                    descriptorService)) return true
        }
        return false
    }

    function refreshVisibleRows() {
        const entries = []
        if (root.showActiveTasks) {
            for (let row = 0; row < tasksModel.count; row++) {
                if (isTaskRowVisible(row)) {
                    const nextEntry = buildVisibleTaskEntryForRow(row)
                    if (groupingEnabled()
                            && (nextEntry.appId.length > 0 || nextEntry.launcherUrl.length > 0)) {
                        let existingIndex = -1
                        for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
                            if (taskEntriesMatch(entries[entryIndex], nextEntry)) {
                                existingIndex = entryIndex
                                break
                            }
                        }
                        if (existingIndex >= 0) {
                            const existingEntry = entries[existingIndex]
                            existingEntry.rows.push(row)
                            existingEntry.count += 1
                            existingEntry.active = existingEntry.active || nextEntry.active
                            existingEntry.demandsAttention = existingEntry.demandsAttention || nextEntry.demandsAttention
                            existingEntry.temporaryTrayId = existingEntry.temporaryTrayId
                                || nextEntry.temporaryTrayId
                            appendEntryIdentity(existingEntry, nextEntry)
                            continue
                        }
                    }
                    entries.push(nextEntry)
                }
            }
        }

        root.totalDynamicGroups = entries.length

        const configuredLimit = root.automaticDynamicGroups
            ? entries.length
            : Math.max(1, Math.min(20, root.maxDynamicGroups))
        if (root.dynamicGroupCapacity < 0) {
            root.visibleTaskRows = entries.slice(0, configuredLimit)
            root.overflowTaskRows = entries.slice(configuredLimit)
            return
        }

        const availableSlots = Math.max(0, Math.floor(root.dynamicGroupCapacity))
        if (entries.length <= Math.min(configuredLimit, availableSlots)) {
            root.visibleTaskRows = entries
            root.overflowTaskRows = []
            return
        }

        // When entries do not fit, the last available slot belongs to the
        // overflow item. The effective limit is manual outside flexible mode
        // and capacity-driven while automatic mode is active.
        const directLimit = Math.min(configuredLimit, Math.max(0, availableSlots - 1))
        root.visibleTaskRows = entries.slice(0, directLimit)
        root.overflowTaskRows = entries.slice(directLimit)
    }

    function bumpVisualRevision() {
        root.visualRevision += 1
    }

    function bumpStructureRevision() {
        root.structureRevision += 1
        root.structureChanged()
    }

    function scheduleRefresh(needsStructureRefresh) {
        if (!root.diagnosticTaskObservationEnabled) return
        root.pendingVisualRefresh = true
        root.pendingStructureRefresh = root.pendingStructureRefresh || !!needsStructureRefresh
        if (root.fanRevealActive || root.fanPresentationHold) {
            root.fanUpdatesDeferred = true
            return
        }
        refreshTimer.restart()
    }

    function flushRefresh() {
        if (!root.diagnosticTaskObservationEnabled) return
        if (root.fanRevealActive || root.fanPresentationHold) {
            root.fanUpdatesDeferred = true
            return
        }
        const visualChanged = root.pendingVisualRefresh || root.pendingStructureRefresh
        root.pendingVisualRefresh = false
        if (root.pendingStructureRefresh) {
            refreshVisibleRows()
            root.pendingStructureRefresh = false
            bumpStructureRevision()
        }
        if (root.pendingWindowObservation) {
            root.pendingWindowObservation = false
            root.pendingMaximizedObservation = false
            root.windowObservationRequested()
        } else if (root.pendingMaximizedObservation) {
            root.pendingMaximizedObservation = false
            root.maximizedObservationRequested()
        }
        if (visualChanged) bumpVisualRevision()
    }

    function taskStateForDockItem(item) {
        const result = {
            "count": 0,
            "minimizedCount": 0,
            "maximizedCount": 0,
            "isActive": false,
            "demandsAttention": false,
            "firstRow": -1,
            "rows": []
        }
        if (dockItemApplicationId(item).length === 0
                && dockItemLauncherUrl(item).length === 0
                && !String(item && item.command || "").trim()) {
            return result
        }

        for (let row = 0; row < tasksModel.count; row++) {
            const taskIndex = tasksModel.index(row, 0)
            if (!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar)
                    || !dockItemMatchesTaskRow(item, row)) {
                continue
            }
            if (result.firstRow === -1) {
                result.firstRow = row
            }
            result.count += 1
            if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
                result.minimizedCount += 1
            }
            if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximized)) {
                result.maximizedCount += 1
            }
            result.rows.push(row)
            result.isActive = result.isActive || isTaskRowActive(row)
            result.demandsAttention = result.demandsAttention
                || !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsDemandingAttention)
        }

        return result
    }

    function taskWindowsForRows(rows) {
        const windows = []
        for (let index = 0; index < rows.length; index++) {
            const row = rows[index]
            const taskIndex = tasksModel.index(row, 0)
            windows.push({
                "row": row,
                "title": String(tasksModel.data(taskIndex, Qt.DisplayRole) || ""),
                "name": String(tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppName) || ""),
                "subtitle": String(tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.GenericName) || ""),
                "active": isTaskRowActive(row),
                "closable": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsClosable),
                "minimizable": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimizable),
                "minimized": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized),
                "maximizable": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximizable),
                "maximized": !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximized),
                "icon": taskIconSourceForRow(row),
                "windowUuid": taskWindowUuidForRow(row),
                "winId": taskWinIdForRow(row)
            })
        }
        return windows
    }

    function taskApplicationIdForRows(rows) {
        for (let index = 0; index < rows.length; index++) {
            const row = Number(rows[index])
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid
                    || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar)) {
                continue
            }

            const appId = taskAppIdForRow(row)
            if (appId.length > 0) {
                return appId
            }
        }

        return ""
    }

    function taskWindowsForIdentity(applicationId, windowUuids) {
        const normalizedAppId = normalizeApplicationId(applicationId)
        const acceptedUuids = {}
        const uuids = windowUuids instanceof Array ? windowUuids : []
        for (let index = 0; index < uuids.length; index++) {
            const uuid = String(uuids[index] || "")
            if (uuid.length > 0) {
                acceptedUuids[uuid] = true
            }
        }

        const rows = []
        for (let row = 0; row < tasksModel.count; row++) {
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid
                    || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    || tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.SkipTaskbar)) {
                continue
            }

            const matchesApplication = normalizedAppId.length > 0
                && taskAppIdForRow(row) === normalizedAppId
            const windowUuid = taskWindowUuidForRow(row)
            const matchesWindow = normalizedAppId.length === 0
                && windowUuid.length > 0
                && acceptedUuids[windowUuid] === true
            if (matchesApplication || matchesWindow) {
                rows.push(row)
            }
        }

        return taskWindowsForRows(rows)
    }

    function taskDataForEntry(entry) {
        if (!entry || !entry.rows || entry.rows.length === 0) {
            return {
                "name": "",
                "icon": "application-x-executable",
                "count": 0,
                "minimizedCount": 0,
                "maximizedCount": 0,
                "rows": [],
                "firstRow": -1,
                "active": false,
                "demandsAttention": false,
                "windowUuid": "",
                "temporaryTrayId": String(entry && entry.temporaryTrayId || "")
            }
        }

        const firstRow = Number(entry.firstRow)
        const taskIndex = tasksModel.index(firstRow, 0)
        if (!taskIndex.valid) {
            return {
                "name": "",
                "icon": "application-x-executable",
                "count": 0,
                "minimizedCount": 0,
                "maximizedCount": 0,
                "rows": [],
                "firstRow": -1,
                "active": false,
                "demandsAttention": false,
                "windowUuid": "",
                "temporaryTrayId": String(entry && entry.temporaryTrayId || "")
            }
        }

        const rows = entry.rows.slice()
        let active = false
        let demandsAttention = false
        let minimizedCount = 0
        let maximizedCount = 0
        for (let index = 0; index < rows.length; index++) {
            const row = rows[index]
            const rowIndex = tasksModel.index(row, 0)
            if (!rowIndex.valid) {
                continue
            }
            active = active || isTaskRowActive(row)
            demandsAttention = demandsAttention || !!tasksModel.data(rowIndex, TaskManager.AbstractTasksModel.IsDemandingAttention)
            if (tasksModel.data(rowIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
                minimizedCount += 1
            }
            if (tasksModel.data(rowIndex, TaskManager.AbstractTasksModel.IsMaximized)) {
                maximizedCount += 1
            }
        }
        return {
            "name": String(tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppName)
                || tasksModel.data(taskIndex, Qt.DisplayRole)
                || ""),
            "icon": taskIconSourceForRow(firstRow),
            "count": Math.max(1, Number(entry.count || rows.length || 1)),
            "minimizedCount": minimizedCount,
            "maximizedCount": maximizedCount,
            "rows": rows,
            "firstRow": firstRow,
            "active": active,
            "demandsAttention": demandsAttention,
            "windowUuid": taskWindowUuidForRow(firstRow),
            // Keep the verified session-only tray identity all the way into
            // main.qml. R63.5 lost it here, so the hover guard never ran.
            "temporaryTrayId": String(entry.temporaryTrayId || "")
        }
    }

    function minimizedCountForRows(taskRows) {
        const rows = taskRows instanceof Array ? taskRows : []
        let minimizedCount = 0
        for (let index = 0; index < rows.length; index++) {
            const taskIndex = tasksModel.index(Number(rows[index]), 0)
            if (taskIndex.valid
                    && tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow)
                    && tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
                minimizedCount += 1
            }
        }
        return minimizedCount
    }

    // qmllint disable unqualified
    function contextActionsForRows(taskRows) {
        const sourceRows = taskRows instanceof Array ? taskRows : []
        const rows = []
        for (let index = 0; index < sourceRows.length; index++) {
            const row = Number(sourceRows[index])
            if (tasksModel.index(row, 0).valid) {
                rows.push(row)
            }
        }
        if (rows.length === 0) {
            return []
        }

        let preferredRow = rows[0]
        for (let index = 0; index < rows.length; index++) {
            if (isTaskRowActive(rows[index])) {
                preferredRow = rows[index]
                break
            }
        }

        const taskIndex = tasksModel.index(preferredRow, 0)
        const actions = []
        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.CanLaunchNewInstance)) {
            actions.push({
                "kind": "taskAction",
                "operation": "newInstance",
                "name": i18n("New window"),
                "icon": "window-new",
                "taskRow": preferredRow,
                "enabled": true
            })
        }

        if (rows.length > 1) {
            let closableCount = 0
            for (let index = 0; index < rows.length; index++) {
                const rowIndex = tasksModel.index(rows[index], 0)
                if (rowIndex.valid && tasksModel.data(rowIndex, TaskManager.AbstractTasksModel.IsClosable)) {
                    closableCount++
                }
            }
            if (closableCount > 0) {
                actions.push({
                    "kind": "taskAction",
                    "operation": "closeAll",
                    "name": i18np("Close %1 window", "Close all %1 windows", closableCount),
                    "icon": "window-close",
                    "taskRows": rows,
                    "enabled": true,
                    "destructive": true
                })
            }
            return actions
        }

        const minimized = !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)
        const maximized = !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximized)
        const keepAbove = !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsKeepAbove)
        const fullScreen = !!tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsFullScreen)

        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimizable)) {
            actions.push({
                "kind": "taskAction",
                "operation": "toggleMinimized",
                "name": minimized ? i18n("Restore") : i18n("Minimize"),
                "icon": minimized ? "window-restore" : "window-minimize",
                "taskRow": preferredRow,
                "enabled": true
            })
        }
        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximizable)) {
            actions.push({
                "kind": "taskAction",
                "operation": "toggleMaximized",
                "name": maximized ? i18n("Restore from maximized") : i18n("Maximize"),
                "icon": maximized ? "window-restore" : "window-maximize",
                "taskRow": preferredRow,
                "enabled": true
            })
        }
        actions.push({
            "kind": "taskAction",
            "operation": "toggleKeepAbove",
            "name": keepAbove ? i18n("Do not keep above") : i18n("Keep above"),
            "icon": "window-keep-above",
            "taskRow": preferredRow,
            "enabled": true,
            "checked": keepAbove
        })
        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsFullScreenable)) {
            actions.push({
                "kind": "taskAction",
                "operation": "toggleFullScreen",
                "name": fullScreen ? i18n("Exit full screen") : i18n("Full screen"),
                "icon": fullScreen ? "view-restore" : "view-fullscreen",
                "taskRow": preferredRow,
                "enabled": true,
                "checked": fullScreen
            })
        }
        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsClosable)) {
            actions.push({
                "kind": "taskAction",
                "operation": "close",
                "name": i18n("Close"),
                "icon": "window-close",
                "taskRow": preferredRow,
                "enabled": true,
                "destructive": true
            })
        }
        return actions
    }
    // qmllint enable unqualified

    function triggerContextAction(action) {
        if (!action || action.kind !== "taskAction") {
            return false
        }

        const operation = String(action.operation || "")
        const row = Number(action.taskRow)
        const taskIndex = tasksModel.index(row, 0)
        if (operation === "closeAll") {
            const rows = action.taskRows instanceof Array ? action.taskRows.slice() : []
            for (let index = 0; index < rows.length; index++) {
                closeTaskRow(Number(rows[index]))
            }
            return rows.length > 0
        }
        if (!taskIndex.valid) {
            return false
        }
        if (operation === "newInstance") {
            tasksModel.requestNewInstance(taskIndex)
        } else if (operation === "toggleMinimized") {
            minimizeTaskRow(row)
        } else if (operation === "toggleMaximized") {
            toggleMaximizedTaskRow(row)
        } else if (operation === "toggleKeepAbove") {
            tasksModel.requestToggleKeepAbove(taskIndex)
        } else if (operation === "toggleFullScreen") {
            tasksModel.requestToggleFullScreen(taskIndex)
        } else if (operation === "close") {
            return closeTaskRow(row)
        } else {
            return false
        }
        return true
    }

    // R63.5: promoted SNI applications are already running. A click toggles
    // their existing window when KDE exposes a minimizable TasksModel row;
    // otherwise the application's native SNI Activate handles its own popup
    // (MEGAsync and other non-minimizable tray interfaces). Never launch a
    // second process and never unpromote merely because a window was hidden.
    function togglePromotedTrayApplication(desktopId, rows, activateNotifier) {
        const id = root.canonicalServiceId(desktopId)
        if (!id || !root.isTrayTemporarilyPromoted(id)) return false
        // MEGAsync creates its own transient window. Its SNI Activate is the
        // same primary action as a click on the real KDE tray icon; prefer it
        // over stale TasksModel focus/minimize state when toggling the popup.
        // Other promoted applications keep KDE's normal window toggle logic.
        const megaNotifier = id === "megasync" || id === "mega"
            || id === "nz.mega.megasync"
        if (megaNotifier && typeof activateNotifier === "function"
                && activateNotifier() === true) return true
        const candidates = Array.isArray(rows) ? rows : []
        let preferred = null
        for (const value of candidates) {
            const row = Number(value)
            if (!Number.isInteger(row) || row < 0 || row >= tasksModel.count)
                continue
            const idx = tasksModel.index(row, 0)
            if (!idx.valid
                    || !tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                    || root.trayOnlyIdentityForRow(row) !== id)
                continue
            if (!tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimizable))
                continue
            // Prefer the focused window if a notifier has several normal ones.
            if (!preferred || tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive)) {
                preferred = idx
                if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive)) break
            }
        }
        if (preferred) {
            if (tasksModel.data(preferred, TaskManager.AbstractTasksModel.IsActive)
                    && !tasksModel.data(preferred, TaskManager.AbstractTasksModel.IsMinimized))
                tasksModel.requestToggleMinimized(preferred)
            else
                tasksModel.requestActivate(preferred)
            return true
        }
        // SNI does not standardize a Hide method. Native Activate toggles
        // app-specific popups when the exporter supports this behavior.
        return typeof activateNotifier === "function" && activateNotifier() === true
    }

    function activateTaskRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid) {
            return
        }

        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsActive)
                && tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimizable)) {
            tasksModel.requestToggleMinimized(taskIndex)
            return
        }

        tasksModel.requestActivate(taskIndex)
    }

    function activatePreferredTaskRow(rows) {
        if (!rows || rows.length === 0) {
            return
        }

        for (let index = 0; index < rows.length; index++) {
            const row = Number(rows[index])
            if (isTaskRowActive(row)) {
                activateTaskRow(row)
                return
            }
        }

        activateTaskRow(Number(rows[0]))
    }

    function openUrlsWithTaskRows(rows, urls) {
        if (!rows || rows.length === 0 || !urls || urls.length === 0) {
            return false
        }

        let preferredRow = -1
        for (let index = 0; index < rows.length; index++) {
            const row = Number(rows[index])
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid) {
                continue
            }
            if (preferredRow < 0) {
                preferredRow = row
            }
            if (isTaskRowActive(row)) {
                preferredRow = row
                break
            }
        }
        if (preferredRow < 0) {
            return false
        }

        const preferredIndex = tasksModel.index(preferredRow, 0)
        tasksModel.requestActivate(preferredIndex)
        tasksModel.requestOpenUrls(preferredIndex, urls)
        return true
    }

    function activateTaskRowsForExternalDrop(rows) {
        if (!rows || rows.length === 0) {
            return false
        }

        let preferredRow = -1
        for (let index = 0; index < rows.length; index++) {
            const row = Number(rows[index])
            const taskIndex = tasksModel.index(row, 0)
            if (!taskIndex.valid) {
                continue
            }
            if (isTaskRowActive(row)) {
                return false
            }
            if (preferredRow < 0) {
                preferredRow = row
            }
        }
        if (preferredRow < 0) {
            return false
        }

        tasksModel.requestActivate(tasksModel.index(preferredRow, 0))
        return true
    }

    function closeTaskRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsClosable)) {
            return false
        }
        tasksModel.requestClose(taskIndex)
        return true
    }

    function minimizeTaskRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimizable)) {
            return
        }

        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
            tasksModel.requestActivate(taskIndex)
            return
        }

        tasksModel.requestToggleMinimized(taskIndex)
    }

    function toggleMaximizedTaskRow(row) {
        const taskIndex = tasksModel.index(row, 0)
        if (!taskIndex.valid || !tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMaximizable)) {
            return
        }

        if (tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized)) {
            tasksModel.requestActivate(taskIndex)
        }

        tasksModel.requestToggleMaximized(taskIndex)
        tasksModel.requestActivate(taskIndex)
    }
}
