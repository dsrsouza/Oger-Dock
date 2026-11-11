pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import "org/punchi/dock" as Punchi
import "components"
import "components/controlcenter"
import "components/punchimenu"
import "config/code/configItems.js" as ConfigItemsJS
import "../code/wheelInput.js" as WheelInput

PlasmoidItem {
    id: root
    objectName: "punchiDockRoot"

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""
    toolTipSubText: ""
    preferredRepresentation: fullRepresentation
    compactRepresentation: fullRepresentation

    onExpandedChanged: {
        // A dock hosted in a panel owns its popups and must never expose its
        // full representation through Plasma's generic activation lifecycle.
        if (root.inPanel
                && (root.configuredPunchiMenuItem
                    || root.configuredControlCenterItem)
                && root.expanded) {
            root.expanded = false
        }
    }

    // Plasma documents PlasmaCore.Action as the QAction factory for
    // Plasmoid.contextualActions. Qt 6.8 qmllint cannot resolve that type from
    // the installed Plasma metadata and reports cascading property warnings.
    // qmllint disable import
    // qmllint disable missing-property
    // qmllint disable unqualified
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action:context", "Add Quick Note")
            icon.name: "knotes"
            onTriggered: dockItemsController.addQuickNote()
        },
        PlasmaCore.Action {
            text: Plasmoid.configuration.enableFloatingItemDragReordering === true
                ? i18nc("@action:context", "Travar a dock")
                : i18nc("@action:context", "Destravar a dock")
            icon.name: Plasmoid.configuration.enableFloatingItemDragReordering === true
                ? "object-locked" : "object-unlocked"
            onTriggered: {
                Plasmoid.configuration.enableFloatingItemDragReordering
                    = Plasmoid.configuration.enableFloatingItemDragReordering !== true
                Plasmoid.configuration.writeConfig()
            }
        },
        PlasmaCore.Action {
            text: i18nc("@action:context", "Add Separator")
            icon.name: "draw-line"
            onTriggered: dockItemsController.addQuickSeparator()
        },
        PlasmaCore.Action {
            text: i18n("Plasma theme")
            icon.name: "preferences-desktop-theme-global"
            checkable: true
            checked: String(Plasmoid.configuration.dockThemeMode || "plasma") === "plasma"
            onTriggered: Plasmoid.configuration.dockThemeMode = "plasma"
        },
        PlasmaCore.Action {
            visible: String(Plasmoid.configuration.dockThemeCustomId || "").length > 0
            text: i18n("External JSON theme")
            icon.name: "preferences-desktop-theme-global"
            checkable: true
            checked: String(Plasmoid.configuration.dockThemeMode || "plasma") === "custom"
            onTriggered: Plasmoid.configuration.dockThemeMode = "custom"
        }
        // qmllint enable unqualified
    ]
    // qmllint enable missing-property
    // qmllint enable import

    property bool deletingActiveNote: false
    // R19: one direct DBusMenu host for pinned, windowed and tray-only apps.
    // The application's original actions are read asynchronously from its
    // StatusNotifierItem.Menu object; no app-specific fake Quit shortcuts.
    property string pinnedTrayMenuDesktopId: ""
    property var pinnedTrayMenuAnchor: null
    property string pinnedTrayPromotedId: ""
    // fullRepresentation is a nested QML component. Its dialog ids are NOT
    // visible to root functions: retain a runtime instance reference instead.
    property var trayActionsPopupRef: null
    property var trayDefaultAnchorRef: null
    property int pinnedTrayMenuParentId: 0
    property var pinnedTrayMenuStack: []
    property bool pinnedTrayMenuFallback: false
    property bool pinnedTrayMenuLoading: false
    property bool pinnedTrayMenuNavigating: false
    // An app might not export DBusMenu, or Wayland may delay the reply. Never
    // let a right-click appear to do nothing while awaiting the async reply.
    Timer {
        id: pinnedTrayMenuTimeout
        interval: 4200
        repeat: false
        onTriggered: {
            if (root.pinnedTrayMenuLoading && root.pinnedTrayMenuDesktopId)
                root.showPinnedTrayFallback()
        }
    }
    function normalizedNotifierId(value) {
        let id = String(value || "").trim().toLowerCase()
        if (id.startsWith("applications:")) id = id.substring(13)
        if (id.indexOf("/") >= 0) id = id.split("/").pop()
        if (id.endsWith(".desktop")) id = id.substring(0, id.length - 8)
        return id
    }
    function openPinnedTrayActions(desktopId, visualAnchor, promotedIdentity) {
        if (!desktopId) return false
        const id = root.normalizedNotifierId(desktopId)
        trayWindowBridge.noteUserInteraction(id)
        root.pinnedTrayMenuDesktopId = id
        root.pinnedTrayPromotedId = String(promotedIdentity || "")
        root.pinnedTrayMenuAnchor = visualAnchor || root.trayDefaultAnchorRef
        root.pinnedTrayMenuParentId = 0
        root.pinnedTrayMenuStack = []
        root.pinnedTrayMenuFallback = false
        root.pinnedTrayMenuLoading = true
        pinnedTrayMenuTimeout.stop()
        // R28: avoid opening a tiny loading popup and then resizing a live
        // PlasmaCore.Dialog: its Wayland geometry can remain stuck at 64px,
        // clipping the DBusMenu and leaving a misleading scrollbar. Open
        // once, after real actions arrive, or after the timeout fallback.
        if (root.trayActionsPopupRef && root.trayActionsPopupRef.visible)
            root.trayActionsPopupRef.closeSafely()
        if (trayWindowBridge.requestNotifierActions(id)) {
            pinnedTrayMenuTimeout.restart()
            return true
        }
        console.warn("Oger Dock R21: no matched StatusNotifierItem for", id)
        trayWindowBridge.refresh()
        // A just-launched notifier may not yet be in the async SNI snapshot.
        // Keep the visible loading state and retry when refresh completes.
        pinnedTrayMenuTimeout.restart()
        return true
    }
    function showPinnedTrayFallback() {
        if (!root.pinnedTrayMenuDesktopId) return false
        // R29: never construct substitute menus for a missing SNI DBusMenu.
        // Ask the application to present its own native ContextMenu when it
        // exports one. Some apps intentionally expose no context menu.
        pinnedTrayMenuTimeout.stop()
        root.pinnedTrayMenuLoading = false
        root.pinnedTrayMenuFallback = true
        // A temporarily promoted item must retain Return to tray even if
        // its SNI does not export a DBusMenu. The native menu stays available.
        if (taskController.isTrayTemporarilyPromoted(root.pinnedTrayPromotedId))
            return root.openTrayQuickMenu(true)
        const opened = root.tryNativeTrayMenu()
        if (!opened)
            console.warn("Punchi tray: application has no usable native menu:",
                root.pinnedTrayMenuDesktopId)
        return opened
    }
    // PlasmaCore.Dialog uses visualParent to position its Wayland xdg-popup.
    // QtQuick.Window's global x/y are not a reliable Wayland placement API.
    // The menu request now happens on mouse release, so the opening click
    // cannot instantly dismiss the popup before the first frame.
    function openTrayQuickMenu(reposition) {
        const popup = root.trayActionsPopupRef
        const anchor = root.pinnedTrayMenuAnchor || root.trayDefaultAnchorRef
        if (!popup || !anchor) {
            console.warn("Punchi tray: popup unavailable (representation or anchor not created)")
            return false
        }
        if (popup.visualParent !== anchor || reposition !== false)
            popup.visualParent = anchor
        if (!popup.visible && !popup.preparingToShow)
            popup.openSafely()
        return true
    }
    // A submenu may have a different number of rows. Qt/Wayland does not
    // reliably resize an already-mapped Plasma dialog: safely remap the
    // dialog once with the new implicit content size, without losing the SNI.
    function navigatePinnedTrayMenu() {
        const popup = root.trayActionsPopupRef
        if (!popup) return false
        if (popup.visible || popup.preparingToShow) {
            root.pinnedTrayMenuNavigating = true
            popup.closeSafely()
            Qt.callLater(function() {
                if (!root.pinnedTrayMenuNavigating) return
                root.pinnedTrayMenuNavigating = false
                root.openTrayQuickMenu(true)
            })
            return true
        }
        return root.openTrayQuickMenu(true)
    }
    function trayActivationGlobalPoint(anchor) {
        if (!anchor || typeof anchor.mapToGlobal !== "function")
            return Qt.point(-1, -1)
        return anchor.mapToGlobal(Qt.point(anchor.width / 2, anchor.height / 2))
    }
    function activateTrayDesktopEntry(desktopId, anchor) {
        const point = root.trayActivationGlobalPoint(anchor)
        return trayWindowBridge.activateDesktopEntry(
            String(desktopId || ""), Math.round(point.x), Math.round(point.y))
    }
    function tryNativeTrayMenu() {
        const anchor = root.pinnedTrayMenuAnchor
        if (!anchor) return false
        const pos = anchor.mapToGlobal(Qt.point(0, 0))
        const area = dockGeometry.availableScreenRect
        const gap = Math.max(8, Kirigami.Units.smallSpacing)
        const menuWidth = 340
        const menuHeight = 280
        let x = pos.x
        let y = pos.y - menuHeight - gap
        if (dockGeometry.leftPanel) {
            x = pos.x + anchor.width + gap
            y = pos.y
        } else if (dockGeometry.rightPanel) {
            x = pos.x - menuWidth - gap
            y = pos.y
        }
        x = Math.round(Math.max(area.x + gap,
            Math.min(x, area.x + area.width - menuWidth - gap)))
        y = Math.round(Math.max(area.y + gap,
            Math.min(y, area.y + area.height - menuHeight - gap)))
        return trayWindowBridge.openNotifierMenu(root.pinnedTrayMenuDesktopId, x, y)
    }
    Connections {
        target: trayWindowBridge
        // Full SNI registry changes can update a pinned native menu even
        // when no dynamic app entry is added or removed (R37).
        function onRegisteredDesktopIdsChanged() {
            root.invalidatePinnedTrayIds()
        }
        function onRegisteredEntriesChanged() {
            if (root.pinnedTrayMenuLoading && root.pinnedTrayMenuDesktopId
                    && trayWindowBridge.containsDesktopEntry(root.pinnedTrayMenuDesktopId)) {
                trayWindowBridge.requestNotifierActions(root.pinnedTrayMenuDesktopId)
            }
        }
        function onObservedEntriesChanged() {
            // A user-observed window may have just become a tray-only app.
            root.invalidatePinnedTrayIds()
        }
        function onContextActionsChanged() {
            if (!root.pinnedTrayMenuDesktopId || root.pinnedTrayMenuFallback
                    || trayWindowBridge.contextMenuDesktopId !== root.pinnedTrayMenuDesktopId
                    || trayWindowBridge.contextActions.length === 0) return
            pinnedTrayMenuTimeout.stop()
            root.pinnedTrayMenuLoading = false
            root.pinnedTrayMenuParentId = 0
            root.pinnedTrayMenuStack = []
            console.info("Punchi tray: presenting received DBusMenu actions for",
                root.pinnedTrayMenuDesktopId, "count", trayWindowBridge.contextActions.length)
            root.openTrayQuickMenu(true)
        }
        function onNotifierActionsUnavailable(desktopId) {
            if (desktopId === root.pinnedTrayMenuDesktopId)
                root.showPinnedTrayFallback()
        }
    }
    property var dynamicApplicationsMoveModeTarget: null
    readonly property bool dynamicApplicationsMoveModeActive:
        !!dynamicApplicationsMoveModeTarget
        && dynamicApplicationsMoveModeTarget.dynamicApplicationsMoveModeActive

    function requestDynamicApplicationsMoveMode() {
        const target = root.dynamicApplicationsMoveModeTarget
        if (!target || typeof target.enterDynamicApplicationsMoveMode
                !== "function" || root.dynamicApplicationsMarkerIndex < 0) {
            return false
        }
        Qt.callLater(function() {
            if (root.dynamicApplicationsMoveModeTarget === target
                    && typeof target.enterDynamicApplicationsMoveMode
                        === "function") {
                target.enterDynamicApplicationsMoveMode()
            }
        })
        return true
    }
    
    // Host environment detection (panel or floating dock).
    property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // User-controlled orientation for a freely floating dock. Plasma owns
    // orientation when hosted inside a KDE panel, never the other way around.
    // Legacy "horizontal" preferences are treated as Bottom.
    readonly property string floatingDockPlacement: {
        const preference = String(Plasmoid.configuration.floatingDockOrientation || "bottom")
        return preference === "left" || preference === "right" ? preference : "bottom"
    }
    readonly property bool floatingVertical: floatingDockPlacement !== "bottom"
    property var floatingDockAnchor: null
    property bool floatingOrientationReady: false
    property bool mediaItemExpanded: true
    property var mediaInlineTitleExtents: ({})
    function setMediaInlineTitleExtent(index, value) {
        const key = String(index)
        const width = Math.max(0, Number(value) || 0)
        const old = Number(root.mediaInlineTitleExtents[key] || 0)
        if (Math.abs(old - width) < 0.35) return
        const next = Object.assign({}, root.mediaInlineTitleExtents)
        if (width < 0.35) delete next[key]
        else next[key] = width
        root.mediaInlineTitleExtents = next
    }
    // Output audio must be audible, not simply a MPRIS session whose state
    // switched to Playing when the pointer passed over a silent preview.
    property bool mediaSoundConfirmed: false
    readonly property bool mediaSoundCurrentlyDetected:
        dockMediaController.available && dockMediaController.playing
        && (audioSpectrumController.available && audioSpectrumController.active)
    readonly property bool needsMediaAudioDetection: {
        const items = dockItemsController.dockItems || []
        for (let i = 0; i < items.length; ++i) {
            if (items[i] && items[i].type === "media"
                    && String(items[i].mediaIdleVisibility || "sound") === "sound")
                return true
        }
        return false
    }
    // Timing is user-configurable on the first media item in audible mode.
    // A single monitor and gate are shared by all media items to avoid
    // opening duplicate PipeWire clients for every item.
    readonly property var audibleMediaItem: {
        const items = dockItemsController.dockItems || []
        for (let i = 0; i < items.length; ++i) {
            if (items[i] && items[i].type === "media"
                    && String(items[i].mediaIdleVisibility || "sound") === "sound")
                return items[i]
        }
        return ({})
    }
    function mediaGateDelay(value, fallback, maximum) {
        const n = Number(value)
        return Number.isFinite(n) ? Math.max(0, Math.min(maximum, Math.round(n)))
            : fallback
    }
    readonly property int audibleShowDelayMs: mediaGateDelay(
        audibleMediaItem.mediaSoundShowDelayMs, 650, 3000)
    readonly property int audibleHideDelayMs: Math.max(7000, mediaGateDelay(
        audibleMediaItem.mediaSoundHideDelayMs, 7000, 30000))
    function updateMediaSoundGate() {
        if (mediaSoundCurrentlyDetected
                || (!audioSpectrumController.available && mediaPlaybackCurrentlyPlaying)) {
            mediaSoundCloseTimer.stop()
            if (!mediaSoundConfirmed) mediaSoundOpenTimer.restart()
        } else {
            mediaSoundOpenTimer.stop()
            if (mediaSoundConfirmed && !mediaSoundCloseTimer.running)
                mediaSoundCloseTimer.start()
        }
    }
    Timer {
        id: mediaSoundOpenTimer
        interval: root.audibleShowDelayMs
        repeat: false
        onTriggered: root.mediaSoundConfirmed = root.mediaSoundCurrentlyDetected
            || (!audioSpectrumController.available && root.mediaPlaybackCurrentlyPlaying)
    }
    Timer {
        id: mediaSoundCloseTimer
        interval: root.audibleHideDelayMs
        repeat: false
        onTriggered: {
            if (!root.mediaSoundCurrentlyDetected
                    && (audioSpectrumController.available || !root.mediaPlaybackCurrentlyPlaying))
                root.mediaSoundConfirmed = false
        }
    }
    readonly property var folderCategoryColors: {
        try {
            const colors = JSON.parse(String(Plasmoid.configuration.folderCategoryColorsJson || "{}"))
            return colors && typeof colors === "object" ? colors : ({})
        } catch (error) { return ({}) }
    }
    readonly property var mediaPinPreferences: {
        try {
            const data = JSON.parse(String(Plasmoid.configuration.mediaPinnedByApplicationJson || "{}"))
            return data && typeof data === "object" && !Array.isArray(data) ? data : ({})
        } catch (error) { return ({}) }
    }
    function setMediaPinPreference(key, pinned) {
        const identity = String(key || "").trim().toLowerCase().slice(0, 128)
        if (!identity) return
        const next = Object.assign({}, mediaPinPreferences)
        next[identity] = !!pinned
        Plasmoid.configuration.mediaPinnedByApplicationJson = JSON.stringify(next)
    }
    property bool mediaPlaybackConfirmed: false
    readonly property bool mediaPlaybackCurrentlyPlaying:
        dockMediaController.available && dockMediaController.playing
    function updateMediaPlaybackGate() {
        if (mediaPlaybackCurrentlyPlaying) {
            mediaPlaybackCloseTimer.stop()
            mediaPlaybackConfirmed = true
        } else if (mediaPlaybackConfirmed && !mediaPlaybackCloseTimer.running) {
            mediaPlaybackCloseTimer.start()
        }
    }
    Timer {
        id: mediaPlaybackCloseTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.mediaPlaybackCurrentlyPlaying)
                root.mediaPlaybackConfirmed = false
        }
    }
    onMediaPlaybackCurrentlyPlayingChanged: {
        updateMediaPlaybackGate()
        updateMediaSoundGate()
    }
    onMediaSoundCurrentlyDetectedChanged: updateMediaSoundGate()
    onNeedsMediaAudioDetectionChanged: {
        if (!needsMediaAudioDetection) {
            mediaSoundOpenTimer.stop()
            mediaSoundCloseTimer.stop()
            mediaSoundConfirmed = false
        } else updateMediaSoundGate()
    }
    // Observe windows independently of the dynamic-task dock filter: pinned
    // applications must also be recognized when they close into the tray.
    // R33: task visual revisions also fire for presentation changes (e.g. a
    // popup gaining focus). The tray bridge needs WINDOW changes,
    // not a repeated full scan of identical KDE TasksModel snapshots.
    property string lastTrayWindowSnapshotSignature: ""
    property string lastMaximizedWindowSnapshotSignature: ""
    property int lastMaximizedWindowCount: 0
    property int lastActiveMaximizedWindowCount: 0
    function updateMaximizedWindowObservation(maximizedSnapshot) {
        if (!taskController.diagnosticTaskObservationEnabled) return
        const state = maximizedSnapshot !== undefined
            ? maximizedSnapshot : taskController.maximizedWindowSnapshot()
        const maximized = state instanceof Array ? state : state.ids
        if (!(state instanceof Array)) {
            lastMaximizedWindowCount = Number(state.total || 0)
            lastActiveMaximizedWindowCount = Number(state.active || 0)
        }
        const signature = JSON.stringify(maximized)
        if (signature === lastMaximizedWindowSnapshotSignature) return
        lastMaximizedWindowSnapshotSignature = signature
    }
    function updateTrayWindowObservation() {
        if (!taskController.diagnosticTaskObservationEnabled) return
        // R41: a single TaskManager scan replaces three separate QML loops.
        // Maximization/focus of the active window is NOT an SNI registration.
        const snapshot = taskController.allWindowObservationSnapshot()
        const applications = snapshot.applications
        const windows = snapshot.windows
        const maximized = snapshot.maximized
        const signature = JSON.stringify([applications, windows])
        if (signature !== lastTrayWindowSnapshotSignature) {
            lastTrayWindowSnapshotSignature = signature
            // R42 A/B: freeze only Punchi SNI observation;
            // task indicators continue receiving native task data.
            if (trayWindowBridge.diagnosticObservationEnabled)
                trayWindowBridge.observeWindowTasks(windows)
        }
        root.updateMaximizedWindowObservation({ids: maximized,
            total: snapshot.maximizedCount, active: snapshot.activeMaximizedCount})
    }
    // R36: protect only the opening of the folder fan, not its whole visible
    // lifetime. Ordinary tray menus and application activation stay immediate
    // once the arc has finished opening; closing releases any pending updates.
    readonly property bool fanRevealCritical: folderPopupDialog.visible
        && folderPopupContent.layoutMode === "fan"
        && !folderPopupAnimatedContent.closing
        && (folderPopupAnimatedContent.openingPending
            || folderPopupAnimatedContent.openingProgress < 0.999)
    Punchi.TrayWindowBridge {
        id: trayWindowBridge
        fanRevealActive: root.fanRevealCritical
        onDiagnosticObservationEnabledChanged: {
            // The first snapshot after resuming is a baseline; no startup
            // notifier is promoted merely because it remained registered.
            root.lastTrayWindowSnapshotSignature = ""
            if (diagnosticObservationEnabled)
                Qt.callLater(root.updateTrayWindowObservation)
        }
    }
    // The D-Bus notifier reveals applications which have no taskbar window.
    // Keep them in the dynamic dock until their notifier really unregisters.
    readonly property var visibleTrayEntries: {
        const modelStartMs = Date.now()
        const notifiers = trayWindowBridge.entries || []
        // Revision binding keeps the tray presentation current when the user
        // edits an XDG autostart entry in Plasma's Session Autostart settings.
        const autostartRevision = systemDiscovery.autostartRuleRevision
        const pinned = dockItemsController.dockItems || []
        const tasks = taskController.visibleTaskRows || []
        function normalize(value) {
            return String(value || "").toLowerCase().replace(/\.desktop$/, "")
                .split("/").pop()
        }
        const occupied = ({})
        const occupiedServices = ({})
        for (const item of pinned) {
            if (!item || item.type !== "app") continue
            for (const candidate of [item.appId, item.desktopEntry,
                    item.storageId, item.launcherUrl]) {
                const key = normalize(candidate)
                if (key) occupied[key] = true
            }
            const serviceId = taskController.resolvedDockServiceId(item)
            if (serviceId) occupiedServices[serviceId] = true
        }
        for (const task of tasks) {
            const key = normalize(task && task.appId)
            if (key) occupied[key] = true
            const serviceId = String(task && task.resolvedApplicationId || "")
            if (serviceId) occupiedServices[serviceId] = true
        }
        const extra = []
        for (const notifier of notifiers) {
            const key = normalize(notifier.desktopId)
            if (!key || occupied[key]) continue
            // R63.4: after an explicit foreground activation, keep the
            // temporary icon while the SNI exists, including when MEGA
            // hides its TaskManager window. Return to tray is the only
            // intentional way to dismiss this temporary representation.
            if (typeof systemDiscovery.userAutostartTrayOnly === "function"
                    && systemDiscovery.userAutostartTrayOnly(String(notifier.desktopId || key))
                    && !taskController.isTrayTemporarilyPromoted(String(notifier.desktopId || key)))
                continue
            // R28: command-only legacy pins can also own SNI entries. Reuse
            // the very same KDE identity resolver used for task suppression.
            if (pinned.some(function(item) {
                    return item && item.type === "app"
                        && taskController.dockItemMatchesNotifierId(item, key)
                })) continue
            const resolved = systemDiscovery.applicationForLauncher(key, "")
            const serviceId = taskController.resolvedNotifierServiceId(key)
                || taskController.canonicalServiceId(
                    resolved && (resolved.storageId || resolved.appId))
            // Do not render a second tray-only icon for an app which already
            // owns a pinned launcher or a dynamic task group under another
            // KDE desktop-file alias. Unrelated notifiers remain separate.
            if (serviceId && occupiedServices[serviceId]) continue
            // Both visible task groups and their notifier can have different
            // AppIds but resolve to one verified KService identity.
            if (tasks.some(function(task) {
                    return taskController.taskEntryMatchesNotifierId(task, key)
                })) continue
            occupied[key] = true
            if (serviceId) occupiedServices[serviceId] = true
            extra.push(notifier)
        }
        const modelElapsedMs = Date.now() - modelStartMs
        if (modelElapsedMs > 20)
            console.info("Punchi tray R38 visible-model-ms", modelElapsedMs,
                "notifiers", notifiers.length, "pinned", pinned.length,
                "tasks", tasks.length)
        return extra
    }
    // Launcher-specific memoization: popup focus must never rescan KService.
    property int trayIdentityRevision: 0
    property var pinnedTrayIdCache: ({})
    function invalidatePinnedTrayIds() {
        root.pinnedTrayIdCache = ({})
        root.trayIdentityRevision++
    }
    function trayDesktopIdForItem(item) {
        if (!item) return ""
        const version = root.trayIdentityRevision
        const cacheKey = JSON.stringify([
            item.appId || "", item.desktopEntry || "", item.storageId || "",
            item.launcherUrl || "", item.command || "",
            item.appIds || [], item.launcherUrls || []
        ])
        const cached = root.pinnedTrayIdCache[cacheKey]
        if (cached && cached.version === version) return cached.id
        const began = Date.now()
        function save(id) {
            root.pinnedTrayIdCache[cacheKey] = {version: version, id: id}
            const ms = Date.now() - began
            if (ms > 20) console.info("Punchi tray R38 pinned-resolve-ms", ms)
            return id
        }
        // The pinned launcher and the SNI can have different desktop IDs.
        // Prefer the first identity that actually owns an exported notifier
        // instead of relying on the launcher's storageId alone.
        const options = [item.appId, item.desktopEntry, item.storageId,
            item.launcherUrl]
        if (item.appIds instanceof Array) options.push(...item.appIds)
        if (item.launcherUrls instanceof Array) options.push(...item.launcherUrls)
        for (const candidate of options) {
            const key = root.normalizedNotifierId(candidate)
            if (key && trayWindowBridge.containsDesktopEntry(key)) return save(key)
        }
        // R29: pinned items must resolve against ALL registered SNIs,
        // including ones created at login that are intentionally absent from
        // the dynamic list. This property must NOT render extra dock items.
        for (const desktopId of trayWindowBridge.registeredDesktopIds || []) {
            const key = root.normalizedNotifierId(desktopId)
            if (key && taskController.dockItemMatchesNotifierId(item, key))
                return save(key)
        }
        return save(root.normalizedNotifierId(options.find(v => !!v) || ""))
    }
    readonly property var visibleTaskRows: taskController.visibleTaskRows
    readonly property var overflowTaskRows: taskController.overflowTaskRows
    readonly property int dynamicApplicationsMarkerIndex: {
        const items = dockItemsController.dockItems || []
        for (let index = 0; index < items.length; index++) {
            if (items[index]
                    && items[index].type === "dynamic-applications") {
                return index
            }
        }
        return -1
    }
    readonly property int dynamicApplicationsAnchorIndex:
        dynamicApplicationsMarkerIndex >= 0
            ? dynamicApplicationsMarkerIndex
            : dockItemsController.dockItems.length
    readonly property int renderedOverflowItemCount:
        overflowTaskRows.length > 0 ? 1 : 0
    readonly property int taskVisualRevision: taskController.visualRevision
    readonly property var dockItemsControllerService: dockItemsController
    readonly property var configuredMediaItem: {
        const items = dockItemsController.dockItems || []
        for (let index = 0; index < items.length; index++) {
            if (items[index] && items[index].type === "media") {
                return items[index]
            }
        }
        return null
    }
    readonly property string configuredMediaApplicationId: configuredMediaItem
        ? String(configuredMediaItem.defaultPlayerAppId
            || configuredMediaItem.defaultPlayerStorageId || "").substring(0, 512)
        : ""
    readonly property int configuredPunchiMenuItemIndex: {
        const items = dockItemsController.dockItems || []
        for (let index = 0; index < items.length; index++) {
            if (items[index] && items[index].type === "punchimenu") {
                return index
            }
        }
        return -1
    }
    readonly property var configuredPunchiMenuItem: configuredPunchiMenuItemIndex >= 0
        ? (dockItemsController.dockItems || [])[configuredPunchiMenuItemIndex]
        : null
    readonly property int configuredControlCenterItemIndex: {
        const items = dockItemsController.dockItems || []
        for (let index = 0; index < items.length; index++) {
            if (items[index] && items[index].type === "control-center") {
                return index
            }
        }
        return -1
    }
    readonly property var configuredControlCenterItem:
        configuredControlCenterItemIndex >= 0
            ? (dockItemsController.dockItems
                || [])[configuredControlCenterItemIndex]
            : null
    readonly property string configuredControlCenterMode:
        ConfigItemsJS.normalizedControlCenterMode(
            configuredControlCenterItem
                ? configuredControlCenterItem.controlCenterMode
                : "floating")
    readonly property real configuredPunchiMenuGridIconScale: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.gridIconScalePercent
            : 100)
        const safePercent = Number.isFinite(requestedPercent)
            ? Math.max(75, Math.min(150, Math.round(requestedPercent / 5) * 5))
            : 100
        return safePercent / 100
    }
    readonly property real configuredPunchiMenuFavoriteIconScale: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.favoriteIconScalePercent
            : 100)
        const safePercent = Number.isFinite(requestedPercent)
            ? Math.max(75, Math.min(110, Math.round(requestedPercent / 5) * 5))
            : 100
        return safePercent / 100
    }
    readonly property int configuredPunchiMenuNormalFolderMaximumColumns: {
        const requestedCount = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalFolderMaximumColumns
            : 3)
        return Number.isFinite(requestedCount)
            ? Math.max(1, Math.min(3, Math.round(requestedCount)))
            : 3
    }
    readonly property int configuredPunchiMenuNormalFolderMaximumRows: {
        const requestedCount = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalFolderMaximumRows
            : 3)
        return Number.isFinite(requestedCount)
            ? Math.max(1, Math.min(3, Math.round(requestedCount)))
            : 3
    }
    readonly property int configuredPunchiMenuFullScreenFolderMaximumColumns: {
        const requestedCount = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.fullScreenFolderMaximumColumns
            : 5)
        return Number.isFinite(requestedCount)
            ? Math.max(1, Math.min(5, Math.round(requestedCount)))
            : 5
    }
    readonly property int configuredPunchiMenuFullScreenFolderMaximumRows: {
        const requestedCount = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.fullScreenFolderMaximumRows
            : 5)
        return Number.isFinite(requestedCount)
            ? Math.max(1, Math.min(5, Math.round(requestedCount)))
            : 5
    }
    readonly property bool configuredPunchiMenuShowDistributionName:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.showDistributionName !== false
    readonly property bool configuredPunchiMenuShowPageNavigationArrows:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.showPageNavigationArrows !== false
    readonly property bool configuredPunchiMenuShowApplicationLabels:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.showApplicationLabels !== false
    readonly property string configuredPunchiMenuPerformanceMode: {
        const value = String(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.performanceMode || "automatic" : "automatic")
        return value === "economy" || value === "visual" ? value : "automatic"
    }
    readonly property int configuredPunchiMenuPerformanceThreshold: {
        const value = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.performanceThreshold : 120)
        return Number.isFinite(value) && value > 0
            ? Math.max(40, Math.min(400, Math.round(value))) : 120
    }
    readonly property string configuredPunchiMenuHoverAnimation:
        ConfigItemsJS.normalizedPunchiMenuHoverAnimation(
            configuredPunchiMenuItem
                ? configuredPunchiMenuItem.hoverAnimation : "pulse")
    readonly property bool configuredPunchiMenuSortApplicationsAlphabetically:
        !!configuredPunchiMenuItem
        && configuredPunchiMenuItem.sortApplicationsAlphabetically === true
    readonly property string configuredPunchiMenuFullScreenApplicationOrder:
        ConfigItemsJS.normalizedPunchiMenuFullScreenApplicationOrder(
            configuredPunchiMenuItem
                ? configuredPunchiMenuItem.fullScreenApplicationOrder : "",
            configuredPunchiMenuSortApplicationsAlphabetically)
    readonly property string configuredPunchiMenuFullScreenCloseButtonPosition:
        configuredPunchiMenuItem
            && configuredPunchiMenuItem.fullScreenCloseButtonPosition === "left"
        ? "left"
        : "right"
    readonly property bool configuredPunchiMenuFullScreenBlurEnabled:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.fullScreenBlurEnabled !== false
    readonly property real configuredPunchiMenuFullScreenBackgroundOpacity: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.fullScreenBackgroundOpacityPercent
            : 50)
        const safePercent = Number.isFinite(requestedPercent)
            ? Math.max(50, Math.min(100, Math.round(requestedPercent / 5) * 5))
            : 50
        return safePercent / 100
    }
    readonly property bool configuredPunchiMenuNormalBlurEnabled:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.normalBlurEnabled !== false
    readonly property real configuredPunchiMenuNormalBackgroundOpacity: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalBackgroundOpacityPercent
            : 75)
        const safePercent = Number.isFinite(requestedPercent)
            ? Math.max(50, Math.min(100, Math.round(requestedPercent / 5) * 5))
            : 75
        return safePercent / 100
    }
    readonly property bool configuredPunchiMenuNormalFloatingLabelShorteningEnabled:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.normalFloatingLabelShorteningEnabled !== false
    readonly property int configuredPunchiMenuNormalFloatingLabelVisibleCharacters:
        ConfigItemsJS.normalizedPunchiMenuNormalFloatingLabelVisibleCharacters(
            configuredPunchiMenuItem
                ? configuredPunchiMenuItem.normalFloatingLabelVisibleCharacters
                : 10)
    readonly property bool configuredPunchiMenuNormalFloatingTextShadowsEnabled:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.normalFloatingTextShadowsEnabled !== false
    readonly property int configuredPunchiMenuNormalFloatingTextShadowPercent:
        ConfigItemsJS.normalizedPunchiMenuNormalFloatingTextShadowPercent(
            configuredPunchiMenuItem
                ? configuredPunchiMenuItem.normalFloatingTextShadowPercent
                : 25)
    readonly property var configuredPunchiMenuHiddenApplicationIds: {
        const source = configuredPunchiMenuItem
                && configuredPunchiMenuItem.hiddenApplicationIds instanceof Array
            ? configuredPunchiMenuItem.hiddenApplicationIds
            : []
        const result = []
        const seen = {}
        for (let index = 0; index < source.length && result.length < 512; index++) {
            const storageId = String(source[index] || "").trim()
            if (storageId.length === 0 || storageId.length > 512
                    || /[\u0000-\u001f\u007f]/.test(storageId)) {
                continue
            }
            const comparisonKey = "#" + storageId
            if (seen[comparisonKey] === true) {
                continue
            }
            seen[comparisonKey] = true
            result.push(storageId)
        }
        return result
    }
    readonly property bool configuredPunchiMenuCompactBlurEnabled:
        !configuredPunchiMenuItem
        || configuredPunchiMenuItem.compactBlurEnabled !== false
    readonly property real configuredPunchiMenuCompactBackgroundOpacity: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.compactBackgroundOpacityPercent
            : 85)
        const safePercent = Number.isFinite(requestedPercent)
            ? Math.max(50, Math.min(100, Math.round(requestedPercent / 5) * 5))
            : 85
        return safePercent / 100
    }
    readonly property bool configuredPunchiMenuCompactShowQuickLaunchers: {
        const item = configuredPunchiMenuItem
        if (item && item.compactShowQuickLaunchers !== undefined) {
            return item.compactShowQuickLaunchers !== false
        }
        return true
    }
    readonly property string configuredPunchiMenuMode: {
        const itemMode = configuredPunchiMenuItem
            ? String(configuredPunchiMenuItem.menuMode || "normal")
            : "normal"
        if (itemMode === "compact") {
            return "compact"
        }
        if (itemMode === "normal") {
            return "normal"
        }
        return "normal" // Migrate old full-screen profiles to the two supported modes.
    }
    readonly property string configuredPunchiMenuNormalPlacementMode:
        configuredPunchiMenuItem
            && String(configuredPunchiMenuItem.normalPlacementMode || "anchored")
                === "centered"
        ? "centered"
        : "anchored"
    readonly property int configuredPunchiMenuNormalWidthPercent: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalWidthPercent
            : 55)
        return Number.isFinite(requestedPercent)
            ? Math.max(35, Math.min(40, Math.round(requestedPercent)))
            : 40
    }
    readonly property int configuredPunchiMenuNormalHeightPercent: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalHeightPercent
            : 65)
        return Number.isFinite(requestedPercent)
            ? Math.max(40, Math.min(45, Math.round(requestedPercent)))
            : 45
    }
    readonly property int configuredPunchiMenuNormalPanelDistancePercent: {
        const requestedPercent = Number(configuredPunchiMenuItem
            ? configuredPunchiMenuItem.normalPanelDistancePercent
            : 25)
        return Number.isFinite(requestedPercent)
            ? Math.max(0, Math.min(100,
                Math.round(requestedPercent / 5) * 5))
            : 25
    }
    readonly property int configuredPunchiMenuNormalPanelGap: 5
    readonly property bool configuredPunchiMenuNormalShowCategories: {
        const item = configuredPunchiMenuItem
        if (item && item.normalShowCategories !== undefined) {
            return item.normalShowCategories !== false
        }
        return true
    }
    readonly property bool configuredPunchiMenuNormalCategoryGrouping: {
        const item = configuredPunchiMenuItem
        if (item && item.normalCategoryGrouping !== undefined) {
            return item.normalCategoryGrouping === true
        }
        return false
    }
    signal taskStructureChanged()

    // Visual indices omit playback-only media slots while hidden, without
    // mutating saved item IDs or disrupting user-configured item order.
    function hiddenMediaCountBefore(modelIndex) {
        const items = dockItemsController.dockItems || []
        let hidden = 0
        for (let i = 0; i < Math.min(modelIndex, items.length); ++i) {
            if (items[i] && items[i].type === "media"
                    && !dockGeometry.mediaItemVisibleForItem(items[i])) ++hidden
        }
        return hidden
    }

    function persistentVisualIndex(modelIndex) {
        const index = Number(modelIndex)
        const compactIndex = index - root.hiddenMediaCountBefore(index)
        if (root.dynamicApplicationsMarkerIndex < 0
                || index <= root.dynamicApplicationsMarkerIndex) {
            return compactIndex
        }
        return compactIndex + root.visibleTaskRows.length
            + root.visibleTrayEntries.length + root.renderedOverflowItemCount
    }

    function dynamicVisualIndex(taskIndex) {
        return root.dynamicApplicationsAnchorIndex
            - root.hiddenMediaCountBefore(root.dynamicApplicationsAnchorIndex)
            + (root.dynamicApplicationsMarkerIndex >= 0 ? 1 : 0)
            + Number(taskIndex)
    }

    function dynamicLauncherInsertionIndex() {
        return root.dynamicApplicationsMarkerIndex >= 0
            ? root.dynamicApplicationsMarkerIndex
            : dockItemsController.dockItems.length
    }

    readonly property var recentApplications: {
        const controller = recentApplicationsLoader.item as RecentApplicationsController
        return controller ? controller.items : []
    }
    property int recentApplicationCapacity: -1
    readonly property int visibleRecentApplicationCount: Math.min(root.recentApplications.length,
        root.recentApplicationCapacity < 0 ? dockConfig.recentApplicationsCount : root.recentApplicationCapacity)
    readonly property bool recentContainerVisible: dockConfig.recentApplicationsMode === "container"
        && root.visibleRecentApplicationCount > 0
    readonly property bool recentSeparatorVisible: root.visibleRecentApplicationCount > 0
        && dockGeometry.panelBaseCompactContentLength > 0
    readonly property var recentContainerDescriptor: ({
        "type": "folder", "entryRole": "recent-container", "key": "recent-container",
        "name": i18nc("@title", "Recent applications"), // qmllint disable unqualified
        "icon": "folder-temp", "layout": dockConfig.recentApplicationsContainerLayout,
        "apps": root.recentApplications
    })
    readonly property var recentPresentationItems: {
        if (root.visibleRecentApplicationCount === 0) { return [] }
        const result = root.recentSeparatorVisible ? [{ "type": "separator" }] : []
        return result.concat(root.recentContainerVisible
            ? [root.recentContainerDescriptor]
            : root.recentApplications.slice(0, root.visibleRecentApplicationCount))
    }
    function recentVisualIndex(offset) {
        return dockItemsController.dockItems.length
            - root.hiddenMediaCountBefore(dockItemsController.dockItems.length)
            + root.visibleTaskRows.length
            + root.visibleTrayEntries.length
            + root.renderedOverflowItemCount + offset
    }

    function dockItemReorderIconName(item) {
        const itemData = item || ({})
        const configuredIcon = String(itemData.icon || "")
        if (configuredIcon.length > 0) {
            return configuredIcon
        }
        const type = String(itemData.type || "")
        if (type === "dynamic-applications") {
            return "window-duplicate"
        }
        if (type === "separator") {
            return "draw-line"
        }
        if (type === "spacer") {
            return "distribute-horizontal-x"
        }
        if (type === "calendar") {
            return "view-calendar-day"
        }
        if (type === "note") {
            return "knotes"
        }
        if (type === "folder") {
            return "folder"
        }
        if (type === "trash") {
            return "user-trash"
        }
        if (type === "punchimenu") {
            return "start-here-kde"
        }
        if (type === "control-center") {
            return "preferences-system"
        }
        return "application-x-executable"
    }

    // Virtual desktop visibility.
    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }
    Punchi.SystemDiscovery {
        id: systemDiscovery
        // R62.7: scan XDG autostart only for the running dock, never for
        // short-lived configuration/catalog instances.
        autostartMonitoringEnabled: true
        onApplicationCatalogReady: function(applications) {
            const storageIds = []
            const catalog = []
            const seenStorageIds = {}
            const source = applications || []
            for (let index = 0; index < source.length && index < 1024; index++) {
                const application = source[index]
                const storageId = String(application
                    ? application.storageId || ""
                    : "")
                if (storageId.length > 0
                        && !seenStorageIds["#" + storageId]) {
                    seenStorageIds["#" + storageId] = true
                    storageIds.push(storageId)
                    catalog.push({
                        storageId: storageId,
                        name: String(application.name || storageId),
                        icon: String(application.icon
                            || "application-x-executable"),
                        categories: application.categories || []
                    })
                }
            }
            root.punchiMenuApplicationCatalog = catalog
            root.punchiMenuApplicationCatalogLoaded = true
            punchiMenuLayoutController.applicationStorageIds = storageIds
        }
        onOperationFailed: function(operation, message) {
            console.warn("Oger Dock:", operation, message)
        }
    }
    ControlCenterController {
        id: controlCenterController
        applicationLauncher: systemDiscovery
    }
    Punchi.ControlCenterThemeAdapter {
        id: controlCenterThemeAdapter
    }
    Punchi.ControlCenterNightLightAdapter {
        id: controlCenterNightLightAdapter
    }
    Punchi.ControlCenterVolumeOsdAdapter {
        id: controlCenterVolumeOsdAdapter
    }
    readonly property var systemDiscoveryService: systemDiscovery
    readonly property var punchiMenuLayoutControllerService: punchiMenuLayoutController
    property var punchiMenuApplicationCatalog: []
    property bool punchiMenuApplicationCatalogLoaded: false
    Punchi.DockRuntimeService {
        id: runtimeService
        onOperationFailed: function(operation, message) {
            console.warn("Oger Dock:", operation, message)
        }
    }
    Punchi.DockItemsPersistenceAdapter {
        id: dockItemsPersistenceAdapter
        applet: root.plasmoid
    }
    Punchi.PunchiMenuLayoutController {
        id: punchiMenuLayoutController

        onPersistenceRequested: function(transactionId, document, operation, subjectId) {
            const result = dockItemsController.commitPunchiMenuApplicationLayout(
                punchiMenuLayoutController.layoutDocument, document)
            if (result && result.success) {
                punchiMenuLayoutController.confirmPersistence(transactionId)
            } else {
                const errorCode = result
                    ? String(result.errorCode || "persist-failed")
                    : "persist-failed"
                punchiMenuLayoutController.rejectPersistence(
                    transactionId, errorCode)
                if (result && (errorCode === "conflict"
                        || errorCode === "layout-conflict"
                        || errorCode === "persistence-failed")) {
                    const reconciliation
                        = dockItemsPersistenceAdapter.reconcileDockItemsJson(
                            String(result.currentJson || ""))
                    if (!reconciliation || !reconciliation.success) {
                        console.warn(
                            "Oger Dock: Unable to reconcile dock item configuration after a persistence conflict.")
                    }
                }
            }
        }
    }
    Punchi.MprisController {
        id: mprisController
    }
    Punchi.MprisController {
        id: dockMediaController
        selectionMode: root.configuredMediaApplicationId.length > 0
            ? "application"
            : "activePlayer"
        applicationId: root.configuredMediaApplicationId
    }
    Punchi.ThemeIntegration {
        id: themeIntegration
    }
    Punchi.DockThemeRepository {
        id: dockThemeRepository
        themeId: String(Plasmoid.configuration.dockThemeCustomId || "")
        customThemeDirectoryEnabled: !!Plasmoid.configuration.dockCustomThemeDirectoryEnabled
        customThemeDirectory: String(Plasmoid.configuration.dockCustomThemeDirectory || "")
    }
    DockConfigurationState {
        id: dockConfig
        inPanel: root.inPanel
        horizontalPanel: dockGeometry.horizontalPanel
        effectiveIconSize: dockGeometry.effectiveIconSize
        themeRepositoryValid: dockThemeRepository.valid
        theme: dockThemeRepository.theme
    }
    DockGeometryState {
        id: dockGeometry
        inPanel: root.inPanel
        hiddenByVirtualDesktop: root.hiddenByVirtualDesktop
        verticalPanel: root.inPanel ? Plasmoid.formFactor === PlasmaCore.Types.Vertical : root.floatingVertical
        horizontalPanel: root.inPanel ? Plasmoid.formFactor === PlasmaCore.Types.Horizontal : !root.floatingVertical
        panelLocation: root.inPanel ? Plasmoid.location
            : (root.floatingDockPlacement === "left" ? PlasmaCore.Types.LeftEdge
                : (root.floatingDockPlacement === "right" ? PlasmaCore.Types.RightEdge
                : PlasmaCore.Types.BottomEdge))
        configuredFloatingEdge: root.floatingDockPlacement === "left"
            ? PlasmaCore.Types.LeftEdge
            : (root.floatingDockPlacement === "right"
                ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.BottomEdge)
        configuredIconSize: Number(Plasmoid.configuration.iconSize || 42)
        configuredPanelThickness: root.configuredPanelThickness
        unlockPanelIconSizeLimit: !!Plasmoid.configuration.unlockPanelIconSizeLimit
        panelAlwaysVisible: root.panelAlwaysVisible
        configuredIconSpacing: {
            const spacing = Number(Plasmoid.configuration.iconSpacing)
            return Number.isFinite(spacing) ? spacing : 8
        }
        configuredPanelLengthMode: {
            if (root.configuredPanelLengthMode !== "system") {
                return root.configuredPanelLengthMode
            }
            if (dockGeometry.detectedPanelLengthMode === 0) {
                return "fill"
            }
            return "content"
        }
        configuredPanelAlignmentMode: {
            if (root.configuredPanelAlignmentMode !== "system") {
                return root.configuredPanelAlignmentMode
            }
            if (dockGeometry.detectedPanelAlignment === 1) {
                return "center"
            }
            if (dockGeometry.detectedPanelAlignment === 2) {
                return "end"
            }
            return "start"
        }
        panelHoverScale: dockConfig.panelHoverScale
        folderPopupDistancePercent: dockConfig.folderPopupDistancePercent
        contextMenuDistancePercent: dockConfig.contextMenuDistancePercent
        dockShowLabels: dockConfig.dockShowLabels
        dockLabelAreaHeight: dockConfig.dockLabelAreaHeight
        dockItems: dockItemsController.dockItems
        mediaInlineTitleExtents: root.mediaInlineTitleExtents
        mediaItemExpanded: root.mediaItemExpanded
        mediaPlayerAvailable: dockMediaController.available || root.mediaPlaybackConfirmed
        mediaPlayerPlaying: root.mediaPlaybackConfirmed
        mediaSoundConfirmed: root.mediaSoundConfirmed
        supplementalDockItems: root.recentPresentationItems
        visibleTaskCount: root.visibleTaskRows.length + root.visibleTrayEntries.length
        overflowTaskCount: root.overflowTaskRows.length
        totalDynamicGroups: taskController.totalDynamicGroups
        dynamicApplicationsMoveModeActive:
            root.dynamicApplicationsMoveModeActive
        customSeparatorEnabled: dockConfig.customDockSeparatorActive
        separatorTheme: dockConfig.customDockSeparatorTheme
        customThemeSurfaceRadius: dockConfig.customThemeSurfaceRadius
        customThemeActive: dockConfig.customDockThemeActive
        availableScreenRect: root.availableScreenRect
        floatingAnchor: root.floatingDockAnchor
        hostHeight: root.height
        // PanelView and containment expose these properties at runtime.
        // qmllint disable missing-property
        panelWindow: root.Window.window
        containment: Plasmoid.containment
        // qmllint enable missing-property
    }
    Punchi.PanelLengthModeBridge {
        containmentId: Plasmoid.containment ? Plasmoid.containment.id : 0
        reportedPanelLengthMode: dockGeometry.detectedPanelLengthMode
        reportedPanelFloatingMode: dockGeometry.detectedPanelFloatingMode
        reportedPanelVisibilityMode: dockGeometry.detectedPanelVisibilityMode
        reportedPanelAlignment: dockGeometry.detectedPanelAlignment
        reportedPanelThickness: dockGeometry.detectedPanelThickness
        reportedPanelOpacityMode: dockGeometry.detectedPanelOpacityMode
    }
    Punchi.PanelInputRegionSynchronizer {
        panelWindow: root.inPanel ? root.Window.window : null
        enabled: root.inPanel
        verticalPanel: dockGeometry.verticalPanel
    }
    Punchi.PanelRevealAdapter {
        objectName: "panelRevealAdapter"
        applet: Plasmoid
        // PanelView exposes visibilityMode on the hosting window at runtime.
        // qmllint disable missing-property
        panelWindow: root.inPanel ? root.Window.window : null
        requested: Plasmoid.userConfiguring
        // qmllint enable missing-property
    }
    readonly property string configuredPanelOpacityMode: String(Plasmoid.configuration.panelOpacityMode || "system")
    onConfiguredPanelOpacityModeChanged: applyConfiguredPanelOpacityMode()
    readonly property bool customDockThemeActiveForPanel: root.inPanel && dockConfig.customDockThemeActive
    onCustomDockThemeActiveForPanelChanged: applyConfiguredPanelOpacityMode()
    readonly property bool audioSpectrumReplacesPanelBackground: root.inPanel
        && dockConfig.audioSpectrumConfigured
        && dockConfig.audioSpectrumBackgroundMode === "spectrumOnly"
    onAudioSpectrumReplacesPanelBackgroundChanged: applyConfiguredPanelOpacityMode()

    // Shell window and containment expose backgroundHints and opacityMode at runtime.
    // qmllint disable missing-property
    function applyConfiguredPanelOpacityMode() {
        if (!root.inPanel) {
            return
        }
        const mode = root.configuredPanelOpacityMode
        const forceNoBackground = mode === "none" || dockConfig.customDockThemeActive
            || root.audioSpectrumReplacesPanelBackground
        const hints = forceNoBackground ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.StandardBackground

        try {
            if (root.Window.window && typeof root.Window.window["backgroundHints"] !== "undefined") {
                root.Window.window["backgroundHints"] = hints
            }
        } catch (error) {
            // Guard against read-only window properties
        }
        try {
            var containment = Plasmoid.containment
            if (containment) {
                if (typeof containment["backgroundHints"] !== "undefined") {
                    containment["backgroundHints"] = hints
                }
                var containmentPlasmoid = containment["plasmoid"]
                if (containmentPlasmoid && typeof containmentPlasmoid["backgroundHints"] !== "undefined") {
                    containmentPlasmoid["backgroundHints"] = hints
                }
            }
        } catch (error) {
            // Guard against variations in Plasma containment APIs
        }

        if (!root.Window.window || mode === "system" || mode === "none"
                || dockConfig.customDockThemeActive
                || root.audioSpectrumReplacesPanelBackground) {
            return
        }
        try {
            if (mode === "adaptive") {
                root.Window.window.opacityMode = 0
            } else if (mode === "opaque") {
                root.Window.window.opacityMode = 1
            } else if (mode === "translucent") {
                root.Window.window.opacityMode = 2
            }
        } catch (error) {
            // Guard against custom shells
        }
    }
    // qmllint enable missing-property
    readonly property int configuredPanelThickness: Number(Plasmoid.configuration.panelThickness || 0)
    onConfiguredPanelThicknessChanged: applyConfiguredPanelThickness()

    function applyConfiguredPanelThickness() {
        if (!root.inPanel || !root.Window.window) {
            return
        }
        const autoThickness = dockGeometry.verticalPanel
            ? dockGeometry.panelPreferredWidth
            : dockGeometry.panelPreferredHeight
        const thickness = root.configuredPanelThickness > 0
            ? root.configuredPanelThickness
            : autoThickness
        if (thickness <= 0) {
            return
        }
        try {
            root.Window.window.thickness = thickness
        } catch (error) {
            // Guard against custom shells
        }
    }
    Connections {
        target: dockGeometry
        function onPanelPreferredHeightChanged() {
            if (!dockGeometry.verticalPanel) {
                root.applyConfiguredPanelThickness()
            }
        }
        function onPanelPreferredWidthChanged() {
            if (dockGeometry.verticalPanel) {
                root.applyConfiguredPanelThickness()
            }
        }
    }
    readonly property string configuredPanelLengthMode: String(Plasmoid.configuration.panelLengthMode || "system")
    onConfiguredPanelLengthModeChanged: applyConfiguredPanelLengthMode()

    function applyConfiguredPanelLengthMode() {
        if (!root.inPanel || !root.Window.window) {
            return
        }
        const mode = root.configuredPanelLengthMode
        if (mode === "system") {
            return
        }
        try {
            if (mode === "fill" || mode === "fillAvailable") {
                root.Window.window.lengthMode = 0
            } else if (mode === "content" || mode === "fitContent") {
                root.Window.window.lengthMode = 1
            } else if (mode === "custom") {
                root.Window.window.lengthMode = 2
            }
        } catch (error) {
            // Guard against custom shells
        }
    }

    readonly property string configuredPanelAlignmentMode: String(Plasmoid.configuration.panelAlignmentMode || "system")
    onConfiguredPanelAlignmentModeChanged: applyConfiguredPanelAlignmentMode()

    function applyConfiguredPanelAlignmentMode() {
        if (!root.inPanel || !root.Window.window) {
            return
        }
        const mode = root.configuredPanelAlignmentMode
        if (mode === "system") {
            return
        }
        try {
            if (mode === "start") {
                root.Window.window.alignment = Qt.AlignLeft
            } else if (mode === "center") {
                root.Window.window.alignment = Qt.AlignCenter
            } else if (mode === "end") {
                root.Window.window.alignment = Qt.AlignRight
            }
        } catch (error) {
            // Guard against custom shells
        }
    }
    readonly property string configuredPanelFloatingMode: String(Plasmoid.configuration.panelFloatingMode || "system")
    onConfiguredPanelFloatingModeChanged: applyConfiguredPanelFloatingMode()

    function applyConfiguredPanelFloatingMode() {
        if (!root.inPanel || !root.Window.window) {
            return
        }
        const mode = root.configuredPanelFloatingMode
        if (mode === "system") {
            return
        }
        try {
            if (mode === "disabled") {
                root.Window.window.floating = false
                root.Window.window.floatingApplets = false
            } else if (mode === "appletsOnly") {
                root.Window.window.floating = false
                root.Window.window.floatingApplets = true
            } else if (mode === "panelAndApplets") {
                root.Window.window.floating = true
            }
        } catch (error) {
            // Guard against custom shells
        }
    }
    readonly property string configuredPanelVisibilityMode: String(Plasmoid.configuration.panelVisibilityMode || "system")
    readonly property bool panelAlwaysVisible: {
        if (!root.inPanel) {
            return false
        }
        if (root.configuredPanelVisibilityMode === "alwaysVisible") {
            return true
        }
        if (root.configuredPanelVisibilityMode === "system") {
            return dockGeometry.detectedPanelVisibilityMode === 0
        }
        return false
    }
    onConfiguredPanelVisibilityModeChanged: applyConfiguredPanelVisibilityMode()

    function applyConfiguredPanelVisibilityMode() {
        if (!root.inPanel || !root.Window.window) {
            return
        }
        const mode = root.configuredPanelVisibilityMode
        if (mode === "system") {
            return
        }
        try {
            if (mode === "alwaysVisible") {
                root.Window.window.visibilityMode = 0
            } else if (mode === "autoHide") {
                root.Window.window.visibilityMode = 1
            } else if (mode === "dodgeWindows") {
                root.Window.window.visibilityMode = 2
            } else if (mode === "windowsGoBelow") {
                root.Window.window.visibilityMode = 3
            }
        } catch (error) {
            // Guard against custom shells
        }
    }
    Punchi.TaskGeometryOwnershipBridge {
        id: taskGeometryOwnership
        instanceId: Plasmoid.id
        panel: root.inPanel
        eligible: !root.hiddenByVirtualDesktop
    }
    Punchi.PunchiMenuShortcutController {
        id: punchiMenuShortcutController
        instanceId: Plasmoid.id
        configuredShortcut: String(Plasmoid.configuration.punchiMenuShortcut || "")
        enabled: Boolean(root.configuredPunchiMenuItem)
        onActivated: {
            if (root.configuredPunchiMenuItem) {
                root.togglePunchiMenu()
            }
        }
        onShortcutRegistrationFailed: function(requestedShortcut) {
            console.warn("Oger Dock: OgerMenu shortcut registration failed:",
                requestedShortcut)
        }
    }
    Punchi.AudioSpectrumController {
        id: audioSpectrumController
        enabled: (dockConfig.audioSpectrumConfigured || root.needsMediaAudioDetection)
            && !root.hiddenByVirtualDesktop
    }

    property var punchiMenuDialogInstance: null
    property var punchiMenuAnchorItem: null

    function togglePunchiMenu(anchorItem) {
        if (controlCenterDialogInstance
                && controlCenterDialogInstance.visible) {
            controlCenterDialogInstance.closeImmediately()
        }
        if (anchorItem && typeof anchorItem.mapToGlobal === "function") {
            root.punchiMenuAnchorItem = anchorItem
        }
        const requestedMode = root.configuredPunchiMenuMode
        if (punchiMenuDialogInstance
                && punchiMenuDialogInstance.menuMode !== requestedMode) {
            punchiMenuDialogInstance.closeImmediately()
            punchiMenuDialogInstance.destroy()
            punchiMenuDialogInstance = null
        }

        if ((requestedMode === "normal" || requestedMode === "compact") && anchorItem
                && punchiMenuDialogInstance
                && typeof punchiMenuDialogInstance.consumeRecentExternalHide
                    === "function"
                && punchiMenuDialogInstance.consumeRecentExternalHide()) {
            return
        }

        if (!punchiMenuDialogInstance) {
            const component = requestedMode === "normal"
                ? punchiMenuNormalDialogComponent
                : (requestedMode === "compact"
                    ? punchiMenuCompactDialogComponent
                    : punchiMenuFullscreenDialogComponent)
            punchiMenuDialogInstance = component.createObject(root)
            if (!punchiMenuDialogInstance) {
                return
            }
        }

        if (requestedMode === "fullScreen"
                && punchiMenuDialogInstance.openedFromPanel !== undefined) {
            punchiMenuDialogInstance.openedFromPanel = root.inPanel
        }

        if (punchiMenuDialogInstance.visible) {
            if (typeof punchiMenuDialogInstance.closeWithFade === "function") {
                punchiMenuDialogInstance.closeWithFade()
            } else {
                punchiMenuDialogInstance.closeImmediately()
            }
        } else {
            punchiMenuDialogInstance.openWithReveal()
        }
    }

    property var controlCenterDialogInstance: null
    property var controlCenterAnchorItem: null

    function toggleControlCenter(anchorItem) {
        if (punchiMenuDialogInstance && punchiMenuDialogInstance.visible) {
            punchiMenuDialogInstance.closeImmediately()
        }
        if (anchorItem && typeof anchorItem.mapToGlobal === "function") {
            root.controlCenterAnchorItem = anchorItem
        }
        const requestedMode = root.configuredControlCenterMode
        if (controlCenterDialogInstance
                && controlCenterDialogInstance.controlCenterMode
                    !== requestedMode) {
            controlCenterDialogInstance.closeImmediately()
            controlCenterDialogInstance.destroy()
            controlCenterDialogInstance = null
        }
        if (requestedMode === "floating" && anchorItem
                && controlCenterDialogInstance
                && typeof controlCenterDialogInstance.consumeRecentExternalHide
                    === "function"
                && controlCenterDialogInstance.consumeRecentExternalHide()) {
            return
        }
        if (!controlCenterDialogInstance) {
            const component = requestedMode === "floating"
                ? controlCenterFloatingDialogComponent
                : controlCenterFullscreenDialogComponent
            controlCenterDialogInstance = component.createObject(root)
            if (!controlCenterDialogInstance) {
                return
            }
        }

        if (controlCenterDialogInstance.openedFromPanel !== undefined) {
            controlCenterDialogInstance.openedFromPanel = root.inPanel
        }
        if (controlCenterDialogInstance.visible) {
            controlCenterDialogInstance.closeWithFade()
        } else {
            controlCenterDialogInstance.openWithReveal()
        }
    }

    Component {
        id: controlCenterFullscreenDialogComponent

        PlasmaCore.Dialog {
            id: controlCenterDialog

            readonly property string controlCenterMode: "fullScreen"
            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property bool openedFromPanel: false

            objectName: "controlCenterFullscreenDialog"
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.Normal
            flags: openedFromPanel
                ? Qt.Window | Qt.FramelessWindowHint
                : isX11Session
                    ? Qt.Window | Qt.FramelessWindowHint
                        | Qt.WindowStaysOnTopHint
                    : Qt.Window | Qt.FramelessWindowHint
                        | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            x: 0
            y: 0
            width: Screen.width
            height: Screen.height
            hideOnWindowDeactivate: true
            visible: false
            opacity: 0

            function openWithReveal() {
                opacity = 1
                visible = true
                requestActivate()
                controlCenterOverlay.openOverlay()
                if (KWindowSystem.isPlatformX11) {
                    Qt.callLater(function() {
                        if (controlCenterDialog.visible) {
                            controlCenterDialog.requestActivate()
                            controlCenterOverlay.forceActiveFocus()
                        }
                    })
                }
            }

            function closeWithFade() {
                controlCenterOverlay.forceClose()
            }

            function closeImmediately() {
                controlCenterOverlay.resetOverlay()
                opacity = 0
                visible = false
            }

            onVisibleChanged: {
                if (!visible) {
                    controlCenterOverlay.resetOverlay()
                    opacity = 0
                }
            }

            mainItem: ControlCenterOverlay {
                id: controlCenterOverlay
                width: Screen.width
                height: Screen.height
                controller: controlCenterController
                themeAdapter: controlCenterThemeAdapter
                nightLightAdapter: controlCenterNightLightAdapter
                volumeOsdAdapter: controlCenterVolumeOsdAdapter
                presentationMode: controlCenterDialog.controlCenterMode
                viewportWidth: Screen.width
                viewportHeight: Screen.height
                onCloseFinished: controlCenterDialog.closeImmediately()
            }
        }
    }

    Component {
        id: controlCenterFloatingDialogComponent

        PlasmaCore.Dialog {
            id: controlCenterFloatingDialog

            readonly property string controlCenterMode: "floating"
            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property bool openedFromPanel: false
            property bool internalCloseRequested: false
            property double lastExternalHideTimestamp: -1
            readonly property rect activeScreenGeometry:
                Plasmoid.containment
                    && Plasmoid.containment.screenGeometry
                    ? Plasmoid.containment.screenGeometry
                    : Qt.rect(0, 0, Screen.width, Screen.height)
            readonly property ControlCenterFloatingGeometry floatingGeometry:
                ControlCenterFloatingGeometry {
                    screenGeometry:
                        controlCenterFloatingDialog.activeScreenGeometry
                    availableScreenRect: root.availableScreenRect
                    gridUnit: Kirigami.Units.gridUnit
                }
            readonly property int desiredContentWidth:
                floatingGeometry.contentWidth
            readonly property int desiredContentHeight:
                floatingGeometry.contentHeight

            objectName: "controlCenterFloatingDialog"
            visualParent: null
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.PopupMenu
            flags: isX11Session
                ? Qt.Popup | Qt.FramelessWindowHint
                : Qt.Dialog | Qt.FramelessWindowHint
                    | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true
            visible: false
            opacity: 0

            readonly property Punchi.BlurBehindController floatingBlurController:
                Punchi.BlurBehindController {
                    window: controlCenterFloatingDialog
                    fullWindow: false
                    maskSource: controlCenterFloatingOverlay.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: controlCenterFloatingOverlay.backgroundBlurMaskOffset
                    enabled: controlCenterFloatingDialog.visible
                        && controlCenterFloatingOverlay.controlCenterOpen
                }

            function themeFrameMargin(side) {
                const nativeMargins = margins
                const requestedMargin = nativeMargins
                    ? Number(nativeMargins[side]) : 0
                return Number.isFinite(requestedMargin)
                    ? Math.max(0, requestedMargin) : 0
            }

            function positionAtTopRight() {
                const targetPosition = floatingGeometry.positionFor(
                    width, height)
                x = targetPosition.x
                y = targetPosition.y
            }

            function scheduleReposition() {
                if (visible) {
                    Qt.callLater(positionAtTopRight)
                }
            }

            onWidthChanged: scheduleReposition()
            onHeightChanged: scheduleReposition()
            onActiveScreenGeometryChanged: scheduleReposition()
            onDesiredContentWidthChanged: scheduleReposition()
            onDesiredContentHeightChanged: scheduleReposition()

            readonly property Connections geometryConnections: Connections {
                target: root

                function onAvailableScreenRectChanged() {
                    controlCenterFloatingDialog.scheduleReposition()
                }
            }

            function consumeRecentExternalHide() {
                const hideTimestamp = lastExternalHideTimestamp
                lastExternalHideTimestamp = -1
                if (hideTimestamp < 0) {
                    return false
                }
                const elapsed = Date.now() - hideTimestamp
                // QtStyleHints exposes this property at runtime, but qmllint
                // resolves Qt.styleHints as a generic QObject.
                // qmllint disable missing-property
                const guardInterval = Math.max(1,
                    Qt.styleHints.mouseDoubleClickInterval)
                // qmllint enable missing-property
                return elapsed >= 0 && elapsed <= guardInterval
            }

            function finishOpening() {
                if (!visible) {
                    return
                }
                positionAtTopRight()
                requestActivate()
                controlCenterFloatingOverlay.openOverlay()
                Qt.callLater(function() {
                    if (controlCenterFloatingDialog.visible) {
                        controlCenterFloatingDialog.floatingBlurController.reapply()
                        controlCenterFloatingDialog.requestActivate()
                    }
                })
            }

            function openWithReveal() {
                internalCloseRequested = false
                lastExternalHideTimestamp = -1
                positionAtTopRight()
                opacity = 1
                visible = true
                Qt.callLater(finishOpening)
            }

            function closeWithFade() {
                if (!visible) {
                    return
                }
                internalCloseRequested = true
                controlCenterFloatingOverlay.forceClose()
            }

            function closeImmediately() {
                internalCloseRequested = true
                lastExternalHideTimestamp = -1
                controlCenterFloatingOverlay.resetOverlay()
                opacity = 0
                visible = false
                Qt.callLater(function() {
                    controlCenterFloatingDialog.internalCloseRequested = false
                })
            }

            onVisibleChanged: {
                if (!visible) {
                    if (!internalCloseRequested) {
                        lastExternalHideTimestamp = Date.now()
                    }
                    controlCenterFloatingOverlay.resetOverlay()
                    opacity = 0
                }
            }

            mainItem: ControlCenterOverlay {
                id: controlCenterFloatingOverlay

                width: controlCenterFloatingDialog.desiredContentWidth
                height: controlCenterFloatingDialog.desiredContentHeight
                Layout.minimumWidth:
                    controlCenterFloatingDialog.desiredContentWidth
                Layout.preferredWidth:
                    controlCenterFloatingDialog.desiredContentWidth
                Layout.maximumWidth:
                    controlCenterFloatingDialog.desiredContentWidth
                Layout.minimumHeight:
                    controlCenterFloatingDialog.desiredContentHeight
                Layout.preferredHeight:
                    controlCenterFloatingDialog.desiredContentHeight
                Layout.maximumHeight:
                    controlCenterFloatingDialog.desiredContentHeight
                controller: controlCenterController
                themeAdapter: controlCenterThemeAdapter
                nightLightAdapter: controlCenterNightLightAdapter
                volumeOsdAdapter: controlCenterVolumeOsdAdapter
                presentationMode: controlCenterFloatingDialog.controlCenterMode
                viewportWidth:
                    controlCenterFloatingDialog.floatingGeometry.referenceWidth
                viewportHeight:
                    controlCenterFloatingDialog.floatingGeometry.referenceHeight
                themeFrameLeftMargin:
                    controlCenterFloatingDialog.themeFrameMargin("left")
                themeFrameTopMargin:
                    controlCenterFloatingDialog.themeFrameMargin("top")
                themeFrameRightMargin:
                    controlCenterFloatingDialog.themeFrameMargin("right")
                themeFrameBottomMargin:
                    controlCenterFloatingDialog.themeFrameMargin("bottom")
                onCloseFinished:
                    controlCenterFloatingDialog.closeImmediately()
            }
        }
    }

    Component {
        id: punchiMenuFullscreenDialogComponent

        PlasmaCore.Dialog {
            id: punchiMenuDialog
            readonly property string menuMode: "fullScreen"
            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property bool openedFromPanel: false
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.Normal
            flags: openedFromPanel
                ? Qt.Window | Qt.FramelessWindowHint
                : isX11Session
                    ? Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
                    : Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            x: 0
            y: 0
            width: Screen.width
            height: Screen.height
            hideOnWindowDeactivate: true
            visible: false
            opacity: 0

            function openWithReveal() {
                opacity = 1
                visible = true
                requestActivate()
                punchiMenuOverlay.openOverlay()
                if (KWindowSystem.isPlatformX11) {
                    Qt.callLater(function() {
                        if (punchiMenuDialog.visible) {
                            punchiMenuDialog.requestActivate()
                            punchiMenuOverlay.forceActiveFocus()
                        }
                    })
                }
            }

            function closeImmediately() {
                punchiMenuOverlay.resetOverlay()
                opacity = 0
                visible = false
            }

            onVisibleChanged: {
                if (!visible) {
                    punchiMenuOverlay.resetOverlay()
                    opacity = 0
                }
            }

            mainItem: PunchiMenuOverlay {
                id: punchiMenuOverlay
                width: Screen.width
                height: Screen.height
                systemDiscovery: root.systemDiscoveryService
                applicationCatalog: root.punchiMenuApplicationCatalog
                // qmllint disable unqualified
                applicationCatalogLoaded:
                    root.punchiMenuApplicationCatalogLoaded
                // qmllint enable unqualified
                applicationLayoutController:
                    root.punchiMenuLayoutControllerService
                // qmllint disable unqualified
                dockItemsController: root.dockItemsControllerService
                favorites: punchiMenuFavoritesController.favorites
                applicationIconScale: root.configuredPunchiMenuGridIconScale
                favoriteIconScale: root.configuredPunchiMenuFavoriteIconScale
                folderMaximumColumns:
                    root.configuredPunchiMenuFullScreenFolderMaximumColumns
                folderMaximumRows:
                    root.configuredPunchiMenuFullScreenFolderMaximumRows
                showDistributionName: root.configuredPunchiMenuShowDistributionName
                showPageNavigationArrows:
                    root.configuredPunchiMenuShowPageNavigationArrows
                showApplicationLabels:
                    root.configuredPunchiMenuShowApplicationLabels
                hoverAnimation: root.configuredPunchiMenuHoverAnimation
                performanceMode: root.configuredPunchiMenuPerformanceMode
                performanceThreshold: root.configuredPunchiMenuPerformanceThreshold
                applicationOrderMode:
                    root.configuredPunchiMenuFullScreenApplicationOrder
                closeButtonPosition:
                    root.configuredPunchiMenuFullScreenCloseButtonPosition
                backgroundBlurEnabled: root.configuredPunchiMenuFullScreenBlurEnabled
                backgroundOpacity: root.configuredPunchiMenuFullScreenBackgroundOpacity
                hiddenApplicationIds: root.configuredPunchiMenuHiddenApplicationIds
                onAddFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.addFavorite(storageId)
                }
                onRemoveFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.removeFavorite(storageId)
                }
                onPinToDockRequested: function(storageId, appName, appIcon, appCommand) {
                    punchiMenuOverlay.showOperationResult(
                        root.dockItemsControllerService.togglePinAppToDock(
                            storageId, appName, appIcon, appCommand))
                }
                onAddToDesktopRequested: function(storageId, appCommand) {
                    punchiMenuOverlay.showOperationResult(
                        root.dockItemsControllerService.pinAppToDesktop(storageId, appCommand))
                }
                onSetApplicationHiddenRequested: function(storageId, hidden) {
                    if (!root.dockItemsControllerService.setPunchiMenuApplicationHidden(
                            storageId, hidden)) {
                        punchiMenuOverlay.showOperationResult(
                            root.dockItemsControllerService.operationResult(
                            false, "persist-failed", ""))
                    }
                }
                onSettingChangeRequested: function(fieldName, value) {
                    if (!root.dockItemsControllerService.setPunchiMenuValue(
                            fieldName, value)) {
                        punchiMenuOverlay.showSettingsPersistenceError()
                    }
                }
                onConfigureRequested: {
                    const itemIndex = root.configuredPunchiMenuItemIndex
                    punchiMenuDialog.closeImmediately()
                    Qt.callLater(function() {
                        root.openDockItemEditor(itemIndex)
                    })
                }
                onCloseFinished: punchiMenuDialog.closeImmediately()
                // qmllint enable unqualified
            }
        }
    }

    Component {
        id: punchiMenuNormalDialogComponent

        PlasmaCore.Dialog {
            id: punchiMenuNormalDialog

            readonly property string menuMode: "normal"
            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property double lastExternalHideTimestamp: -1
            property bool internalCloseRequested: false
            readonly property int screenMargin: Kirigami.Units.gridUnit * 2
            readonly property int minimumContentWidth:
                Kirigami.Units.gridUnit * 22
            readonly property int minimumContentHeight:
                Kirigami.Units.gridUnit * 16
            readonly property real activeScreenWidth: {
                const containment = Plasmoid.containment
                const geometry = containment
                    ? containment.screenGeometry : null
                const geometryWidth = Number(geometry ? geometry.width : 0)
                return Number.isFinite(geometryWidth) && geometryWidth > 1
                    ? geometryWidth : Number(Screen.width || 0)
            }
            readonly property real activeScreenHeight: {
                const containment = Plasmoid.containment
                const geometry = containment
                    ? containment.screenGeometry : null
                const geometryHeight = Number(geometry ? geometry.height : 0)
                return Number.isFinite(geometryHeight) && geometryHeight > 1
                    ? geometryHeight : Number(Screen.height || 0)
            }
            readonly property PunchiMenuNormalSizeState normalSizeState:
                PunchiMenuNormalSizeState {
                    configuredWidthPercent:
                        root.configuredPunchiMenuNormalWidthPercent
                    configuredHeightPercent:
                        root.configuredPunchiMenuNormalHeightPercent
                    screenWidth: punchiMenuNormalDialog.activeScreenWidth
                    screenHeight: punchiMenuNormalDialog.activeScreenHeight
                    availableWidth: Number(root.availableScreenRect.width || 0)
                    availableHeight: Number(root.availableScreenRect.height || 0)
                    screenMargin: punchiMenuNormalDialog.screenMargin
                    contentMargin: Kirigami.Units.largeSpacing
                    minimumContentWidth:
                        punchiMenuNormalDialog.minimumContentWidth
                    minimumContentHeight:
                        punchiMenuNormalDialog.minimumContentHeight
                }
            readonly property int desiredContentWidth:
                normalSizeState.appliedContentWidth
            readonly property int desiredContentHeight:
                normalSizeState.appliedContentHeight

            // The normal menu is a lazily created component whose owner ids
            // remain available in the plasmoid runtime context.
            // qmllint disable unqualified
            // PunchiMenuNormalPlacement owns the final window coordinates.
            // A visualParent makes PlasmaQuick::Dialog recompute popupPosition()
            // after our configured panel gap has already been applied.
            visualParent: null
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.PopupMenu
            flags: isX11Session
                ? Qt.Popup | Qt.FramelessWindowHint
                : Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true
            visible: false
            opacity: 0

            readonly property Punchi.BlurBehindController normalBlurController:
                Punchi.BlurBehindController {
                    window: punchiMenuNormalDialog
                    fullWindow: false
                    maskSource: punchiMenuNormal.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: punchiMenuNormal.backgroundBlurMaskOffset
                    enabled: punchiMenuNormalDialog.visible
                        && root.configuredPunchiMenuNormalBlurEnabled
                }

            readonly property PunchiMenuNormalPlacement normalPlacement: PunchiMenuNormalPlacement {

                inPanel: root.inPanel
                placementMode: root.configuredPunchiMenuNormalPlacementMode
                panelLocation: dockGeometry.effectivePanelLocation
                availableScreenRect: root.availableScreenRect
                screenGeometry: Plasmoid.containment
                    && Plasmoid.containment.screenGeometry
                    ? Plasmoid.containment.screenGeometry
                    : Qt.rect(0, 0, Screen.width, Screen.height)
                itemAnchor: root.punchiMenuAnchorItem
                floatingDockAnchor: root.floatingDockAnchor
                panelWindow: root.Window.window
                panelThickness: dockGeometry.detectedPanelThickness
                menuWidth: punchiMenuNormalDialog.width
                menuHeight: punchiMenuNormalDialog.height
                panelGap: root.configuredPunchiMenuNormalPanelGap
                floatingGap: root.configuredPunchiMenuNormalPanelGap
                screenInset: root.configuredPunchiMenuNormalPlacementMode === "anchored"
                    ? root.configuredPunchiMenuNormalPanelGap
                    : 0
                themeFrameLeftMargin: punchiMenuNormalDialog.themeFrameMargin("left")
                themeFrameTopMargin: punchiMenuNormalDialog.themeFrameMargin("top")
                themeFrameRightMargin: punchiMenuNormalDialog.themeFrameMargin("right")
                themeFrameBottomMargin: punchiMenuNormalDialog.themeFrameMargin("bottom")
                surfaceFrameLeftMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("left")
                surfaceFrameTopMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("top")
                surfaceFrameRightMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("right")
                surfaceFrameBottomMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("bottom")
            }

            function positionAtAnchor() {
                const targetPosition = normalPlacement.calculatePosition()
                x = targetPosition.x
                y = targetPosition.y
            }

            function scheduleReposition() {
                if (visible) {
                    Qt.callLater(positionAtAnchor)
                }
            }

            function themeFrameMargin(side) {
                const nativeMargins = margins
                const requestedMargin = nativeMargins
                    ? Number(nativeMargins[side])
                    : 0
                return Number.isFinite(requestedMargin)
                    ? Math.max(0, requestedMargin)
                    : 0
            }

            onWidthChanged: scheduleReposition()
            onHeightChanged: scheduleReposition()

            readonly property Connections configurationConnections: Connections {
                target: root
                function onConfiguredPunchiMenuNormalPlacementModeChanged() {
                    punchiMenuNormalDialog.scheduleReposition()
                }
                function onConfiguredPunchiMenuNormalPanelGapChanged() {
                    punchiMenuNormalDialog.scheduleReposition()
                }
                function onConfiguredPunchiMenuNormalBlurEnabledChanged() {
                    Qt.callLater(function() {
                        punchiMenuNormalDialog.normalBlurController.reapply()
                    })
                }
            }

            function consumeRecentExternalHide() {
                const hideTimestamp = lastExternalHideTimestamp
                lastExternalHideTimestamp = -1
                if (hideTimestamp < 0) {
                    return false
                }
                const elapsed = Date.now() - hideTimestamp
                // QtStyleHints exposes this property at runtime, but qmllint
                // resolves Qt.styleHints as a generic QObject.
                // qmllint disable missing-property
                const guardInterval = Math.max(1,
                    Qt.styleHints.mouseDoubleClickInterval)
                // qmllint enable missing-property
                return elapsed >= 0
                    && elapsed <= guardInterval
            }

            function finishOpening() {
                if (!visible) {
                    return
                }
                positionAtAnchor()
                opacity = 1
                requestActivate()
                Qt.callLater(function() {
                    punchiMenuNormalDialog.normalBlurController.reapply()
                })
                punchiMenuFavoritesController.refresh()
                punchiMenuNormal.openMenu()
            }

            function openWithReveal() {
                internalCloseRequested = false
                lastExternalHideTimestamp = -1
                opacity = 0
                normalSizeState.applyConfiguredDimensions()
                positionAtAnchor()
                visible = true
                Qt.callLater(finishOpening)
            }

            readonly property Timer normalDialogCloseTimer: Timer {
                id: normalDialogCloseTimer
                interval: 160
                repeat: false
                onTriggered: {
                    punchiMenuNormalDialog.closeImmediately()
                }
            }

            function closeWithFade() {
                if (!visible || normalDialogCloseTimer.running) {
                    return
                }
                internalCloseRequested = true
                punchiMenuNormal.forceClose()
                normalDialogCloseTimer.restart()
            }

            function closeImmediately() {
                normalDialogCloseTimer.stop()
                internalCloseRequested = true
                lastExternalHideTimestamp = -1
                punchiMenuNormal.resetMenu()
                opacity = 0
                visible = false
                Qt.callLater(function() {
                    punchiMenuNormalDialog.internalCloseRequested = false
                })
            }

            onVisibleChanged: {
                if (!visible) {
                    if (!internalCloseRequested) {
                        lastExternalHideTimestamp = Date.now()
                    }
                    punchiMenuNormal.resetMenu()
                    opacity = 0
                }
            }

            // qmllint disable unqualified
            mainItem: PunchiMenuNormal {
                id: punchiMenuNormal
                width: punchiMenuNormalDialog.desiredContentWidth
                height: punchiMenuNormalDialog.desiredContentHeight
                Layout.minimumWidth: punchiMenuNormalDialog.desiredContentWidth
                Layout.preferredWidth: punchiMenuNormalDialog.desiredContentWidth
                Layout.maximumWidth: punchiMenuNormalDialog.desiredContentWidth
                Layout.minimumHeight: punchiMenuNormalDialog.desiredContentHeight
                Layout.preferredHeight: punchiMenuNormalDialog.desiredContentHeight
                Layout.maximumHeight: punchiMenuNormalDialog.desiredContentHeight
                systemDiscovery: root.systemDiscoveryService
                applicationCatalog: root.punchiMenuApplicationCatalog
                applicationLayoutController:
                    root.punchiMenuLayoutControllerService
                dockItemsController: root.dockItemsControllerService
                applicationIconScale: root.configuredPunchiMenuGridIconScale
                favoriteIconScale: root.configuredPunchiMenuFavoriteIconScale
                folderMaximumColumns:
                    root.configuredPunchiMenuNormalFolderMaximumColumns
                folderMaximumRows:
                    root.configuredPunchiMenuNormalFolderMaximumRows
                showApplicationLabels:
                    root.configuredPunchiMenuShowApplicationLabels
                hoverAnimation: root.configuredPunchiMenuHoverAnimation
                performanceMode: root.configuredPunchiMenuPerformanceMode
                performanceThreshold: root.configuredPunchiMenuPerformanceThreshold
                sortApplicationsAlphabetically:
                    root.configuredPunchiMenuSortApplicationsAlphabetically
                backgroundBlurEnabled:
                    root.configuredPunchiMenuNormalBlurEnabled
                backgroundOpacity: root.configuredPunchiMenuNormalBackgroundOpacity
                normalFloatingLabelShorteningEnabled:
                    root.configuredPunchiMenuNormalFloatingLabelShorteningEnabled
                normalFloatingLabelVisibleCharacters:
                    root.configuredPunchiMenuNormalFloatingLabelVisibleCharacters
                normalFloatingTextShadowsEnabled:
                    root.configuredPunchiMenuNormalFloatingTextShadowsEnabled
                normalFloatingTextShadowPercent:
                    root.configuredPunchiMenuNormalFloatingTextShadowPercent
                normalPlacementMode:
                    root.configuredPunchiMenuNormalPlacementMode
                normalPanelDistancePercent:
                    root.configuredPunchiMenuNormalPanelDistancePercent
                normalWidthPercent: root.configuredPunchiMenuNormalWidthPercent
                normalHeightPercent: root.configuredPunchiMenuNormalHeightPercent
                showCategories: root.configuredPunchiMenuNormalShowCategories
                categoryGroupingEnabled: root.configuredPunchiMenuNormalCategoryGrouping
                themeFrameLeftMargin: punchiMenuNormalDialog.themeFrameMargin("left")
                themeFrameTopMargin: punchiMenuNormalDialog.themeFrameMargin("top")
                themeFrameRightMargin: punchiMenuNormalDialog.themeFrameMargin("right")
                themeFrameBottomMargin: punchiMenuNormalDialog.themeFrameMargin("bottom")
                favorites: punchiMenuFavoritesController.favorites
                favoriteLimitReached: punchiMenuFavoritesController.limitReached
                hiddenApplicationIds: root.configuredPunchiMenuHiddenApplicationIds
                onAddFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.addFavorite(storageId)
                }
                onRemoveFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.removeFavorite(storageId)
                }
                onPinToDockRequested: function(storageId, appName, appIcon, appCommand) {
                    punchiMenuNormal.showOperationResult(
                        root.dockItemsControllerService.togglePinAppToDock(
                            storageId, appName, appIcon, appCommand))
                }
                onAddToDesktopRequested: function(storageId, appCommand) {
                    punchiMenuNormal.showOperationResult(
                        root.dockItemsControllerService.pinAppToDesktop(storageId, appCommand))
                }
                onSetApplicationHiddenRequested: function(storageId, hidden) {
                    if (!root.dockItemsControllerService.setPunchiMenuApplicationHidden(
                            storageId, hidden)) {
                        punchiMenuNormal.showOperationResult(
                            root.dockItemsControllerService.operationResult(
                                false, "persist-failed", ""))
                    }
                }
                onSettingChangeRequested: function(fieldName, value) {
                    if (!root.dockItemsControllerService.setPunchiMenuValue(
                            fieldName, value)) {
                        punchiMenuNormal.showSettingsPersistenceError()
                    }
                }
                onConfigureRequested: {
                    const itemIndex = root.configuredPunchiMenuItemIndex
                    punchiMenuNormalDialog.closeImmediately()
                    Qt.callLater(function() {
                        root.openDockItemEditor(itemIndex)
                    })
                }
                onCloseFinished: punchiMenuNormalDialog.closeImmediately()
            }
            // qmllint enable unqualified
        }
    }

    Component {
        id: punchiMenuCompactDialogComponent

        PlasmaCore.Dialog {
            id: punchiMenuCompactDialog

            readonly property string menuMode: "compact"
            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property double lastExternalHideTimestamp: -1
            property bool internalCloseRequested: false

            readonly property int defaultContentWidth: Math.round(punchiMenuCompact.implicitWidth)
            readonly property int defaultContentHeight: Math.round(punchiMenuCompact.implicitHeight)

            readonly property int desiredContentWidth: Math.max(
                Math.round(Kirigami.Units.gridUnit * 15),
                defaultContentWidth)
            readonly property int desiredContentHeight: Math.max(
                Math.round(Kirigami.Units.gridUnit * 15),
                defaultContentHeight)

            // qmllint disable unqualified
            visualParent: null
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.PopupMenu
            flags: isX11Session
                ? Qt.Popup | Qt.FramelessWindowHint
                : Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true
            visible: false
            opacity: 0

            readonly property Punchi.BlurBehindController compactBlurController:
                Punchi.BlurBehindController {
                    window: punchiMenuCompactDialog
                    fullWindow: false
                    maskSource: punchiMenuCompact.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: punchiMenuCompact.backgroundBlurMaskOffset
                    enabled: punchiMenuCompactDialog.visible
                        && root.configuredPunchiMenuCompactBlurEnabled
                }

            readonly property PunchiMenuNormalPlacement compactPlacement: PunchiMenuNormalPlacement {
                inPanel: root.inPanel
                placementMode: "anchored"
                panelLocation: dockGeometry.effectivePanelLocation
                availableScreenRect: root.availableScreenRect
                screenGeometry: Plasmoid.containment
                    && Plasmoid.containment.screenGeometry
                    ? Plasmoid.containment.screenGeometry
                    : Qt.rect(0, 0, Screen.width, Screen.height)
                itemAnchor: root.punchiMenuAnchorItem
                floatingDockAnchor: root.floatingDockAnchor
                panelWindow: root.Window.window
                panelThickness: dockGeometry.detectedPanelThickness
                menuWidth: punchiMenuCompactDialog.width
                menuHeight: punchiMenuCompactDialog.height
                horizontalAnchorWidth: punchiMenuCompact.primarySurfaceWidth
                panelGap: root.configuredPunchiMenuNormalPanelGap
                floatingGap: root.configuredPunchiMenuNormalPanelGap
                screenInset: root.configuredPunchiMenuNormalPanelGap
                themeFrameLeftMargin: punchiMenuCompactDialog.themeFrameMargin("left")
                themeFrameTopMargin: punchiMenuCompactDialog.themeFrameMargin("top")
                themeFrameRightMargin: punchiMenuCompactDialog.themeFrameMargin("right")
                themeFrameBottomMargin: punchiMenuCompactDialog.themeFrameMargin("bottom")
                surfaceFrameLeftMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("left")
                surfaceFrameTopMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("top")
                surfaceFrameRightMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("right")
                surfaceFrameBottomMargin: root.inPanel
                    ? 0 : dockBackground.backgroundFrameInset("bottom")
            }

            function positionAtAnchor() {
                const targetPosition = compactPlacement.calculatePosition()
                x = targetPosition.x
                y = targetPosition.y
            }

            function scheduleReposition() {
                if (visible) {
                    Qt.callLater(positionAtAnchor)
                }
            }

            function themeFrameMargin(side) {
                const nativeMargins = margins
                const requestedMargin = nativeMargins
                    ? Number(nativeMargins[side])
                    : 0
                return Number.isFinite(requestedMargin)
                    ? Math.max(0, requestedMargin)
                    : 0
            }

            onWidthChanged: scheduleReposition()
            onHeightChanged: scheduleReposition()

            function recordExternalHide() {
                lastExternalHideTimestamp = Date.now()
            }

            function consumeRecentExternalHide() {
                if (lastExternalHideTimestamp <= 0) {
                    return false
                }
                const elapsedMs = Date.now() - lastExternalHideTimestamp
                lastExternalHideTimestamp = -1
                return elapsedMs >= 0 && elapsedMs < 350
            }

            readonly property Connections configurationConnections: Connections {
                target: root
                function onInPanelChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
                function onPunchiMenuAnchorItemChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
                function onFloatingDockAnchorChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
                function onConfiguredPunchiMenuNormalPanelGapChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
                function onConfiguredPunchiMenuCompactBlurEnabledChanged() {
                    if (punchiMenuCompactDialog.visible) {
                        punchiMenuCompactDialog.compactBlurController.reapply()
                    }
                }
            }

            readonly property Connections dockGeometryConnections: Connections {
                target: dockGeometry
                function onDetectedPanelThicknessChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
                function onEffectivePanelLocationChanged() {
                    punchiMenuCompactDialog.scheduleReposition()
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    recordExternalHide()
                    opacity = 0
                    punchiMenuCompact.resetMenu()
                }
            }

            function openWithReveal() {
                internalCloseRequested = false
                positionAtAnchor()
                visible = true
                opacity = 1
                requestActivate()
                Qt.callLater(function() {
                    punchiMenuCompactDialog.compactBlurController.reapply()
                })
                punchiMenuCompact.openMenu()
            }

            readonly property Timer compactDialogCloseTimer: Timer {
                id: compactDialogCloseTimer
                interval: 160
                repeat: false
                onTriggered: {
                    punchiMenuCompactDialog.closeImmediately()
                }
            }

            function closeWithFade() {
                if (!visible || compactDialogCloseTimer.running) {
                    return
                }
                internalCloseRequested = true
                punchiMenuCompact.forceClose()
                compactDialogCloseTimer.restart()
            }

            function closeImmediately() {
                compactDialogCloseTimer.stop()
                internalCloseRequested = true
                visible = false
                opacity = 0
                punchiMenuCompact.resetMenu()
                Qt.callLater(function() {
                    punchiMenuCompactDialog.internalCloseRequested = false
                })
            }

            mainItem: PunchiMenuCompact {
                id: punchiMenuCompact
                width: punchiMenuCompactDialog.desiredContentWidth
                height: punchiMenuCompactDialog.desiredContentHeight
                Layout.minimumWidth: punchiMenuCompactDialog.desiredContentWidth
                Layout.preferredWidth: punchiMenuCompactDialog.desiredContentWidth
                Layout.maximumWidth: punchiMenuCompactDialog.desiredContentWidth
                Layout.minimumHeight: punchiMenuCompactDialog.desiredContentHeight
                Layout.preferredHeight: punchiMenuCompactDialog.desiredContentHeight
                Layout.maximumHeight: punchiMenuCompactDialog.desiredContentHeight
                systemDiscovery: root.systemDiscoveryService
                applicationCatalog: root.punchiMenuApplicationCatalog
                dockItemsController: root.dockItemsControllerService
                showApplicationLabels: root.configuredPunchiMenuShowApplicationLabels
                hoverAnimation: root.configuredPunchiMenuHoverAnimation
                performanceMode: root.configuredPunchiMenuPerformanceMode
                performanceThreshold: root.configuredPunchiMenuPerformanceThreshold
                sortApplicationsAlphabetically: root.configuredPunchiMenuSortApplicationsAlphabetically
                backgroundBlurEnabled: root.configuredPunchiMenuCompactBlurEnabled
                backgroundOpacity: root.configuredPunchiMenuCompactBackgroundOpacity
                compactShowQuickLaunchers: root.configuredPunchiMenuCompactShowQuickLaunchers
                normalPanelDistancePercent:
                    root.configuredPunchiMenuNormalPanelDistancePercent
                themeFrameLeftMargin: punchiMenuCompactDialog.themeFrameMargin("left")
                themeFrameTopMargin: punchiMenuCompactDialog.themeFrameMargin("top")
                themeFrameRightMargin: punchiMenuCompactDialog.themeFrameMargin("right")
                themeFrameBottomMargin: punchiMenuCompactDialog.themeFrameMargin("bottom")
                favorites: punchiMenuFavoritesController.favorites
                favoriteLimitReached: punchiMenuFavoritesController.limitReached

                onAddFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.addFavorite(storageId)
                }
                onRemoveFavoriteRequested: function(storageId) {
                    punchiMenuFavoritesController.removeFavorite(storageId)
                }
                onPinToDockRequested: function(storageId, appName, appIcon, appCommand) {
                    root.dockItemsControllerService.togglePinAppToDock(
                        storageId, appName, appIcon, appCommand)
                }
                onAddToDesktopRequested: function(storageId, appCommand) {
                    root.dockItemsControllerService.pinAppToDesktop(storageId, appCommand)
                }
                onSetApplicationHiddenRequested: function(storageId, hidden) {
                    root.dockItemsControllerService.setPunchiMenuApplicationHidden(
                        storageId, hidden)
                }
                onApplicationLaunched: punchiMenuCompactDialog.closeWithFade()
                onMenuCloseRequested: punchiMenuCompactDialog.closeWithFade()
                onCloseFinished: punchiMenuCompactDialog.closeImmediately()
                onSettingChangeRequested: function(fieldName, value) {
                    root.dockItemsControllerService.setPunchiMenuValue(fieldName, value)
                }
            }
            // qmllint enable unqualified
        }
    }

    TaskModelController {
        id: taskController
        wheelMaximizeActivated: false
        // R43 uses the existing per-session Qt watcher only as a control
        // plane. SNI remains enabled while TaskManager QML callbacks pause.
        diagnosticTaskObservationEnabled: trayWindowBridge.diagnosticTaskObservationEnabled
        // R44: keep window monitoring and the real SNI alive; coalesce only
        // Punchi QML visual publications while the fan reveal is animating.
        fanRevealActive: root.fanRevealCritical
        trayEntries: trayWindowBridge.identityModel
        trayIdentityBridge: trayWindowBridge
        trayActivator: function(desktopId) {
            return trayWindowBridge.activateDesktopEntry(String(desktopId || ""), -1, -1)
        }
        dockItems: dockItemsController.dockItems
        showActiveTasks: Plasmoid.configuration.showActiveTasks
        currentDesktopOnly: Plasmoid.configuration.showTasksCurrentDesktopOnly
        windowGroupingMode: String(Plasmoid.configuration.windowGroupingMode || "application")
        maxDynamicGroups: Math.max(1, Math.min(20,
            Number(Plasmoid.configuration.maxDynamicTaskGroups || 8)))
        automaticDynamicGroups: dockGeometry.panelFillLengthEnabled
        dynamicGroupCapacity: root.panelDynamicGroupCapacity
        systemDiscovery: systemDiscovery
        trayAutostartPolicy: systemDiscovery
        onStructureChanged: {
            root.taskStructureChanged()
            root.updateTrayWindowObservation()
        }
        onWindowObservationRequested: root.updateTrayWindowObservation()
        onMaximizedObservationRequested: root.updateMaximizedWindowObservation()
        Component.onCompleted: Qt.callLater(root.updateTrayWindowObservation)
    }
    Loader {
        id: recentApplicationsLoader
        active: dockConfig.showRecentApplications
        sourceComponent: RecentApplicationsController {
            maximumItems: dockConfig.recentApplicationsCount
            dockItems: dockItemsController.dockItems
            systemDiscovery: systemDiscovery
        }
    }
    function invalidatePunchiMenuInstance() {
        if (punchiMenuDialogInstance && !punchiMenuDialogInstance.visible) {
            punchiMenuDialogInstance.destroy()
            punchiMenuDialogInstance = null
        }
    }

    function invalidateControlCenterInstance() {
        if (controlCenterDialogInstance
                && (!configuredControlCenterItem
                    || controlCenterDialogInstance.controlCenterMode
                        !== root.configuredControlCenterMode)) {
            controlCenterDialogInstance.closeImmediately()
            controlCenterDialogInstance.destroy()
            controlCenterDialogInstance = null
            controlCenterAnchorItem = null
        }
    }

    function synchronizePunchiMenuLayoutController() {
        punchiMenuLayoutController.layoutDocument
            = dockItemsController.punchiMenuApplicationLayout()
    }

    DockItemsController {
        id: dockItemsController
        objectName: "dockItemsController"
        dynamicApplicationsEnabled: Plasmoid.configuration.showActiveTasks
        runtimeService: runtimeService
        persistenceAdapter: dockItemsPersistenceAdapter
        systemDiscovery: systemDiscovery
        taskController: taskController
        trashIntegration: trashIntegration
        minimizeEffect: dockConfig.dockWindowMinimizeEffect
        onConfigurationChanged: {
            root.synchronizePunchiMenuLayoutController()
            root.invalidatePunchiMenuInstance()
            root.invalidateControlCenterInstance()
        }
    }
    PunchiMenuFavoritesController {
        id: punchiMenuFavoritesController
        systemDiscovery: systemDiscovery
    }
    DockContextActionsController {
        id: dockContextActionsController
        objectName: "dockContextActionsController"
        systemDiscovery: systemDiscovery
        taskController: taskController
        dockItemsController: dockItemsController
        trayBridge: trayWindowBridge
        showConfigureDockAction: Plasmoid.configuration.showConfigureDockAction !== false
        configureDockHandler: function() {
            return root.openDockConfiguration()
        }
        moveDynamicApplicationsHandler: function() {
            return root.requestDynamicApplicationsMoveMode()
        }
        recentContainerActive: dockConfig.showRecentApplications
            && dockConfig.recentApplicationsMode === "container"
        disableRecentApplicationsHandler: function() {
            return dockConfig.disableRecentApplications()
        }
        setRecentContainerViewHandler: function(layout) {
            return dockConfig.setRecentApplicationsContainerLayout(layout)
        }
    }
    DropFeedbackPopup {
        id: dropFeedbackPopup
    }
    readonly property string currentVirtualDesktopId: String(virtualDesktopInfo.currentDesktop || "")
    readonly property bool singleVirtualDesktopMode: Plasmoid.configuration.virtualDesktopMode === "single"
        && Plasmoid.configuration.targetVirtualDesktop !== ""
    readonly property bool hiddenByVirtualDesktop: singleVirtualDesktopMode
        && currentVirtualDesktopId !== Plasmoid.configuration.targetVirtualDesktop
    property int panelDynamicGroupCapacity: -1

    // Translation functions and controller ids are provided by the plasmoid
    // context and remain valid at runtime.
    // qmllint disable unqualified
    function openDockConfiguration() {
        const configureAction = Plasmoid.internalAction("configure")
        if (!configureAction || configureAction.enabled === false) {
            return false
        }

        Plasmoid.configuration.pendingEditDockItemIndex = -1
        // Persist the hand-off before opening the KCM, which may run in a
        // separate configuration context.
        // qmllint disable missing-property
        Plasmoid.configuration.writeConfig()
        // qmllint enable missing-property
        configureAction.trigger()
        return true
    }

    function openDockItemEditor(index) {
        if (!Number.isInteger(index) || index < 0) {
            return false
        }

        const configureAction = Plasmoid.internalAction("configure")
        if (!configureAction || configureAction.enabled === false) {
            return false
        }

        Plasmoid.configuration.pendingEditDockItemIndex = index
        // Persist the hand-off before opening the KCM, which may run in a
        // separate configuration context.
        // qmllint disable missing-property
        Plasmoid.configuration.writeConfig()
        // qmllint enable missing-property
        configureAction.trigger()
        return true
    }

    function droppedUrlErrorMessage(result) {
        const errorCode = String(result && result.errorCode || "")
        if (errorCode === "noUrls") {
            return i18nc("@info:status", "No local files were found in this drop.")
        }
        if (errorCode === "tooManyUrls") {
            const maximumCount = Number(result.maximumUrlCount || 64)
            return i18nc("@info:status", "You can open up to %1 local files at once.",
                maximumCount)
        }
        if (errorCode === "invalidUrl") {
            return i18nc("@info:status", "The drop contains an invalid local file location.")
        }
        if (errorCode === "unsupportedScheme") {
            return i18nc("@info:status", "Only local files can be opened with an application.")
        }
        if (errorCode === "urlTooLong") {
            return i18nc("@info:status", "A file location is too long to open safely.")
        }
        if (errorCode === "batchTooLarge") {
            return i18nc("@info:status", "The dropped file list is too large to open safely.")
        }
        if (errorCode === "applicationUnavailable") {
            return i18nc("@info:status", "This application cannot be resolved safely for file opening.")
        }
        return i18nc("@info:status", "The dropped files could not be opened.")
    }

    function handleApplicationUrlsDrop(item, taskRows, urls, visualParent,
            coordinator) {
        const result = dockItemsController.handleApplicationUrlsDrop(
            item, taskRows, urls)
        if (!result.accepted) {
            dropFeedbackPopup.presentFeedback(visualParent,
                root.droppedUrlErrorMessage(result))
            return
        }
        dropFeedbackPopup.dismissFeedback()
        if (coordinator) {
            coordinator.closeAllPopups(null)
        }
    }

    function handleContainerApplicationLauncherDrop(urls, targetIndex,
            expectedContainerText, visualParent, coordinator) {
        const result = dockItemsController.addApplicationLauncherToContainer(
            urls, targetIndex, expectedContainerText)
        if (!result.success) {
            dropFeedbackPopup.presentFeedback(visualParent, result.message,
                false)
            return
        }

        dropFeedbackPopup.dismissFeedback()
        const folderPopup = coordinator
            ? coordinator.folderPopupDialogRef : null
        const activeFolderMatches = folderPopup && folderPopup.visible
            && dockItemsController.canonicalJsonText(
                coordinator.activeFolderData) === expectedContainerText
        if (result.success && activeFolderMatches && result.container) {
            coordinator.activeFolderData = result.container
        }
    }

    function launchConfiguredMediaPlayer(item, playWhenReady) {
        const storageId = String(
            item.defaultPlayerStorageId || "").substring(0, 512)
        if (storageId.length === 0) {
            return
        }

        taskController.cancelPendingMediaWindowMinimize()
        if (item.openPlayerMinimized === true) {
            taskController.requestMinimizeNextApplicationWindow(
                String(item.defaultPlayerAppId || "").substring(0, 512),
                storageId)
        }
        if (playWhenReady) {
            dockMediaController.requestPlayWhenAvailable(10000)
        }
        systemDiscovery.launchApplication(storageId)
    }
    // qmllint enable unqualified

    implicitWidth: inPanel ? dockGeometry.panelPreferredWidth : 0
    implicitHeight: inPanel ? dockGeometry.panelPreferredHeight : 0
    switchWidth: inPanel ? dockGeometry.panelPreferredWidth : Math.ceil(dockGeometry.panelItemWidth)
    switchHeight: inPanel ? dockGeometry.panelPreferredHeight : Math.ceil(dockGeometry.panelItemHeight)

    function applyFloatingOrientationFootprint(preserveLeftEdge) {
        if (inPanel || !floatingDockAnchor) {
            return
        }

        const targetWidth = Math.ceil(floatingDockAnchor.implicitWidth)
        const targetHeight = Math.ceil(floatingDockAnchor.implicitHeight)
        if (targetWidth <= 0 || targetHeight <= 0) {
            return
        }

        const centerX = x + (width / 2)
        const centerY = y + (height / 2)
        const leftEdge = x
        width = targetWidth
        height = targetHeight
        // The title now expands to the RIGHT of fixed controls and artwork.
        // Retain the LEFT boundary to avoid shifting controls with each frame.
        // Non-media orientation changes still use the traditional centering.
        const area = dockGeometry.availableScreenRect
        const padding = Math.max(8, Kirigami.Units.smallSpacing * 2)
        const areaWidth = Math.max(0, Number(area.width || 0))
        const areaHeight = Math.max(0, Number(area.height || 0))
        if (areaWidth > width && areaHeight > height) {
            const left = Number(area.x || 0)
            const top = Number(area.y || 0)
            if (root.floatingDockPlacement === "left") {
                x = Math.round(left + padding)
                y = Math.round(top + Math.max(padding, (areaHeight - height) / 2))
            } else if (root.floatingDockPlacement === "right") {
                x = Math.round(left + areaWidth - width - padding)
                y = Math.round(top + Math.max(padding, (areaHeight - height) / 2))
            } else {
                x = Math.round(Math.max(left + padding,
                    Math.min(left + areaWidth - width - padding,
                        preserveLeftEdge ? leftEdge : centerX - width / 2)))
                y = Math.round(top + areaHeight - height - padding)
            }
        } else {
            // Desktop containment may not supply an available geometry at startup.
            x = Math.round(preserveLeftEdge ? leftEdge : centerX - width / 2)
            y = Math.round(centerY - height / 2)
        }
        dockGeometry.updateFloatingScreenEdge(floatingDockAnchor)
    }

    onFloatingDockPlacementChanged: {
        if (floatingOrientationReady && !inPanel)
            floatingOrientationFootprintTimer.restart()
    }
    Component.onCompleted: {
        floatingOrientationReady = true
        Qt.callLater(function() {
            systemDiscovery.requestApplicationCatalog()
        })
        Qt.callLater(root.synchronizePunchiMenuLayoutController)
        Qt.callLater(root.applyConfiguredPanelLengthMode)
        Qt.callLater(root.applyConfiguredPanelAlignmentMode)
        Qt.callLater(root.applyConfiguredPanelFloatingMode)
        Qt.callLater(root.applyConfiguredPanelVisibilityMode)
        Qt.callLater(root.applyConfiguredPanelThickness)
        Qt.callLater(root.applyConfiguredPanelOpacityMode)
    }

    Timer {
        id: floatingOrientationFootprintTimer
        interval: 50
        repeat: false
        onTriggered: root.applyFloatingOrientationFootprint()
    }
    // Keep the floating host window as wide as the inline title animation;
    // without this, Plasma may clip the rightmost playback buttons.
    Timer {
        id: floatingMediaFootprintTimer
        interval: 16
        repeat: false
        onTriggered: root.applyFloatingOrientationFootprint(!root.floatingVertical)
    }

    Layout.fillWidth: inPanel && !hiddenByVirtualDesktop
        && (dockGeometry.verticalPanel || dockGeometry.panelFillLengthEnabled)
    Layout.fillHeight: inPanel && !hiddenByVirtualDesktop
        && (dockGeometry.horizontalPanel || dockGeometry.panelFillLengthEnabled)
    Layout.minimumWidth: inPanel ? dockGeometry.panelMinimumWidth : -1
    Layout.minimumHeight: inPanel ? dockGeometry.panelMinimumHeight : -1
    Layout.preferredWidth: inPanel ? dockGeometry.panelPreferredWidth : -1
    Layout.preferredHeight: inPanel ? dockGeometry.panelPreferredHeight : -1

    Punchi.TrashIntegration {
        id: trashIntegration
        // qmllint disable unqualified
        onOperationFailed: function(operation, message) {
            console.warn("Oger Dock:", operation, message)
        }
        // qmllint enable unqualified
    }

    fullRepresentation: Item {
        id: mainContainer
        objectName: "punchiDockFullRepresentation"
        property bool contextMenuVisible: false
        readonly property bool dynamicApplicationsMoveModeActive:
            dockLayout.persistentMoveModeActive

        function enterDynamicApplicationsMoveMode() {
            return dockLayout.enterDynamicApplicationsMoveMode()
        }

        Component.onCompleted: {
            root.dynamicApplicationsMoveModeTarget = mainContainer
            // IDs inside fullRepresentation cannot be referenced lexically
            // by methods declared on the outer PlasmoidItem (R26 line 162).
            root.trayActionsPopupRef = pinnedTrayActionsPopup
            root.trayDefaultAnchorRef = dockLayout
        }
        Component.onDestruction: {
            if (root.dynamicApplicationsMoveModeTarget === mainContainer)
                root.dynamicApplicationsMoveModeTarget = null
            if (root.trayActionsPopupRef === pinnedTrayActionsPopup)
                root.trayActionsPopupRef = null
            if (root.trayDefaultAnchorRef === dockLayout)
                root.trayDefaultAnchorRef = null
        }
        // fullRepresentation is compiled as a nested component, so qmllint
        // cannot resolve accesses to the owning PlasmoidItem even though
        // Plasma provides that lexical context at runtime.
        // qmllint disable unqualified
        visible: !root.hiddenByVirtualDesktop
        enabled: visible
        implicitWidth: visible ? dockGeometry.panelPreferredWidth : 0
        implicitHeight: visible ? dockGeometry.panelPreferredHeight : 0
        Layout.fillWidth: root.inPanel && visible
            && (dockGeometry.verticalPanel || dockGeometry.panelFillLengthEnabled)
        Layout.fillHeight: root.inPanel && visible
            && (dockGeometry.horizontalPanel || dockGeometry.panelFillLengthEnabled)
        Layout.minimumWidth: dockGeometry.panelMinimumWidth
        Layout.minimumHeight: dockGeometry.panelMinimumHeight
        Layout.preferredWidth: dockGeometry.panelPreferredWidth
        Layout.preferredHeight: dockGeometry.panelPreferredHeight
        // qmllint enable unqualified

        PopupCoordinator {
            id: popupCoordinator
            objectName: "popupCoordinator"
            folderItemsControllerRef: root.dockItemsControllerService
            // R45: latch the task presentation BEFORE popup visibility and
            // Wayland focus events. Other popup types remain unaffected.
            onFolderPopupOpening: function(itemData) {
                if (String(itemData && itemData.layout || "") === "fan")
                    taskController.beginFanPresentationHold()
            }
            inPanel: root.inPanel
            panelPopupDirection: dockGeometry.popupDirection
            availableScreenRect: root.availableScreenRect
            // qmllint disable unqualified
            geometryStateRef: dockGeometry
            // qmllint enable unqualified
            dockFallbackAnchor: dockWrapper
            taskStructureSource: root
            taskControllerRef: taskController
            mprisControllerRef: mprisController
            trashIntegrationRef: trashIntegration
            trashContextContentRef: trashContextContent
            notePopupContentRef: notePopupContent
            taskWindowsPopupContentRef: taskWindowsPopupContent
            taskPopupSurfaceRef: taskPopupSurface
            taskPopupAnimatedContentRef: taskPopupAnimatedContent
            stableTaskPopupAnchorRef: stableTaskPopupAnchor
            // These ids belong to the owning full representation.
            // qmllint disable unqualified
            mediaHoverMode: dockConfig.mediaControlsMode
            mediaHoverEnabled: dockConfig.mediaControlsOnHover
            windowPreviewsEnabled: dockConfig.windowPreviewStyle !== "none"
            // qmllint enable unqualified
            folderPopupDialogRef: folderPopupDialog
            folderPopupAnimatedContentRef: folderPopupAnimatedContent
            calendarPopupDialogRef: calendarPopupDialog
            trashMenuDialogRef: trashMenuDialog
            trashDockContentsDialogRef: trashDockContentsDialog
            notePopupDialogRef: notePopupDialog
            appActionsDialogRef: appActionsDialog
            taskWindowsDialogRef: taskWindowsDialog
            taskOverflowDialogRef: taskOverflowDialog
            // The dynamic PunchiMenu instance belongs to the owning PlasmoidItem.
            // qmllint disable unqualified
            punchiMenuDialogRef: root.punchiMenuDialogInstance
            // qmllint enable unqualified
            applicationIdentityResolver: function(itemData) {
                return dockContextActionsController.applicationIdentityForItem(itemData)
            }
            // qmllint disable unqualified
            contextActionsResolver: function(itemData, rows, itemOrigin, persistentIndex) {
                return dockContextActionsController.actionsForItem(
                    itemData, rows, itemOrigin, persistentIndex)
            }
            // qmllint enable unqualified
        }

        // qmllint disable unqualified
        Connections {
            target: trashIntegration

            function onOperationSucceeded(operation) {
                if (operation !== "emptyTrash") {
                    return
                }
                runtimeService.playSound(popupCoordinator.activeTrashEmptySound, "trash-empty")
                if (trashMenuDialog.visible && trashContextContent.confirmationVisible) {
                    trashSuccessCloseTimer.restart()
                }
            }
        }

        Timer {
            id: trashSuccessCloseTimer
            interval: 1200
            repeat: false
            onTriggered: {
                trashMenuDialog.closeSafely()
                trashContextContent.showMenu()
                trashIntegration.resetOperationState()
            }
        }
        // qmllint enable unqualified

        Item {
            id: dockWrapper
            anchors.centerIn: parent
            // This nested representation intentionally reads the owning
            // PlasmoidItem and sibling controllers to follow panel geometry.
            // qmllint disable unqualified
            implicitWidth: root.inPanel
                ? dockGeometry.panelPreferredWidth
                : dockLayout.implicitWidth + dockGeometry.floatingExtraWidth
            implicitHeight: root.inPanel ? dockGeometry.panelPreferredHeight : dockLayout.implicitHeight
                + dockGeometry.floatingExtraHeight
            width: root.inPanel ? parent.width : implicitWidth
            height: root.inPanel ? parent.height : implicitHeight

            TaskPopupAnchorProxy {
                id: stableTaskPopupAnchor
            }

            Component.onCompleted: root.floatingDockAnchor = dockWrapper
            onXChanged: dockGeometry.updateFloatingScreenEdge(dockWrapper)
            onYChanged: dockGeometry.updateFloatingScreenEdge(dockWrapper)
            onWidthChanged: dockGeometry.updateFloatingScreenEdge(dockWrapper)
            onHeightChanged: dockGeometry.updateFloatingScreenEdge(dockWrapper)
            onImplicitHeightChanged: {
                if (!root.inPanel && root.floatingOrientationReady
                        && !floatingMediaFootprintTimer.running)
                    floatingMediaFootprintTimer.start()
            }
            onImplicitWidthChanged: {
                if (!root.inPanel && root.floatingOrientationReady
                        && !floatingMediaFootprintTimer.running)
                    floatingMediaFootprintTimer.start()
            }

            readonly property real dynamicTaskCapacityLength: {
                if (!root.inPanel) {
                    if (root.floatingVertical) {
                        const h = Number(root.availableScreenRect.height || 0)
                        return h > 160 ? h - 64 : -1
                    }
                    return -1
                }

                const isVertical = dockGeometry.verticalPanel
                if (dockGeometry.panelFillLengthEnabled) {
                    return isVertical ? height : width
                }

                // Fit-content geometry must not feed the dock's own assigned
                // length back into its capacity. The available screen axis is
                // independent from the preferred size produced by this dock.
                const availableLength = isVertical
                    ? Number(root.availableScreenRect.height || 0)
                    : Number(root.availableScreenRect.width || 0)
                return Number.isFinite(availableLength) && availableLength > 0
                    ? availableLength : -1
            }
            readonly property int dynamicTaskSlotCapacity: {
                if (dynamicTaskCapacityLength < 0) {
                    return -1
                }

                const isVertical = dockGeometry.verticalPanel
                const totalPadding = isVertical
                    ? (dockGeometry.dockBackgroundVerticalPadding * 2)
                    : (dockGeometry.dockBackgroundHorizontalPadding * 2)
                const innerLength = Math.max(0,
                    dynamicTaskCapacityLength - totalPadding)
                const boundarySpacing = dockItemsController.dockItems.length > 0
                    && taskController.totalDynamicGroups > 0
                    ? dockGeometry.dockSpacing
                    : 0
                const availableLength = Math.max(0, innerLength
                    - dockGeometry.panelFixedContentLength - boundarySpacing)
                const itemExtent = isVertical
                    ? dockGeometry.panelItemHeight
                    : dockGeometry.panelItemWidth
                return Math.max(0, Math.floor(
                    (availableLength + dockGeometry.dockSpacing)
                    / (itemExtent + dockGeometry.dockSpacing)))
            }

            Binding {
                target: root
                property: "panelDynamicGroupCapacity"
                value: dockWrapper.dynamicTaskSlotCapacity
                restoreMode: Binding.RestoreBindingOrValue
            }
            readonly property int recentSlotCapacity: {
                if (dynamicTaskCapacityLength < 0) { return -1 }
                const isVertical = dockGeometry.verticalPanel
                const padding = isVertical ? dockGeometry.dockBackgroundVerticalPadding * 2
                    : dockGeometry.dockBackgroundHorizontalPadding * 2
                const hasPrecedingItems = dockGeometry.panelBaseCompactContentLength > 0
                const separatorExtent = hasPrecedingItems
                    ? dockGeometry.panelMainAxisExtentForDockItem({ "type": "separator" }) + dockGeometry.dockSpacing * 2
                    : 0
                const remaining = dynamicTaskCapacityLength - padding
                    - dockGeometry.panelBaseCompactContentLength - separatorExtent
                const itemExtent = isVertical ? dockGeometry.panelItemHeight : dockGeometry.panelItemWidth
                const slots = Math.max(0, Math.floor((remaining + dockGeometry.dockSpacing)
                    / (itemExtent + dockGeometry.dockSpacing)))
                return dockConfig.recentApplicationsMode === "container"
                    ? (slots > 0 ? dockConfig.recentApplicationsCount : 0) : slots
            }
            Binding {
                target: root
                property: "recentApplicationCapacity"
                value: dockWrapper.recentSlotCapacity
                restoreMode: Binding.RestoreBindingOrValue
            }
            // qmllint enable unqualified

            WindowIntersectionController {
                id: windowIntersectionController
                targetItem: dockWrapper
                monitoringEnabled: !root.inPanel
                    && mainContainer.visible
                    && themeIntegration.adaptiveTransparencyEnabled
                screenGeometry: {
                    const containment = Plasmoid.containment
                    return containment && containment.screenGeometry
                        ? containment.screenGeometry
                        : Qt.rect(0, 0, 0, 0)
                }
            }

            PanelFlatThemeBackground {
                id: panelFlatBackground
                objectName: "panelFlatThemeBackground"
                panelWindow: root.Window.window
                requested: root.inPanel && mainContainer.visible
                    && (root.audioSpectrumReplacesPanelBackground
                        || (dockConfig.customDockThemeActive
                            && dockThemeRepository.theme.renderer === "flat"))
                theme: dockThemeRepository.theme
                dockVertical: dockGeometry.verticalPanel
                contentReference: dockLayout
                restingPadding: dockBackground.customThemeVisualVerticalPadding
                backgroundVisible: dockConfig.customDockThemeActive
                    && dockThemeRepository.theme.renderer === "flat"
                    && !root.audioSpectrumReplacesPanelBackground
                spectrumVisible: root.audioSpectrumReplacesPanelBackground
                spectrumActive: dockConfig.audioSpectrumConfigured
                    && audioSpectrumController.active
                spectrumLevels: audioSpectrumController.levels
                spectrumIntensity: dockConfig.audioSpectrumIntensity
                spectrumUsePlasmaTheme: dockConfig.audioSpectrumUsePlasmaTheme
                spectrumBarCount: dockConfig.audioSpectrumBarCount
                spectrumOriginEdge: dockGeometry.spectrumOriginEdge
                spectrumBarStyle: dockConfig.audioSpectrumStyle
                spectrumFlowDirection: dockConfig.audioSpectrumFlow
            }

            DockBackground {
                id: dockBackground
                anchors.fill: (!root.inPanel || !dockConfig.customDockThemeActive) ? parent : undefined

                readonly property var activeShadow: dockConfig.customDockThemeActive
                    && dockThemeRepository.theme && dockThemeRepository.theme.shadow
                    ? dockThemeRepository.theme.shadow : ({})
                readonly property real shadowSize: Number(activeShadow.size || 0)
                readonly property real shadowXOffset: Number(activeShadow.xOffset || 0)
                readonly property real shadowYOffset: Number(activeShadow.yOffset || 0)
                readonly property real shadowLeftReserve: shadowSize + Math.max(0, -shadowXOffset)
                readonly property real shadowRightReserve: shadowSize + Math.max(0, shadowXOffset)
                readonly property real shadowTopReserve: shadowSize + Math.max(0, -shadowYOffset)
                readonly property real shadowBottomReserve: shadowSize + Math.max(0, shadowYOffset)
                readonly property real customThemeVisualVerticalPadding: Math.max(2, Math.round(Kirigami.Units.smallSpacing * 0.5))
                readonly property real panelHoverExpansion: {
                    if (!root.inPanel || dockGeometry.panelFillLengthEnabled) {
                        return 0
                    }
                    return Math.round(dockLayout.hoverZoomProgress * (Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing))
                }

                x: {
                    if (!root.inPanel || !dockConfig.customDockThemeActive) {
                        return 0
                    }
                    if (dockGeometry.verticalPanel) {
                        return dockLayout.x - customThemeVisualVerticalPadding - shadowLeftReserve
                    }
                    return -Math.round(panelHoverExpansion / 2)
                }
                y: {
                    if (!root.inPanel || !dockConfig.customDockThemeActive) {
                        return 0
                    }
                    if (dockGeometry.verticalPanel) {
                        return -Math.round(panelHoverExpansion / 2)
                    }
                    return dockLayout.y - customThemeVisualVerticalPadding - shadowTopReserve
                }
                width: {
                    if (!root.inPanel || !dockConfig.customDockThemeActive) {
                        return parent ? parent.width : 0
                    }
                    if (dockGeometry.verticalPanel) {
                        return dockLayout.width + (customThemeVisualVerticalPadding * 2) + shadowLeftReserve + shadowRightReserve
                    }
                    return (parent ? parent.width : 0) + panelHoverExpansion
                }
                height: {
                    if (!root.inPanel || !dockConfig.customDockThemeActive) {
                        return parent ? parent.height : 0
                    }
                    if (dockGeometry.verticalPanel) {
                        return (parent ? parent.height : 0) + panelHoverExpansion
                    }
                    return dockLayout.height + (customThemeVisualVerticalPadding * 2) + shadowTopReserve + shadowBottomReserve
                }

                preferOpaque: !!(Plasmoid.containmentDisplayHints
                    & PlasmaCore.Types.ContainmentPrefersOpaqueBackground)
                    || windowIntersectionController.touchingWindow
                // qmllint disable unqualified
                spectrumActive: !root.inPanel && dockConfig.audioSpectrumConfigured
                    && audioSpectrumController.active
                spectrumLevels: audioSpectrumController.levels
                spectrumIntensity: dockConfig.audioSpectrumIntensity
                spectrumUsePlasmaTheme: dockConfig.audioSpectrumUsePlasmaTheme
                spectrumBarCount: dockConfig.audioSpectrumBarCount
                spectrumVertical: dockGeometry.verticalPanel
                dockVertical: dockGeometry.verticalPanel
                spectrumOriginEdge: dockGeometry.verticalPanel ? dockGeometry.spectrumOriginEdge
                    : (dockConfig.audioSpectrumOrigin === "top" ? Qt.TopEdge : Qt.BottomEdge)
                spectrumEdgeInset: dockGeometry.verticalPanel
                    ? dockGeometry.floatingExtraWidth / 2
                    : dockGeometry.floatingExtraHeight / 2
                spectrumBarStyle: dockConfig.audioSpectrumStyle
                spectrumFlowDirection: dockConfig.audioSpectrumFlow
                plasmaBackgroundVisible: !dockConfig.audioSpectrumConfigured
                    || dockConfig.audioSpectrumBackgroundMode === "plasma"
                customThemeEnabled: dockConfig.customDockThemeActive
                customTheme: dockThemeRepository.theme
                inPanel: root.inPanel
                panelLocation: dockGeometry.effectivePanelLocation
                // qmllint enable unqualified
                visible: (!root.inPanel || dockConfig.customDockThemeActive)
                    && !panelFlatBackground.aligned
            }

            // qmllint disable unqualified
            Item {
                id: panelSpectrumViewport

                readonly property real panelCrossAxisExtent: {
                    const extent = Number(dockGeometry.verticalPanel ? root.width : root.height)
                    return extent > 0
                        ? extent
                        : (dockGeometry.verticalPanel ? dockLayout.width : dockLayout.height)
                }

                // The applet allocation excludes Plasma's adaptive floating margin.
                x: dockGeometry.verticalPanel
                    ? Math.round((parent.width - width) / 2)
                    : dockLayout.x
                y: dockGeometry.verticalPanel
                    ? dockLayout.y
                    : Math.round((parent.height - height) / 2)
                width: dockGeometry.verticalPanel
                    ? Math.min(dockLayout.width, panelCrossAxisExtent)
                    : (dockGeometry.panelFillLengthEnabled
                        ? Math.max(0, parent.width - x
                            - dockGeometry.dockBackgroundHorizontalPadding)
                        : dockLayout.width)
                height: dockGeometry.verticalPanel
                    ? (dockGeometry.panelFillLengthEnabled
                        ? Math.max(0, parent.height - y
                            - dockGeometry.dockBackgroundVerticalPadding)
                        : dockLayout.height)
                    : Math.min(dockLayout.height, panelCrossAxisExtent)
                clip: true
                visible: root.inPanel && dockConfig.audioSpectrumConfigured
                    && !panelFlatBackground.spectrumHosted

                AudioSpectrumLayer {
                    anchors.fill: parent
                    active: root.inPanel && dockConfig.audioSpectrumConfigured
                        && audioSpectrumController.active
                    levels: audioSpectrumController.levels
                    intensity: dockConfig.audioSpectrumIntensity
                    usePlasmaTheme: dockConfig.audioSpectrumUsePlasmaTheme
                    barCount: dockConfig.audioSpectrumBarCount
                    barStyle: dockConfig.audioSpectrumStyle
                    flowDirection: dockConfig.audioSpectrumFlow
                    vertical: dockGeometry.verticalPanel
                    originEdge: dockGeometry.spectrumOriginEdge
                }
            }
            // qmllint enable unqualified

            GridLayout {
                id: dockLayout
                readonly property DockClickCollision clickCollision: DockClickCollision {
                    layoutItem: dockLayout
                    verticalPanel: dockGeometry.verticalPanel // qmllint disable unqualified
                    motionSpeedPercent: dockConfig.dockMotionSpeedPercent // qmllint disable unqualified
                    enabled: dockConfig.dockClickEffect === "collision" // qmllint disable unqualified
                        && !dockLayout.persistentDragActive
                }
                Binding {
                    target: dockGeometry // qmllint disable unqualified
                    property: "panelHoverAnimation"
                    value: dockLayout.effectiveHoverAnimationMode
                }
                Binding {
                    target: dockGeometry // qmllint disable unqualified
                    property: "panelIconGeometries"
                    value: {
                        // Mapping alone does not subscribe to ancestor geometry changes.
                        let geometryState = 0
                        for (let item = dockLayout; item; item = item.parent) {
                            geometryState += item.x + item.y + item.width + item.height
                                + item.scale + item.rotation + item.transformOrigin
                        }
                        const result = []
                        if (!Number.isFinite(geometryState)) {
                            return result
                        }
                        for (const child of dockLayout.children) {
                            if (!(child instanceof DockItem)) {
                                continue
                            }
                            const delegate = child as DockItem
                            if (delegate.mediaItem || delegate.separatorItem || delegate.spacerItem) {
                                continue
                            }
                            const delegateState = delegate.x + delegate.y + delegate.width
                                + delegate.height + delegate.scale + delegate.rotation
                                + delegate.transformOrigin
                            if (!Number.isFinite(delegateState)) {
                                continue
                            }
                            const size = delegate.iconSize
                            // Measure the resting icon box, before its own zoom/translation.
                            result.push(delegate.mapToItem(null, Qt.rect(
                                (delegate.width - size) / 2,
                                (delegate.visualAreaHeight - size) / 2, size, size)))
                        }
                        return result
                    }
                }
                z: 10
                flow: dockGeometry.verticalPanel ? GridLayout.TopToBottom : GridLayout.LeftToRight
                columns: dockGeometry.verticalPanel ? 1 : -1
                rows: dockGeometry.verticalPanel ? -1 : 1
                rowSpacing: dockGeometry.dockSpacing
                columnSpacing: dockGeometry.dockSpacing
                x: {
                    if (!root.inPanel) {
                        return Math.round((parent.width - width) / 2)
                    }
                    if (dockGeometry.verticalPanel) {
                        // Plasma already recenters the containment while an
                        // adaptive panel moves between floating and attached.
                        // Preserve a centered overflow when Wave needs more
                        // width than the lateral panel can allocate.
                        return Math.round((parent.width - width) / 2)
                    }
                    if (dockGeometry.configuredPanelAlignmentMode === "center") {
                        return Math.round((parent.width - width) / 2)
                    }
                    if (dockGeometry.configuredPanelAlignmentMode === "end") {
                        return parent.width - width
                            - dockGeometry.dockBackgroundHorizontalPadding
                    }
                    return dockGeometry.dockBackgroundHorizontalPadding
                }
                y: {
                    if (!root.inPanel) {
                        return Math.round((parent.height - height) / 2)
                    }
                    if (!dockGeometry.verticalPanel) {
                        if (dockConfig.customDockThemeActive) {
                            if (dockGeometry.panelLocation === PlasmaCore.Types.TopEdge) {
                                return Kirigami.Units.smallSpacing
                            }
                            return parent ? Math.max(0, parent.height - height - Kirigami.Units.smallSpacing) : 0
                        }
                        return Math.round((parent.height - height) / 2)
                    }
                    if (dockGeometry.configuredPanelAlignmentMode === "center") {
                        return Math.round((parent.height - height) / 2)
                    }
                    if (dockGeometry.configuredPanelAlignmentMode === "end") {
                        return parent.height - height
                            - dockGeometry.dockBackgroundVerticalPadding
                    }
                    return dockGeometry.dockBackgroundVerticalPadding
                }
                
                property int hoveredIndex: -1
                property real mouseOffset: 0.0
                property real pointerPrimaryAxis: -1
                property real lastPointerPrimaryAxis: -1
                readonly property bool wavePointerInsideLayout:
                    dockWaveHover.hovered

                // State used for smooth transitions when entering or leaving the dock.
                property int lastHoveredIndex: -1
                property real lastMouseOffset: 0.0
                property real hoverZoomProgress: hoveredIndex >= 0 ? 1.0 : 0.0
                property bool mediaMorphActive: false
                property bool launcherDropTransitionActive: false
                property double persistentDragLastWatchdogMs: 0
                property int persistentDragSourceIndex: -1
                property int persistentMoveModeIndex: -1
                property int persistentDragTargetIndex: -1
                property string persistentDragExpectedItemText: ""
                property var persistentDragSourceItem: null
                property point persistentDragPointerPosition:
                    Qt.point(0, 0)
                property string persistentDragIconName:
                    "application-x-executable"
                property bool persistentDragMovesDynamicApplications: false
                readonly property bool persistentDragActive:
                    persistentDragSourceIndex >= 0
                readonly property bool persistentMoveModeActive:
                    persistentMoveModeIndex >= 0
                readonly property string effectiveHoverAnimationMode:
                    persistentDragActive ? "none"
                        : dockConfig.dockHoverAnimation

                Timer {
                    id: persistentDragWatchdogTimer
                    interval: 3000
                    repeat: false
                    onTriggered: {
                        if (dockLayout.persistentDragActive) {
                            dockLayout.cancelPersistentDrag()
                        }
                    }
                }

                function cancelPersistentDrag() {
                    persistentDragWatchdogTimer.stop()
                    const sourceItem = persistentDragSourceItem
                    persistentDragSourceIndex = -1
                    persistentDragTargetIndex = -1
                    persistentDragExpectedItemText = ""
                    persistentDragSourceItem = null
                    persistentDragPointerPosition = Qt.point(0, 0)
                    persistentDragIconName = "application-x-executable"
                    persistentDragMovesDynamicApplications = false
                    persistentMoveModeIndex = -1
                    hoveredIndex = -1
                    lastHoveredIndex = -1
                    mouseOffset = 0.0
                    lastMouseOffset = 0.0
                    pointerPrimaryAxis = -1
                    lastPointerPrimaryAxis = -1
                    if (sourceItem
                            && sourceItem.releasePersistentReorderInteraction) {
                        sourceItem.releasePersistentReorderInteraction()
                    }
                    dockLayout.forceActiveFocus(Qt.OtherFocusReason)
                }

                function enterDynamicApplicationsMoveMode() {
                    const index = root.dynamicApplicationsMarkerIndex
                    const items = dockItemsController.dockItems || []
                    if (!Number.isInteger(index) || index < 0
                            || index >= items.length || !items[index]
                            || items[index].type !== "dynamic-applications") {
                        return false
                    }
                    popupCoordinator.closeAllPopups(null)
                    persistentMoveModeIndex = index
                    Qt.callLater(function() {
                        const handle = persistentDockItemsRepeater.itemAt(index)
                        if (handle && handle.focusItem) {
                            handle.focusItem()
                        }
                    })
                    return true
                }

                function beginPersistentDrag(sourceIndex, sourceItem) {
                    const index = Number(sourceIndex)
                    const items = dockItemsController.dockItems || []
                    if (persistentDragActive || !sourceItem
                            || !Number.isInteger(index)
                            || index < 0 || index >= items.length
                            || !items[index]
                            || items[index].type === "media") {
                        return false
                    }
                    if (!dockConfig.floatingItemDragReorderingEnabled
                            && persistentMoveModeIndex !== index) {
                        return false
                    }
                    popupCoordinator.closeAllPopups(null)
                    hoveredIndex = -1
                    lastHoveredIndex = -1
                    mouseOffset = 0.0
                    lastMouseOffset = 0.0
                    pointerPrimaryAxis = -1
                    lastPointerPrimaryAxis = -1
                    persistentDragSourceIndex = index
                    persistentDragTargetIndex = index
                    persistentDragExpectedItemText
                        = dockItemsController.canonicalJsonText(items[index])
                    persistentDragSourceItem = sourceItem
                    persistentDragIconName
                        = root.dockItemReorderIconName(items[index])
                    persistentDragMovesDynamicApplications
                        = items[index].type === "dynamic-applications"
                    persistentDragLastWatchdogMs = Date.now()
                    persistentDragWatchdogTimer.restart()
                    return persistentDragExpectedItemText.length > 0
                }

                function updatePersistentDrag(sourceItem, x, y) {
                    if (!persistentDragActive
                            || sourceItem !== persistentDragSourceItem) {
                        return
                    }
                    const now = Date.now()
                    if (now - persistentDragLastWatchdogMs >= 450) {
                        persistentDragWatchdogTimer.restart()
                        persistentDragLastWatchdogMs = now
                    }
                    const point = sourceItem.mapToItem(dockLayout, x, y)
                    persistentDragPointerPosition
                        = sourceItem.mapToItem(dockWrapper, x, y)
                    const primaryPosition = dockGeometry.verticalPanel
                        ? point.y : point.x
                    const itemCount = persistentDockItemsRepeater.count
                    let beforeIndex = itemCount
                    for (let index = 0; index < itemCount; index++) {
                        if (index === persistentDragSourceIndex) {
                            continue
                        }
                        const candidate = persistentDockItemsRepeater.itemAt(index)
                        if (!candidate) {
                            continue
                        }
                        const candidateCenter = dockGeometry.verticalPanel
                            ? candidate.y + candidate.height / 2
                            : candidate.x + candidate.width / 2
                        if (primaryPosition < candidateCenter) {
                            beforeIndex = index
                            break
                        }
                    }
                    let nextTarget = beforeIndex >= itemCount ? itemCount - 1
                        : beforeIndex > persistentDragSourceIndex
                            ? beforeIndex - 1 : beforeIndex
                    // Hysteresis prevents one-pixel oscillation between slots
                    // while the pointer crosses the midpoint of an icon.
                    if (nextTarget !== persistentDragTargetIndex) {
                        const neighbor = persistentDockItemsRepeater.itemAt(
                            Math.max(0, Math.min(itemCount - 1, nextTarget)))
                        if (neighbor) {
                            const center = dockGeometry.verticalPanel
                                ? neighbor.y + neighbor.height / 2
                                : neighbor.x + neighbor.width / 2
                            const deadZone = Math.min(7,
                                (dockGeometry.verticalPanel ? neighbor.height : neighbor.width) * 0.10)
                            if (Math.abs(primaryPosition - center) < deadZone)
                                return
                        }
                        persistentDragTargetIndex = nextTarget
                    }
                }

                function finishPersistentDrag() {
                    if (!persistentDragActive) {
                        return
                    }
                    persistentDragWatchdogTimer.stop()
                    const sourceIndex = persistentDragSourceIndex
                    const targetIndex = persistentDragTargetIndex
                    const expectedItemText = persistentDragExpectedItemText
                    cancelPersistentDrag()
                    if (!dockItemsController.movePersistentItem(
                            sourceIndex, targetIndex, expectedItemText)) {
                        console.warn("Oger Dock: Persistent item reorder was canceled because the configuration changed or could not be saved.")
                    }
                }

                function movePersistentItemFromKeyboard(modelIndex, delta) {
                    if (!dockConfig.floatingItemDragReorderingEnabled)
                        return
                    const sourceIndex = Number(modelIndex)
                    const targetIndex = sourceIndex + Number(delta)
                    const items = dockItemsController.dockItems || []
                    if (!Number.isInteger(sourceIndex)
                            || !Number.isInteger(targetIndex)
                            || sourceIndex < 0 || sourceIndex >= items.length
                            || targetIndex < 0 || targetIndex >= items.length
                            || !items[sourceIndex]) {
                        return
                    }
                    const expectedItemText
                        = dockItemsController.canonicalJsonText(items[sourceIndex])
                    if (dockItemsController.movePersistentItem(
                            sourceIndex, targetIndex, expectedItemText)
                            && persistentMoveModeIndex === sourceIndex) {
                        persistentMoveModeIndex = targetIndex
                        Qt.callLater(function() {
                            const handle = persistentDockItemsRepeater.itemAt(targetIndex)
                            if (handle && handle.focusItem) {
                                handle.focusItem()
                            }
                        })
                    }
                }

                Connections {
                    target: dockItemsController

                    function onConfigurationChanged() {
                        if (dockLayout.persistentDragActive) {
                            dockLayout.cancelPersistentDrag()
                        }
                    }
                }

                Connections {
                    target: dockConfig

                    function onFloatingItemDragReorderingEnabledChanged() {
                        if (!root.inPanel
                                && !dockConfig.floatingItemDragReorderingEnabled
                                && dockLayout.persistentDragActive) {
                            dockLayout.cancelPersistentDrag()
                        }
                    }
                }

                Connections {
                    target: root

                    function onInPanelChanged() {
                        if (!root.inPanel
                                && !dockConfig.floatingItemDragReorderingEnabled
                                && dockLayout.persistentDragActive) {
                            dockLayout.cancelPersistentDrag()
                        }
                    }
                }

                // Only the visible dock receives the wheel, not popup menus.
                // Keep the player's own volume/scroll interaction untouched.
                property real windowWheelRemainder: 0
                property int windowWheelDirection: 0
                // The gesture queue is drained in physical order. A fast wheel
                // event may contain multiple notches, and asynchronous TaskManager
                // activation must not cause us to skip or reorder them.
                property var windowWheelPendingDirections: []

                Timer {
                    id: windowWheelDrainTimer
                    interval: 95
                    repeat: false
                    onTriggered: dockLayout.drainWindowWheel()
                }

                Timer {
                    id: windowWheelResetTimer
                    interval: 700
                    repeat: false
                    onTriggered: {
                        dockLayout.windowWheelRemainder = 0
                        dockLayout.windowWheelDirection = 0
                    }
                }

                // Passive previews should not disable wheel navigation. Only
                // interactive menus/surfaces keep their own wheel gestures.
                readonly property bool wheelBlockedByPopup:
                    popupCoordinator.contextMenuVisible
                    || folderPopupDialog.visible
                    || calendarPopupDialog.visible
                    || trashMenuDialog.visible
                    || trashDockContentsDialog.visible
                    || notePopupDialog.visible
                    || taskOverflowDialog.visible
                    || (root.punchiMenuDialogInstance
                        && root.punchiMenuDialogInstance.visible)
                    || (root.controlCenterDialogInstance
                        && root.controlCenterDialogInstance.visible)

                // Keep scroll ownership with interactive dock elements.
                // mapFromItem() accounts for scaled/transformed icons during hover zoom.
                function wheelHitsItem(item, position) {
                    if (!item || !item.visible || !position) return false
                    const local = item.mapFromItem(dockLayout, position.x, position.y)
                    return item.contains(Qt.point(local.x, local.y))
                }

                function wheelOverMediaItem(position) {
                    for (let i = 0; i < persistentDockItemsRepeater.count; ++i) {
                        const item = persistentDockItemsRepeater.itemAt(i)
                        if (item && item.modelData && item.modelData.type === "media"
                                && wheelHitsItem(item, position)) return true
                    }
                    return false
                }

                // Never turn a folder fan's own scrolling into global Alt+Tab,
                // even while the folder popup is still animating into view.
                function wheelOverFolderItem(position) {
                    for (let i = 0; i < persistentDockItemsRepeater.count; ++i) {
                        const item = persistentDockItemsRepeater.itemAt(i)
                        if (item && item.modelData && item.modelData.type === "folder"
                                && wheelHitsItem(item, position)) return true
                    }
                    return root.recentContainerVisible
                        && wheelHitsItem(recentContainer, position)
                }

                // Do not process the same physical wheel input twice through
                // a child MouseArea and its ancestor WheelHandler.
                function wheelOverDockItem(position) {
                    const groups = [persistentDockItemsRepeater,
                        activeApplicationRepeater, trayApplicationRepeater,
                        recentApplicationRepeater]
                    for (const group of groups) {
                        if (!group) continue
                        for (let i = 0; i < group.count; ++i) {
                            if (wheelHitsItem(group.itemAt(i), position)) return true
                        }
                    }
                    return false
                }

                function drainWindowWheel() {
                    if (windowWheelPendingDirections.length === 0) return
                    if (wheelBlockedByPopup || persistentDragActive || !mainContainer.visible) {
                        windowWheelPendingDirections = []
                        return
                    }
                    const pending = windowWheelPendingDirections.slice()
                    const direction = pending.shift()
                    windowWheelPendingDirections = pending
                    if (taskController.canCycleOpenWindow()) {
                        const switched = taskController.cycleOpenWindow(direction)
                        if (switched && taskWindowsDialog.visible)
                            popupCoordinator.cancelTaskPopupForPointerReorder()
                    }
                    if (windowWheelPendingDirections.length > 0)
                        windowWheelDrainTimer.restart()
                }

                // Shared dispatch for background and icons. Every notch is
                // queued once; the timer serializes TaskManager transitions.
                function handleGlobalWindowWheel(delta, modifiers) {
                    const forbiddenModifiers = Qt.ControlModifier | Qt.AltModifier
                        | Qt.ShiftModifier | Qt.MetaModifier
                    if (Plasmoid.configuration.wheelSwitchWindowsEnabled === false
                            || !mainContainer.visible || persistentDragActive
                            || (modifiers & forbiddenModifiers) !== 0
                            || wheelBlockedByPopup
                            || !taskController.canCycleOpenWindow()) return false
                    if (!Number.isFinite(delta) || delta === 0) return false
                    // Follow Plasma's 15-degree/120-angle-unit convention,
                    // but retain high-resolution partial wheel movements.
                    const step = WheelInput.accumulate(windowWheelRemainder,
                        windowWheelDirection, delta, 120)
                    windowWheelDirection = step.direction
                    windowWheelRemainder = step.remainder
                    windowWheelResetTimer.restart()
                    if (!step.ready) return true
                    const reverse = Plasmoid.configuration.wheelSwitchWindowsReverse === true
                    const direction = (step.steps < 0 ? -1 : 1) * (reverse ? 1 : -1)
                    const queued = windowWheelPendingDirections.slice()
                    // Limit bursts to avoid a runaway backlog on faulty input
                    // devices, without dropping ordinary high-resolution scroll.
                    const availableSlots = Math.max(0, 24 - queued.length)
                    for (let i = 0; i < Math.min(Math.abs(step.steps), availableSlots); ++i)
                        queued.push(direction)
                    windowWheelPendingDirections = queued
                    if (!windowWheelDrainTimer.running)
                        drainWindowWheel()
                    return true
                }

                WheelHandler {
                    id: windowCycleWheel
                    enabled: Plasmoid.configuration.wheelSwitchWindowsEnabled !== false
                        && mainContainer.visible && !dockLayout.persistentDragActive
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    orientation: Qt.Vertical
                    onWheel: function(event) {
                        const position = windowCycleWheel.point.position
                        if (dockLayout.wheelOverMediaItem(position)
                                || dockLayout.wheelOverFolderItem(position)
                                || dockLayout.wheelOverDockItem(position)) {
                            event.accepted = false
                            return
                        }
                        const delta = WheelInput.signedDelta(
                            event.angleDelta.y, event.pixelDelta.y)
                        event.accepted = dockLayout.handleGlobalWindowWheel(
                            delta, event.modifiers)
                    }
                }

                HoverHandler {
                    id: dockWaveHover
                    // qmllint disable unqualified
                    enabled:
                        dockConfig.dockHoverAnimation === "wave"
                        && !dockLayout.persistentDragActive
                    // qmllint enable unqualified
                    readonly property point trackedPosition: point.position

                    function updateWavePointer() {
                        if (!hovered) {
                            return
                        }
                        const position = dockLayout.flow === GridLayout.TopToBottom
                            ? trackedPosition.y : trackedPosition.x
                        if (!Number.isFinite(position)) {
                            return
                        }
                        dockLayout.pointerPrimaryAxis = position
                        dockLayout.lastPointerPrimaryAxis = position
                    }

                    onTrackedPositionChanged: updateWavePointer()
                    onHoveredChanged: {
                        if (hovered) {
                            updateWavePointer()
                            return
                        }
                        dockLayout.hoveredIndex = -1
                        dockLayout.mouseOffset = 0.0
                    }
                }

                function beginMediaMorph(transitionDuration) {
                    mediaMorphActive = true
                    mediaMorphTimer.interval = Math.max(1, Number(transitionDuration) || 220)
                    mediaMorphTimer.restart()
                }

                Timer {
                    id: mediaMorphTimer
                    interval: 220
                    repeat: false
                    onTriggered: dockLayout.mediaMorphActive = false
                }

                onHoveredIndexChanged: {
                    if (hoveredIndex >= 0) {
                        lastHoveredIndex = hoveredIndex
                    }
                }
                onMouseOffsetChanged: {
                    if (hoveredIndex >= 0) {
                        lastMouseOffset = mouseOffset
                    }
                }

                Behavior on hoverZoomProgress {
                    enabled: Kirigami.Units.longDuration > 0
                    NumberAnimation {
                        duration: dockLayout.hoveredIndex >= 0
                            ? Math.max(80, Math.round(Kirigami.Units.shortDuration * 1.1))
                            : Math.max(60, Math.round(Kirigami.Units.shortDuration * 0.85))
                        easing.type: dockLayout.hoveredIndex >= 0 ? Easing.OutCubic : Easing.InQuad
                    }
                }

                signal trashUrlsDropped(var urls)
                onTrashUrlsDropped: function(urls) {
                    trashIntegration.trashUrls(urls)
                }

                Repeater {
                    id: persistentDockItemsRepeater
                    // A numeric model preserves DockItem objects when the same number
                    // of items is reordered. R19 bound the Repeater to a newly
                    // allocated JS array, destroying/recreating EVERY delegate.
                    model: dockItemsController.dockItems.length
                    delegate: DockItem {
                        id: dockItemDelegate
                        // Data tracks each index reactively, without resetting the model.
                        property var entryData: dockItemsController.dockItems[index] || ({})
                        required property int index
                        property int lastReportedMediaIndex: -1
                        function reportMediaTitleExtent(extent) {
                            if (!entryData || entryData.type !== "media") return
                            if (lastReportedMediaIndex >= 0
                                    && lastReportedMediaIndex !== index)
                                root.setMediaInlineTitleExtent(lastReportedMediaIndex, 0)
                            root.setMediaInlineTitleExtent(index, extent)
                            lastReportedMediaIndex = index
                        }
                        onIndexChanged: reportMediaTitleExtent(mediaInlineTitleExtent)
                        onEntryDataChanged: {
                            if (entryData && entryData.type === "media")
                                reportMediaTitleExtent(mediaInlineTitleExtent)
                        }
                        layoutController: dockLayout
                        clickCollisionController: dockLayout.clickCollision
                        Layout.column: dockGeometry.verticalPanel
                            ? 0 : root.persistentVisualIndex(dockItemDelegate.index)
                        Layout.row: dockGeometry.verticalPanel
                            ? root.persistentVisualIndex(dockItemDelegate.index) : 0
                        itemIndex: root.persistentVisualIndex(dockItemDelegate.index)
                        persistentModelIndex: dockItemDelegate.index
                        persistentReorderEnabled:
                            dockItemDelegate.entryData.type !== "media"
                        persistentPointerReorderEnabled:
                            dockItemDelegate.persistentReorderEnabled
                            && dockConfig.floatingItemDragReorderingEnabled
                        persistentMoveHandleVisible:
                            dockItemDelegate.entryData.type
                                === "dynamic-applications"
                            && dockLayout.persistentMoveModeIndex
                                === dockItemDelegate.index
                        persistentDirectReorderEnabled:
                            dockItemDelegate.persistentMoveHandleVisible
                        persistentReorderActive: dockLayout.persistentDragActive
                        persistentReorderSource: dockLayout.persistentDragSourceIndex
                            === dockItemDelegate.index
                        persistentReorderTarget: dockLayout.persistentDragActive
                            && dockLayout.persistentDragTargetIndex
                                === dockItemDelegate.index
                            && dockLayout.persistentDragSourceIndex
                                !== dockItemDelegate.index
                        persistentReorderInsertAfter:
                            dockLayout.persistentDragSourceIndex
                                < dockLayout.persistentDragTargetIndex
                        // Mac/Android-like neighbor slide without relayout or
                        // recreating the QML delegate on every pointer movement.
                        persistentReorderShift: {
                            if (!dockLayout.persistentDragActive) return 0
                            const src = dockLayout.persistentDragSourceIndex
                            const dst = dockLayout.persistentDragTargetIndex
                            const here = dockItemDelegate.index
                            if (here === src || src === dst) return 0
                            const source = dockLayout.persistentDragSourceItem
                            const extent = source ? (dockGeometry.verticalPanel
                                ? source.height + dockLayout.rowSpacing
                                : source.width + dockLayout.columnSpacing) : 0
                            if (src < dst && here > src && here <= dst) return -extent
                            if (src > dst && here >= dst && here < src) return extent
                            return 0
                        }
                        launcherModelInsertionIndex: dockItemDelegate.index
                        hoveredIndex: dockLayout.hoveredIndex
                        inPanel: root.inPanel
                        panelLocation: dockGeometry.effectivePanelLocation
                        iconSize: dockGeometry.effectiveIconSize
                        panelCrossAxisLimit: root.inPanel
                            ? dockGeometry.detectedPanelThickness : 0
                        // The media item's text preference belongs to entryData.
                        // qmllint disable unqualified
                        mediaMainAxisLength: dockGeometry.mediaItemMainAxisLengthForItem(dockItemDelegate.entryData)
                        mediaMaxInlineTitleExtent: Math.min(150,
                            dockGeometry.mediaTitleFreeSideExtent)
                        onMediaInlineExtentChanged: function(extent) {
                            dockItemDelegate.reportMediaTitleExtent(extent)
                        }
                        // qmllint enable unqualified
                        mediaItemShown: dockItemDelegate.entryData.type !== "media"
                            || dockGeometry.mediaItemVisibleForItem(dockItemDelegate.entryData)
                        launcherMenuOpen: dockItemDelegate.entryData.type === "punchimenu"
                            && !!root.punchiMenuDialogInstance
                            && root.punchiMenuDialogInstance.visible
                        folderOpen: dockItemDelegate.entryData.type === "folder"
                            && folderPopupDialog.visible
                            && folderPopupDialog.sourceAnchor === dockItemDelegate
                        folderPreviewEntries: dockItemDelegate.entryData.type === "folder"
                            ? (dockItemDelegate.entryData.apps || []) : []
                        mediaProgressDrivenByGeometry:
                            dockItemDelegate.entryData.type === "media"
                        mediaPresentationProgress: dockItemDelegate.entryData.type === "media"
                            ? dockGeometry.mediaVisibilityFactorForItem(dockItemDelegate.entryData)
                            : 1.0
                        mediaController: dockItemDelegate.entryData.type === "media"
                            ? dockMediaController
                            : null
                        mediaLaunchAvailable: dockItemDelegate.entryData.type === "media"
                            && String(dockItemDelegate.entryData.defaultPlayerStorageId || "").length > 0
                        mediaPinPreferences: root.mediaPinPreferences
                        onMediaPinRequested: function(identity, pinned) {
                            root.setMediaPinPreference(identity, pinned)
                        }
                        mediaDefaultPlayerName: dockItemDelegate.entryData.type === "media"
                            ? String(dockItemDelegate.entryData.defaultPlayerName || "")
                            : ""
                        mediaDefaultPlayerIcon: dockItemDelegate.entryData.type === "media"
                            ? String(dockItemDelegate.entryData.defaultPlayerIcon || "")
                            : ""
                        // The delegate model supplies entryData at runtime.
                        // qmllint disable unqualified
                        mediaTextMode: dockItemDelegate.entryData.type === "media"
                            ? String(dockItemDelegate.entryData.mediaTextMode || "automatic")
                            : "automatic"
                        mediaEntranceAnimation: String(
                            dockItemDelegate.entryData.mediaEntranceAnimation || "fade")
                        mediaShowCover: dockItemDelegate.entryData.mediaShowCover !== false
                        mediaShowTitle: dockItemDelegate.entryData.mediaShowTitle !== false
                        mediaShowControls: dockItemDelegate.entryData.mediaShowControls !== false
                        mediaShowProgress: dockItemDelegate.entryData.mediaShowProgress !== false
                        mediaShowVolume: dockItemDelegate.entryData.mediaShowVolume !== false
                        mediaBackgroundStyle: String(
                            dockItemDelegate.entryData.mediaBackgroundStyle || "artwork")
                        mediaDisplayMode: dockItemDelegate.entryData.type === "media"
                            ? String(dockItemDelegate.entryData.mediaDisplayMode || "normal")
                            : "normal"
                        mediaAutoCollapseDelaySeconds: dockItemDelegate.entryData.type === "media"
                            ? Number(dockItemDelegate.entryData.mediaAutoCollapseDelaySeconds === undefined
                                ? 3 : dockItemDelegate.entryData.mediaAutoCollapseDelaySeconds)
                            : 3
                        dockMotionSpeedPercent: dockConfig.dockMotionSpeedPercent
                        mediaMotionEnabled: dockConfig.menuAnimationStyle !== "none"
                            && dockConfig.dockHoverAnimation !== "none"
                        hoverScaleSetting: dockGeometry.effectivePanelHoverScale
                        hoverAnimationMode:
                            dockLayout.effectiveHoverAnimationMode
                        clickEffect: dockConfig.dockClickEffect
                        windowMinimizeEffect: dockConfig.dockWindowMinimizeEffect
                        taskMinimizedCount: taskState.minimizedCount
                        taskMaximizedCount: taskState.maximizedCount
                        minimizeReactionRevision: dockItemsController.minimizeReactionRevision
                        minimizeReactionTargetIndex: dockItemsController.minimizeReactionTargetIndex
                        showItemHoverBackground: dockConfig.dockShowItemHoverBackground
                        iconReflectionEnabled: dockConfig.dockIconReflectionsEnabled
                        iconReflectionOpacity: dockConfig.dockIconReflectionOpacity
                        iconReflectionAvailableExtent: dockGeometry.panelReflectionAvailableExtent
                        // qmllint enable unqualified
                        // The delegate is compiled as a nested component by
                        // qmllint; these bindings resolve the owning plasmoid at runtime.
                        // qmllint disable unqualified
                        positionTransitionEnabled: dockItemsController.itemTransitionActive
                        animateEntry: {
                            const appId = taskController.dockItemApplicationId(dockItemDelegate.entryData)
                            const launcherUrl = taskController.dockItemLauncherUrl(dockItemDelegate.entryData)
                            return (dockItemsController.recentlyTransitionedAppId.length > 0
                                    && appId === dockItemsController.recentlyTransitionedAppId)
                                || (dockItemsController.recentlyTransitionedLauncherUrl.length > 0
                                    && launcherUrl === dockItemsController.recentlyTransitionedLauncherUrl)
                        }
                        // qmllint enable unqualified
                        // qmllint disable unqualified
                        showPersistentLabel: dockConfig.dockShowLabels
                        textShadowsEnabled: dockConfig.dockTextShadowsEnabled
                        calendarTextShadowsEnabled: dockItemDelegate.entryData.calendarTextShadowsEnabled !== false
                        labelFontSize: dockConfig.dockLabelFontSize
                        indicatorType: dockConfig.dockIndicatorType
                        indicatorPosition: dockConfig.dockIndicatorPosition
                        indicatorColor: dockConfig.dockIndicatorColor
                        // qmllint disable unqualified
                        indicatorThickness: dockConfig.dockIndicatorThickness
                        indicatorOpacity: dockConfig.dockIndicatorOpacity
                        indicatorNeonEnabled: dockConfig.dockIndicatorNeonEnabled
                        indicatorNeonIntensity: dockConfig.dockIndicatorNeonIntensity
                        windowCountBadgeEnabled: dockConfig.windowCountBadgeEnabled
                        windowCountBadgePosition: dockConfig.windowCountBadgePosition
                        windowGroupingEnabled: taskController.groupingEnabled()
                        windowCountEmblemColor: dockConfig.windowCountEmblemColor
                        windowCountEmblemOpacity: dockConfig.windowCountEmblemOpacity
                        windowCountEmblemScale: dockConfig.windowCountEmblemScale
                        // qmllint enable unqualified
                        customSeparatorEnabled: dockConfig.customDockSeparatorActive
                        separatorTheme: dockConfig.customDockSeparatorTheme
                        // qmllint enable unqualified
                        
                        // Wave animation state.
                        hoverZoomProgress: dockLayout.hoverZoomProgress
                        lastHoveredIndex: dockLayout.lastHoveredIndex
                        lastMouseOffset: dockLayout.lastMouseOffset
                        readonly property int taskRevision: root.taskVisualRevision
                        readonly property var taskState: {
                            taskRevision
                            return taskController.taskStateForDockItem(dockItemDelegate.entryData)
                        }
                        
                        itemType: dockItemDelegate.entryData.type || "app"
                        folderCategoryColors: root.folderCategoryColors
                        folderAccentColor: String(dockItemDelegate.entryData.folderAccentColor || "")
                        folderSourceCategory: dockItemDelegate.entryData.sourceType === "category"
                            ? String(dockItemDelegate.entryData.sourceCategory || "") : ""
                        timeTextScale: dockItemDelegate.entryData.timeTextScale === undefined ? (dockItemDelegate.entryData.textScale === undefined ? 1.0 : dockItemDelegate.entryData.textScale) : dockItemDelegate.entryData.timeTextScale
                        dateTextScale: dockItemDelegate.entryData.dateTextScale === undefined ? (dockItemDelegate.entryData.textScale === undefined ? 1.0 : dockItemDelegate.entryData.textScale) : dockItemDelegate.entryData.dateTextScale
                        separatorStyleSetting: dockItemDelegate.entryData.separatorStyle || "line"
                        separatorThicknessSetting: dockItemDelegate.entryData.separatorThickness === undefined ? 2 : dockItemDelegate.entryData.separatorThickness
                        separatorLengthRatioSetting: dockItemDelegate.entryData.separatorLengthRatio === undefined ? 0.72 : dockItemDelegate.entryData.separatorLengthRatio
                        separatorOpacitySetting: dockItemDelegate.entryData.separatorOpacity === undefined ? 0.34 : dockItemDelegate.entryData.separatorOpacity
                        separatorGlowSetting: dockItemDelegate.entryData.separatorGlowEnabled === true
                        separatorAppearanceSourceSetting:
                            ConfigItemsJS.normalizedSeparatorAppearanceSource(
                                dockItemDelegate.entryData)
                        separatorVisibleSetting:
                            dockItemDelegate.entryData.showSeparator !== false
                        iconName: dockItemDelegate.entryData.type === "trash" && dockItemDelegate.entryData.showState !== false
                            ? (dockItemsController.trashHasItems ? (dockItemDelegate.entryData.fullIcon || "user-trash-full") : (dockItemDelegate.entryData.icon || "user-trash"))
                            : (dockItemDelegate.entryData.icon || "")
                        itemName: dockItemDelegate.entryData.name || ""
                        itemCommand: dockItemDelegate.entryData.command || ""
                        pinnedApplicationLauncher:
                            dockItemDelegate.entryData.type === "app"
                        // Share one cached notifier identity with both states.
                        readonly property string matchedNotifierId:
                            dockItemDelegate.entryData.type === "app"
                                ? root.trayDesktopIdForItem(dockItemDelegate.entryData)
                                : ""
                        readonly property bool hasMatchedNotifier:
                            root.trayIdentityRevision >= 0
                            && matchedNotifierId.length > 0
                            && trayWindowBridge.containsDesktopEntry(matchedNotifierId)
                        trayOnlyExecution: dockItemDelegate.entryData.type === "app"
                            && taskState.count === 0 && hasMatchedNotifier
                        taskIndicatorCount: dockItemDelegate.entryData.type === "trash"
                            ? (trashDockContentsDialog.visible
                                && trashDockContentsDialog.sourceAnchor === dockItemDelegate ? 1 : 0)
                            : (taskState.count > 0 ? taskState.count
                                : (dockItemDelegate.entryData.type === "app"
                                    && hasMatchedNotifier ? 1 : 0))
                        taskIsActive: dockItemDelegate.entryData.type === "trash"
                            ? (trashDockContentsDialog.visible
                                && trashDockContentsDialog.sourceAnchor === dockItemDelegate)
                            : taskState.isActive
                        taskDemandsAttention: taskState.demandsAttention
                        // Popup ids belong to the owning full representation.
                        // qmllint disable unqualified
                        suppressTooltip: mainContainer.contextMenuVisible
                            || (taskWindowsDialog.visible && popupCoordinator.taskPopupVisualParent === dockItemDelegate)
                            || (folderPopupDialog.visible && folderPopupDialog.sourceAnchor === dockItemDelegate)
                            || (calendarPopupDialog.visible && calendarPopupDialog.visualParent === dockItemDelegate)
                            || (notePopupDialog.visible && notePopupDialog.visualParent === dockItemDelegate)
                            || (trashMenuDialog.visible && trashMenuDialog.sourceAnchor === dockItemDelegate)
                            || (appActionsDialog.visible && appActionsDialog.sourceAnchor === dockItemDelegate)
                            || (root.punchiMenuDialogInstance && root.punchiMenuDialogInstance.visible && root.punchiMenuAnchorItem === dockItemDelegate)
                            || (root.controlCenterDialogInstance
                                && root.controlCenterDialogInstance.visible
                                && root.controlCenterAnchorItem
                                    === dockItemDelegate)
                        // qmllint enable unqualified
                        supportsContextMenu: dockContextActionsController.itemHasContextMenu(dockItemDelegate.entryData, taskState.rows, "pinned")
                        mediaHoverControlsEnabled: dockConfig.mediaControlsOnHover && taskState.count > 0
                        // qmllint disable unqualified
                        externalDropEnabled: dockItemDelegate.entryData.type === "app"
                            && dockConfig.appDragAndDropEnabled
                        launcherDropEnabled: true
                        launcherDropValidator: function(urls) {
                            return dockItemsController.validateApplicationLauncherDrop(urls)
                        }
                        launcherContainerDropTarget:
                            dockItemDelegate.entryData.type === "folder"
                        launcherContainerDropEnabled:
                            dockItemDelegate.launcherContainerDropTarget
                            && (dockItemDelegate.entryData.sourceType
                                || "manual") === "manual"
                        externalDropActivationEnabled: taskState.count > 0
                            && !taskState.isActive
                        externalDropActivator: function() {
                            return taskController.activateTaskRowsForExternalDrop(taskState.rows)
                        }
                        // qmllint enable unqualified

                        // The delegate is compiled separately and these handlers
                        // intentionally retain its owning plasmoid and model row.
                        // qmllint disable unqualified
                        Component.onCompleted: {
                            if (dockItemDelegate.entryData.type === "punchimenu") {
                                root.punchiMenuAnchorItem = dockItemDelegate
                            } else if (dockItemDelegate.entryData.type
                                    === "control-center") {
                                root.controlCenterAnchorItem = dockItemDelegate
                            }
                        }
                        Component.onDestruction: {
                            if (dockItemDelegate.lastReportedMediaIndex >= 0)
                                root.setMediaInlineTitleExtent(
                                    dockItemDelegate.lastReportedMediaIndex, 0)
                            if (root.punchiMenuAnchorItem === dockItemDelegate) {
                                root.punchiMenuAnchorItem = null
                            }
                            if (root.controlCenterAnchorItem
                                    === dockItemDelegate) {
                                root.controlCenterAnchorItem = null
                            }
                        }
                        // qmllint enable unqualified

                        // qmllint disable unqualified
                        TaskDelegateGeometryPublisher {
                            taskModelController: taskController
                            targetItem: dockItemDelegate.taskGeometryItem
                            taskRows: dockItemDelegate.taskState.rows
                            publicationEnabled: taskGeometryOwnership.ownsTaskGeometry
                        }
                        // qmllint enable unqualified
                        
                        onItemClicked: function(cmd) {
                            if (dockItemDelegate.entryData.type === "folder") {
                                popupCoordinator.openFolderPopup(dockItemDelegate.entryData, dockItemDelegate)
                            } else if (dockItemDelegate.entryData.type === "trash") {
                                if (trashDockContentsDialog.visible) {
                                    trashDockContentsDialog.closeSafely()
                                } else {
                                    popupCoordinator.closeAllPopups(null)
                                    trashIntegration.refresh()
                                    trashDockContentsDialog.setPopupAnchor(dockItemDelegate)
                                    trashDockContentsDialog.openSafely()
                                }
                            } else if (dockItemDelegate.entryData.type === "calendar") {
                                popupCoordinator.openCalendarPopup(dockItemDelegate.entryData, dockItemDelegate)
                            } else if (dockItemDelegate.entryData.type === "note") {
                                popupCoordinator.openNotePopup(dockItemDelegate.entryData, dockItemDelegate, dockItemDelegate.index)
                            } else if (dockItemDelegate.entryData.type === "punchimenu") {
                                popupCoordinator.closeAllPopups(null)
                                root.togglePunchiMenu(dockItemDelegate)
                            } else if (dockItemDelegate.entryData.type
                                    === "control-center") {
                                popupCoordinator.closeAllPopups(null)
                                root.toggleControlCenter(dockItemDelegate)
                            } else {
                                popupCoordinator.closeAllPopups(null)
                                const entry = dockItemDelegate.entryData
                                const hasTrayOnly = entry.type === "app"
                                    && taskState.count === 0
                                    && trayWindowBridge.containsDesktopEntry(root.trayDesktopIdForItem(entry))
                                // Explicit click grants SNI tracking, never registration alone.
                                trayWindowBridge.noteUserInteraction(root.trayDesktopIdForItem(entry))
                                if (hasTrayOnly)
                                    root.activateTrayDesktopEntry(
                                        root.trayDesktopIdForItem(entry), dockItemDelegate)
                                else
                                    dockItemsController.handleDockItemActivation(entry, dockItemDelegate)
                            }
                        }
                        // qmllint disable unqualified
                        onTaskMinimized: function(minimizedItemIndex) {
                            dockItemsController.triggerMinimizeReaction(minimizedItemIndex)
                        }
                        onExternalUrlsDropped: function(urls, visualParent) {
                            root.handleApplicationUrlsDrop(
                                dockItemDelegate.entryData, taskState.rows,
                                urls, visualParent, popupCoordinator)
                        }
                        onApplicationLauncherDropped: function(urls, insertionIndex) {
                            dockItemsController.pinApplicationLauncherAt(
                                urls, insertionIndex)
                        }
                        onApplicationLauncherContainerDropped: function(
                                urls, visualParent) {
                            root.handleContainerApplicationLauncherDrop(
                                urls, dockItemDelegate.index,
                                dockItemsController.canonicalJsonText(
                                    dockItemDelegate.entryData), visualParent,
                                popupCoordinator)
                        }
                        onPersistentReorderPressStarted: {
                            popupCoordinator.cancelTaskPopupForPointerReorder()
                        }
                        onPersistentReorderStarted: function(modelIndex, visualParent) {
                            dockLayout.beginPersistentDrag(modelIndex, visualParent)
                        }
                        onPersistentReorderMoved: function(x, y) {
                            dockLayout.updatePersistentDrag(dockItemDelegate, x, y)
                        }
                        onPersistentReorderFinished: dockLayout.finishPersistentDrag()
                        onPersistentReorderCanceled: dockLayout.cancelPersistentDrag()
                        onPersistentMoveModeCanceled: dockLayout.cancelPersistentDrag()
                        onPersistentKeyboardMoveRequested: function(modelIndex, delta) {
                            dockLayout.movePersistentItemFromKeyboard(modelIndex, delta)
                        }
                        onMediaLaunchRequested: {
                            root.launchConfiguredMediaPlayer(dockItemDelegate.entryData, false)
                        }
                        onMediaPlaybackLaunchRequested: {
                            root.launchConfiguredMediaPlayer(dockItemDelegate.entryData, true)
                        }
                        onMediaExpansionChanged: function(expanded, transitionDuration) {
                            root.mediaItemExpanded = expanded
                            dockLayout.beginMediaMorph(transitionDuration)
                        }
                        // qmllint enable unqualified
                        onContextMenuRequested: function(visualParent, keyboardInvoked) {
                            if (dockItemDelegate.entryData.type === "trash") {
                                // R6: actions now live in the primary Trash popup.
                                return
                            } else {
                                const desktopId = root.trayDesktopIdForItem(
                                    dockItemDelegate.entryData)
                                // R18: an actual tray-backed application owns its
                                // right-click menu. Fetch its DBusMenu directly;
                                // don't bury it under a second generic dock menu.
                                // Closed applications have no SNI by definition.
                                // A missing window is NOT evidence of a tray process.
                                // Keep their regular dock context menu available,
                                // regardless of the dock's drag-lock state.
                                if (!keyboardInvoked && desktopId.length > 0
                                        && trayWindowBridge.containsDesktopEntry(desktopId)) {
                                    root.openPinnedTrayActions(desktopId, visualParent)
                                    return
                                }
                                if (dockContextActionsController.itemHasContextMenu(
                                        dockItemDelegate.entryData, taskState.rows, "pinned")) {
                                    popupCoordinator.openAppContextMenu(dockItemDelegate.entryData, visualParent,
                                        taskState.rows, "pinned", dockItemDelegate.index)
                                }
                            }
                        }
                        onHoverEntered: function(visualParent) {
                            if (dockItemDelegate.entryData.type === "folder") {
                                popupCoordinator.requestFolderHoverSwitch(
                                    dockItemDelegate.entryData, visualParent, false)
                            }
                            if ((dockConfig.mediaControlsOnHover || dockConfig.windowPreviewStyle !== "none")
                                    && taskState.count > 0) {
                                popupCoordinator.scheduleTaskWindowsPopup(dockItemDelegate.entryData.name || "",
                                    taskState.rows, visualParent, false,
                                    dockConfig.windowPreviewStyle !== "none")
                            }
                        }
                        onMediaControlsRequested: function(visualParent) {
                            popupCoordinator.scheduleTaskWindowsPopup(dockItemDelegate.entryData.name || "",
                                taskState.rows, visualParent, true, false)
                        }
                        onHoverExited: function(visualParent) {
                            popupCoordinator.cancelFolderHoverSwitch(visualParent)
                            popupCoordinator.cancelPendingTaskWindowsPopup(visualParent)
                        }
                    }
                }

                Repeater {
                    id: activeApplicationRepeater
                    model: root.visibleTaskRows
                    delegate: DockItem {
                        id: taskDockItemDelegate
                        layoutController: dockLayout
                        clickCollisionController: dockLayout.clickCollision
                        required property var modelData
                        required property int index
                        readonly property int taskRevision: root.taskVisualRevision
                        readonly property var taskData: {
                            taskRevision
                            return taskController.taskDataForEntry(modelData)
                        }
                        // The original visual entry carries the verified
                        // tray promotion ID. Also retain the decoded task
                        // field as fallback if a future projection changes.
                        readonly property string effectiveTemporaryTrayId:
                            String(modelData.temporaryTrayId
                                || taskData.temporaryTrayId || "")
                        readonly property bool temporaryTrayPresentation:
                            effectiveTemporaryTrayId.length > 0
                        onTemporaryTrayPresentationChanged: {
                            if (!temporaryTrayPresentation) return
                            // If the task was just promoted while hovering,
                            // cancel previews scheduled before the SNI identity
                            // arrived. Never let them steal MEGA popup focus.
                            popupCoordinator.cancelPendingTaskWindowsPopup(taskDockItemDelegate)
                            if (popupCoordinator.taskPopupVisualParent === taskDockItemDelegate)
                                popupCoordinator.closeTaskWindowsPopup(false)
                        }

                        Component.onCompleted: {
                            // Hover previews are forbidden for temporarily
                            // promoted SNI popups (R63.5).
                            if (!temporaryTrayPresentation)
                                popupCoordinator.scheduleDynamicTaskPopupOwnerRestore(
                                    taskDockItemDelegate, taskData.rows)
                        }

                        Layout.column: dockGeometry.verticalPanel
                            ? 0 : root.dynamicVisualIndex(taskDockItemDelegate.index)
                        Layout.row: dockGeometry.verticalPanel
                            ? root.dynamicVisualIndex(taskDockItemDelegate.index) : 0
                        itemIndex: root.dynamicVisualIndex(taskDockItemDelegate.index)
                        launcherModelInsertionIndex:
                            root.dynamicLauncherInsertionIndex()
                        hoveredIndex: dockLayout.hoveredIndex
                        inPanel: root.inPanel
                        panelLocation: dockGeometry.effectivePanelLocation
                        iconSize: dockGeometry.effectiveIconSize
                        panelCrossAxisLimit: root.inPanel
                            ? dockGeometry.detectedPanelThickness : 0
                        hoverScaleSetting: dockGeometry.effectivePanelHoverScale
                        // qmllint disable unqualified
                        hoverAnimationMode:
                            dockLayout.effectiveHoverAnimationMode
                        persistentReorderActive:
                            dockLayout.persistentDragActive
                        persistentReorderGroupMember:
                            dockLayout.persistentDragMovesDynamicApplications
                        // qmllint enable unqualified
                        dockMotionSpeedPercent: dockConfig.dockMotionSpeedPercent
                        clickEffect: dockConfig.dockClickEffect
                        // qmllint disable unqualified
                        windowMinimizeEffect: dockConfig.dockWindowMinimizeEffect
                        taskMinimizedCount: taskData.minimizedCount
                        taskMaximizedCount: taskData.maximizedCount
                        minimizeReactionRevision: dockItemsController.minimizeReactionRevision
                        minimizeReactionTargetIndex: dockItemsController.minimizeReactionTargetIndex
                        showItemHoverBackground: dockConfig.dockShowItemHoverBackground
                        iconReflectionEnabled: dockConfig.dockIconReflectionsEnabled
                        iconReflectionOpacity: dockConfig.dockIconReflectionOpacity
                        iconReflectionAvailableExtent: dockGeometry.panelReflectionAvailableExtent
                        // qmllint enable unqualified
                        // qmllint disable unqualified
                        positionTransitionEnabled: dockItemsController.itemTransitionActive
                        taskPopupTracksVisualArea: true
                        animateEntry: {
                            const appIds = modelData.appIds instanceof Array
                                ? modelData.appIds
                                : [String(modelData.appId || "")]
                            const launcherUrls = modelData.launcherUrls instanceof Array
                                ? modelData.launcherUrls
                                : [String(modelData.launcherUrl || "")]
                            return (dockItemsController.recentlyTransitionedAppId.length > 0
                                    && appIds.indexOf(dockItemsController.recentlyTransitionedAppId) >= 0)
                                || (dockItemsController.recentlyTransitionedLauncherUrl.length > 0
                                    && launcherUrls.indexOf(dockItemsController.recentlyTransitionedLauncherUrl) >= 0)
                        }
                        // qmllint enable unqualified
                        // qmllint disable unqualified
                        showPersistentLabel: dockConfig.dockShowLabels
                        textShadowsEnabled: dockConfig.dockTextShadowsEnabled
                        labelFontSize: dockConfig.dockLabelFontSize
                        indicatorType: dockConfig.dockIndicatorType
                        indicatorPosition: dockConfig.dockIndicatorPosition
                        indicatorColor: dockConfig.dockIndicatorColor
                        // qmllint disable unqualified
                        indicatorThickness: dockConfig.dockIndicatorThickness
                        indicatorOpacity: dockConfig.dockIndicatorOpacity
                        indicatorNeonEnabled: dockConfig.dockIndicatorNeonEnabled
                        indicatorNeonIntensity: dockConfig.dockIndicatorNeonIntensity
                        windowCountBadgeEnabled: dockConfig.windowCountBadgeEnabled
                        windowCountBadgePosition: dockConfig.windowCountBadgePosition
                        windowGroupingEnabled: taskController.groupingEnabled()
                        windowCountEmblemColor: dockConfig.windowCountEmblemColor
                        windowCountEmblemOpacity: dockConfig.windowCountEmblemOpacity
                        windowCountEmblemScale: dockConfig.windowCountEmblemScale
                        // qmllint enable unqualified
                        hoverZoomProgress: dockLayout.hoverZoomProgress
                        lastHoveredIndex: dockLayout.lastHoveredIndex
                        lastMouseOffset: dockLayout.lastMouseOffset

                        itemType: "app"
                        iconName: taskData.icon
                        itemName: taskData.name
                        taskIndicatorCount: taskData.count
                        taskIsActive: taskData.active
                        taskDemandsAttention: taskData.demandsAttention
                        // Popup ids belong to the owning full representation.
                        // qmllint disable unqualified
                        suppressTooltip: temporaryTrayPresentation
                            || mainContainer.contextMenuVisible
                            || (taskWindowsDialog.visible && popupCoordinator.taskPopupVisualParent === taskDockItemDelegate)
                            || (folderPopupDialog.visible && folderPopupDialog.sourceAnchor === taskDockItemDelegate)
                            || (calendarPopupDialog.visible && calendarPopupDialog.visualParent === taskDockItemDelegate)
                            || (notePopupDialog.visible && notePopupDialog.visualParent === taskDockItemDelegate)
                            || (trashMenuDialog.visible && trashMenuDialog.sourceAnchor === taskDockItemDelegate)
                            || (appActionsDialog.visible && appActionsDialog.sourceAnchor === taskDockItemDelegate)
                            || (root.punchiMenuDialogInstance && root.punchiMenuDialogInstance.visible && root.punchiMenuAnchorItem === taskDockItemDelegate)
                        // qmllint enable unqualified
                        supportsContextMenu: dockContextActionsController.itemHasContextMenu(modelData, taskData.rows, "dynamic")
                        mediaHoverControlsEnabled: !temporaryTrayPresentation
                            && dockConfig.mediaControlsOnHover && taskData.count > 0
                        externalDropEnabled: dockConfig.appDragAndDropEnabled
                        // qmllint disable unqualified
                        launcherDropEnabled: true
                        launcherDropValidator: function(urls) {
                            return dockItemsController.validateApplicationLauncherDrop(urls)
                        }
                        externalDropActivationEnabled: taskData.count > 0
                            && !taskData.active
                        externalDropActivator: function() {
                            return taskController.activateTaskRowsForExternalDrop(taskData.rows)
                        }
                        // qmllint enable unqualified

                        // qmllint disable unqualified
                        TaskDelegateGeometryPublisher {
                            taskModelController: taskController
                            targetItem: taskDockItemDelegate.taskGeometryItem
                            taskRows: taskDockItemDelegate.taskData.rows
                            publicationEnabled: taskGeometryOwnership.ownsTaskGeometry
                        }
                        // qmllint enable unqualified

                        onItemClicked: function() {
                            popupCoordinator.closeAllPopups(null)
                            const desktopId = root.trayDesktopIdForItem(modelData)
                            trayWindowBridge.noteUserInteraction(desktopId)
                            const promotedId = effectiveTemporaryTrayId
                            if (promotedId && taskController.isTrayTemporarilyPromoted(promotedId)) {
                                // Click, never hover, toggles the native popup
                                // or KDE-managed window without killing MEGA.
                                taskController.togglePromotedTrayApplication(
                                    promotedId, taskData.rows, function() {
                                        return root.activateTrayDesktopEntry(
                                            promotedId, taskDockItemDelegate)
                                    })
                                return
                            }
                            if (taskData.count > 1) {
                                taskController.activatePreferredTaskRow(taskData.rows)
                            } else if (taskData.firstRow >= 0) {
                                taskController.activateTaskRow(taskData.firstRow)
                            }
                        }
                        // qmllint disable unqualified
                        onTaskMinimized: function(minimizedItemIndex) {
                            dockItemsController.triggerMinimizeReaction(minimizedItemIndex)
                        }
                        onExternalUrlsDropped: function(urls, visualParent) {
                            root.handleApplicationUrlsDrop(
                                modelData, taskData.rows, urls, visualParent)
                        }
                        onApplicationLauncherDropped: function(urls, insertionIndex) {
                            dockItemsController.pinApplicationLauncherAt(
                                urls, root.dynamicLauncherInsertionIndex())
                        }
                        // qmllint enable unqualified
                        onContextMenuRequested: function(visualParent) {
                            const desktopId = root.trayDesktopIdForItem(modelData)
                            // A dynamic app may also own a StatusNotifierItem.
                            // Native SNI actions take priority on right-click.
                            if (desktopId.length > 0
                                    && trayWindowBridge.containsDesktopEntry(desktopId)) {
                                root.openPinnedTrayActions(desktopId, visualParent,
                                    effectiveTemporaryTrayId)
                                return
                            }
                            popupCoordinator.openAppContextMenu(modelData, visualParent,
                                taskData.rows, "dynamic", -1)
                        }
                        onHoverEntered: function(visualParent) {
                            // Do not create another Wayland popup while the
                            // MEGA SNI popup is visible: it can lose focus and
                            // close without any click from the user.
                            if (temporaryTrayPresentation) return
                            if ((dockConfig.mediaControlsOnHover || dockConfig.windowPreviewStyle !== "none")
                                    && taskData.count > 0) {
                                popupCoordinator.scheduleTaskWindowsPopup(itemName,
                                    taskData.rows, visualParent, false,
                                    dockConfig.windowPreviewStyle !== "none")
                            }
                        }
                        onMediaControlsRequested: function(visualParent) {
                            if (temporaryTrayPresentation) return
                            popupCoordinator.scheduleTaskWindowsPopup(itemName,
                                taskData.rows, visualParent, true, false)
                        }
                        onHoverExited: function(visualParent) {
                            popupCoordinator.cancelPendingTaskWindowsPopup(visualParent)
                        }
                    }
                }

                // Overflow is a synthetic entry. It participates in
                // the same layout as regular dock items but never enters the
                // persistent or reorderable dock-items model.
                // qmllint disable unqualified
                DockItem {
                    id: taskOverflowDockItem
                    visible: root.overflowTaskRows.length > 0
                    layoutController: dockLayout
                    clickCollisionController: dockLayout.clickCollision
                    Layout.column: dockGeometry.verticalPanel
                        ? 0 : root.dynamicVisualIndex(root.visibleTaskRows.length)
                    Layout.row: dockGeometry.verticalPanel
                        ? root.dynamicVisualIndex(root.visibleTaskRows.length) : 0
                    Layout.preferredWidth: root.inPanel
                        ? dockGeometry.panelItemWidth : implicitWidth
                    Layout.preferredHeight: root.inPanel
                        ? dockGeometry.panelItemHeight : implicitHeight
                    itemIndex: root.dynamicVisualIndex(root.visibleTaskRows.length)
                    launcherModelInsertionIndex:
                        root.dynamicLauncherInsertionIndex()
                    hoveredIndex: dockLayout.hoveredIndex
                    inPanel: root.inPanel
                    panelLocation: dockGeometry.effectivePanelLocation
                    iconSize: dockGeometry.effectiveIconSize
                    panelCrossAxisLimit: root.inPanel
                        ? dockGeometry.detectedPanelThickness : 0
                    hoverScaleSetting: dockGeometry.effectivePanelHoverScale
                    hoverAnimationMode:
                        dockLayout.effectiveHoverAnimationMode
                    persistentReorderActive:
                        dockLayout.persistentDragActive
                    persistentReorderGroupMember:
                        dockLayout.persistentDragMovesDynamicApplications
                    dockMotionSpeedPercent: dockConfig.dockMotionSpeedPercent
                    clickEffect: dockConfig.dockClickEffect
                    windowMinimizeEffect: dockConfig.dockWindowMinimizeEffect
                    taskMinimizedCount: {
                        root.taskVisualRevision
                        return taskController.minimizedCountForRows(
                            taskController.taskRowsForEntries(root.overflowTaskRows))
                    }
                    minimizeReactionRevision: dockItemsController.minimizeReactionRevision
                    minimizeReactionTargetIndex: dockItemsController.minimizeReactionTargetIndex
                    showItemHoverBackground: dockConfig.dockShowItemHoverBackground
                    iconReflectionEnabled: false
                    positionTransitionEnabled: dockItemsController.itemTransitionActive
                    hoverZoomProgress: dockLayout.hoverZoomProgress
                    lastHoveredIndex: dockLayout.lastHoveredIndex
                    lastMouseOffset: dockLayout.lastMouseOffset
                    itemType: "overflow"
                    iconName: "view-grid"
                    itemName: i18np("%1 more window group", "%1 more window groups",
                        root.overflowTaskRows.length)
                    taskIndicatorCount: root.overflowTaskRows.length
                    launcherDropEnabled: true
                    launcherDropValidator: function(urls) {
                        return dockItemsController.validateApplicationLauncherDrop(urls)
                    }

                    TaskDelegateGeometryPublisher {
                        taskModelController: taskController
                        targetItem: taskOverflowDockItem.taskGeometryItem
                        taskRows: taskController.taskRowsForEntries(root.overflowTaskRows)
                        publicationEnabled: taskGeometryOwnership.ownsTaskGeometry
                    }

                    onItemClicked: popupCoordinator.openTaskOverflowPopup(taskOverflowDockItem)
                    onTaskMinimized: function(minimizedItemIndex) {
                        dockItemsController.triggerMinimizeReaction(minimizedItemIndex)
                    }
                    onApplicationLauncherDropped: function(urls, insertionIndex) {
                        dockItemsController.pinApplicationLauncherAt(
                            urls, root.dynamicLauncherInsertionIndex())
                    }
                }
                RecentApplicationDockItem {
                    id: recentSeparator
                    objectName: "recentApplicationsSeparator"
                    visible: root.recentSeparatorVisible
                    descriptor: ({ "type": "separator" })
                    configState: dockConfig
                    geometryState: dockGeometry
                    layoutController: dockLayout
                    clickCollisionController: dockLayout.clickCollision
                    itemIndex: root.recentVisualIndex(0)
                    Layout.column: dockGeometry.verticalPanel ? 0 : itemIndex
                    Layout.row: dockGeometry.verticalPanel ? itemIndex : 0
                    hoveredIndex: dockLayout.hoveredIndex
                    hoverAnimationMode: dockLayout.effectiveHoverAnimationMode
                    hoverZoomProgress: dockLayout.hoverZoomProgress
                    lastHoveredIndex: dockLayout.lastHoveredIndex
                    lastMouseOffset: dockLayout.lastMouseOffset
                }
                RecentApplicationDockItem {
                    id: recentContainer
                    objectName: "recentApplicationsContainer"
                    visible: root.recentContainerVisible
                    descriptor: root.recentContainerDescriptor
                    configState: dockConfig
                    geometryState: dockGeometry
                    layoutController: dockLayout
                    clickCollisionController: dockLayout.clickCollision
                    itemIndex: root.recentVisualIndex(root.recentSeparatorVisible ? 1 : 0)
                    Layout.column: dockGeometry.verticalPanel ? 0 : itemIndex
                    Layout.row: dockGeometry.verticalPanel ? itemIndex : 0
                    hoveredIndex: dockLayout.hoveredIndex
                    hoverAnimationMode: dockLayout.effectiveHoverAnimationMode
                    hoverZoomProgress: dockLayout.hoverZoomProgress
                    lastHoveredIndex: dockLayout.lastHoveredIndex
                    lastMouseOffset: dockLayout.lastMouseOffset
                    supportsContextMenu: dockContextActionsController.itemHasContextMenu(
                        descriptor, [], "recent-container")
                    suppressTooltip: mainContainer.contextMenuVisible
                    onItemClicked: popupCoordinator.openFolderPopup(descriptor, recentContainer)
                    onContextMenuRequested: function(visualParent) {
                        popupCoordinator.openAppContextMenu(descriptor, visualParent,
                            [], "recent-container", -1)
                    }
                    onVisibleChanged: {
                        if (!visible && popupCoordinator.activeFolderData.entryRole === "recent-container") {
                            popupCoordinator.hidePopupDialog(folderPopupDialog)
                        }
                    }
                }
                // Notifiers without a visible taskbar window or a pinned dock item.
                // These are native StatusNotifierItem endpoints, never launches.
                Repeater {
                    id: trayApplicationRepeater
                    model: root.visibleTrayEntries
                    delegate: DockItem {
                        id: trayDockItem
                        required property var modelData
                        required property int index
                        objectName: "trayApplication-" + index
                        layoutController: dockLayout
                        clickCollisionController: dockLayout.clickCollision
                        itemIndex: root.dynamicVisualIndex(root.visibleTaskRows.length
                            + root.renderedOverflowItemCount + index)
                        Layout.column: dockGeometry.verticalPanel ? 0 : itemIndex
                        Layout.row: dockGeometry.verticalPanel ? itemIndex : 0
                        hoveredIndex: dockLayout.hoveredIndex
                        hoverZoomProgress: dockLayout.hoverZoomProgress
                        lastHoveredIndex: dockLayout.lastHoveredIndex
                        lastMouseOffset: dockLayout.lastMouseOffset
                        inPanel: root.inPanel
                        panelLocation: dockGeometry.effectivePanelLocation
                        iconSize: dockGeometry.effectiveIconSize
                        hoverScaleSetting: dockGeometry.effectivePanelHoverScale
                        hoverAnimationMode: dockLayout.effectiveHoverAnimationMode
                        itemType: "app"
                        iconName: String(modelData.icon || "application-x-executable")
                        itemName: String(modelData.title || modelData.desktopId || "Tray application")
                        trayOnlyExecution: true
                        taskIndicatorCount: 1
                        taskIsActive: false
                        taskMinimizedCount: 1
                        indicatorType: dockConfig.dockIndicatorType
                        indicatorPosition: dockConfig.dockIndicatorPosition
                        indicatorColor: dockConfig.dockIndicatorColor
                        indicatorThickness: dockConfig.dockIndicatorThickness
                        indicatorOpacity: dockConfig.dockIndicatorOpacity
                        indicatorNeonEnabled: dockConfig.dockIndicatorNeonEnabled
                        indicatorNeonIntensity: dockConfig.dockIndicatorNeonIntensity
                        supportsContextMenu: true
                        onItemClicked: {
                            const desktopId = String(modelData.desktopId || "")
                            trayWindowBridge.noteUserInteraction(desktopId)
                            if (taskController.isTrayTemporarilyPromoted(desktopId)) {
                                taskController.togglePromotedTrayApplication(
                                    desktopId, [], function() {
                                        return root.activateTrayDesktopEntry(desktopId, trayDockItem)
                                    })
                            } else {
                                root.activateTrayDesktopEntry(desktopId, trayDockItem)
                            }
                        }
                        onContextMenuRequested: function() {
                            const trayId = String(modelData.desktopId || "")
                            root.openPinnedTrayActions(trayId, trayDockItem,
                                taskController.isTrayTemporarilyPromoted(trayId)
                                    ? trayId : "")
                        }
                        // The wheel belongs to DockItem, not to a competing SNI
                        // handler. The unified root popup is anchored to this item.

                    }
                }

                Repeater {
                    id: recentApplicationRepeater
                    model: dockConfig.showRecentApplications ? dockConfig.recentApplicationsCount : 0
                    delegate: RecentApplicationDockItem {
                        id: recentItem
                        required property int index
                        objectName: "recentApplication-" + index
                        visible: !root.recentContainerVisible && index < root.visibleRecentApplicationCount
                        descriptor: root.recentApplications[index] || ({})
                        configState: dockConfig
                        geometryState: dockGeometry
                        layoutController: dockLayout
                        clickCollisionController: dockLayout.clickCollision
                        itemIndex: root.recentVisualIndex((root.recentSeparatorVisible ? 1 : 0) + index)
                        Layout.column: dockGeometry.verticalPanel ? 0 : itemIndex
                        Layout.row: dockGeometry.verticalPanel ? itemIndex : 0
                        hoveredIndex: dockLayout.hoveredIndex
                        hoverAnimationMode: dockLayout.effectiveHoverAnimationMode
                        hoverZoomProgress: dockLayout.hoverZoomProgress
                        lastHoveredIndex: dockLayout.lastHoveredIndex
                        lastMouseOffset: dockLayout.lastMouseOffset
                        supportsContextMenu: true
                        suppressTooltip: mainContainer.contextMenuVisible
                        onItemClicked: dockItemsController.handleDockItemActivation(descriptor)
                        onContextMenuRequested: function(visualParent) {
                            popupCoordinator.openAppContextMenu(descriptor, visualParent, [], "recent", -1)
                        }
                    }
                }
                // qmllint enable unqualified

            }

            DockReorderDragLayer {
                id: dockReorderDragLayer
                anchors.fill: parent
                z: 20
                active: dockLayout.persistentDragActive
                pointerPosition:
                    dockLayout.persistentDragPointerPosition
                iconName: dockLayout.persistentDragIconName
                iconSize: dockGeometry.effectiveIconSize
                motionEnabled: Kirigami.Units.longDuration > 0
            }
        }

        GuardedPopupDialog {
            id: folderPopupDialog
            // Close/cancel before the first animation must also release the
            // R45 pre-open fence, rather than waiting for the safety timer.
            onVisibleChanged: {
                if (!visible) taskController.endFanPresentationHold("popup-closed")
                if (!visible) popupCoordinator.abortFolderHoverSwitch()
            }
            location: dockGeometry.effectivePanelLocation
            hideOnWindowDeactivate: true
            onBlurReapplyRequested: folderPopupBlurController.reapply()

            property Item sourceAnchor: null
            readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
                sourceAnchor: folderPopupDialog.sourceAnchor
                popup: folderPopupDialog
                gap: dockGeometry.folderPopupGap
                location: folderPopupDialog.location
                preserveHorizontalAnchorCenter: true
                preserveVerticalAnchorCenter: true
                targetSurface: folderSurfaceStack
                targetTranslationX: folderPopupAnimatedContent.contentTranslationX
                targetTranslationY: folderPopupAnimatedContent.contentTranslationY
                deferRepositionDuringReveal: root.fanRevealCritical
                horizontalAnchorOffset:
                    folderPopupContent.layoutMode === "fan"
                    ? folderSurfaceStack.width / 2
                        - (folderSurfaceStack.contentFramePadding
                            + folderPopupContent.fanOriginIconCenterX)
                    : 0
            }

            function setPopupAnchor(anchor) {
                folderPopupDialog.sourceAnchor = anchor
                folderPopupDialog.popupSpacing.refreshAnchor()
            }

            readonly property Punchi.BlurBehindController folderPopupBlurController:
                Punchi.BlurBehindController {
                    window: folderPopupDialog
                    restoreAfterFrame: true
                    fullWindow: false
                    maskSource: folderSurfaceStack.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: folderSurfaceStack.backgroundBlurMaskOffset
                    additionalMaskPolygon:
                        folderSurfaceStack.backgroundBlurAdditionalMaskPolygon
                    enabled: folderPopupDialog.visible
                        && folderSurfaceStack.backgroundBlurEnabled
                        && folderSurfaceStack.backgroundBlurMaskPresent
                        && dockConfig.popupBackgroundBlurEnabled
                        && systemDiscovery.kwinBlurSafe
                }

            mainItem: PopupAnimatedContent {
                id: folderPopupAnimatedContent
                popupVisible: folderPopupDialog.visible
                // R34: the fan has its own per-row reveal. Avoid applying a
                // redundant whole-popup opacity/scale pass as well.
                contentHandlesReveal: folderPopupContent.layoutMode === "fan"
                onCloseAnimationFinished: popupCoordinator.finishFolderHoverSwitch()
                // qmllint disable unqualified
                animationStyle: dockConfig.folderFanMotionStyle === "none"
                    && folderPopupContent.layoutMode === "fan"
                    ? "none" : dockConfig.popupAnimationStyle
                animationSpeedPercent: dockConfig.popupAnimationSpeedPercent
                animationIntensityPercent: dockConfig.popupAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                ContextSurfaceStack {
                    id: folderSurfaceStack
                    blurTransformSurface: folderPopupAnimatedContent.transformSurfaceItem
                    blurTranslationX: folderPopupAnimatedContent.contentTranslationX
                    blurTranslationY: folderPopupAnimatedContent.contentTranslationY
                    maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                    showMedia: false
                    // Folder profiles use different widths. Resolve the final
                    // geometry before mapping the dialog so Plasma can center
                    // it against visualParent without an intermediate width.
                    contentGeometryTransitionsEnabled: false
                    drawContentBackground:
                        folderPopupContent.layoutMode !== "fan"
                    // Comic-style tail, composed from the same theme frame that
                    // draws the background. The three classic presentations of the
                    // folder popup ask for it — grid, list and detailed — and the
                    // fan stays out, because it draws no card background of its
                    // own and its alignment belongs to its arc. The accepted
                    // layouts are listed one by one on purpose: a layout added
                    // later must not inherit the tail without a review. The side is
                    // the dock edge: popupDirection is the edge the popup grows
                    // away from and would put the tail at the far side of the popup.
                    edgeTailEnabled: ["grid", "list", "detailed"].indexOf(folderPopupContent.layoutMode) >= 0
                    edgeTailLocation: dockGeometry.spectrumOriginEdge
                    constrainEdgeTailTip: !folderSurfaceStack.edgeTailHorizontal
                    // Fan has no tail. Do not map an anchor across Qt windows
                    // for every progress tick when the entire tail is disabled.
                    edgeTailTipOffset: folderSurfaceStack.edgeTailEnabled
                        && !folderSurfaceStack.edgeTailHorizontal
                        ? folderPopupDialog.popupSpacing.sourceCenterInTarget.y : NaN
                    // The tail is as wide as the dock item it points at.
                    edgeTailAnchorExtent: folderPopupDialog.sourceAnchor
                        ? Math.min(
                            Number(folderPopupDialog.sourceAnchor.width || 0),
                            Number(folderPopupDialog.sourceAnchor.height || 0))
                        : 0
                    backgroundBlurEnabled:
                        folderPopupContent.layoutMode !== "fan"
                    backgroundImagePath: "widgets/background"
                    backgroundOpacity: dockConfig.folderPopupBackgroundOpacity
                    contentFramePaddingPercent: 2
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing

                    FolderPopup {
                        id: folderPopupContent
                        objectName: "folderPopupContent"
                        sessionActive: folderPopupDialog.visible
                        folderItem: popupCoordinator.activeFolderData.entryRole === "recent-container"
                            ? root.recentContainerDescriptor : popupCoordinator.activeFolderData
                        animationStyle: folderPopupAnimatedContent.animationStyle
                        animationIntensityPercent:
                            folderPopupAnimatedContent.animationIntensityPercent
                        popupDirection: folderPopupAnimatedContent.popupDirection
                        revealProgress: folderPopupAnimatedContent.openingProgress
                        // Keep the same fading curve as R33, but apply it to
                        // individual fan entries rather than the whole surface.
                        fanOuterOpacity: folderPopupAnimatedContent.contentHandlesReveal
                            && folderPopupAnimatedContent.animationStyle !== "none"
                            ? Math.min(1, folderPopupAnimatedContent.initialOpacity
                                + folderPopupAnimatedContent.openingProgress
                                    * (1 - folderPopupAnimatedContent.initialOpacity))
                            : 1
                        layoutMode: ["list", "detailed", "fan"].indexOf(folderPopupContent.folderItem.layout) >= 0
                            ? folderPopupContent.folderItem.layout
                            : "grid"
                        // qmllint disable unqualified
                        profileIconSize: folderPopupContent.layoutMode === "fan"
                            ? dockConfig.folderFanIconSize
                            : (folderPopupContent.layoutMode === "list"
                            ? dockConfig.folderListIconSize
                            : (folderPopupContent.layoutMode === "detailed"
                                ? dockConfig.folderDetailedIconSize
                                : dockConfig.folderGridIconSize))
                        profileAutoLayout: dockConfig.folderGridAutoLayout
                        profileColumns: dockConfig.folderGridColumns
                        profileRows: folderPopupContent.layoutMode === "fan"
                            ? dockConfig.folderFanRows
                            : (folderPopupContent.layoutMode === "list"
                            ? dockConfig.folderListRows
                            : (folderPopupContent.layoutMode === "detailed"
                                ? dockConfig.folderDetailedRows
                                : dockConfig.folderGridRows))
                        profileShowLabels: folderPopupContent.layoutMode === "fan"
                            ? dockConfig.folderFanShowLabels
                            : (folderPopupContent.layoutMode === "list"
                            ? dockConfig.folderListShowLabels
                            : (folderPopupContent.layoutMode === "detailed"
                                ? dockConfig.folderDetailedShowLabels
                                : dockConfig.folderGridShowLabels))
                        profileFontFamily: folderPopupContent.layoutMode === "fan"
                            ? dockConfig.folderFanFontFamily
                            : (folderPopupContent.layoutMode === "list"
                            ? dockConfig.folderListFontFamily
                            : (folderPopupContent.layoutMode === "detailed"
                                ? dockConfig.folderDetailedFontFamily
                                : dockConfig.folderGridFontFamily))
                        profileFontSize: folderPopupContent.layoutMode === "fan"
                            ? dockConfig.folderFanFontSize
                            : (folderPopupContent.layoutMode === "list"
                            ? dockConfig.folderListFontSize
                            : (folderPopupContent.layoutMode === "detailed"
                                ? dockConfig.folderDetailedFontSize
                                : dockConfig.folderGridFontSize))
                        profileFanScrollEnabled: dockConfig.folderFanScrollEnabled
                        profileFanMotionStyle: dockConfig.folderFanMotionStyle
                        profileScale: dockConfig.folderPopupScale
                        showHeaderLabel: dockConfig.folderPopupShowHeader
                        textShadowsEnabled: dockConfig.popupTextShadowsEnabled
                        textShadowPercent: dockConfig.folderPopupTextShadowPercent
                        maximumAvailableWidth: dockGeometry.taskPopupAvailableWidth
                        maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                        // The fan sizes its arc from the height the display
                        // really offers, so its invisible frame never grows past
                        // the screen and it shows the rows that fit.
                        maximumSurfaceHeight: dockGeometry.folderFanAvailableHeight
                        folderOpenerName: dockItemsController.folderOpenerName
                        // qmllint enable unqualified

                        onAppLaunched: function(app) {
                            folderPopupDialog.closeSafely()
                            dockItemsController.launchDockItem(app)
                        }

                        onAppContextMenuRequested: function(app) {
                            popupCoordinator.openAppContextMenu(app,
                                folderPopupDialog.sourceAnchor, undefined,
                                app.entryRole === "recent" ? "recent" : "folder", -1)
                        }

                        // The container opens its own folder in the file manager.
                        // The popup closes first, exactly like a launch.
                        onOpenLocationRequested: function(path) {
                            folderPopupDialog.closeSafely()
                            dockItemsController.openLocation(path)
                        }

                        onCloseRequested: folderPopupDialog.closeSafely()
                    }
                }
            }
        }

        // R35 frame-pacing telemetry for the folder fan. Samples swaps only
        // during the active reveal, not during the time the popup stays open.
        // One summary on close; no logs, JS allocations or writes per frame.
        QtObject {
            id: folderFanFrameProbe
            property double lastFrameMs: 0
            property double revealStartMs: 0
            property int firstSwapDelayMs: -1
            // Unlike firstSwapDelayMs (first ANIMATED swap), this measures
            // the first visible swap even while openingPending is true.
            property int firstPresentedSwapDelayMs: -1
            property int revealStartDelayMs: -1
            property string releaseSource: ""
            property int deferredRepositionAtStart: 0
            property int appliedRepositionAtStart: 0
            property int frames: 0
            property int slowFrames: 0
            property real longestFrameMs: 0
            property real totalFrameMs: 0
            property int trayAtStart: 0
            property string trayObservationAtStart: "enabled"
            property string taskObservationAtStart: "enabled"
            property int taskDeferredEventsAtStart: 0
            property int taskReconciliationsAtStart: 0
            property bool taskHoldAtStart: false
            property int taskHoldCountAtStart: 0
            property int maximizedAtStart: 0
            property int activeMaximizedAtStart: 0
            property int trayRevisionsDuringOpen: 0
            function clear() {
                trayAtStart = trayWindowBridge.observedEntries.length
                trayObservationAtStart = trayWindowBridge.diagnosticObservationEnabled
                    ? "enabled" : "suspended"
                taskObservationAtStart = taskController.diagnosticTaskObservationEnabled
                    ? "enabled" : "suspended"
                taskDeferredEventsAtStart = taskController.fanDeferredEventCount
                taskReconciliationsAtStart = taskController.fanReconciliations
                taskHoldAtStart = taskController.fanPresentationHold
                taskHoldCountAtStart = taskController.fanPresentationHoldCount
                maximizedAtStart = root.lastMaximizedWindowCount
                activeMaximizedAtStart = root.lastActiveMaximizedWindowCount
                trayRevisionsDuringOpen = 0
                lastFrameMs = 0
                revealStartMs = Date.now()
                firstSwapDelayMs = -1
                firstPresentedSwapDelayMs = -1
                revealStartDelayMs = -1
                releaseSource = ""
                deferredRepositionAtStart = folderPopupDialog.popupSpacing.deferredRepositionCount
                appliedRepositionAtStart = folderPopupDialog.popupSpacing.appliedRepositionCount
                frames = 0
                slowFrames = 0
                longestFrameMs = 0
                totalFrameMs = 0
            }
            function frame() {
                const now = Date.now()
                if (folderPopupContent.layoutMode === "fan"
                        && firstPresentedSwapDelayMs < 0)
                    firstPresentedSwapDelayMs = Math.max(0, now - revealStartMs)
                const animated = folderPopupContent.layoutMode === "fan"
                    && !folderPopupAnimatedContent.closing
                    && !folderPopupAnimatedContent.openingPending
                    && folderPopupAnimatedContent.openingProgress > 0.001
                    && folderPopupAnimatedContent.openingProgress < 0.999
                if (!animated) {
                    lastFrameMs = 0
                    return
                }
                if (firstSwapDelayMs < 0)
                    firstSwapDelayMs = Math.max(0, now - revealStartMs)
                if (lastFrameMs > 0) {
                    const dt = now - lastFrameMs
                    frames++
                    totalFrameMs += dt
                    if (dt > 25) slowFrames++
                    if (dt > longestFrameMs) longestFrameMs = dt
                }
                lastFrameMs = now
            }
            function finish() {
                if (frames <= 0) return
                console.info("Punchi fan R40 frame-pacing: frames", frames,
                    "diagnostic-version", "R45",
                    "tray-observation", trayObservationAtStart,
                    "task-observation", taskObservationAtStart,
                    "task-reveal-guard", "preopen-presentation-fence",
                    "task-hold-at-start", taskHoldAtStart,
                    "task-hold-session", taskHoldCountAtStart,
                    "task-deferred-events", Math.max(0, taskController.fanDeferredEventCount - taskDeferredEventsAtStart),
                    "task-deferred-flushes", Math.max(0, taskController.fanReconciliations - taskReconciliationsAtStart),
                    "slow-over-25ms", slowFrames,
                    "worst-ms", Math.round(longestFrameMs),
                    "avg-ms", Math.round(totalFrameMs / frames),
                    "tray-entries", trayWindowBridge.observedEntries.length,
                    "tray-at-start", trayAtStart,
                    "maximized-at-start", maximizedAtStart,
                    "active-maximized-at-start", activeMaximizedAtStart,
                    "tray-revisions", trayRevisionsDuringOpen,
                    // Historic first-swap-delay-ms was the first *animated*
                    // frame, not necessarily the popup's first presented frame.
                    "first-swap-delay-ms", firstSwapDelayMs,
                    "first-presented-swap-delay-ms", firstPresentedSwapDelayMs,
                    // Correct Qt meaning: queued for display, not proof of
                    // physical presentation by the Wayland compositor.
                    "first-queued-swap-delay-ms", firstPresentedSwapDelayMs,
                    "reveal-start-delay-ms", revealStartDelayMs,
                    "reveal-release-source", releaseSource,
                    "native-repositions-deferred",
                    folderPopupDialog.popupSpacing.deferredRepositionCount - deferredRepositionAtStart,
                    "native-repositions-applied",
                    folderPopupDialog.popupSpacing.appliedRepositionCount - appliedRepositionAtStart)
            }
        }
        Connections {
            target: folderPopupAnimatedContent.Window.window
            enabled: folderPopupDialog.visible
            function onFrameSwapped() { folderFanFrameProbe.frame() }
        }
        Connections {
            target: folderPopupAnimatedContent
            enabled: folderPopupDialog.visible
            function onOpeningPendingChanged() {
                if (!folderPopupAnimatedContent.openingPending
                        && folderFanFrameProbe.revealStartDelayMs < 0
                        && folderPopupContent.layoutMode === "fan") {
                    folderFanFrameProbe.revealStartDelayMs = Math.max(0,
                        Date.now() - folderFanFrameProbe.revealStartMs)
                    // Capture before closing changes popupVisible and resets
                    // the reveal source; the diagnosis refers to this open.
                    folderFanFrameProbe.releaseSource =
                        folderPopupAnimatedContent.openingReleaseSource
                }
            }
        }
        Connections {
            target: trayWindowBridge
            enabled: folderPopupDialog.visible
            function onEntriesChanged() {
                if (folderPopupContent.layoutMode === "fan"
                        && !folderPopupAnimatedContent.openingPending
                        && !folderPopupAnimatedContent.closing
                        && folderPopupAnimatedContent.openingProgress > 0.001
                        && folderPopupAnimatedContent.openingProgress < 0.999)
                    folderFanFrameProbe.trayRevisionsDuringOpen++
            }
        }
        Connections {
            target: folderPopupDialog
            function onVisibleChanged() {
                if (folderPopupDialog.visible) folderFanFrameProbe.clear()
                else folderFanFrameProbe.finish()
            }
        }

        // Calendar popup.
        PlasmaCore.AppletPopup {
            id: calendarPopupDialog
            popupDirection: popupCoordinator.popupDirection
            margin: dockGeometry.popupMargin
            floating: !root.inPanel
            removeBorderStrategy: root.inPanel
                ? PlasmaCore.AppletPopup.AtScreenEdges | PlasmaCore.AppletPopup.AtPanelEdges
                : PlasmaCore.AppletPopup.AtScreenEdges
            visible: false
            hideOnWindowDeactivate: true
            // The calendar always uses the native KDE theme background, like Kickoff.
            backgroundHints: PlasmaCore.AppletPopup.StandardBackground

            mainItem: PopupAnimatedContent {
                popupVisible: calendarPopupDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.popupAnimationStyle
                animationSpeedPercent: dockConfig.popupAnimationSpeedPercent
                animationIntensityPercent: dockConfig.popupAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                CalendarPopup {
                    showWeekNumbers: popupCoordinator.activeCalendarData.showWeekNumbers === undefined
                        ? true
                        : popupCoordinator.activeCalendarData.showWeekNumbers
                    popupScale: popupCoordinator.activeCalendarData.popupScale === undefined
                        ? 1.0
                        : Number(popupCoordinator.activeCalendarData.popupScale || 1.0)
                    // Reset the popup to the current date whenever it opens.
                    Component.onCompleted: {
                        displayedDate = new Date()
                        updateGrid()
                    }
                    onCloseRequested: {
                        calendarPopupDialog.visible = false
                    }
                }
            }
        }

        // A real dock-owned trash popup, anchored to the trash launcher.
        // Dolphin is never launched merely by clicking the trash icon.
        GuardedPopupDialog {
            id: trashDockContentsDialog
            objectName: "trashDockContentsDialog"
            location: dockGeometry.effectivePanelLocation
            hideOnWindowDeactivate: true
            onVisibleChanged: {
                // Closing without confirming must discard the confirmation
                // even when a window-deactivation closes the Plasma dialog.
                // The component itself preserves any KIO job already started.
                if (!visible && mainItem)
                    mainItem.resetTransientState()
            }
            property Item sourceAnchor: null
            readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
                sourceAnchor: trashDockContentsDialog.sourceAnchor
                popup: trashDockContentsDialog
                gap: dockGeometry.contextMenuGap
                location: trashDockContentsDialog.location
            }
            function setPopupAnchor(anchor) {
                sourceAnchor = anchor
                popupSpacing.refreshAnchor()
            }
            mainItem: TrashContentsPopup {
                popupActive: trashDockContentsDialog.visible
                trashIntegration: trashIntegration
                onCloseRequested: trashDockContentsDialog.closeSafely()
                onOpenInFileManagerRequested: {
                    trashDockContentsDialog.closeSafely()
                    trashIntegration.openTrash()
                }
            }
        }

        // Trash context menu popup.
        GuardedPopupDialog {
            id: trashMenuDialog
            location: dockGeometry.effectivePanelLocation
            // The secondary trash context menu must also close on outside
            // clicks while its confirmation is pending.
            hideOnWindowDeactivate: true
            onVisibleChanged: {
                if (!visible && !trashIntegration.emptying) {
                    trashSuccessCloseTimer.stop()
                    trashContextContent.showMenu(false)
                    trashIntegration.resetOperationState()
                }
            }
            onBlurReapplyRequested: trashMenuBlurController.reapply()

            property Item sourceAnchor: null
            readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
                sourceAnchor: trashMenuDialog.sourceAnchor
                popup: trashMenuDialog
                gap: dockGeometry.contextMenuGap
                location: trashMenuDialog.location
            }

            function setPopupAnchor(anchor) {
                trashMenuDialog.sourceAnchor = anchor
                trashMenuDialog.popupSpacing.refreshAnchor()
            }

            readonly property Punchi.BlurBehindController trashMenuBlurController:
                Punchi.BlurBehindController {
                    window: trashMenuDialog
                    restoreAfterFrame: true
                    fullWindow: false
                    maskSource: trashSurfaceStack.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: trashSurfaceStack.backgroundBlurMaskOffset
                    enabled: trashMenuDialog.visible
                        && trashSurfaceStack.backgroundBlurEnabled
                        && trashSurfaceStack.backgroundBlurMaskPresent
                        && dockConfig.contextMenuBackgroundBlurEnabled
                }

            mainItem: PopupAnimatedContent {
                id: trashMenuAnimatedContent
                popupVisible: trashMenuDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.menuAnimationStyle
                // A lixeira usa uma entrada ligeiramente mais lenta, sem alterar os demais menus.
                animationSpeedPercent: Math.min(80, dockConfig.menuAnimationSpeedPercent)
                animationIntensityPercent: dockConfig.menuAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                ContextSurfaceStack {
                    id: trashSurfaceStack
                    blurTransformSurface: trashMenuAnimatedContent.transformSurfaceItem
                    blurTranslationX: trashMenuAnimatedContent.contentTranslationX
                    blurTranslationY: trashMenuAnimatedContent.contentTranslationY
                    showMedia: false
                    maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                    drawContentBackground: true
                    backgroundImagePath: "widgets/background"
                    backgroundOpacity: dockConfig.contextMenuBackgroundOpacity
                    contentFramePaddingPercent: 2
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing

                    TrashContextPopup {
                        id: trashContextContent
                        // qmllint disable unqualified
                        operationState: trashIntegration.operationState
                        progressPercent: trashIntegration.progressPercent
                        progressDeterminate: trashIntegration.progressDeterminate
                        processedItems: trashIntegration.processedItems
                        totalItems: trashIntegration.totalItems
                        errorMessage: trashIntegration.errorMessage
                        transitionSpeedPercent: dockConfig.contextMenuTransitionSpeed
                        menuWidth: dockConfig.contextMenuWidth
                        menuRowHeight: dockConfig.contextMenuRowHeight
                        menuIconSize: dockConfig.contextMenuIconSize
                        menuTextShadowsEnabled: dockConfig.menuTextShadowsEnabled
                        maximumAvailableWidth: dockGeometry.taskPopupAvailableWidth
                        maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                        onOpenTrashRequested: {
                            trashMenuDialog.closeSafely()
                            trashIntegration.openTrash()
                        }
                        onEmptyTrashRequested: {
                            trashIntegration.emptyTrash()
                        }
                        onCloseRequested: {
                            trashSuccessCloseTimer.stop()
                            trashMenuDialog.closeSafely()
                            if (!trashIntegration.emptying) {
                                trashIntegration.resetOperationState()
                                trashContextContent.showMenu()
                            }
                        }
                        // qmllint enable unqualified
                    }
                }
            }
        }

        GuardedPopupDialog {
            id: appActionsDialog
            location: dockGeometry.effectivePanelLocation
            hideOnWindowDeactivate: !popupCoordinator.contextMenuOpening
            onOpenFailed: popupCoordinator.contextMenuOpening = false
            onBlurReapplyRequested: appActionsBlurController.reapply()

            property Item sourceAnchor: null
            readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
                sourceAnchor: appActionsDialog.sourceAnchor
                popup: appActionsDialog
                gap: dockGeometry.contextMenuGap
                location: appActionsDialog.location
            }

            function setPopupAnchor(anchor) {
                appActionsDialog.sourceAnchor = anchor
                appActionsDialog.popupSpacing.refreshAnchor()
            }

            readonly property Punchi.BlurBehindController appActionsBlurController:
                Punchi.BlurBehindController {
                    window: appActionsDialog
                    restoreAfterFrame: true
                    fullWindow: false
                    maskSource: appActionsSurfaceStack.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: appActionsSurfaceStack.backgroundBlurMaskOffset
                    enabled: appActionsDialog.visible
                        && appActionsSurfaceStack.backgroundBlurEnabled
                        && appActionsSurfaceStack.backgroundBlurMaskPresent
                        && dockConfig.contextMenuBackgroundBlurEnabled
                }

            mainItem: PopupAnimatedContent {
                id: appActionsAnimatedContent
                popupVisible: appActionsDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.menuAnimationStyle
                animationSpeedPercent: dockConfig.menuAnimationSpeedPercent
                animationIntensityPercent: dockConfig.menuAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                ContextSurfaceStack {
                    id: appActionsSurfaceStack
                    blurTransformSurface: appActionsAnimatedContent.transformSurfaceItem
                    blurTranslationX: appActionsAnimatedContent.contentTranslationX
                    blurTranslationY: appActionsAnimatedContent.contentTranslationY
                    showMedia: false
                    maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                    drawContentBackground: true
                    backgroundImagePath: "widgets/background"
                    backgroundOpacity: dockConfig.contextMenuBackgroundOpacity
                    contentFramePaddingPercent: 2
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing

                    AppActionsPopup {
                        id: appActionsContent
                        itemName: popupCoordinator.activeAppContextMenuData.name || ""
                        actions: popupCoordinator.activeAppContextMenuData.actions || []
                        // qmllint disable unqualified
                        maxVisibleRows: Number(
                            popupCoordinator.activeAppContextMenuData.maxVisibleRows) > 0
                            ? Number(popupCoordinator.activeAppContextMenuData.maxVisibleRows)
                            : dockConfig.contextMenuVisibleRows
                        rowHeight: dockConfig.contextMenuRowHeight
                        iconSize: dockConfig.contextMenuIconSize
                        targetWidth: dockConfig.contextMenuWidth
                        textShadowsEnabled: dockConfig.menuTextShadowsEnabled
                        maximumAvailableWidth: dockGeometry.taskPopupAvailableWidth
                        maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                        // qmllint enable unqualified

                        onActionTriggered: function(action) {
                            if (action && action.kind === "openTrayAppMenu") {
                                const desktopId = String(action.desktopId || "")
                                const visualAnchor = appActionsDialog.sourceAnchor
                                appActionsDialog.closeSafely()
                                root.openPinnedTrayActions(desktopId, visualAnchor)
                                return
                            }
                            appActionsDialog.closeSafely()
                            dockContextActionsController.triggerAction(action)
                        }
                        onCloseRequested: {
                            appActionsDialog.closeSafely()
                        }
                    }
                }
            }
        }

        // R23: the Wayland-native Plasma popup is anchored to the actual
        // clicked delegate. Unlike an unpositioned QtQuick.Window, Plasma's
        // dialog applies screen-edge clamping and panel popup geometry.
        GuardedPopupDialog {
            id: pinnedTrayActionsPopup
            objectName: "reaTrayActionsDialog"
            location: dockGeometry.effectivePanelLocation
            // Retain the async request when Wayland temporarily deactivates the
            // dialog before GetLayout arrives. The reply will reopen the menu.
            hideOnWindowDeactivate: true
            onOpenFailed: {
                // Do not recursively reopen an invalid popup; use the
                // diagnostics to determine why Plasma lacks usable geometry.
                console.warn("Punchi tray: KDE popup has invalid geometry")
                pinnedTrayMenuTimeout.stop()
                root.pinnedTrayMenuLoading = false
            }
            onVisibleChanged: {
                if (!visible && !root.pinnedTrayMenuLoading
                        && !root.pinnedTrayMenuNavigating) {
                    pinnedTrayMenuTimeout.stop()
                    root.pinnedTrayMenuDesktopId = ""
                    root.pinnedTrayPromotedId = ""
                    root.pinnedTrayMenuAnchor = null
                }
            }
            readonly property var menuRows: {
                if (root.pinnedTrayMenuLoading && !root.pinnedTrayMenuFallback)
                    return [{"id": -3, "label": i18nc("@info:inmenu", "Carregando ações do aplicativo…"),
                        "parentId": 0, "enabled": false}]
                const promoted = taskController.isTrayTemporarilyPromoted(
                    root.pinnedTrayPromotedId)
                if (root.pinnedTrayMenuFallback) {
                    return promoted ? [
                        {"id": -8, "label": i18nc("@action:inmenu", "Return to system tray"),
                            "iconName": "window-minimize", "enabled": true},
                        {"id": -9, "label": i18nc("@action:inmenu", "Native application menu…"),
                            "iconName": "application-menu", "enabled": true}
                    ] : []
                }
                if (trayWindowBridge.contextMenuDesktopId !== root.pinnedTrayMenuDesktopId)
                    return []
                const actions = trayWindowBridge.contextActions.filter(function(action) {
                    return Number(action.parentId) === root.pinnedTrayMenuParentId
                })
                if (promoted && root.pinnedTrayMenuParentId === 0) {
                    actions.push({"id": -7, "separator": true, "enabled": false})
                    actions.push({"id": -8, "label": i18nc("@action:inmenu", "Return to system tray"),
                        "iconName": "window-minimize", "enabled": true})
                }
                if (root.pinnedTrayMenuStack.length > 0)
                    actions.unshift({"id": -4, "label": i18nc("@action:inmenu", "‹ Voltar"),
                        "parentId": root.pinnedTrayMenuParentId, "enabled": true})
                return actions
            }
            mainItem: Item {
                id: trayMenuSurface
                // Content-driven size BEFORE the Wayland popup opens. The
                // height must not depend on the Repeater being instantiated.
                readonly property var displayRows: pinnedTrayActionsPopup.menuRows
                implicitWidth: Math.min(354, Math.max(272,
                    90 + displayRows.reduce(function(width, item) {
                        return Math.max(width, String(item.label || "").length * 7)
                    }, 0)))
                implicitHeight: Math.max(58, Math.min(424,
                    displayRows.reduce(function(total, row) {
                        return total + (row.separator ? 12 : 38)
                    }, 0) + 20))
                width: implicitWidth
                height: implicitHeight
                // Inset shadow stays INSIDE the popup geometry, so it can
                // never overlap the dock or demand extra Wayland screen space.
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "#36101525"
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 11
                    color: "#F0181C2A"
                    border.width: 1
                    border.color: "#526C7B98"
                }
                Controls.ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
                    contentWidth: availableWidth
                    Column {
                        id: trayRows
                        width: trayMenuSurface.width - 20
                        spacing: 0
                        Repeater {
                            model: pinnedTrayActionsPopup.menuRows
                            delegate: Item {
                                id: trayRow
                                required property var modelData
                                width: trayRows.width
                                height: modelData.separator ? 12 : 38
                                readonly property bool canTrigger:
                                    !!modelData.enabled && !modelData.separator
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 6
                                    color: rowHit.containsMouse && trayRow.canTrigger
                                        ? "#38405A" : "transparent"
                                }
                                Kirigami.Icon {
                                    id: menuIcon
                                    visible: !!modelData.iconName && !modelData.separator
                                    source: String(modelData.iconName || "")
                                    width: 17
                                    height: 17
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Controls.Label {
                                    text: modelData.separator ? ""
                                        : (String(modelData.toggleType || "") !== ""
                                            && Number(modelData.toggleState || 0) === 1 ? "✓  " : "")
                                            + String(modelData.label || "")
                                            + (modelData.hasChildren ? "  ›" : "")
                                    color: trayRow.canTrigger ? "#F1F4FB" : "#A1AABC"
                                    elide: Text.ElideRight
                                    x: menuIcon.visible ? 35 : 12
                                    width: parent.width - x - 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 13
                                }
                                Rectangle {
                                    visible: !!modelData.separator
                                    anchors.centerIn: parent
                                    width: parent.width - 20
                                    height: 1
                                    color: "#59647780"
                                }
                                MouseArea {
                                    id: rowHit
                                    anchors.fill: parent
                                    enabled: trayRow.canTrigger
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        const actionId = Number(trayRow.modelData.id)
                                        if (actionId === -8) {
                                            taskController.returnTemporaryTrayAppToTray(
                                                root.pinnedTrayPromotedId)
                                            pinnedTrayActionsPopup.closeSafely()
                                        } else if (actionId === -9) {
                                            root.tryNativeTrayMenu()
                                            pinnedTrayActionsPopup.closeSafely()
                                        } else if (actionId === -4) {
                                            const path = root.pinnedTrayMenuStack.slice()
                                            root.pinnedTrayMenuParentId = Number(path.pop() || 0)
                                            root.pinnedTrayMenuStack = path
                                            root.navigatePinnedTrayMenu()
                                        } else if (actionId === -1 || actionId === -2) {
                                            // Historic fallback actions are intentionally disabled.
                                            return
                                        } else if (trayRow.modelData.hasChildren) {
                                            const path = root.pinnedTrayMenuStack.slice()
                                            path.push(root.pinnedTrayMenuParentId)
                                            root.pinnedTrayMenuStack = path
                                            root.pinnedTrayMenuParentId = actionId
                                            root.navigatePinnedTrayMenu()
                                        } else {
                                            trayWindowBridge.triggerNotifierAction(
                                                root.pinnedTrayMenuDesktopId, actionId)
                                            pinnedTrayActionsPopup.closeSafely()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Shortcut {
                    sequence: "Escape"
                    enabled: pinnedTrayActionsPopup.visible
                    onActivated: pinnedTrayActionsPopup.closeSafely()
                }
            }
        }

        GuardedPopupDialog {
            id: notePopupDialog
            location: dockGeometry.effectivePanelLocation
            hideOnWindowDeactivate: true
            onBlurReapplyRequested: notePopupBlurController.reapply()
            onVisibleChanged: {
                if (!visible && !root.deletingActiveNote
                        && notePopupContent.currentText !== notePopupContent.initialText) {
                    const updatedNote = dockItemsController.updateNoteItem(popupCoordinator.activeNoteData,
                        notePopupContent.currentText, notePopupContent.activeWidth,
                        notePopupContent.activeHeight, popupCoordinator.activeNoteIndex)
                    if (updatedNote) {
                        popupCoordinator.activeNoteData = updatedNote
                        notePopupContent.markSaved(notePopupContent.currentText)
                    }
                }
            }

            readonly property Punchi.BlurBehindController notePopupBlurController:
                Punchi.BlurBehindController {
                    window: notePopupDialog
                    restoreAfterFrame: true
                    fullWindow: false
                    maskSource: noteSurfaceStack.backgroundBlurMaskSource
                    useMaskSourceInsets: true
                    maskOffset: noteSurfaceStack.backgroundBlurMaskOffset
                    enabled: notePopupDialog.visible
                        && noteSurfaceStack.backgroundBlurEnabled
                        && noteSurfaceStack.backgroundBlurMaskPresent
                        && dockConfig.popupBackgroundBlurEnabled
                }

            mainItem: PopupAnimatedContent {
                id: notePopupAnimatedContent
                popupVisible: notePopupDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.popupAnimationStyle
                animationSpeedPercent: dockConfig.popupAnimationSpeedPercent
                animationIntensityPercent: dockConfig.popupAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                ContextSurfaceStack {
                    id: noteSurfaceStack
                    blurTransformSurface: notePopupAnimatedContent.transformSurfaceItem
                    blurTranslationX: notePopupAnimatedContent.contentTranslationX
                    blurTranslationY: notePopupAnimatedContent.contentTranslationY
                    showMedia: false
                    maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                    drawContentBackground: true
                    backgroundImagePath: "widgets/background"
                    backgroundOpacity:
                        root.configuredPunchiMenuNormalBackgroundOpacity
                    contentFramePaddingPercent: 2
                    contentFramePaddingScale: 1.5
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing

                    NotePopup {
                        id: notePopupContent
                        noteItem: popupCoordinator.activeNoteData
                        textShadowsEnabled: dockConfig.popupTextShadowsEnabled
                        // qmllint disable unqualified
                        onNoteChanged: function(noteText, popupWidth, popupHeight) {
                            const updatedNote = dockItemsController.updateNoteItem(
                                popupCoordinator.activeNoteData, noteText, popupWidth,
                                popupHeight, popupCoordinator.activeNoteIndex)
                            if (updatedNote) {
                                popupCoordinator.activeNoteData = updatedNote
                                notePopupContent.markSaved(noteText)
                            }
                        }
                        // qmllint enable unqualified
                        onCloseRequested: notePopupDialog.closeSafely()
                        onClearRequested: function(noteText, popupWidth, popupHeight) {
                            notePopupContent.initialText = noteText
                            popupCoordinator.activeNoteData = dockItemsController.updateNoteItem(
                                popupCoordinator.activeNoteData, noteText, popupWidth,
                                popupHeight, popupCoordinator.activeNoteIndex)
                        }
                        onDeleteRequested: {
                            root.deletingActiveNote = true
                            notePopupDialog.closeSafely()
                            if (dockItemsController.removeNoteItemAtIndex(popupCoordinator.activeNoteIndex)) {
                                popupCoordinator.activeNoteData = ({})
                                popupCoordinator.activeNoteIndex = -1
                            }
                            root.deletingActiveNote = false
                        }
                    }
                }
            }
        }

        PlasmaCore.Dialog {
            id: taskWindowsDialog

            readonly property bool isX11Session: KWindowSystem.isPlatformX11
            property bool preparingToShow: false
            property int openRequestSerial: 0
            property bool anchorExtentRefreshPending: false

            location: dockGeometry.effectivePanelLocation
            type: PlasmaCore.Dialog.AppletPopup
            flags: isX11Session
                ? Qt.Popup | Qt.FramelessWindowHint
                : Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            visible: false
            hideOnWindowDeactivate: true
            backgroundHints: PlasmaCore.Dialog.NoBackground

            // qmllint disable unqualified
            function configureStableAnchorExtent(reposition) {
                if (!popupCoordinator.taskPopupUsesStableAnchor) {
                    return
                }
                const popupWidth = Math.max(Number(width || 0),
                    Number(taskPopupAnimatedContent.width || 0))
                const popupHeight = Math.max(Number(height || 0),
                    Number(taskPopupAnimatedContent.height || 0))
                popupCoordinator.configureStableTaskPopupAnchor(
                    popupWidth, popupHeight,
                    location === PlasmaCore.Types.TopEdge
                        || location === PlasmaCore.Types.BottomEdge)
                if (reposition && visible) {
                    popupCoordinator.refreshDynamicTaskPopupAnchor()
                }
            }

            function scheduleStableAnchorExtentRefresh() {
                if (anchorExtentRefreshPending
                        || !popupCoordinator.taskPopupUsesStableAnchor
                        || (!visible && !preparingToShow)) {
                    return
                }
                anchorExtentRefreshPending = true
                Qt.callLater(function() {
                    taskWindowsDialog.anchorExtentRefreshPending = false
                    if (taskWindowsDialog.visible
                            || taskWindowsDialog.preparingToShow) {
                        taskWindowsDialog.configureStableAnchorExtent(true)
                    }
                })
            }

            function finishPreparedOpen(requestSerial, remainingAttempts) {
                if (requestSerial !== openRequestSerial || !preparingToShow) {
                    return
                }
                const widthReady = Number(taskPopupAnimatedContent.implicitWidth) > 0
                    && Number(taskPopupAnimatedContent.width) > 0
                const heightReady = Number(taskPopupAnimatedContent.implicitHeight) > 0
                    && Number(taskPopupAnimatedContent.height) > 0
                const surfaceReady = taskPopupSurface.geometryReady
                if (!surfaceReady || !widthReady || !heightReady) {
                    if (remainingAttempts > 0) {
                        Qt.callLater(function() {
                            taskWindowsDialog.finishPreparedOpen(requestSerial,
                                remainingAttempts - 1)
                        })
                    } else {
                        preparingToShow = false
                        popupCoordinator.resetTaskPopupState()
                    }
                    return
                }
                configureStableAnchorExtent(false)
                visible = true
                preparingToShow = false
            }

            function openSafely() {
                openRequestSerial += 1
                const requestSerial = openRequestSerial
                preparingToShow = true
                Qt.callLater(function() {
                    taskWindowsDialog.finishPreparedOpen(requestSerial, 3)
                })
            }

            function closeSafely() {
                openRequestSerial += 1
                preparingToShow = false
                anchorExtentRefreshPending = false
                visible = false
            }
            // qmllint enable unqualified

            onWidthChanged: scheduleStableAnchorExtentRefresh()
            onHeightChanged: scheduleStableAnchorExtentRefresh()
            onLocationChanged: scheduleStableAnchorExtentRefresh()

            onVisibleChanged: {
                if (!visible) {
                    taskWindowsPopupContent.showPreviews()
                    popupCoordinator.resetTaskPopupState()
                }
            }

            mainItem: PopupAnimatedContent {
                id: taskPopupAnimatedContent
                spatialBounceEnabled: true
                popupVisible: taskWindowsDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.windowPreviewAnimationStyle
                animationSpeedPercent: dockConfig.windowPreviewAnimationSpeedPercent
                animationIntensityPercent: dockConfig.windowPreviewAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified
                onCloseAnimationFinished: taskWindowsDialog.closeSafely()

                TaskPopupSurface {
                    id: taskPopupSurface
                    visible: taskWindowsDialog.visible
                        || taskWindowsDialog.preparingToShow
                    enabled: visible
                    presentationMode: popupCoordinator.activeTaskPopupPresentation
                    mediaController: mprisController
                    taskControllerRef: taskController
                    mediaWindows: popupCoordinator.activeTaskPopupData.windows || []
                    mediaIcon: popupCoordinator.activeTaskPopupData.icon || "emblem-music-symbolic"
                    mediaActionsComposed: taskWindowsPopupContent.mediaActionsComposed
                    // qmllint disable unqualified
                    backgroundOpacity: taskPopupSurface.replacementMediaPresentation
                        ? dockConfig.mediaCardBackgroundOpacity
                        : dockConfig.windowPreviewBackgroundOpacity
                    // qmllint enable unqualified
                    contentFramePaddingPercent: 2
                    contentFramePaddingScale: dockConfig.windowPreviewFrameScale
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing
                    maximumSurfaceWidth: dockGeometry.taskPopupAvailableWidth
                        - Math.min(taskPopupAnimatedContent.bounceHorizontalMargin,
                            dockGeometry.taskPopupAvailableWidth - 1)
                    maximumSurfaceHeight: dockGeometry.taskPopupAvailableHeight
                        - Math.min(taskPopupAnimatedContent.bounceVerticalMargin,
                            dockGeometry.taskPopupAvailableHeight - 1)
                    onContainsMouseChanged: {
                        popupCoordinator.setTaskPopupHovered(containsMouse)
                    }
                    onMediaCloseRequested: popupCoordinator.closeMediaHoverFromKeyboard()

                    TaskContextPopup {
                        id: taskWindowsPopupContent
                        windows: popupCoordinator.activeTaskPopupData.windows || []
                        taskControllerRef: taskController
                        taskRevision: root.taskVisualRevision
                        applicationId: popupCoordinator.activeTaskPopupData.applicationId || ""
                        windowUuids: popupCoordinator.activeTaskPopupData.windowUuids || []
                        previewStyle: dockConfig.windowPreviewStyle
                        presentationMode: popupCoordinator.activeTaskPopupPresentation
                        mprisControllerRef: mprisController
                        previewScale: dockConfig.windowPreviewScale
                        previewInfoMode: dockConfig.windowPreviewInfoMode
                        windowPreviewTextShadowsEnabled: dockConfig.windowPreviewTextShadowsEnabled
                        menuTextShadowsEnabled: dockConfig.menuTextShadowsEnabled
                        maxVisibleRows: dockConfig.maxPopupRows
                        maximumAvailableWidth: taskPopupSurface.maximumContentWidth
                        maximumAvailableHeight: taskPopupSurface.maximumContentHeight
                        actionItemName: popupCoordinator.activeAppContextMenuData.name || ""
                        actions: popupCoordinator.activeAppContextMenuData.actions || []
                        // qmllint disable unqualified
                        maxVisibleActionRows: Number(
                            popupCoordinator.activeAppContextMenuData.maxVisibleRows) > 0
                            ? Number(popupCoordinator.activeAppContextMenuData.maxVisibleRows)
                            : dockConfig.contextMenuVisibleRows
                        actionRowHeight: dockConfig.contextMenuRowHeight
                        actionIconSize: dockConfig.contextMenuIconSize
                        actionMenuWidth: dockConfig.contextMenuWidth
                        transitionDirection: dockConfig.contextMenuTransitionDirection
                        // qmllint enable unqualified
                        previewsEnabled: (taskWindowsDialog.visible
                                || taskWindowsDialog.preparingToShow)
                            && (popupCoordinator.activeTaskPopupPresentation === "preview"
                                || popupCoordinator.activeTaskPopupPresentation === "overlay")
                        returnToMedia: popupCoordinator.mediaHoverActive
                        transitionsEnabled: dockConfig.menuAnimationStyle !== "none"
                        // qmllint disable unqualified
                        transitionSpeedPercent: dockConfig.contextMenuTransitionSpeed
                        // qmllint enable unqualified

                        onActivateRequested: function(taskRow) {
                            taskWindowsDialog.closeSafely()
                            taskController.activateTaskRow(taskRow)
                        }
                        onMinimizeWindowRequested: function(taskRow) {
                            taskController.minimizeTaskRow(taskRow)
                        }
                        onMaximizeWindowRequested: function(taskRow) {
                            taskController.toggleMaximizedTaskRow(taskRow)
                        }
                        onCloseWindowRequested: function(taskRow) {
                            if (taskController.closeTaskRow(taskRow)) {
                                popupCoordinator.removeTaskPopupWindow(taskRow)
                            }
                        }
                        onMediaCloseRequested: popupCoordinator.closeMediaHoverFromKeyboard()
                        onActionTriggered: function(action) {
                            taskWindowsDialog.closeSafely()
                            dockContextActionsController.triggerAction(action)
                        }
                    }
                }
            }
        }

        GuardedPopupDialog {
            id: taskOverflowDialog
            location: dockGeometry.effectivePanelLocation
            hideOnWindowDeactivate: true

            mainItem: PopupAnimatedContent {
                popupVisible: taskOverflowDialog.visible
                // qmllint disable unqualified
                animationStyle: dockConfig.popupAnimationStyle
                animationSpeedPercent: dockConfig.popupAnimationSpeedPercent
                animationIntensityPercent: dockConfig.popupAnimationIntensity
                popupDirection: popupCoordinator.popupDirection
                // qmllint enable unqualified

                ContextSurfaceStack {
                    showMedia: false
                    maximumAvailableHeight: dockGeometry.taskPopupAvailableHeight
                    drawContentBackground: true
                    backgroundImagePath: "widgets/background"
                    backgroundOpacity: dockConfig.contextMenuBackgroundOpacity
                    contentFramePaddingPercent: 2
                    minimumSurfaceWidth: Kirigami.Units.smallSpacing
                    minimumSurfaceHeight: Kirigami.Units.smallSpacing

                    TaskOverflowPopup {
                        id: taskOverflowPopupContent
                        entries: root.overflowTaskRows
                        taskControllerRef: taskController
                        maxVisibleRows: dockConfig.maxPopupRows
                        textShadowsEnabled:
                            dockConfig.windowPreviewTextShadowsEnabled

                        onEntryActivated: function(entry) {
                            taskOverflowDialog.closeSafely()
                            if (entry.count > 1) {
                                popupCoordinator.openTaskWindowsPopup(entry.name,
                                    entry.rows, taskOverflowDockItem)
                            } else if (entry.firstRow >= 0) {
                                taskOverflowPopupContent.taskControllerRef
                                    .activateTaskRow(entry.firstRow)
                            }
                        }
                        onMinimizeWindowRequested: function(taskRow) {
                            taskOverflowPopupContent.taskControllerRef
                                .minimizeTaskRow(taskRow)
                        }
                        onMaximizeWindowRequested: function(taskRow) {
                            taskOverflowPopupContent.taskControllerRef
                                .toggleMaximizedTaskRow(taskRow)
                        }
                        onCloseWindowRequested: function(taskRow) {
                            taskOverflowPopupContent.taskControllerRef
                                .closeTaskRow(taskRow)
                        }
                        onCloseRequested: taskOverflowDialog.closeSafely()
                    }
                }
            }
        }

    }

}
