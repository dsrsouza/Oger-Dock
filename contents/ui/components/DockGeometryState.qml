import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import "../../code/separatorAppearance.js" as SeparatorAppearance
import "../../code/plasmaPanelSizing.js" as PlasmaPanelSizing

QtObject {
    id: root

    property bool inPanel: false
    property bool hiddenByVirtualDesktop: false
    property bool verticalPanel: false
    property bool horizontalPanel: false
    property int panelLocation: PlasmaCore.Types.BottomEdge
    property int configuredFloatingEdge: PlasmaCore.Types.BottomEdge
    property int configuredIconSize: 32
    property int configuredPanelThickness: 0
    property bool unlockPanelIconSizeLimit: false
    property bool panelAlwaysVisible: false
    property int configuredIconSpacing: 8
    property string configuredPanelLengthMode: "fit"
    property string configuredPanelAlignmentMode: "start"
    property int folderPopupDistancePercent: 0
    property int contextMenuDistancePercent: 0
    property real panelHoverScale: 1.0
    property bool dockShowLabels: false
    property int dockLabelAreaHeight: 0
    property var dockItems: []
    property var supplementalDockItems: []
    property bool mediaItemExpanded: true
    property bool mediaPlayerAvailable: false
    property bool mediaPlayerPlaying: false
    property bool mediaSoundConfirmed: false
    // One animated value drives both the dock layout and the delegate. This
    // prevents the gap disappearing before the mini-player fades/slides out.
    property real mediaSoundReveal: mediaSoundConfirmed ? 1.0 : 0.0
    Behavior on mediaSoundReveal {
        NumberAnimation { duration: 320; easing.type: Easing.InOutCubic }
    }
    function mediaVisibilityFactorForItem(item) {
        if (!item || String(item.type || "") !== "media") return 1.0
        const mode = String(item.mediaIdleVisibility || "sound")
        if (mode === "always") return 1.0
        if (mode === "available") return root.mediaPlayerAvailable ? 1.0 : 0.0
        if (mode === "playing") return root.mediaPlayerAvailable && root.mediaPlayerPlaying ? 1.0 : 0.0
        return root.mediaSoundReveal
    }
    function mediaItemVisibleForItem(item) {
        return root.mediaVisibilityFactorForItem(item) > 0.004
    }
    property int visibleTaskCount: 0
    property int overflowTaskCount: 0
    property int totalDynamicGroups: 0
    property bool dynamicApplicationsMoveModeActive: false
    property bool customSeparatorEnabled: false
    property var separatorTheme: ({})
    property real customThemeSurfaceRadius: 0
    property bool customThemeActive: false
    property rect availableScreenRect: Qt.rect(0, 0, 800, 640)
    // Animated width reserved by each media delegate, keyed by its index.
    // It is intentionally separate from mediaItemMainAxisLengthForItem(),
    // which supplies the UNEXPANDED base to MediaDockItem (no binding loop).
    property var mediaInlineTitleExtents: ({})
    property var floatingAnchor: null
    property int floatingScreenEdge: PlasmaCore.Types.LeftEdge
    property real hostHeight: 0
    property var panelWindow: null
    property var containment: null
    property var panelIconGeometries: []
    property string panelHoverAnimation: "wave"

    readonly property PopupSpacingMetrics popupSpacingMetrics:
        PopupSpacingMetrics {}

    readonly property int dockSpacing: {
        const spacing = Number(root.configuredIconSpacing)
        return Math.round(Math.max(0, Math.min(24,
            Number.isFinite(spacing) ? spacing : 8)))
    }
    readonly property int dockBackgroundHorizontalPadding: {
        if (!root.customThemeActive) {
            return root.inPanel ? 10 : 10
        }
        const gridUnit = Kirigami.Units.gridUnit > 0 ? Kirigami.Units.gridUnit : 16
        const smallSpacing = Kirigami.Units.smallSpacing > 0 ? Kirigami.Units.smallSpacing : 4
        const basePadding = root.inPanel ? (gridUnit + smallSpacing) : 10
        if (root.inPanel && root.customThemeSurfaceRadius > 0) {
            return Math.max(basePadding, Math.round(root.customThemeSurfaceRadius + smallSpacing))
        }
        return basePadding
    }
    readonly property int dockBackgroundVerticalPadding: 12
    readonly property int floatingExtraWidth: 48
    readonly property int floatingExtraHeight: 32
    readonly property int effectivePanelLocation: root.inPanel
        ? root.panelLocation
        : root.configuredFloatingEdge

    function updateFloatingScreenEdge(anchor) {
        // A panel is managed by Plasma; only a floating dock uses our
        // explicitly selected edge, without inferring from moving geometry.
        if (!root.inPanel)
            root.floatingScreenEdge = root.configuredFloatingEdge
    }

    onFloatingAnchorChanged: updateFloatingScreenEdge(root.floatingAnchor)
    onAvailableScreenRectChanged: updateFloatingScreenEdge(root.floatingAnchor)
    onVerticalPanelChanged: updateFloatingScreenEdge(root.floatingAnchor)
    readonly property bool topPanel: effectivePanelLocation === PlasmaCore.Types.TopEdge
    readonly property bool bottomPanel: effectivePanelLocation === PlasmaCore.Types.BottomEdge
    readonly property bool leftPanel: effectivePanelLocation === PlasmaCore.Types.LeftEdge
    readonly property bool rightPanel: effectivePanelLocation === PlasmaCore.Types.RightEdge

    readonly property int detectedPanelLengthMode: {
        const _trigger = root.panelStateTrigger
        try {
            if (!root.inPanel || !root.panelWindow
                    || typeof root.panelWindow["lengthMode"] === "undefined") {
                return -1
            }
            const lengthMode = Number(root.panelWindow["lengthMode"])
            return Number.isFinite(lengthMode) ? lengthMode : -1
        } catch (error) {
            return -1
        }
    }
    property int panelStateTrigger: 0
    readonly property Connections panelStateConnections: Connections {
        target: root.panelWindow
        ignoreUnknownSignals: true
        function onFloatingChanged() {
            root.panelStateTrigger++
        }
        function onFloatingAppletsChanged() {
            root.panelStateTrigger++
        }
        function onVisibilityModeChanged() {
            root.panelStateTrigger++
        }
        function onLengthModeChanged() {
            root.panelStateTrigger++
        }
        function onAlignmentChanged() {
            root.panelStateTrigger++
        }
        function onThicknessChanged() {
            root.panelStateTrigger++
        }
        function onOpacityModeChanged() {
            root.panelStateTrigger++
        }
    }
    readonly property int detectedPanelFloatingMode: {
        const _trigger = root.panelStateTrigger
        try {
            if (!root.inPanel || !root.panelWindow
                    || typeof root.panelWindow["floating"] === "undefined") {
                return -1
            }
            if (Boolean(root.panelWindow["floating"])) {
                return 2
            }
            if (Boolean(root.panelWindow["floatingApplets"])) {
                return 1
            }
            return 0
        } catch (error) {
            return -1
        }
    }
    readonly property int detectedPanelVisibilityMode: {
        const _trigger = root.panelStateTrigger
        try {
            if (!root.inPanel || !root.panelWindow
                    || typeof root.panelWindow["visibilityMode"] === "undefined") {
                return -1
            }
            const mode = Number(root.panelWindow["visibilityMode"])
            return !isNaN(mode) && mode >= 0 ? mode : -1
        } catch (error) {
            return -1
        }
    }
    readonly property int detectedPanelAlignment: {
        const _trigger = root.panelStateTrigger
        try {
            if (!root.inPanel || !root.panelWindow
                    || typeof root.panelWindow["alignment"] === "undefined") {
                return -1
            }
            const align = root.panelWindow["alignment"]
            if (align === Qt.AlignLeft || align === Qt.AlignTop) {
                return 0
            }
            if (align === Qt.AlignCenter || align === Qt.AlignHCenter || align === Qt.AlignVCenter) {
                return 1
            }
            if (align === Qt.AlignRight || align === Qt.AlignBottom) {
                return 2
            }
            return -1
        } catch (error) {
            return -1
        }
    }
    readonly property int detectedPanelOpacityMode: {
        const _trigger = root.panelStateTrigger
        try {
            if (!root.inPanel || !root.panelWindow
                    || typeof root.panelWindow["opacityMode"] === "undefined") {
                return -1
            }
            const mode = Number(root.panelWindow["opacityMode"])
            return !isNaN(mode) && mode >= 0 ? mode : -1
        } catch (error) {
            return -1
        }
    }
    readonly property bool panelUsesFillAvailable: detectedPanelLengthMode === 0
    readonly property int popupDirection: {
        if (topPanel) {
            return Qt.BottomEdge
        }
        if (bottomPanel) {
            return Qt.TopEdge
        }
        if (leftPanel) {
            return Qt.RightEdge
        }
        if (rightPanel) {
            return Qt.LeftEdge
        }
        return Qt.TopEdge
    }
    readonly property int spectrumOriginEdge: {
        if (topPanel) {
            return Qt.TopEdge
        }
        if (bottomPanel) {
            return Qt.BottomEdge
        }
        if (leftPanel) {
            return Qt.LeftEdge
        }
        if (rightPanel) {
            return Qt.RightEdge
        }
        return Qt.BottomEdge
    }
    readonly property int popupMargin: 5
    readonly property int popupGapPixels: 0 // KDE Plasma 6.8.2 native frame/margins
    readonly property int folderPopupGap: popupGapPixels
    readonly property int contextMenuGap: popupGapPixels
    readonly property int detectedPanelThickness: {
        const _trigger = root.panelStateTrigger
        try {
            if (root.inPanel && root.panelWindow
                    && typeof root.panelWindow["thickness"] !== "undefined") {
                const th = Number(root.panelWindow["thickness"])
                if (Number.isFinite(th) && th > 0) {
                    return th
                }
            }
            if (!root.containment) {
                return 0
            }

            const thickness = root.verticalPanel
                ? Math.max(0, Number(root.containment["width"] || 0))
                : Math.max(0, Number(root.containment["height"] || 0))
            return thickness > 0 ? thickness : 0
        } catch (error) {
            return 0
        }
    }
    readonly property var plasmaPanelSizing: PlasmaPanelSizing.calculate(
        root.configuredIconSize, root.panelHoverScale,
        root.configuredPanelThickness, root.verticalPanel,
        root.dockShowLabels, Kirigami.Units.smallSpacing * 3)
    readonly property real effectivePanelHoverScale: {
        if (root.customThemeActive || !root.inPanel) {
            return Math.max(1.0, root.panelHoverScale)
        }
        let scale = root.plasmaPanelSizing.hoverScale
        const windowExtent = root.panelWindow ? Number(root.verticalPanel
            ? root.panelWindow.width : root.panelWindow.height) : 0
        for (const rect of root.panelIconGeometries) {
            scale = Math.min(scale, PlasmaPanelSizing.boundedHoverScale(
                root.plasmaPanelSizing.hoverScale,
                root.verticalPanel ? rect.width : rect.height,
                root.verticalPanel ? rect.x + rect.width / 2 : rect.y + rect.height / 2,
                windowExtent, root.leftPanel || root.topPanel ? 1 : -1,
                root.panelHoverAnimation))
        }
        return scale
    }
    readonly property int plasmaThemeCrossAxisMargin: {
        return root.effectivePanelHoverScale > 1.01 ? 2 : 4
    }
    readonly property int crossAxisBaseMargin: root.customThemeActive ? 10 : plasmaThemeCrossAxisMargin
    readonly property int effectivePanelBaseIconLimit: detectedPanelThickness > 0
        ? Math.max(24, Math.round((detectedPanelThickness - crossAxisBaseMargin) / root.effectivePanelHoverScale))
        : Math.max(24, root.configuredIconSize)
    readonly property int effectiveIconSize: {
        const requested = root.inPanel && !root.customThemeActive
            ? root.plasmaPanelSizing.iconSize
            : (root.inPanel && !root.unlockPanelIconSizeLimit
                && root.configuredPanelThickness > 0)
                ? Math.min(root.configuredIconSize, effectivePanelBaseIconLimit)
                : root.configuredIconSize
        // KWin clips content at the panel's real lower edge, regardless of a
        // user-defined icon size or custom theme. Keep the *base* icon inside.
        if (root.inPanel && root.detectedPanelThickness > 0) {
            const labelRoom = root.horizontalPanel ? root.dockLabelAreaHeight : 0
            return Math.max(16, Math.min(requested,
                root.detectedPanelThickness - labelRoom - 10))
        }
        return requested
    }
    readonly property int mediaItemMainAxisLength: Math.round(Math.max(120,
        Math.min(320, effectiveIconSize * 4.2)))
    readonly property int compactMediaItemMainAxisLength: Math.round(Math.max(120,
        Math.min(240, effectiveIconSize * 2.9)))
    readonly property bool panelFillLengthEnabled: root.inPanel
        && panelUsesFillAvailable
        && !root.hiddenByVirtualDesktop
        && root.configuredPanelLengthMode === "fill"
    readonly property int panelItemWidth: Math.ceil(Math.max(effectiveIconSize + 12,
        root.dockShowLabels ? effectiveIconSize * 1.85 : 0))
    readonly property int panelItemHeight: Math.ceil(effectiveIconSize + 12
        + root.dockLabelAreaHeight)
    readonly property int dynamicApplicationsMoveHandleExtent: Math.ceil(
        root.verticalPanel ? root.panelItemHeight
            : Math.max(root.effectiveIconSize
                + Kirigami.Units.smallSpacing * 2,
                root.effectiveIconSize * 3.6))
    readonly property int panelHoverCrossAxisExtent: Math.ceil(root.horizontalPanel
        ? (effectiveIconSize * root.panelHoverScale) + 12 + root.dockLabelAreaHeight
        : Math.max(panelItemWidth, (effectiveIconSize * root.panelHoverScale) + 12))

    function normalizedMediaTextMode(item) {
        const mode = item ? String(item.mediaTextMode || "automatic") : "automatic"
        return mode === "always" || mode === "hidden" ? mode : "automatic"
    }

    function normalizedPopupDistancePercent(value) {
        return root.popupSpacingMetrics.normalizedPercent(value)
    }

    function popupGapForPercent(value) {
        return root.popupSpacingMetrics.gapForPercent(value)
    }

    function mediaMetadataVisibleForItem(item) {
        const mode = root.normalizedMediaTextMode(item)
        return mode === "always"
            || (mode === "automatic"
                && (root.verticalPanel
                    ? root.effectiveIconSize >= Kirigami.Units.gridUnit * 5
                    : root.effectiveIconSize >= 42))
    }

    function mediaItemMainAxisLengthForItem(item) {
        const factor = root.mediaVisibilityFactorForItem(item)
        if (factor <= 0.004) return 0
        let extent
        if (item && String(item.mediaDisplayMode || "normal") !== "compact") {
            extent = root.mediaMetadataVisibleForItem(item)
                ? root.mediaItemMainAxisLength
                : root.compactMediaItemMainAxisLength
        } else if (!root.mediaItemExpanded) {
            extent = root.effectiveIconSize
        } else {
            extent = root.mediaMetadataVisibleForItem(item)
                ? root.mediaItemMainAxisLength
                : root.compactMediaItemMainAxisLength
        }
        return Math.max(0, Math.round(extent * factor))
    }

    // Mirrors DockItem.dynamicApplicationsMarkerCollapsed from the item model:
    // a marker whose separator is hidden must not reserve panel length either.
    function dynamicApplicationsMarkerCollapsed(item) {
        const itemType = item && item.type ? String(item.type) : "app"
        return itemType === "dynamic-applications"
            && item.showSeparator === false
    }

    function panelMainAxisExtentForDockItem(item, index) {
        const itemType = item && item.type ? String(item.type) : "app"
        if (itemType === "dynamic-applications"
                && root.dynamicApplicationsMoveModeActive) {
            return root.dynamicApplicationsMoveHandleExtent
        }
        if (root.dynamicApplicationsMarkerCollapsed(item)) {
            return 0
        }
        if (itemType === "separator" || itemType === "dynamic-applications") {
            const appearance = SeparatorAppearance.resolvedAppearance(
                SeparatorAppearance.sourceForItem(item), item,
                root.customSeparatorEnabled, root.separatorTheme)
            return Math.max(10, Math.ceil(appearance.thickness + 4))
        }
        if (itemType === "spacer") {
            return Math.max(12, effectiveIconSize * 0.5)
        }
        if (itemType === "media") {
            const factor = root.mediaVisibilityFactorForItem(item)
            const inlineTitle = Number(root.mediaInlineTitleExtents[String(index)] || 0)
            return factor > 0.004
                ? root.mediaItemMainAxisLengthForItem(item) + 12 * factor
                    + (Number.isFinite(inlineTitle) ? Math.max(0, inlineTitle) : 0)
                : 0
        }
        return root.verticalPanel ? panelItemHeight : panelItemWidth
    }

    readonly property int visibleFixedDockItemCount: {
        let count = 0
        const items = root.dockItems || []
        for (let index = 0; index < items.length; index++) {
            if (!root.dynamicApplicationsMarkerCollapsed(items[index])
                    && root.mediaItemVisibleForItem(items[index])) {
                count += 1
            }
        }
        return count
    }
    // Baseline size independent of live title animations. Used to grant a
    // safe side-width budget without creating a geometry/title binding loop.
    readonly property int mediaTitleFreeSideExtent: {
        if (root.verticalPanel) return 0
        const items = root.dockItems || []
        let fixed = 0
        for (let i = 0; i < items.length; ++i) {
            const entry = items[i]
            if (entry && entry.type === "media") {
                const factor = root.mediaVisibilityFactorForItem(entry)
                if (factor > 0.004)
                    fixed += root.mediaItemMainAxisLengthForItem(entry) + 12 * factor
            } else {
                fixed += root.panelMainAxisExtentForDockItem(entry, i)
            }
        }
        const fixedGaps = Math.max(0, root.visibleFixedDockItemCount - 1) * root.dockSpacing
        const dynamicCount = root.renderedDynamicItemCount
        const dynamicWidth = dynamicCount > 0
            ? dynamicCount * root.panelItemWidth
                + Math.max(0, dynamicCount - 1) * root.dockSpacing
            : 0
        const boundary = root.visibleFixedDockItemCount > 0 && dynamicCount > 0
            ? root.dockSpacing : 0
        const baseline = fixed + fixedGaps + dynamicWidth + boundary
            + 2 * root.dockBackgroundHorizontalPadding
        const screenWidth = Math.max(0, Number(root.availableScreenRect.width || 0))
        return Math.max(0, Math.floor((screenWidth - baseline) / 2) - 8)
    }
    readonly property int panelFixedContentLength: {
        let extent = 0
        const items = root.dockItems || []
        for (let index = 0; index < items.length; index++) {
            extent += root.panelMainAxisExtentForDockItem(items[index], index)
        }
        return Math.ceil(extent
            + (Math.max(0, root.visibleFixedDockItemCount - 1) * dockSpacing))
    }
    readonly property int renderedDynamicItemCount: root.visibleTaskCount
        + (root.overflowTaskCount > 0 ? 1 : 0)
    readonly property int supplementalContentLength: {
        const items = root.supplementalDockItems || []
        let extent = 0
        for (let i = 0; i < items.length; ++i) {
            extent += root.panelMainAxisExtentForDockItem(items[i], i)
        }
        // Follow the actual preceding footprint, including a temporarily
        // revealed move handle, rather than counting hidden structural items.
        const precedingExtent = root.panelBaseCompactContentLength
        return Math.ceil(extent + Math.max(0, items.length - (precedingExtent > 0 ? 0 : 1)) * root.dockSpacing)
    }
    readonly property int panelCompactContentLength: root.panelBaseCompactContentLength + root.supplementalContentLength
    readonly property int panelBaseCompactContentLength: {
        const boundarySpacing = root.visibleFixedDockItemCount > 0 && renderedDynamicItemCount > 0
            ? dockSpacing
            : 0
        const dynamicItemExtent = root.verticalPanel ? panelItemHeight : panelItemWidth
        const dynamicLength = renderedDynamicItemCount > 0
            ? (renderedDynamicItemCount * dynamicItemExtent)
                + (Math.max(0, renderedDynamicItemCount - 1) * dockSpacing)
            : 0
        return Math.ceil(panelFixedContentLength + boundarySpacing + dynamicLength)
    }
    readonly property int panelMinimumContentLength: {
        const hasDynamicGroups = root.totalDynamicGroups > 0
        const boundarySpacing = root.visibleFixedDockItemCount > 0 && hasDynamicGroups ? dockSpacing : 0
        const dynamicItemExtent = root.verticalPanel ? panelItemHeight : panelItemWidth
        return Math.ceil(panelFixedContentLength + boundarySpacing
            + (hasDynamicGroups ? dynamicItemExtent : 0))
    }
    readonly property int panelContentLength: panelFillLengthEnabled
        ? panelMinimumContentLength
        : Math.max(root.verticalPanel ? panelItemHeight : panelItemWidth,
            panelCompactContentLength)
    readonly property int plasmaThemeCrossAxisExtent: {
        if (root.inPanel && !root.customThemeActive) {
            return root.plasmaPanelSizing.extent
        }
        const iconExtent = root.effectiveIconSize
        const scale = root.effectivePanelHoverScale
        const labelArea = root.horizontalPanel ? root.dockLabelAreaHeight : 0
        const requiredExtent = Math.round(iconExtent * scale) + plasmaThemeCrossAxisMargin + labelArea
        if (root.detectedPanelThickness > 0 && Math.abs(requiredExtent - root.detectedPanelThickness) <= 2) {
            return root.detectedPanelThickness
        }
        return requiredExtent
    }
    readonly property int panelMinimumWidth: root.hiddenByVirtualDesktop
        ? 0
        : Math.ceil(root.verticalPanel
            ? (root.inPanel && !root.customThemeActive
                ? plasmaThemeCrossAxisExtent
                : panelHoverCrossAxisExtent + (root.inPanel ? 0 : (dockBackgroundHorizontalPadding * 2)))
            : panelContentLength + (dockBackgroundHorizontalPadding * 2))
    readonly property int panelBaseHeight: Math.ceil(root.verticalPanel
        ? panelContentLength + (dockBackgroundVerticalPadding * 2)
        : (root.inPanel && !root.customThemeActive
            ? plasmaThemeCrossAxisExtent
            : panelItemHeight + (root.inPanel ? 0 : (dockBackgroundVerticalPadding * 2))))
    readonly property int panelZoomHeadroom: {
        if (!root.inPanel || root.panelAlwaysVisible || root.verticalPanel || !root.customThemeActive) {
            return 0
        }
        const zoomDelta = effectiveIconSize * Math.max(0.0, root.panelHoverScale - 1.0)
        return Math.ceil(zoomDelta + 8)
    }
    readonly property int panelMinimumHeight: root.hiddenByVirtualDesktop
        ? 0
        : panelBaseHeight + panelZoomHeadroom
    readonly property int panelPreferredWidth: root.hiddenByVirtualDesktop ? 0 : panelMinimumWidth
    readonly property int panelPreferredHeight: root.hiddenByVirtualDesktop ? 0 : panelMinimumHeight
    readonly property real panelReflectionAvailableExtent: {
        if (!root.inPanel || !root.horizontalPanel) {
            return -1
        }

        const allocatedHeight = Math.max(panelItemHeight,
            root.hostHeight > 0 ? root.hostHeight : panelPreferredHeight)
        const outerBottomMargin = Math.max(0, (allocatedHeight - panelItemHeight) / 2)
        const itemBottomMargin = Math.max(0, (panelItemHeight - effectiveIconSize) / 2)
        return outerBottomMargin + itemBottomMargin
    }
    readonly property int taskPopupReservedVerticalExtent:
        root.inPanel && !root.verticalPanel ? panelPreferredHeight : 0
    readonly property int taskPopupAvailableHeight: Math.max(240,
        Number(root.availableScreenRect.height || 640)
            - taskPopupReservedVerticalExtent - 24)
    readonly property int taskPopupAvailableWidth: Math.max(280,
        Number(root.availableScreenRect.width || 800) - 48)
    // Height the folder fan may use. `taskPopupAvailableHeight` keeps a 240 px
    // floor so a popup stays usable, but that floor can exceed what a short
    // display really offers; the fan takes the honest value instead, so its
    // invisible frame can never grow past the screen, and it shows fewer rows
    // when the space is not enough.
    readonly property int folderFanAvailableHeight: Math.max(0,
        Number(root.availableScreenRect.height || 640)
            - taskPopupReservedVerticalExtent - 24)
}
