pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import "../../code/dockDropState.js" as DockDropState
import "../../code/separatorAppearance.js" as SeparatorAppearance
import "../../code/folderAccent.js" as FolderAccent
import "punchimenu" as PunchiMenuComponents

Item {
    id: dockItemContainer
    
    property var iconName: ""
    property string itemName: ""
    property string itemCommand: ""
    property int iconSize: 48
    property real timeTextScale: 1.0
    property real dateTextScale: 1.0
    property string separatorStyleSetting: "line"
    property real separatorThicknessSetting: 2
    property real separatorLengthRatioSetting: 0.72
    property real separatorOpacitySetting: 0.34
    property bool separatorGlowSetting: false
    property bool separatorVisibleSetting: true
    property string separatorAppearanceSourceSetting: "theme"

    readonly property string effectiveIndicatorPosition:
        indicatorPosition === "top" ? "top" : "bottom"

    // qmllint disable unqualified
    readonly property string localizedItemName: {
        if (itemType === "trash" && itemName === "Trash") {
            return i18n("Trash")
        }
        if (itemType === "calendar"
                && (itemName === "Calendar" || itemName === "Calendar/Clock")) {
            return i18n("Calendar/Clock")
        }
        if (itemType === "note" && itemName === "Quick Note") {
            return i18nc("@title", "Quick Note")
        }
        if (itemType === "punchimenu") {
            return i18nc("@title", "OgerMenu")
        }
        if (itemType === "control-center"
                && (itemName === "Control Center" || !itemName)) {
            return i18nc("@title", "Control Center")
        }
        if (itemType === "dynamic-applications") {
            return i18nc("@title", "Open applications")
        }
        return itemName
    }
    // qmllint enable unqualified

    property int itemIndex: -1
    property int hoveredIndex: -1
    
    // Wave animation state.
    property real hoverZoomProgress: 0.0
    property int lastHoveredIndex: -1
    property real lastMouseOffset: 0.0
    property real selectionPulseScale: 1.0
    // Wave geometry follows the original project while preserving smooth transitions.
    property real hoverScaleSetting: 1.65
    property string hoverAnimationMode: "wave"
    property string clickEffect: "none"
    property var clickCollisionController: null
    readonly property bool clickCollisionEligible: visible && enabled
        && !structuralWaveItem && !persistentReorderActive
    readonly property real clickCollisionOffset: !clickCollisionController ? 0
        : clickCollisionController.originItem === dockItemContainer
            ? clickCollisionController.originOffset
        : clickCollisionController.positiveItem === dockItemContainer
            ? clickCollisionController.positiveOffset
        : clickCollisionController.negativeItem === dockItemContainer
            ? clickCollisionController.negativeOffset : 0
    property string windowMinimizeEffect: "none"
    property int taskMinimizedCount: 0
    property int taskMaximizedCount: 0
    property int minimizeReactionRevision: 0
    property int minimizeReactionTargetIndex: -1
    property int observedTaskCount: 0
    property int observedTaskMinimizedCount: 0
    property bool taskMinimizedTrackingReady: false
    property bool showItemHoverBackground: true
    property bool iconReflectionEnabled: false
    property real iconReflectionOpacity: 0.22
    property real iconReflectionAvailableExtent: -1
    property bool animateEntry: false
    property bool positionTransitionEnabled: false
    property bool persistentReorderEnabled: false
    property bool persistentPointerReorderEnabled: false
    property bool persistentDirectReorderEnabled: false
    property bool persistentMoveHandleVisible: false
    property bool persistentReorderActive: false
    property bool persistentReorderSource: false
    property bool persistentReorderGroupMember: false
    // Visual-only displacement during drag. Do not mutate the persisted model
    // until the user releases the cursor; keep each delegate and its state.
    property real persistentReorderShift: 0.0
    transform: Translate {
        x: dockItemContainer.verticalPanelMode ? 0 : dockItemContainer.persistentReorderShift
        y: dockItemContainer.verticalPanelMode ? dockItemContainer.persistentReorderShift : 0
    }
    Behavior on persistentReorderShift {
        enabled: Kirigami.Units.longDuration > 0
        NumberAnimation { duration: 155; easing.type: Easing.OutCubic }
    }
    property bool persistentReorderTarget: false
    property bool persistentReorderInsertAfter: false
    property int persistentModelIndex: -1
    property bool suppressClickAfterReorder: false
    property bool persistentReorderInteractionResetPending: false
    property bool taskPopupTracksVisualArea: false
    property real entryOpacity: 1.0
    property real entryScale: 1.0
    property bool positionAnimationReady: false
    property bool showPersistentLabel: false
    property bool textShadowsEnabled: true
    property bool calendarTextShadowsEnabled: true
    property int labelFontSize: Math.max(10, Math.round(iconSize * 0.22))
    property string indicatorType: "line"
    property string indicatorPosition: "bottom"
    property string indicatorColor: ""
    property int indicatorThickness: 4
    property real indicatorOpacity: 1.0
    property bool indicatorNeonEnabled: true
    property real indicatorNeonIntensity: 0.65
    property bool windowCountBadgeEnabled: false
    property string windowCountBadgePosition: "top-right"
    property bool windowGroupingEnabled: false
    property string windowCountEmblemColor: ""
    property real windowCountEmblemOpacity: 1.0
    property real windowCountEmblemScale: 1.0
    property var mediaController: null
    property int mediaMainAxisLength: Math.round(Math.max(120,
        Math.min(320, iconSize * 4.2)))
    property bool mediaMotionEnabled: true
    property real mediaMaxInlineTitleExtent: 150
    property bool mediaLaunchAvailable: false
    property string mediaDefaultPlayerName: ""
    property string mediaDefaultPlayerIcon: ""
    // Keep user-selected icons and all other app icons. Only substitute the
    // legacy KDE start icon on the built-in menu item.
    readonly property var ogerMenuIconSource: itemType === "punchimenu"
        && (String(iconName || "") === "start-here-kde" || !iconName)
        ? Qt.resolvedUrl("../../images/oger-menu-symbolic.png") : iconName
    readonly property var effectiveDockIconSource: ogerMenuIconSource
    property var mediaPinPreferences: ({})
    signal mediaPinRequested(string identity, bool pinned)
    property string mediaTextMode: "automatic"
    property string mediaDisplayMode: "normal"
    property int mediaAutoCollapseDelaySeconds: 3
    property bool mediaItemShown: true
    signal mediaInlineExtentChanged(real extent)
    property bool mediaProgressDrivenByGeometry: false
    property real mediaPresentationProgress: 1.0
    property bool folderOpen: false
    property bool launcherMenuOpen: false
    property var folderPreviewEntries: []
    property var folderCategoryColors: ({})
    property string folderAccentColor: ""
    property string folderSourceCategory: ""
    readonly property color effectiveFolderAccent: FolderAccent.resolvedColor(
        folderAccentColor, folderSourceCategory, folderCategoryColors,
        Kirigami.Theme.highlightColor)
    property string mediaEntranceAnimation: "fade"
    property bool mediaShowCover: true
    property bool mediaShowTitle: true
    property bool mediaShowControls: true
    property bool mediaShowProgress: true
    property bool mediaShowVolume: true
    property string mediaBackgroundStyle: "artwork"
    property real mediaEntranceProgress: mediaProgressDrivenByGeometry
        ? mediaPresentationProgress : (mediaItemShown ? 1.0 : 0.0)
    Behavior on mediaEntranceProgress {
        enabled: mediaItem && !mediaProgressDrivenByGeometry
            && mediaEntranceAnimation !== "none"
        NumberAnimation {
            duration: dockItemContainer.mediaEntranceAnimation === "slide" ? 240 : 175
            easing.type: Easing.OutCubic
        }
    }
    property int dockMotionSpeedPercent: 100
    readonly property int resolvedDockMotionSpeedPercent: Math.max(50,
        Math.min(150, Number.isFinite(dockMotionSpeedPercent)
            ? Math.round(dockMotionSpeedPercent)
            : 100))
    readonly property int dockMotionDuration: Math.round(
        Kirigami.Units.longDuration * 100 / resolvedDockMotionSpeedPercent)
    readonly property int selectionPulseDuration: Math.max(1,
        Math.round(dockMotionDuration * 2.25))
    readonly property real selectionPulsePeakScale:
        Math.max(1.0, hoverScaleSetting)
    readonly property int resolvedMediaAutoCollapseDelaySeconds: Math.max(0,
        Math.min(30, Number.isFinite(mediaAutoCollapseDelaySeconds)
            ? Math.round(mediaAutoCollapseDelaySeconds)
            : 3))
    readonly property real mediaCurrentMainAxisLength: mediaItem
        ? mediaDockItem.currentMainAxisLength
        : mediaMainAxisLength
    readonly property real mediaInlineTitleExtent: mediaItem
        ? mediaDockItem.inlineTitleExtent : 0
    property var layoutController: parent

    // Wheel dispatch is owned by the MouseArea below, preserving leques and
    // media scroll gestures. The layout also handles unoccupied dock space.
    property int highQualityIconSize: {
        const targetSize = Math.ceil(iconSize * Math.max(1.0, hoverScaleSetting))
        if (targetSize <= iconSize) {
            return iconSize
        }
        if (targetSize <= 64 && iconSize < 64) return 64
        if (targetSize <= 96) return 96
        if (targetSize <= 128) return 128
        if (targetSize <= 256) return 256
        return Math.min(512, targetSize)
    }
    property real highQualityIconScale: highQualityIconSize > 0 ? iconSize / highQualityIconSize : 1
    readonly property real hoverScaleDelta: Math.max(0.0001, hoverScaleSetting - 1.0)
    readonly property real waveSharedScaleDelta: Math.min(0.50,
        Math.max(0.0, hoverScaleSetting - 1.0))
    readonly property real wavePrimaryScaleDelta: Math.max(0.0,
        hoverScaleSetting - 1.0 - waveSharedScaleDelta)
    readonly property real waveLayoutSpacing: {
        if (!layoutController) {
            return Kirigami.Units.smallSpacing
        }
        const value = verticalPanelMode
            ? Number(layoutController.rowSpacing)
            : Number(layoutController.columnSpacing)
        return Number.isFinite(value) && value >= 0
            ? value : Kirigami.Units.smallSpacing
    }
    readonly property real waveCanonicalItemExtent: verticalPanelMode
        ? iconSize + 12 + (showPersistentLabel ? labelFontSize + 12 : 0)
        : Math.max(iconSize + 12,
            showPersistentLabel ? Math.round(iconSize * 1.85) : 0)
    readonly property real waveItemPitch: Math.max(1,
        (structuralWaveItem
            ? waveCanonicalItemExtent
            : (verticalPanelMode ? height : width)) + waveLayoutSpacing)
    readonly property point waveMappedCenter: {
        // Mapping also depends on the delegate position inside its layout.
        dockItemContainer.x
        dockItemContainer.y
        return layoutController
            ? mapToItem(layoutController, width / 2, height / 2)
            : Qt.point(0, 0)
    }
    readonly property real waveItemCenter: verticalPanelMode
        ? waveMappedCenter.y : waveMappedCenter.x
    readonly property real waveInfluenceRadius: Math.max(iconSize * 3.0,
        waveItemPitch * 2.75)
    readonly property real iconReflectionMaximumVisibleRatio: 0.26
    readonly property real iconReflectionDisplaySize: iconSize * waveScale
    readonly property real iconReflectionContainerScale:
        clickAnimationScale * entryScale
    readonly property real iconReflectionBottomDisplacement:
        (((iconReflectionDisplaySize / 2) + hoverOffsetY)
            * iconReflectionContainerScale) - (iconSize / 2)
    readonly property real iconReflectionUsableExtent:
        iconReflectionAvailableExtent < 0
            ? iconReflectionDisplaySize * iconReflectionMaximumVisibleRatio
            : Math.max(0, iconReflectionAvailableExtent
                - iconReflectionBottomDisplacement)
    readonly property real iconReflectionVisibleRatio: Math.max(0,
        Math.min(iconReflectionMaximumVisibleRatio,
            iconReflectionUsableExtent / Math.max(1,
                iconReflectionDisplaySize * iconReflectionContainerScale)))
    readonly property real labelAreaHeight: showPersistentLabel
        && !separatorItem && !spacerItem && !mediaItem
        ? (labelFontSize + 12)
        : 0
    // Use direct values for separators/spacers in vertical mode to avoid
    // a circular binding (implicitHeight depends on visualAreaHeight).
    readonly property real visualAreaHeight: {
        if (mediaItem && verticalPanelMode) {
            return mediaCurrentMainAxisLength + 12
        }
        if ((separatorItem || spacerItem) && verticalPanelMode) {
            if (dynamicApplicationsMarkerCollapsed) {
                return 0
            }
            return separatorItem
                ? Math.max(10, Math.ceil(separatorThickness + 4))
                : Math.max(12, iconSize * 0.5)
        }
        return iconSize + 12
    }
    property real clickAnimationScale: clickFeedback.visualScale
    property bool keyboardFeedbackPressed: false

    function activateItem() {
        if (separatorItem || spacerItem) {
            return
        }
        playClickFeedback()
        itemClicked(itemCommand)
    }

    function playClickFeedback() {
        if (clickEffect === "collision" && clickCollisionController) {
            clickCollisionController.play(dockItemContainer)
        } else {
            clickFeedback.play()
        }
    }

    function collisionVisualBounds() {
        if (mediaItem) {
            return mediaDockItem.mapToItem(layoutController,
                Qt.rect(0, 0, mediaDockItem.width, mediaDockItem.height))
        }
        const size = iconSize * waveScale
        return visualArea.mapToItem(layoutController, Qt.rect(
            (visualArea.width - size) / 2 + hoverOffsetX,
            (visualArea.height - size) / 2 + hoverOffsetY, size, size))
    }

    onClickCollisionEligibleChanged: {
        if (!clickCollisionEligible && clickCollisionController) {
            clickCollisionController.cancelFor(dockItemContainer)
        }
    }
    onClickEffectChanged: {
        if (clickCollisionController) {
            clickCollisionController.cancelFor(dockItemContainer)
        }
    }
    function mediaAdjustedWaveScale(candidateScale) {
        if (!mediaItem) {
            return candidateScale
        }
        return 1.0 + (candidateScale - 1.0) * mediaDockItem.collapseProgress
    }
    // Plasma taskbar bounds are authoritative. An oversized hover transform
    // must not push icons out of the panel window (especially when maximized).
    property real panelCrossAxisLimit: 0
    readonly property real waveScale: inPanel && panelCrossAxisLimit > 0
        ? Math.min(unboundedWaveScale, Math.max(1.0,
            (panelCrossAxisLimit - 8) / Math.max(1, iconSize)))
        : unboundedWaveScale
    property real unboundedWaveScale: {
        if (itemType === "calendar" || structuralWaveItem
                || (mediaItem && !mediaDockItem.compactMode)) {
            return 1.0
        }

        if (hoverAnimationMode === "none") {
            return 1.0
        }

        if (hoverAnimationMode === "selectionPulse") {
            return mediaAdjustedWaveScale(selectionPulseScale)
        }

        var activeIndex = hoveredIndex >= 0 ? hoveredIndex : lastHoveredIndex
        var pointerPosition = hoveredIndex >= 0
            ? Number(dockItemContainer.layoutController.pointerPrimaryAxis)
            : Number(dockItemContainer.layoutController.lastPointerPrimaryAxis)

        if (activeIndex === -1 || hoverZoomProgress <= 0.0) {
            return 1.0
        }

        if (Kirigami.Units.longDuration === 0) {
            // Under Reduce Motion, restrict wave zoom to subtle instant scale on active item only
            if (itemIndex === activeIndex) {
                return mediaAdjustedWaveScale(1.0
                    + Math.min(0.08, (hoverScaleSetting - 1.0) * 0.25))
            }
            return 1.0
        }

        if (hoverAnimationMode === "single" || hoverAnimationMode === "axisZoom") {
            const singleScale = itemIndex === activeIndex
                ? 1.0 + (hoverScaleSetting - 1.0) * hoverZoomProgress
                : 1.0
            return mediaAdjustedWaveScale(singleScale)
        }

        if (!Number.isFinite(pointerPosition) || pointerPosition < 0) {
            return 1.0
        }

        // Keep the original cosine wave, extending its reach by one item.
        var radius = waveInfluenceRadius
        var itemCenterPoint = dockItemContainer.mapToItem(
            dockItemContainer.layoutController,
            dockItemContainer.width / 2,
            dockItemContainer.height / 2)
        var itemCenter = verticalPanelMode ? itemCenterPoint.y : itemCenterPoint.x
        var distance = Math.abs(itemCenter - pointerPosition)
        if (distance >= radius) return 1.0

        // Organic smooth cosine wave curve (0.5 * (1 + cos(pi * d / r)))
        var normalizedDistance = distance / radius
        var influence = 0.5 * (1.0 + Math.cos(Math.PI * normalizedDistance))
        var scale = 1.0 + waveSharedScaleDelta
            * influence * hoverZoomProgress

        // Values above 150% reinforce only the item directly under the
        // pointer. The compact cosine reaches zero at half a cell, so the
        // extra peak transfers continuously without enlarging neighbours.
        const primaryRadius = waveItemPitch * 0.5
        if (wavePrimaryScaleDelta > 0.0 && distance < primaryRadius) {
            const primaryDistance = distance / primaryRadius
            const primaryInfluence = 0.5
                * (1.0 + Math.cos(Math.PI * primaryDistance))
            scale += wavePrimaryScaleDelta
                * primaryInfluence * hoverZoomProgress
        }
        return mediaAdjustedWaveScale(scale)
    }

    readonly property real waveMainAxisShift: {
        if (hoverAnimationMode !== "wave" || hoverZoomProgress <= 0.0
                || !layoutController) {
            return 0.0
        }

        if (Kirigami.Units.longDuration === 0) {
            return 0.0
        }

        const pointerPosition = hoveredIndex >= 0
            ? Number(layoutController.pointerPrimaryAxis)
            : Number(layoutController.lastPointerPrimaryAxis)
        if (!Number.isFinite(pointerPosition) || pointerPosition < 0) {
            return 0.0
        }

        const signedDistance = waveItemCenter - pointerPosition
        const distance = Math.abs(signedDistance)
        if (distance < 0.001) {
            return 0.0
        }

        const normalizedDistance = Math.min(1.0,
            distance / waveInfluenceRadius)
        const integratedInfluence = waveInfluenceRadius
            * (0.5 * normalizedDistance
                + Math.sin(Math.PI * normalizedDistance) / (2.0 * Math.PI))
        const maximumExpansion = iconSize
            * waveSharedScaleDelta * hoverZoomProgress
        const shift = maximumExpansion * integratedInfluence / waveItemPitch
        const directionalShift = signedDistance < 0.0 ? -shift : shift
        return directionalShift
    }

    function updateWavePointer(localX, localY) {
        if (!layoutController || !Number.isFinite(Number(localX))
                || !Number.isFinite(Number(localY))) {
            return
        }
        const point = mapToItem(layoutController, Number(localX), Number(localY))
        const position = verticalPanelMode ? point.y : point.x
        layoutController.pointerPrimaryAxis = position
        layoutController.lastPointerPrimaryAxis = position
    }

    function shouldKeepWaveActiveAcrossLayoutGap() {
        if (hoverAnimationMode !== "wave" || !layoutController) {
            return false
        }
        try {
            return !!layoutController.wavePointerInsideLayout
        } catch (error) {
            return false
        }
    }

    function restartSelectionPulse() {
        selectionPulseAnimation.stop()
        selectionPulseScale = 1.0
        if (hoverAnimationMode !== "selectionPulse"
                || selectionPulsePeakScale <= 1.0
                || Kirigami.Units.longDuration === 0) {
            return
        }
        selectionPulseAnimation.start()
    }

    function resetSelectionPulse() {
        selectionPulseAnimation.stop()
        selectionPulseScale = 1.0
    }

    property bool inPanel: false
    property int panelLocation: PlasmaCore.Types.BottomEdge
    readonly property int tooltipLocation: {
        return panelLocation
    }
    readonly property real hoverTravel: {
        if (waveScale <= 1.0 || hoverAnimationMode === "axisZoom"
                || hoverAnimationMode === "selectionPulse") {
            return 0.0
        }
        if (hoverAnimationMode === "wave") {
            // Scaling is centered, so offset by exactly half of the growth to
            // keep the icon attached to the dock edge on either orientation.
            return iconSize * 0.5 * (waveScale - 1.0)
        }
        return Math.round(iconSize * 0.32
            * ((waveScale - 1.0) / hoverScaleDelta))
    }
    readonly property real hoverOffsetX: {
        if (!verticalPanelMode || hoverTravel <= 0.0) {
            return 0.0
        }
        if (panelLocation === PlasmaCore.Types.LeftEdge) {
            return hoverTravel
        }
        if (panelLocation === PlasmaCore.Types.RightEdge) {
            return -hoverTravel
        }
        return 0.0
    }
    readonly property real hoverOffsetY: {
        if (hoverTravel <= 0.0) {
            return 0.0
        }
        if (panelLocation === PlasmaCore.Types.TopEdge) {
            return hoverTravel
        }
        if (panelLocation === PlasmaCore.Types.BottomEdge) {
            return -hoverTravel
        }
        return !inPanel && !verticalPanelMode ? -hoverTravel : 0.0
    }

    property string itemType: "app"
    property string currentTime: "00:00"
    property string currentDate: "01/01"
    property bool trayOnlyExecution: false
    property int taskIndicatorCount: 0
    property bool taskIsActive: false
    property bool taskDemandsAttention: false
    property bool pinnedApplicationLauncher: false
    property bool recentApplicationLauncher: false
    property bool suppressTooltip: false
    property bool supportsContextMenu: false
    property bool mediaHoverControlsEnabled: false
    property bool externalDropEnabled: false
    property bool launcherDropEnabled: false
    property var launcherDropValidator: null
    property bool launcherContainerDropTarget: false
    property bool launcherContainerDropEnabled: false
    property bool launcherDropInsertAfter: false
    property int launcherModelInsertionIndex: -1
    property string launcherDropApplicationName: ""
    property bool externalDropActivationEnabled: false
    property int externalDropActivationDelay: 250
    property var externalDropActivator: null
    property string externalDropState: "none"
    property real externalDropActivationProgress: 0
    property bool customSeparatorEnabled: false
    property var separatorTheme: ({})
    readonly property var effectiveSeparatorAppearance:
        SeparatorAppearance.resolvedAppearance(
            separatorAppearanceSourceSetting,
            {
                "separatorStyle": separatorStyleSetting,
                "separatorThickness": separatorThicknessSetting,
                "separatorLengthRatio": separatorLengthRatioSetting,
                "separatorOpacity": separatorOpacitySetting,
                "separatorGlowEnabled": separatorGlowSetting
            },
            customSeparatorEnabled,
            separatorTheme)
    readonly property Item taskGeometryItem: taskGeometryProxy
    readonly property bool containsMouse: mouseArea.containsMouse
    readonly property bool separatorItem: itemType === "separator"
        || itemType === "dynamic-applications"
    readonly property bool spacerItem: itemType === "spacer"
    readonly property bool mediaItem: itemType === "media"
    readonly property bool overflowItem: itemType === "overflow"
    readonly property bool structuralWaveItem: separatorItem || spacerItem
    // The dynamic-applications marker only keeps its layout slot while it draws
    // something: its separator, its move handle or the launcher drop
    // placeholder. Hiding the separator must also release the slot, otherwise
    // unchecking "Show separator" would only hide the line and leave a gap.
    readonly property bool dynamicApplicationsMarkerCollapsed:
        itemType === "dynamic-applications"
        && !separatorVisibleSetting
        && !persistentMoveHandleVisible
        && !launcherDropPlaceholderVisible
    readonly property bool isAnyPopupOrMenuOpen: {
        if (layoutController && layoutController.popupCoordinator) {
            const coordinator = layoutController.popupCoordinator
            const targetActive = coordinator.isPopupActiveForVisualParent
                && coordinator.isPopupActiveForVisualParent(dockItemContainer)
            const globalActive = !!coordinator.isAnyPopupActiveGlobally
            return targetActive || globalActive
        }
        return false
    }
    // Pinned and recent launchers use the floating label only while they have
    // no open windows. Once a task exists, its hover preview owns that space.
    readonly property bool tooltipEligibleItem: ((pinnedApplicationLauncher
            || recentApplicationLauncher)
            && itemType === "app"
            && taskIndicatorCount === 0)
        || itemType === "folder"
        || itemType === "trash"
        || itemType === "punchimenu"
        || itemType === "control-center"
        || itemType === "note"
        || itemType === "calendar"
    // The community report #3 showed this label painting over open popups, so it
    // stays off while any surface or context menu of the dock is on screen.
    // `suppressTooltip` carries the item's own context menu and
    // `isAnyPopupOrMenuOpen` covers every popup, including another item's window
    // preview, whichever item it belongs to.
    readonly property bool showAnyTooltip: tooltipEligibleItem
        && !suppressTooltip
        && !isAnyPopupOrMenuOpen
    readonly property real requestedSeparatorThickness:
        Number(effectiveSeparatorAppearance.thickness)
    readonly property real separatorThickness: Math.min(iconSize,
        requestedSeparatorThickness)
    Timer {
        id: clockTimer
        interval: 1000
        running: dockItemContainer.itemType === "calendar"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            var hh = String(date.getHours()).padStart(2, '0')
            var mm = String(date.getMinutes()).padStart(2, '0')
            var dd = String(date.getDate()).padStart(2, '0')
            var mo = String(date.getMonth() + 1).padStart(2, '0')
            dockItemContainer.currentTime = hh + ":" + mm
            dockItemContainer.currentDate = dd + "/" + mo
        }
    }

    Timer {
        id: minimizeStateEvaluationTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (dockItemContainer.taskMinimizedTrackingReady
                    && dockItemContainer.taskIndicatorCount
                        === dockItemContainer.observedTaskCount
                    && dockItemContainer.taskMinimizedCount
                        > dockItemContainer.observedTaskMinimizedCount) {
                dockItemContainer.taskMinimized(dockItemContainer.itemIndex)
            }
            dockItemContainer.observedTaskCount = dockItemContainer.taskIndicatorCount
            dockItemContainer.observedTaskMinimizedCount
                = dockItemContainer.taskMinimizedCount
        }
    }

    signal itemClicked(string cmd)
    signal contextMenuRequested(var visualParent, bool keyboardInvoked)
    signal mediaControlsRequested(var visualParent)
    signal mediaExpansionChanged(bool expanded, int transitionDuration)
    // Used only to commit a delayed folder switch when the pointer is still
    // over the destination. Never infer hover from a stale delegate index.
    readonly property bool pointerOverDockItem: mouseArea.containsMouse
    signal hoverEntered(var visualParent)
    signal hoverExited(var visualParent)
    signal taskMinimized(int itemIndex)
    signal externalUrlsDropped(var urls, var visualParent)
    signal applicationLauncherDropped(var urls, int insertionIndex, var visualParent)
    signal applicationLauncherContainerDropped(var urls, var visualParent)
    signal persistentReorderPressStarted(var visualParent)
    signal persistentReorderStarted(int modelIndex, var visualParent)
    signal persistentReorderMoved(real x, real y)
    signal persistentReorderFinished()
    signal persistentReorderCanceled()
    signal persistentMoveModeCanceled()
    signal persistentKeyboardMoveRequested(int modelIndex, int delta)
    signal mediaLaunchRequested()
    signal mediaPlaybackLaunchRequested()

    function focusItem() {
        if (dockItemContainer.mediaItem) {
            mediaDockItem.focusFirstControl()
        } else {
            mouseArea.forceActiveFocus(Qt.OtherFocusReason)
        }
    }

    function releasePersistentReorderInteraction() {
        suppressClickAfterReorder = false
        resetSelectionPulse()
        keyboardFeedbackPressed = false
        persistentReorderInteractionResetPending = true
        persistentReorderInteractionResetTimer.restart()
    }

    function validateLauncherDrop(urls) {
        if (!dockItemContainer.launcherDropEnabled
                || typeof dockItemContainer.launcherDropValidator !== "function") {
            return { "accepted": false, "errorCode": "applicationUnavailable" }
        }
        return dockItemContainer.launcherDropValidator(urls || [])
    }

    function hasPunchiLauncherMarker(event) {
        return event && event.formats
            && event.formats.indexOf("application/x-punchi-launcher") >= 0
    }

    function mayContainApplicationLauncher(event) {
        if (!dockItemContainer.launcherDropEnabled || !event
                || !event.hasUrls) {
            return false
        }
        if (dockItemContainer.hasPunchiLauncherMarker(event)) {
            return true
        }
        const urls = event.urls || []
        return urls.length === 1
            && /\.desktop$/i.test(String(urls[0] || ""))
    }

    function isApplicationLauncherDrag(event, validation) {
        return dockItemContainer.launcherDropEnabled && event && event.hasUrls
            && (dockItemContainer.hasPunchiLauncherMarker(event)
                || (validation && validation.accepted))
    }

    function updateLauncherDropPosition(x, y) {
        dockItemContainer.launcherDropInsertAfter = dockItemContainer.verticalPanelMode
            ? y >= dockItemContainer.height / 2
            : x >= dockItemContainer.width / 2
    }

    function maintainLauncherDropAcceptance(event) {
        if (!event) {
            return false
        }
        const accepted = DockDropState.launcherDropAcceptance(
            dockItemContainer.externalDropState)
        if (accepted === undefined) {
            return false
        }
        event.accepted = accepted
        return accepted
    }

    function launcherInsertionIndex() {
        const baseIndex = dockItemContainer.launcherModelInsertionIndex >= 0
            ? dockItemContainer.launcherModelInsertionIndex
            : dockItemContainer.itemIndex
        return Math.max(0, baseIndex
            + (dockItemContainer.launcherDropInsertAfter ? 1 : 0))
    }

    function beginExternalDropActivation() {
        dockItemContainer.cancelExternalDropActivation()
        if (!dockItemContainer.externalDropActivationEnabled
                || typeof dockItemContainer.externalDropActivator !== "function") {
            return
        }
        dockItemContainer.externalDropState = "activationPending"
        externalDropActivationProgressAnimation.restart()
        externalDropActivationTimer.restart()
    }

    function cancelExternalDropActivation() {
        externalDropActivationTimer.stop()
        externalDropActivationProgressAnimation.stop()
        dockItemContainer.externalDropActivationProgress = 0
    }

    onExternalDropEnabledChanged: {
        if (!dockItemContainer.externalDropEnabled) {
            dockItemContainer.cancelExternalDropActivation()
            dockItemContainer.externalDropState = "none"
        }
    }

    readonly property bool verticalPanelMode: panelLocation === PlasmaCore.Types.LeftEdge
        || panelLocation === PlasmaCore.Types.RightEdge
    readonly property Item taskPopupAnchorItem: taskPopupTracksVisualArea
        ? visualArea : null
    readonly property bool launcherDropPlaceholderVisible:
        externalDropState === "launcherAcceptable"
    readonly property bool externalDropRejected:
        externalDropState === "rejected"
        || externalDropState === "launcherContainmentRejected"
    readonly property real launcherDropLayoutSpacing: {
        if (!layoutController) {
            return Kirigami.Units.smallSpacing
        }
        const value = verticalPanelMode
            ? Number(layoutController.rowSpacing)
            : Number(layoutController.columnSpacing)
        return Number.isFinite(value) && value >= 0
            ? value : Kirigami.Units.smallSpacing
    }
    readonly property real launcherDropPlaceholderMainExtent: verticalPanelMode
        ? Math.max(iconSize + 12, visualAreaHeight + labelAreaHeight)
        : Math.max(iconSize + 12,
            showPersistentLabel ? Math.round(iconSize * 1.85) : 0)
    readonly property real launcherDropReservedExtent:
        launcherDropPlaceholderMainExtent + launcherDropLayoutSpacing

    Layout.leftMargin: launcherDropPlaceholderVisible
        && !verticalPanelMode && !launcherDropInsertAfter
        ? launcherDropReservedExtent : 0
    Layout.rightMargin: launcherDropPlaceholderVisible
        && !verticalPanelMode && launcherDropInsertAfter
        ? launcherDropReservedExtent : 0
    Layout.topMargin: launcherDropPlaceholderVisible
        && verticalPanelMode && !launcherDropInsertAfter
        ? launcherDropReservedExtent : 0
    Layout.bottomMargin: launcherDropPlaceholderVisible
        && verticalPanelMode && launcherDropInsertAfter
        ? launcherDropReservedExtent : 0

    // Keep layout container measurements fully static to prevent jitter.
    readonly property real persistentMoveHandleMainExtent:
        Math.max(iconSize + Kirigami.Units.smallSpacing * 2,
            Math.round(iconSize * 3.6))

    implicitWidth: verticalPanelMode
        ? Math.max(iconSize + 12, !mediaItem && showPersistentLabel ? Math.round(iconSize * 1.85) : 0)
        : (persistentMoveHandleVisible
            ? persistentMoveHandleMainExtent
            : (separatorItem
            ? (dynamicApplicationsMarkerCollapsed
                ? 0
                : Math.max(10, Math.ceil(separatorThickness + 4)))
            : (spacerItem
                ? Math.max(12, iconSize * 0.5)
                : (mediaItem
                    ? mediaCurrentMainAxisLength * mediaEntranceProgress
                        + 12 * mediaEntranceProgress
                    : Math.max(iconSize + 12,
                        showPersistentLabel ? Math.round(iconSize * 1.85) : 0)))))
    implicitHeight: verticalPanelMode
        ? (persistentMoveHandleVisible
            ? Math.max(iconSize + 12, visualAreaHeight + labelAreaHeight)
            : (separatorItem
            ? (dynamicApplicationsMarkerCollapsed
                ? 0
                : Math.max(10, Math.ceil(separatorThickness + 4)))
            : (spacerItem
                ? Math.max(12, iconSize * 0.5)
                : (mediaItem
                    ? mediaCurrentMainAxisLength * mediaEntranceProgress
                        + 12 * mediaEntranceProgress
                    : (visualAreaHeight + labelAreaHeight)))))
        : (visualAreaHeight + labelAreaHeight)
    // An invisible delegate contributes no size and no layout spacing, which is
    // what removes the gap left by a hidden dynamic-applications separator.
    visible: !dockItemContainer.dynamicApplicationsMarkerCollapsed
        && (!dockItemContainer.mediaItem
            || dockItemContainer.mediaEntranceProgress > 0.004)
    opacity: dockItemContainer.entryOpacity
        * (dockItemContainer.mediaItem && dockItemContainer.mediaEntranceAnimation !== "none"
            ? dockItemContainer.mediaEntranceProgress : 1.0)
        * ((dockItemContainer.persistentReorderSource
            || dockItemContainer.persistentReorderGroupMember) ? 0.28 : 1.0)

    Behavior on x {
        enabled: dockItemContainer.positionAnimationReady
            && (dockItemContainer.positionTransitionEnabled
                || (dockItemContainer.layoutController
                    && (dockItemContainer.layoutController.mediaMorphActive
                        || (dockItemContainer.layoutController.launcherDropTransitionActive
                            && Kirigami.Units.longDuration > 0))))
        NumberAnimation {
            duration: dockItemContainer.dockMotionDuration
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on y {
        enabled: dockItemContainer.positionAnimationReady
            && (dockItemContainer.positionTransitionEnabled
                || (dockItemContainer.layoutController
                    && (dockItemContainer.layoutController.mediaMorphActive
                        || (dockItemContainer.layoutController.launcherDropTransitionActive
                            && Kirigami.Units.longDuration > 0))))
        NumberAnimation {
            duration: dockItemContainer.dockMotionDuration
            easing.type: Easing.InOutCubic
        }
    }

    Component.onCompleted: {
        dockItemContainer.observedTaskCount = dockItemContainer.taskIndicatorCount
        dockItemContainer.observedTaskMinimizedCount
            = dockItemContainer.taskMinimizedCount
        if (dockItemContainer.animateEntry) {
            dockItemContainer.entryOpacity = 0.0
            dockItemContainer.entryScale = 0.88
            entryAnimation.restart()
        }
        Qt.callLater(function() {
            dockItemContainer.positionAnimationReady = true
            dockItemContainer.taskMinimizedTrackingReady = true
        })
    }

    onTaskIndicatorCountChanged: minimizeStateEvaluationTimer.restart()
    onTaskMinimizedCountChanged: minimizeStateEvaluationTimer.restart()

    MinimizeItemReaction {
        id: minimizeItemReaction
        mode: dockItemContainer.windowMinimizeEffect
        itemIndex: dockItemContainer.itemIndex
        targetIndex: dockItemContainer.minimizeReactionTargetIndex
        revision: dockItemContainer.minimizeReactionRevision
        iconSize: dockItemContainer.iconSize
        verticalPanel: dockItemContainer.verticalPanelMode
        bounceDirection: dockItemContainer.panelLocation === PlasmaCore.Types.RightEdge
            || dockItemContainer.panelLocation === PlasmaCore.Types.BottomEdge
            ? -1
            : 1
        reactionEnabled: !dockItemContainer.separatorItem
            && !dockItemContainer.spacerItem
    }

    ParallelAnimation {
        id: entryAnimation

        NumberAnimation {
            target: dockItemContainer
            property: "entryOpacity"
            to: 1.0
            duration: dockItemContainer.dockMotionDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: dockItemContainer
            property: "entryScale"
            to: 1.0
            duration: dockItemContainer.dockMotionDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: hoverBackground
        anchors.fill: parent
        readonly property bool pointerHighlighted: mouseArea.containsMouse
            || (dockItemContainer.hoverAnimationMode === "wave"
                && dockItemContainer.hoveredIndex
                    === dockItemContainer.itemIndex)
        visible: dockItemContainer.showItemHoverBackground
            && !dockItemContainer.separatorItem
            && !dockItemContainer.spacerItem
            && !dockItemContainer.mediaItem
            && dockItemContainer.itemType !== "calendar"
        transformOrigin: Item.Center
        scale: dockItemContainer.waveScale
        transform: Translate {
            x: dockItemContainer.hoverOffsetX
                + (dockItemContainer.hoverAnimationMode === "wave"
                    && !dockItemContainer.verticalPanelMode
                    ? dockItemContainer.waveMainAxisShift : 0.0)
            y: dockItemContainer.hoverOffsetY
                + (dockItemContainer.hoverAnimationMode === "wave"
                    && dockItemContainer.verticalPanelMode
                    ? dockItemContainer.waveMainAxisShift : 0.0)
        }

        PunchiMenuComponents.PunchiMenuItemHighlight {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            hovered: hoverBackground.pointerHighlighted
            selected: hoverBackground.pointerHighlighted
            focused: mouseArea.activeFocus
            pressed: mouseArea.pressed
            motionEnabled: Kirigami.Units.longDuration > 0
        }
    }

    Rectangle {
        id: persistentReorderInsertionIndicator
        z: 9
        visible: dockItemContainer.persistentReorderTarget
        radius: Math.min(width, height) / 2
        color: Kirigami.Theme.highlightColor
        width: dockItemContainer.verticalPanelMode
            ? Math.max(12, dockItemContainer.width * 0.72)
            : Math.max(3, Math.round(Kirigami.Units.smallSpacing / 2))
        height: dockItemContainer.verticalPanelMode
            ? Math.max(3, Math.round(Kirigami.Units.smallSpacing / 2))
            : Math.max(12, dockItemContainer.height * 0.72)
        x: dockItemContainer.verticalPanelMode
            ? Math.round((dockItemContainer.width - width) / 2)
            : (dockItemContainer.persistentReorderInsertAfter
                ? dockItemContainer.width - width / 2 : -width / 2)
        y: dockItemContainer.verticalPanelMode
            ? (dockItemContainer.persistentReorderInsertAfter
                ? dockItemContainer.height - height / 2 : -height / 2)
            : Math.round((dockItemContainer.height - height) / 2)
    }

    Item {
        id: persistentMoveHandle
        z: 7
        anchors.fill: parent
        visible: dockItemContainer.persistentMoveHandleVisible
        Accessible.ignored: true

        PunchiMenuComponents.PunchiMenuItemHighlight {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            hovered: mouseArea.containsMouse
            selected: true
            focused: mouseArea.activeFocus
            pressed: mouseArea.pressed
            motionEnabled: Kirigami.Units.longDuration > 0
        }

        RowLayout {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width
                - Kirigami.Units.smallSpacing * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: dockItemContainer.verticalPanelMode
                    ? Math.max(18, Math.round(dockItemContainer.iconSize * 0.56))
                    : Math.min(dockItemContainer.iconSize,
                        Math.max(16, persistentMoveHandle.height
                            - Kirigami.Units.smallSpacing * 3))
                Layout.preferredHeight: Layout.preferredWidth
                source: "window-duplicate"
                Accessible.ignored: true
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: !dockItemContainer.verticalPanelMode
                text: dockItemContainer.localizedItemName
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Kirigami.Icon {
                Layout.preferredWidth: Math.max(14,
                    Math.round(dockItemContainer.iconSize * 0.34))
                Layout.preferredHeight: Layout.preferredWidth
                source: "transform-move"
                color: Kirigami.Theme.textColor
                Accessible.ignored: true
            }
        }
    }

    Rectangle {
        z: 8
        anchors.fill: parent
        visible: dockItemContainer.externalDropState !== "none"
            && dockItemContainer.externalDropState !== "launcherAcceptable"
        radius: 8
        color: !dockItemContainer.externalDropRejected
            ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                Kirigami.Theme.highlightColor.g,
                Kirigami.Theme.highlightColor.b, 0.22)
            : Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                Kirigami.Theme.negativeTextColor.g,
                Kirigami.Theme.negativeTextColor.b, 0.18)
        border.width: 2
        border.color: !dockItemContainer.externalDropRejected
            ? Kirigami.Theme.highlightColor
            : Kirigami.Theme.negativeTextColor

        Kirigami.Icon {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.max(14, dockItemContainer.iconSize * 0.34)
            height: width
            source: dockItemContainer.externalDropRejected
                ? "dialog-warning-symbolic"
                : (dockItemContainer.externalDropState === "activated"
                    ? "go-up-symbolic"
                    : (dockItemContainer.externalDropState
                            === "launcherContainmentAcceptable"
                        ? "folder-add-symbolic" : "document-open-symbolic"))
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * dockItemContainer.externalDropActivationProgress
            height: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
            visible: dockItemContainer.externalDropState === "activationPending"
            radius: height / 2
            color: Kirigami.Theme.highlightedTextColor
        }
    }

    Rectangle {
        id: launcherDropPlaceholder
        z: 9
        visible: dockItemContainer.launcherDropPlaceholderVisible
        color: Qt.rgba(Kirigami.Theme.highlightColor.r,
            Kirigami.Theme.highlightColor.g,
            Kirigami.Theme.highlightColor.b, 0.22)
        radius: 8
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        width: dockItemContainer.verticalPanelMode
            ? dockItemContainer.width
            : dockItemContainer.launcherDropPlaceholderMainExtent
        height: dockItemContainer.verticalPanelMode
            ? dockItemContainer.launcherDropPlaceholderMainExtent
            : dockItemContainer.height
        x: dockItemContainer.verticalPanelMode
            ? Math.round((dockItemContainer.width - width) / 2)
            : (dockItemContainer.launcherDropInsertAfter
                ? dockItemContainer.width
                    + dockItemContainer.launcherDropLayoutSpacing / 2
                : -dockItemContainer.launcherDropReservedExtent
                    + dockItemContainer.launcherDropLayoutSpacing / 2)
        y: dockItemContainer.verticalPanelMode
            ? (dockItemContainer.launcherDropInsertAfter
                ? dockItemContainer.height
                    + dockItemContainer.launcherDropLayoutSpacing / 2
                : -dockItemContainer.launcherDropReservedExtent
                    + dockItemContainer.launcherDropLayoutSpacing / 2)
            : Math.round((dockItemContainer.height - height) / 2)
        Accessible.ignored: true

        Kirigami.Icon {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.max(14, dockItemContainer.iconSize * 0.34)
            height: width
            source: "list-add-symbolic"
            color: Kirigami.Theme.highlightColor
            Accessible.ignored: true
        }
    }

    NumberAnimation {
        id: externalDropActivationProgressAnimation
        target: dockItemContainer
        property: "externalDropActivationProgress"
        from: 0
        to: 1
        duration: dockItemContainer.externalDropActivationDelay
        easing.type: Easing.Linear
    }

    Timer {
        id: externalDropActivationTimer
        interval: dockItemContainer.externalDropActivationDelay
        repeat: false
        onTriggered: {
            const activated = typeof dockItemContainer.externalDropActivator === "function"
                && dockItemContainer.externalDropActivator()
            dockItemContainer.externalDropActivationProgress = activated ? 1 : 0
            dockItemContainer.externalDropState = activated ? "activated" : "acceptable"
        }
    }

    Item {
        id: visualArea
        objectName: "dockItemVisualArea"
        // The title card changes the delegate's layout width progressively.
        // Clipping the entire media surface here cuts transport buttons while
        // layouts and animations advance in different frames. Only the title
        // card clips its own text; all controls remain visible.
        clip: false
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: dockItemContainer.visualAreaHeight
        scale: dockItemContainer.clickAnimationScale * dockItemContainer.entryScale
        opacity: clickFeedback.visualOpacity
        transform: Translate {
            x: minimizeItemReaction.horizontalOffset
                + clickFeedback.horizontalOffset
                + (dockItemContainer.verticalPanelMode ? 0 : dockItemContainer.clickCollisionOffset)
                + (dockItemContainer.verticalPanelMode
                    ? 0.0 : dockItemContainer.waveMainAxisShift)
            y: minimizeItemReaction.verticalOffset
                + clickFeedback.verticalOffset
                + (dockItemContainer.verticalPanelMode ? dockItemContainer.clickCollisionOffset : 0)
                + (dockItemContainer.verticalPanelMode
                    ? dockItemContainer.waveMainAxisShift : 0.0)
        }

        IconReflection {
            id: iconReflection
            z: 0
            active: dockItemContainer.iconReflectionEnabled
                && dockItemContainer.iconReflectionVisibleRatio > 0.025
                && dockItemContainer.itemType !== "calendar"
                && !dockItemContainer.separatorItem
                && !dockItemContainer.spacerItem
                && !dockItemContainer.mediaItem
            iconSource: dockItemContainer.effectiveDockIconSource
            displaySize: dockItemContainer.iconReflectionDisplaySize
            visibleRatio: dockItemContainer.iconReflectionVisibleRatio
            horizontalOffset: dockItemContainer.hoverOffsetX
            opacity: Math.max(0.05, Math.min(0.50,
                dockItemContainer.iconReflectionOpacity))
            width: parent.width
            height: Math.max(1, displaySize
                * (sourceOverlapRatio + visibleRatio))
            x: 0
            y: (parent.height / 2) + (displaySize / 2)
                + dockItemContainer.hoverOffsetY - sourceOverlap
        }

        Item {
            id: overflowTile
            z: 1
            anchors.centerIn: parent
            width: dockItemContainer.iconSize
            height: width
            visible: dockItemContainer.overflowItem
            transformOrigin: Item.Center
            scale: dockItemContainer.waveScale
            transform: Translate {
                x: dockItemContainer.hoverOffsetX
                y: dockItemContainer.hoverOffsetY
            }
            Accessible.ignored: true

            Rectangle {
                id: overflowTileBackground
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 1.5
                color: Kirigami.Theme.highlightColor
                opacity: mouseArea.containsMouse || mouseArea.activeFocus
                    ? 1.0 : 0.82
                Accessible.ignored: true
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.max(16, dockItemContainer.iconSize * 0.48)
                height: width
                source: dockItemContainer.effectiveDockIconSource
                roundToIconSize: false
                color: Kirigami.Theme.highlightedTextColor
                Accessible.ignored: true
            }
        }

        Kirigami.Icon {
            id: itemIcon
            z: 1
            objectName: "dockItemIcon"
            anchors.centerIn: parent
            width: dockItemContainer.highQualityIconSize
            height: dockItemContainer.highQualityIconSize
            source: dockItemContainer.effectiveDockIconSource
            // Ask the icon theme for this exact pre-scaled size. This avoids
            // snapping to 32/48/64 px before the dock applies its wave zoom.
            roundToIconSize: false
            smooth: true
            visible: dockItemContainer.itemType !== "calendar" && !dockItemContainer.separatorItem && !dockItemContainer.spacerItem
                && !dockItemContainer.overflowItem
                && !dockItemContainer.mediaItem
                && dockItemContainer.itemType !== "folder"

            scale: dockItemContainer.highQualityIconScale
                * (dockItemContainer.itemType === "punchimenu"
                    && dockItemContainer.launcherMenuOpen ? 1.0 : dockItemContainer.waveScale)
                * (dockItemContainer.itemType === "app" ? 0.86 : 1.0)
            // R62.2: the accent overlay exists only for the one built-in menu
            // launcher. Instantiating QtQuick.Shapes for every application icon
            // would add needless work to the dock rendering path.
            Loader {
                z: 3
                anchors.fill: parent
                active: dockItemContainer.itemType === "punchimenu"
                    && (String(dockItemContainer.iconName || "") === "start-here-kde"
                        || !dockItemContainer.iconName)
                sourceComponent: Component {
                    OgerMenuEyes {
                        active: dockItemContainer.launcherMenuOpen
                        eyeColor: Kirigami.Theme.highlightColor
                        Accessible.ignored: true
                    }
                }
            }
            transform: Translate {
                x: dockItemContainer.hoverOffsetX
                    + (dockItemContainer.verticalPanelMode && dockItemContainer.taskIndicatorCount > 0
                        && dockItemContainer.effectiveIndicatorPosition === "right" ? -6 : 0)
                    + (dockItemContainer.verticalPanelMode && dockItemContainer.taskIndicatorCount > 0
                        && dockItemContainer.effectiveIndicatorPosition === "left" ? 6 : 0)
                y: dockItemContainer.hoverOffsetY
                    - (!dockItemContainer.verticalPanelMode
                        && dockItemContainer.taskIndicatorCount > 0 ? 6 : 0)
            }
        }

        FolderStackIcon {
            id: folderStackPreview
            objectName: "dockFolderStackIcon"
            visible: dockItemContainer.itemType === "folder"
            z: 3
            anchors.centerIn: parent
            iconExtent: dockItemContainer.iconSize
            entries: dockItemContainer.folderPreviewEntries
            categoryAccent: dockItemContainer.effectiveFolderAccent
            fallbackIcon: String(dockItemContainer.iconName || "folder")
            opened: dockItemContainer.folderOpen
            motionEnabled: dockItemContainer.mediaMotionEnabled
            scale: dockItemContainer.waveScale
            transform: Translate {
                x: dockItemContainer.hoverOffsetX
                y: dockItemContainer.hoverOffsetY
            }
        }

        // The floating label has to sit on the icon that is on screen. The dock
        // moves that icon while the item keeps its layout rect: an ancestor
        // shifts the whole visual along the main axis (`waveMainAxisShift` lives
        // in `visualArea`) and the icon itself scales about its centre
        // (`waveScale`) and then translates (`hoverOffsetX/Y`). Plasma places a
        // tooltip against its visual parent's scene rect and does not follow that
        // item afterwards, so the label is anchored to this invisible item,
        // which mirrors the visible icon rect instead of the layout rect.
        // Scale, offsets and the icon geometry stay declared here: reading a
        // transformed item does not make a binding depend on its transform.
        // The exact match is the settled state, with `entryScale`,
        // `clickAnimationScale` and the reaction offsets back at 1 and 0.
        Item {
            id: tooltipAnchor

            objectName: "dockItemTooltipAnchor"
            visible: false
            width: itemIcon.width * itemIcon.scale
            height: itemIcon.height * itemIcon.scale
            x: itemIcon.x + (itemIcon.width - width) / 2
                + dockItemContainer.hoverOffsetX
            y: itemIcon.y + (itemIcon.height - height) / 2
                + dockItemContainer.hoverOffsetY
        }

        Column {
            id: calendarText
            anchors.centerIn: parent
            visible: dockItemContainer.itemType === "calendar"
            spacing: 1

            scale: dockItemContainer.waveScale
            transform: Translate {
                x: dockItemContainer.hoverOffsetX
                y: dockItemContainer.hoverOffsetY
            }

            PlasmaExtras.ShadowedLabel {
                text: dockItemContainer.currentTime
                renderShadow: dockItemContainer.calendarTextShadowsEnabled
                font.pixelSize: Math.round(14 * dockItemContainer.timeTextScale)
                font.weight: Font.Normal
                anchors.horizontalCenter: parent.horizontalCenter
            }

            PlasmaExtras.ShadowedLabel {
                text: dockItemContainer.currentDate
                renderShadow: dockItemContainer.calendarTextShadowsEnabled
                font.pixelSize: Math.round(9 * dockItemContainer.dateTextScale)
                opacity: 0.68
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        ThemedSeparator {
            visible: dockItemContainer.separatorItem
                && dockItemContainer.separatorVisibleSetting
                && !dockItemContainer.persistentMoveHandleVisible
            anchors.centerIn: parent
            theme: dockItemContainer.customSeparatorEnabled
                ? dockItemContainer.separatorTheme : ({})
            verticalPanel: dockItemContainer.verticalPanelMode
            availableLength: dockItemContainer.verticalPanelMode
                ? visualArea.width : visualArea.height
            style: dockItemContainer.effectiveSeparatorAppearance.style
            thickness: dockItemContainer.effectiveSeparatorAppearance.thickness
            lengthRatio: dockItemContainer.effectiveSeparatorAppearance.lengthRatio
            customOpacity: dockItemContainer.effectiveSeparatorAppearance.opacity
            glowEnabled: dockItemContainer.effectiveSeparatorAppearance.glowEnabled
        }


        WindowCountBadge {
            z: 3
            anchors.centerIn: parent
            width: dockItemContainer.iconSize
            height: dockItemContainer.iconSize
            count: dockItemContainer.taskIndicatorCount
            iconSize: dockItemContainer.iconSize
            demandsAttention: dockItemContainer.taskDemandsAttention
            badgeEnabled: dockItemContainer.windowCountBadgeEnabled
            groupingEnabled: dockItemContainer.windowGroupingEnabled
            position: dockItemContainer.windowCountBadgePosition
            emblemColor: dockItemContainer.windowCountEmblemColor
            emblemOpacity: dockItemContainer.windowCountEmblemOpacity
            emblemScale: dockItemContainer.windowCountEmblemScale
            transformOrigin: Item.Center
            scale: dockItemContainer.waveScale
            transform: Translate {
                x: dockItemContainer.hoverOffsetX
                y: dockItemContainer.hoverOffsetY
            }
        }

        MediaDockItem {
            id: mediaDockItem
            anchors.centerIn: parent
            width: dockItemContainer.verticalPanelMode
                ? dockItemContainer.iconSize
                : currentMainAxisLength
            height: dockItemContainer.verticalPanelMode
                ? currentMainAxisLength
                : dockItemContainer.iconSize
            visible: dockItemContainer.mediaItem
            pinPreferences: dockItemContainer.mediaPinPreferences
            onPinPreferenceChanged: function(identity, pinned) {
                dockItemContainer.mediaPinRequested(identity, pinned)
            }
            controller: dockItemContainer.mediaController
            iconSize: dockItemContainer.iconSize
            compactIconRenderSize: dockItemContainer.highQualityIconSize
            compactIconBaseScale: dockItemContainer.highQualityIconScale
            // The mini-player contains interactive controls: zooming its
            // entire width can clip the last button at the screen edge.
            visualScale: (dockItemContainer.mediaEntranceAnimation === "zoom"
                    ? (0.88 + 0.12 * dockItemContainer.mediaEntranceProgress) : 1.0)
            visualOffsetX: dockItemContainer.hoverOffsetX
            visualOffsetY: dockItemContainer.hoverOffsetY
                + (dockItemContainer.mediaEntranceAnimation === "slide"
                    && !dockItemContainer.verticalPanelMode
                    ? (1.0 - dockItemContainer.mediaEntranceProgress) * 12 : 0)
            vertical: dockItemContainer.verticalPanelMode
            panelLocation: dockItemContainer.panelLocation
            motionEnabled: dockItemContainer.mediaMotionEnabled
            externalClickFeedback: true
            motionSpeedPercent: dockItemContainer.resolvedDockMotionSpeedPercent
            autoCollapseDelaySeconds: dockItemContainer.resolvedMediaAutoCollapseDelaySeconds
            contextMenuEnabled: dockItemContainer.supportsContextMenu
            launchAvailable: dockItemContainer.mediaLaunchAvailable
            defaultPlayerName: dockItemContainer.mediaDefaultPlayerName
            defaultPlayerIcon: dockItemContainer.mediaDefaultPlayerIcon
            textMode: dockItemContainer.mediaTextMode
            displayMode: dockItemContainer.mediaDisplayMode
            showCover: dockItemContainer.mediaShowCover
            showTitle: dockItemContainer.mediaShowTitle
            showControls: dockItemContainer.mediaShowControls
            showProgress: dockItemContainer.mediaShowProgress
            showVolume: dockItemContainer.mediaShowVolume
            backgroundStyle: dockItemContainer.mediaBackgroundStyle
            expandedMainAxisLength: dockItemContainer.mediaMainAxisLength
            maximumInlineTitleExtent: dockItemContainer.mediaMaxInlineTitleExtent
            onInlineTitleExtentChanged:
                dockItemContainer.mediaInlineExtentChanged(inlineTitleExtent)
            onInteractionActivated: dockItemContainer.playClickFeedback()
            onLaunchRequested: dockItemContainer.mediaLaunchRequested()
            onPlaybackLaunchRequested: dockItemContainer.mediaPlaybackLaunchRequested()
            onContextMenuRequested: function(keyboardInvoked) {
                dockItemContainer.contextMenuRequested(dockItemContainer, keyboardInvoked)
            }
            onHoverChanged: function(hovered) {
                if (hovered) {
                    dockItemContainer.layoutController.hoveredIndex = dockItemContainer.itemIndex
                    const centerPoint = dockItemContainer.mapToItem(
                        dockItemContainer.layoutController,
                        dockItemContainer.width / 2,
                        dockItemContainer.height / 2)
                    const center = dockItemContainer.verticalPanelMode
                        ? centerPoint.y
                        : centerPoint.x
                    dockItemContainer.layoutController.pointerPrimaryAxis = center
                    dockItemContainer.layoutController.lastPointerPrimaryAxis = center
                } else if (dockItemContainer.layoutController.hoveredIndex === dockItemContainer.itemIndex) {
                    dockItemContainer.layoutController.hoveredIndex = -1
                }
            }
            onExpansionChanged: function(expanded, transitionDuration) {
                dockItemContainer.mediaExpansionChanged(expanded, transitionDuration)
            }
        }
    }

    // Dedicated indicator plane: not a child of the zoomed visualArea.
    // Its lane remains visible during hover, opening and maximization.
    TaskIndicator {
        z: 6
        x: Math.round((dockItemContainer.width - width) / 2)
        y: Math.round((dockItemContainer.visualAreaHeight - height) / 2)
            width: dockItemContainer.iconSize + (dockItemContainer.verticalPanelMode ? 12 : 0)
            height: dockItemContainer.iconSize + (dockItemContainer.verticalPanelMode ? 0 : 12)
            visible: (dockItemContainer.itemType === "app"
                    || dockItemContainer.itemType === "trash")
                && dockItemContainer.taskIndicatorCount > 0
            count: dockItemContainer.taskIndicatorCount
            trayOnly: dockItemContainer.trayOnlyExecution
            minimizedCount: dockItemContainer.taskMinimizedCount
            maximizedCount: dockItemContainer.taskMaximizedCount
            motionEnabled: dockItemContainer.mediaMotionEnabled
            active: dockItemContainer.taskIsActive
            demandsAttention: dockItemContainer.taskDemandsAttention
            type: dockItemContainer.indicatorType
            position: dockItemContainer.effectiveIndicatorPosition
            customColor: dockItemContainer.indicatorColor.length > 0
                ? dockItemContainer.indicatorColor
                : "transparent"
            thickness: dockItemContainer.indicatorThickness
            indicatorOpacity: dockItemContainer.indicatorOpacity
            neonEnabled: dockItemContainer.indicatorNeonEnabled
            neonIntensity: dockItemContainer.indicatorNeonIntensity
            iconSize: dockItemContainer.iconSize
            // This sibling is unaffected by visualArea hover or click scale.
            scale: 1.0
        }


    // Active launcher illumination lives outside visualArea: not affected
    // by hover zoom, animation scale or icon translation.
    Rectangle {
        id: stableLauncherGlow
        z: 7
        width: dockItemContainer.iconSize + 4
        height: width
        x: Math.round((dockItemContainer.width - width) / 2)
        y: Math.round((dockItemContainer.visualAreaHeight - height) / 2)
        radius: Math.max(8, width * 0.22)
        color: "transparent"
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        opacity: dockItemContainer.itemType === "punchimenu"
            && dockItemContainer.launcherMenuOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 195; easing.type: Easing.InOutCubic }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Kirigami.Theme.highlightColor
            opacity: 0.24
        }
    }

    Item {
        id: taskGeometryProxy
        anchors.fill: visualArea
    }

    PlasmaExtras.ShadowedLabel {
        id: persistentLabel
        visible: dockItemContainer.showPersistentLabel && !dockItemContainer.separatorItem && !dockItemContainer.spacerItem
            && !dockItemContainer.mediaItem
        anchors.top: visualArea.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 6
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: dockItemContainer.localizedItemName
        renderShadow: dockItemContainer.textShadowsEnabled
        font.pixelSize: dockItemContainer.labelFontSize
        opacity: mouseArea.containsMouse || dockItemContainer.taskIsActive ? 1.0 : 0.88
        transform: Translate {
            x: dockItemContainer.verticalPanelMode
                ? 0.0 : dockItemContainer.waveMainAxisShift
            y: dockItemContainer.verticalPanelMode
                ? dockItemContainer.waveMainAxisShift : 0.0
        }
    }

    SequentialAnimation {
        id: selectionPulseAnimation
        running: false

        NumberAnimation {
            target: dockItemContainer
            property: "selectionPulseScale"
            to: dockItemContainer.selectionPulsePeakScale
            duration: Math.round(dockItemContainer.selectionPulseDuration * 0.45)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: dockItemContainer
            property: "selectionPulseScale"
            to: 0.97
            duration: Math.round(dockItemContainer.selectionPulseDuration * 0.25)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: dockItemContainer
            property: "selectionPulseScale"
            to: 1.0
            duration: Math.round(dockItemContainer.selectionPulseDuration * 0.30)
            easing.type: Easing.OutCubic
        }
    }

    DockItemClickFeedback {
        id: clickFeedback
        objectName: "dockItemClickFeedback"
        effect: dockItemContainer.clickEffect
        iconSize: dockItemContainer.iconSize
        motionSpeedPercent: dockItemContainer.resolvedDockMotionSpeedPercent
        direction: dockItemContainer.inPanel
            && dockItemContainer.panelLocation === PlasmaCore.Types.TopEdge ? 1 : -1
        feedbackEnabled: dockItemContainer.visible && dockItemContainer.enabled
            && !dockItemContainer.structuralWaveItem
            && !dockItemContainer.persistentReorderActive
        pressed: dockItemContainer.mediaItem
            ? mediaDockItem.interactionPressed
            : ((mouseArea.pressed && mouseArea.pressedButtons & Qt.LeftButton)
                || dockItemContainer.keyboardFeedbackPressed)
    }

    Timer {
        id: persistentReorderInteractionResetTimer
        interval: 0
        repeat: false
        onTriggered:
            dockItemContainer.persistentReorderInteractionResetPending = false
    }

    DragHandler {
        id: unlockedReorderGesture
        target: null
        acceptedButtons: Qt.LeftButton
        enabled: dockItemContainer.persistentPointerReorderEnabled
            && !dockItemContainer.mediaItem
        onActiveChanged: {
            if (active) {
                dockItemContainer.persistentReorderPressStarted(dockItemContainer)
                dockItemContainer.persistentReorderStarted(
                    dockItemContainer.persistentModelIndex, dockItemContainer)
                if (dockItemContainer.persistentReorderSource) {
                    dockItemContainer.suppressClickAfterReorder = true
                    dockItemContainer.persistentReorderMoved(
                        centroid.position.x, centroid.position.y)
                }
            } else if (dockItemContainer.persistentReorderSource) {
                dockItemContainer.persistentReorderFinished()
            }
        }
        onCentroidChanged: {
            if (active && dockItemContainer.persistentReorderSource)
                dockItemContainer.persistentReorderMoved(
                    centroid.position.x, centroid.position.y)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: !dockItemContainer.mediaItem
            && !dockItemContainer.persistentReorderInteractionResetPending
        hoverEnabled: !dockItemContainer.persistentReorderActive
            && !dockItemContainer.separatorItem
            && !dockItemContainer.spacerItem
        activeFocusOnTab: true
        // MouseArea often consumes wheel events before an ancestor WheelHandler
        // can receive them on Plasma 6. Handle the actual dock hit target.
        onWheel: function(wheel) {
            if (dockItemContainer.itemType === "folder"
                    || dockItemContainer.itemType === "recent"
                    || dockItemContainer.persistentReorderActive) {
                wheel.accepted = false
                return
            }
            const owner = dockItemContainer.layoutController
            wheel.accepted = !!(owner
                && typeof owner.handleGlobalWindowWheel === "function"
                && owner.handleGlobalWindowWheel(
                    Number(wheel.angleDelta.y || 0)
                        || Number(wheel.pixelDelta.y || 0) * 3,
                    wheel.modifiers))
        }
        preventStealing: dockItemContainer.persistentReorderSource
        cursorShape: dockItemContainer.persistentReorderSource
            ? Qt.ClosedHandCursor
            : (dockItemContainer.persistentDirectReorderEnabled
                ? Qt.OpenHandCursor : Qt.ArrowCursor)
        Accessible.role: (dockItemContainer.separatorItem || dockItemContainer.spacerItem)
                && !dockItemContainer.persistentReorderEnabled
            ? Accessible.StaticText : Accessible.Button
        Accessible.name: dockItemContainer.localizedItemName
        // qmllint disable unqualified
        Accessible.description: {
            if (dockItemContainer.persistentMoveHandleVisible) {
                return i18nc("@info:accessible",
                    "Drag to move the open applications section. Use an arrow key to move it one position, or Escape to cancel.")
            }
            if (dockItemContainer.externalDropState === "activationPending") {
                return i18nc("@info:accessible", "Keep holding to bring %1 to the front",
                    dockItemContainer.localizedItemName)
            }
            if (dockItemContainer.externalDropState === "activated") {
                return i18nc("@info:accessible", "%1 is now in front; release to open the local files",
                    dockItemContainer.localizedItemName)
            }
            if (dockItemContainer.externalDropState === "acceptable") {
                return i18nc("@info:accessible", "Release to open local files with %1",
                    dockItemContainer.localizedItemName)
            }
            if (dockItemContainer.externalDropState === "launcherAcceptable") {
                return i18nc("@info:accessible", "Release to insert %1 in the Dock",
                    dockItemContainer.launcherDropApplicationName.length > 0
                        ? dockItemContainer.launcherDropApplicationName
                        : i18n("Application"))
            }
            if (dockItemContainer.externalDropState
                    === "launcherContainmentAcceptable") {
                return i18nc("@info:accessible", "Release to add %1 to %2",
                    dockItemContainer.launcherDropApplicationName.length > 0
                        ? dockItemContainer.launcherDropApplicationName
                        : i18n("Application"),
                    dockItemContainer.localizedItemName)
            }
            if (dockItemContainer.externalDropState
                    === "launcherContainmentRejected") {
                return i18nc("@info:accessible",
                    "%1 is updated automatically and cannot accept applications",
                    dockItemContainer.localizedItemName)
            }
            if (dockItemContainer.externalDropRejected) {
                return i18nc("@info:accessible", "This file drop cannot be accepted")
            }
            if (dockItemContainer.persistentPointerReorderEnabled) {
                return i18nc("@info:accessible",
                    "Press and hold to move this Dock item. Use Control+Shift with an arrow key to move it from the keyboard.")
            }
            if (dockItemContainer.persistentReorderEnabled) {
                return i18nc("@info:accessible",
                    "Use Control+Shift with an arrow key to move this Dock item.")
            }
            if (dockItemContainer.windowCountBadgeEnabled
                    && dockItemContainer.windowGroupingEnabled
                    && dockItemContainer.taskIndicatorCount >= 2) {
                if (dockItemContainer.mediaHoverControlsEnabled) {
                    return i18np("%1 open window. Press M to open media controls.",
                        "%1 open windows. Press M to open media controls.",
                        dockItemContainer.taskIndicatorCount)
                }
                return i18np("%1 open window", "%1 open windows",
                    dockItemContainer.taskIndicatorCount)
            }
            return dockItemContainer.mediaHoverControlsEnabled
                ? i18nc("@info:accessible", "Press M to open media controls")
                : ""
        }
        // qmllint enable unqualified
        acceptedButtons: (dockItemContainer.separatorItem || dockItemContainer.spacerItem)
                && !dockItemContainer.persistentReorderEnabled
            ? Qt.NoButton
            : (dockItemContainer.supportsContextMenu && dockItemContainer.itemType !== "trash"
                ? Qt.LeftButton | Qt.RightButton
                : Qt.LeftButton)
        
        onContainsMouseChanged: {
            if (dockItemContainer.separatorItem || dockItemContainer.spacerItem || dockItemContainer.itemType === "calendar") {
                if (!containsMouse && dockItemContainer.layoutController.hoveredIndex === dockItemContainer.itemIndex) {
                    dockItemContainer.layoutController.hoveredIndex = -1
                    dockItemContainer.layoutController.mouseOffset = 0.0
                }
                return
            }
            if (containsMouse) {
                dockItemContainer.restartSelectionPulse()
                dockItemContainer.layoutController.hoveredIndex = dockItemContainer.itemIndex
                dockItemContainer.updateWavePointer(
                    mouseArea.mouseX, mouseArea.mouseY)
                dockItemContainer.hoverEntered(dockItemContainer)
            } else if (dockItemContainer.layoutController.hoveredIndex === dockItemContainer.itemIndex) {
                dockItemContainer.resetSelectionPulse()
                if (!dockItemContainer.shouldKeepWaveActiveAcrossLayoutGap()) {
                    dockItemContainer.layoutController.hoveredIndex = -1
                    dockItemContainer.layoutController.mouseOffset = 0.0
                }
                dockItemContainer.hoverExited(dockItemContainer)
            } else {
                dockItemContainer.resetSelectionPulse()
                dockItemContainer.hoverExited(dockItemContainer)
            }
        }
        
        onPositionChanged: function(mouse) {
            if (dockItemContainer.persistentReorderSource && pressed) {
                dockItemContainer.persistentReorderMoved(mouse.x, mouse.y)
            }
            if (dockItemContainer.separatorItem || dockItemContainer.spacerItem || dockItemContainer.itemType === "calendar") {
                return
            }
            if (containsMouse) {
                dockItemContainer.updateWavePointer(mouse.x, mouse.y)
            }
        }

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton
                    && dockItemContainer.persistentDirectReorderEnabled
                    && !dockItemContainer.persistentReorderActive) {
                dockItemContainer.persistentReorderPressStarted(
                    dockItemContainer)
                dockItemContainer.persistentReorderStarted(
                    dockItemContainer.persistentModelIndex,
                    dockItemContainer)
                if (dockItemContainer.persistentReorderSource) {
                    dockItemContainer.suppressClickAfterReorder = true
                    mouse.accepted = true
                    mouseArea.forceActiveFocus(Qt.MouseFocusReason)
                    dockItemContainer.persistentReorderMoved(mouse.x, mouse.y)
                }
                return
            }
            if (mouse.button === Qt.LeftButton
                    && dockItemContainer.persistentPointerReorderEnabled
                    && !dockItemContainer.persistentReorderActive) {
                dockItemContainer.persistentReorderPressStarted(
                    dockItemContainer)
            }
            // Right-click context menus open on RELEASE (below). Opening a
            // Qt.Popup while its triggering button is still pressed can
            // dismiss the menu immediately under KDE Wayland.
        }

        onPressAndHold: function(mouse) {
            if (mouse.button !== Qt.LeftButton
                    || dockItemContainer.persistentDirectReorderEnabled
                    || !dockItemContainer.persistentPointerReorderEnabled
                    || dockItemContainer.persistentReorderActive) {
                return
            }
            dockItemContainer.persistentReorderStarted(
                dockItemContainer.persistentModelIndex, dockItemContainer)
            if (dockItemContainer.persistentReorderSource) {
                dockItemContainer.suppressClickAfterReorder = true
                mouse.accepted = true
                mouseArea.forceActiveFocus(Qt.MouseFocusReason)
                dockItemContainer.persistentReorderMoved(mouse.x, mouse.y)
            }
        }

        onReleased: function(mouse) {
            if (dockItemContainer.persistentReorderSource) {
                dockItemContainer.persistentReorderFinished()
            }
            if (mouse.button === Qt.RightButton
                    && dockItemContainer.itemType !== "trash"
                    && dockItemContainer.supportsContextMenu
                    && containsMouse) {
                // Keep the release serial for native Wayland popups.
                dockItemContainer.contextMenuRequested(dockItemContainer, false)
            }
        }

        onCanceled: {
            if (dockItemContainer.persistentReorderSource) {
                dockItemContainer.persistentReorderCanceled()
            }
        }
        
        onClicked: function(mouse) {
            if (dockItemContainer.suppressClickAfterReorder) {
                dockItemContainer.suppressClickAfterReorder = false
                return
            }
            if (dockItemContainer.separatorItem || dockItemContainer.spacerItem) {
                return
            }
            if (mouse.button === Qt.RightButton) {
                return
            }
            dockItemContainer.activateItem()
        }
        Keys.onReturnPressed: {
            dockItemContainer.keyboardFeedbackPressed = true
            dockItemContainer.activateItem()
        }
        Keys.onSpacePressed: {
            dockItemContainer.keyboardFeedbackPressed = true
            dockItemContainer.activateItem()
        }
        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                dockItemContainer.keyboardFeedbackPressed = false
            }
        }
        onActiveFocusChanged: {
            if (!activeFocus) {
                dockItemContainer.keyboardFeedbackPressed = false
            }
        }
        Accessible.onPressAction: dockItemContainer.activateItem()
        Keys.onPressed: function(event) {
            if (dockItemContainer.persistentMoveHandleVisible
                    && event.key === Qt.Key_Escape) {
                dockItemContainer.persistentMoveModeCanceled()
                event.accepted = true
                return
            }
            if (dockItemContainer.persistentReorderSource
                    && event.key === Qt.Key_Escape) {
                dockItemContainer.suppressClickAfterReorder = true
                dockItemContainer.persistentReorderCanceled()
                event.accepted = true
                return
            }
            const reorderModifiers = Qt.ControlModifier | Qt.ShiftModifier
            if (dockItemContainer.persistentReorderEnabled
                    && (event.modifiers === reorderModifiers
                        || (dockItemContainer.persistentMoveHandleVisible
                            && event.modifiers === Qt.NoModifier))) {
                const previousKey = dockItemContainer.verticalPanelMode
                    ? Qt.Key_Up : Qt.Key_Left
                const nextKey = dockItemContainer.verticalPanelMode
                    ? Qt.Key_Down : Qt.Key_Right
                if (event.key === previousKey || event.key === nextKey) {
                    dockItemContainer.persistentKeyboardMoveRequested(
                        dockItemContainer.persistentModelIndex,
                        event.key === previousKey ? -1 : 1)
                    event.accepted = true
                    return
                }
            }
            if (dockItemContainer.mediaHoverControlsEnabled
                    && event.key === Qt.Key_M
                    && event.modifiers === Qt.NoModifier) {
                dockItemContainer.mediaControlsRequested(dockItemContainer)
                event.accepted = true
                return
            }
            if (dockItemContainer.supportsContextMenu && dockItemContainer.itemType !== "trash" && (event.key === Qt.Key_Menu
                    || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))) {
                dockItemContainer.contextMenuRequested(dockItemContainer, true)
                event.accepted = true
            }
        }
    }

    DropArea {
        id: externalDropArea
        anchors.fill: parent
        anchors.leftMargin: dockItemContainer.launcherDropPlaceholderVisible
            && !dockItemContainer.verticalPanelMode
            && !dockItemContainer.launcherDropInsertAfter
            ? -dockItemContainer.launcherDropReservedExtent : 0
        anchors.rightMargin: dockItemContainer.launcherDropPlaceholderVisible
            && !dockItemContainer.verticalPanelMode
            && dockItemContainer.launcherDropInsertAfter
            ? -dockItemContainer.launcherDropReservedExtent : 0
        anchors.topMargin: dockItemContainer.launcherDropPlaceholderVisible
            && dockItemContainer.verticalPanelMode
            && !dockItemContainer.launcherDropInsertAfter
            ? -dockItemContainer.launcherDropReservedExtent : 0
        anchors.bottomMargin: dockItemContainer.launcherDropPlaceholderVisible
            && dockItemContainer.verticalPanelMode
            && dockItemContainer.launcherDropInsertAfter
            ? -dockItemContainer.launcherDropReservedExtent : 0
        enabled: dockItemContainer.itemType === "trash"
            || dockItemContainer.externalDropEnabled
            || dockItemContainer.launcherDropEnabled

        onContainsDragChanged: {
            if (!containsDrag) {
                dockItemContainer.cancelExternalDropActivation()
                dockItemContainer.externalDropState = "none"
                dockItemContainer.launcherDropApplicationName = ""
                if (dockItemContainer.layoutController) {
                    dockItemContainer.layoutController.launcherDropTransitionActive = false
                }
            }
        }

        onEntered: function(drag) {
            const launcherCandidate
                = dockItemContainer.mayContainApplicationLauncher(drag)
            const launcherValidation = launcherCandidate
                ? dockItemContainer.validateLauncherDrop(drag.urls)
                : { "accepted": false }
            if (dockItemContainer.isApplicationLauncherDrag(
                    drag, launcherValidation)) {
                dockItemContainer.cancelExternalDropActivation()
                dockItemContainer.launcherDropApplicationName
                    = String(launcherValidation.name || "")
                if (!launcherValidation.accepted) {
                    drag.accepted = false
                    dockItemContainer.externalDropState = "rejected"
                    return
                }
                drag.accepted = true
                if (dockItemContainer.launcherContainerDropTarget) {
                    dockItemContainer.externalDropState
                        = dockItemContainer.launcherContainerDropEnabled
                            ? "launcherContainmentAcceptable"
                            : "launcherContainmentRejected"
                } else {
                    const position = externalDropArea.mapToItem(
                        dockItemContainer, drag.x, drag.y)
                    dockItemContainer.updateLauncherDropPosition(
                        position.x, position.y)
                    dockItemContainer.externalDropState = "launcherAcceptable"
                    if (dockItemContainer.layoutController) {
                        dockItemContainer.layoutController.launcherDropTransitionActive = true
                    }
                }
                return
            }
            if (dockItemContainer.itemType !== "trash"
                    && !dockItemContainer.externalDropEnabled) {
                drag.accepted = false
                return
            }
            if (!drag.hasUrls) {
                drag.accepted = false
                return
            }
            drag.accept()
            dockItemContainer.externalDropState = "acceptable"
            if (dockItemContainer.itemType !== "trash") {
                dockItemContainer.beginExternalDropActivation()
            }
        }

        onPositionChanged: function(drag) {
            if (dockItemContainer.externalDropState === "launcherAcceptable") {
                const position = externalDropArea.mapToItem(
                    dockItemContainer, drag.x, drag.y)
                dockItemContainer.updateLauncherDropPosition(
                    position.x, position.y)
            }
            dockItemContainer.maintainLauncherDropAcceptance(drag)
        }

        onExited: {
            dockItemContainer.cancelExternalDropActivation()
            dockItemContainer.externalDropState = "none"
            dockItemContainer.launcherDropApplicationName = ""
            if (dockItemContainer.layoutController) {
                dockItemContainer.layoutController.launcherDropTransitionActive = false
            }
        }

        onDropped: function(drop) {
            dockItemContainer.cancelExternalDropActivation()
            const launcherCandidate
                = dockItemContainer.mayContainApplicationLauncher(drop)
            const launcherValidation = launcherCandidate
                ? dockItemContainer.validateLauncherDrop(drop.urls)
                : { "accepted": false }
            if (dockItemContainer.isApplicationLauncherDrag(
                    drop, launcherValidation)) {
                drop.accepted = launcherValidation.accepted
                if (launcherValidation.accepted
                        && dockItemContainer.launcherContainerDropTarget) {
                    dockItemContainer.applicationLauncherContainerDropped(
                        drop.urls, dockItemContainer)
                } else if (launcherValidation.accepted) {
                    const position = externalDropArea.mapToItem(
                        dockItemContainer, drop.x, drop.y)
                    dockItemContainer.updateLauncherDropPosition(
                        position.x, position.y)
                    dockItemContainer.applicationLauncherDropped(
                        drop.urls, dockItemContainer.launcherInsertionIndex(),
                        dockItemContainer)
                }
                dockItemContainer.externalDropState = "none"
                dockItemContainer.launcherDropApplicationName = ""
                if (dockItemContainer.layoutController) {
                    dockItemContainer.layoutController.launcherDropTransitionActive = false
                }
                return
            }
            if (dockItemContainer.itemType !== "trash"
                    && !dockItemContainer.externalDropEnabled) {
                drop.accepted = false
                dockItemContainer.externalDropState = "none"
                return
            }
            if (dockItemContainer.itemType === "trash" && drop.hasUrls) {
                dockItemContainer.layoutController.trashUrlsDropped(drop.urls)
                dockItemContainer.externalDropState = "none"
                return
            }
            dockItemContainer.externalUrlsDropped(
                drop.hasUrls ? drop.urls : [], dockItemContainer)
            dockItemContainer.externalDropState = "none"
        }
    }
    Timer {
        id: tooltipDelayTimer
        interval: Kirigami.Units.toolTipDelay
        running: dockItemContainer.showAnyTooltip && mouseArea.containsMouse
    }

    Component {
        id: textTooltipComponent

        ColumnLayout {
            spacing: 4

            Controls.Label {
                text: dockItemContainer.localizedItemName
                color: Kirigami.Theme.textColor
                font.bold: true
            }
        }
    }

    PlasmaCore.Dialog {
        id: tooltipDialog
        // Plasma places the label against what the item shows on screen, so the
        // label follows the dock zoom instead of staying on the layout rect.
        visualParent: tooltipAnchor
        location: dockItemContainer.tooltipLocation
        type: PlasmaCore.Dialog.Tooltip
        visible: dockItemContainer.showAnyTooltip && mouseArea.containsMouse && !tooltipDelayTimer.running
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

        mainItem: Item {
            implicitWidth: tooltipContentLoader.implicitWidth
            implicitHeight: tooltipContentLoader.implicitHeight

            Loader {
                id: tooltipContentLoader
                anchors.fill: parent
                sourceComponent: textTooltipComponent
            }
        }
    }
}
