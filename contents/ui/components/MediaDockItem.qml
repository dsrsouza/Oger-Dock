pragma ComponentBehavior: Bound

import QtQuick
import "../../code/reaMediaSource.js" as MediaSource
import QtQuick.Controls as Controls
import QtQuick.Effects as Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore

FocusScope {
    id: root
    objectName: "mediaDockItem"
    scale: root.clickScale * root.visualScale
    transform: Translate {
        x: root.visualOffsetX
        y: root.visualOffsetY
    }

    // Plasma provides translation functions in the applet context.
    // qmllint disable unqualified
    property var pinPreferences: ({})
    readonly property string pinIdentity: {
        const value = controller && controller.available
            ? String(controller.identity || controller.serviceName || "")
            : String(defaultPlayerName || "")
        return value.trim().toLowerCase().slice(0, 128)
    }
    readonly property bool controlsPinned:
        !!(pinPreferences && pinPreferences[pinIdentity])
    // R17: the player starts compact. Titles are shown only after a 5-second
    // continuous cover hover, or for 5s after transport Previous/Next clicks.
    // External metadata changes and opening the launcher are not reveal events.
    property bool temporaryTitleVisible: false
    property bool manualTrackChangePending: false
    property int titleDisplayDuration: 5000
    readonly property bool showTemporaryTitle: temporaryTitleVisible
        && !controlsPinned && !vertical && !compactMode && available
    // Only the artwork can trigger a delayed title reveal; hovering the
    // transport controls must never change their size or position.
    property bool artworkHoverReady: false
    readonly property bool showTitleCard: !vertical && !compactMode
        && available && showTitle && !controlsPinned
        && (artworkHoverReady || temporaryTitleVisible)
    // R14.1: Inline metadata, never a native popup. The width belongs to the
    // mini-player's layout and to the panel/floating-dock footprint.
    // Limit the card on smaller screens; it must not take over the dock.
    property real maximumInlineTitleExtent: 150
    // R20: the title now appears in an upward information popup rather than
    // changing the mini-player's width and shifting the cover under the mouse.
    readonly property real titleCardWidth: Math.max(0,
        Math.min(138, maximumInlineTitleExtent - 12))
    property real titleReveal: showTitleCard ? 1.0 : 0.0
    Behavior on titleReveal {
        enabled: root.motionEnabled && Kirigami.Units.longDuration > 1
        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
    }
    // R19: the controls and cover stay at the left of the mini-player;
    // only the title drawer and the RIGHT edge of the dock grow. The floating
    // host preserves its left edge while this inline extent changes.
    readonly property real inlineTitleExtent: 0
    signal pinPreferenceChanged(string identity, bool pinned)
    property var controller: null
    property int iconSize: 48
    property int compactIconRenderSize: iconSize
    property real compactIconBaseScale: compactIconRenderSize > 0
        ? iconSize / compactIconRenderSize : 1.0
    property real visualScale: 1.0
    property real visualOffsetX: 0.0
    property real visualOffsetY: 0.0
    property bool vertical: false
    property int panelLocation: PlasmaCore.Types.BottomEdge
    property bool motionEnabled: true
    property bool contextMenuEnabled: true
    property bool launchAvailable: false
    property string defaultPlayerName: ""
    property string defaultPlayerIcon: ""
    property string textMode: "automatic"
    property string displayMode: "normal"
    property bool showCover: true
    property bool showTitle: true
    property bool showControls: true
    property bool showProgress: true
    property bool showVolume: true
    property string backgroundStyle: "artwork"
    property int motionSpeedPercent: 100
    property int autoCollapseDelaySeconds: 3
    property int expandedMainAxisLength: Math.round(Math.max(120,
        Math.min(320, iconSize * 4.2)))
    property bool expanded: true
    property real displayedPositionUs: 0
    readonly property bool available: !!controller && controller.available
    readonly property string artUrl: available && controller.artUrl
        ? String(controller.artUrl)
        : ""
    readonly property int controlExtent: Math.round(Math.max(22,
        Math.min(32, iconSize * 0.58)))
    readonly property int coverExtent: Math.max(16, iconSize - 8)
    readonly property string launchActionText: defaultPlayerName.length > 0
        ? i18nc("@action:button", "Open %1", defaultPlayerName)
        : i18nc("@action:button", "Open the default media player")
    // Hide timeline for browser sources: web players often misreport MPRIS
    // position, and a false progress bar is worse than no progress bar.
    readonly property bool browserSource: available && MediaSource.isBrowser(controller)
    readonly property bool progressReliable: available && !browserSource
    readonly property string elapsedText: formatTime(displayedPositionUs)
    readonly property string durationText: available && controller.lengthUs > 0
        ? formatTime(controller.lengthUs)
        : ""
    readonly property string timeText: progressReliable && durationText.length > 0
        ? i18nc("@info:media elapsed and total duration", "%1 / %2", elapsedText, durationText)
        : ""
    readonly property string metadataText: resolvedMetadataText()
    readonly property string metadataMovementKey: resolvedMetadataMovementKey()
    readonly property string normalizedTextMode: textMode === "always"
        || textMode === "hidden" ? textMode : "automatic"
    // In the normal mode, a playing track keeps a small but fully functional
    // mini-player instead of collapsing to an icon after a few seconds.
    readonly property bool compactMode: displayMode === "compact"
    readonly property bool narrowVerticalLayout: vertical
        && width < Kirigami.Units.gridUnit * 5
    readonly property bool compactHorizontalLayout: !vertical
        && (iconSize < 42 || height < 42)
    // Horizontal titles slide RIGHT from under the stationary cover,
    // after the controls. Vertical mode retains its existing compact layout.
    readonly property bool metadataVisible: vertical
        && normalizedTextMode === "always" && available
        && !narrowVerticalLayout
    readonly property int compactMainAxisLength: iconSize
    readonly property int resolvedMotionSpeedPercent: Math.max(50,
        Math.min(150, Number.isFinite(motionSpeedPercent)
            ? Math.round(motionSpeedPercent)
            : 100))
    readonly property int resolvedAutoCollapseDelaySeconds: Math.max(0,
        Math.min(30, Number.isFinite(autoCollapseDelaySeconds)
            ? Math.round(autoCollapseDelaySeconds)
            : 3))
    readonly property int expandMorphDuration: Math.round(220 * 100
        / resolvedMotionSpeedPercent)
    readonly property int collapseMorphDuration: Math.round(190 * 100
        / resolvedMotionSpeedPercent)
    readonly property int currentMorphDuration: expanded
        ? expandMorphDuration : collapseMorphDuration
    property real collapseProgress: compactMode && !expanded ? 1.0 : 0.0
    readonly property real basePlayerLength: vertical ? expandedMainAxisLength
        : Math.max(expandedMainAxisLength,
            coverExtent + 4 * controlExtent + 28)
    // The drawer takes ZERO layout space while hidden; its expanding region
    // is AFTER the anchored controls/cover so neither of them shifts.
    readonly property real currentMainAxisLength: basePlayerLength
        + inlineTitleExtent
        + (compactMainAxisLength - basePlayerLength) * collapseProgress
    readonly property real expandedContentOpacity: 1.0 - Math.max(0.0,
        Math.min(1.0, collapseProgress / 0.45))
    readonly property real compactIconProgress: Math.max(0.0,
        Math.min(1.0, (collapseProgress - 0.35) / 0.65))
    readonly property real compactContentOpacity: compactMode
        ? compactIconProgress : 0.0
    readonly property real compactIconMorphScale: 0.88
        + (0.12 * compactIconProgress)
    readonly property string accessibleDescription: available
        ? (controller.playing
            ? i18nc("@info:accessible", "%1. Playing.", metadataText)
            : i18nc("@info:accessible", "%1. Paused.", metadataText))
        : i18nc("@info:accessible", "No MPRIS player is active")
    readonly property bool interactionActive: hoverHandler.hovered || activeFocus
    readonly property bool interactionPaused: interactionActive

    function startTitleDisplay(manualChange) {
        titleHideTimer.stop()
        // Metadata can arrive after the transport click. Don't require the
        // NEXT track's name to be available synchronously with the click.
        if (!available || controlsPinned || vertical || compactMode) {
            temporaryTitleVisible = false
            return
        }
        titleDisplayDuration = 5000
        temporaryTitleVisible = true
        titleHideTimer.interval = titleDisplayDuration
        titleHideTimer.restart()
    }
    function requestManualTrackChange() {
        // The user's own mini-player buttons are the ONLY automatic reveal.
        manualTrackChangePending = true
        manualChangeTimeout.restart()
        startTitleDisplay(true)
    }
    onMetadataMovementKeyChanged: {
        // MPRIS often reports title, artist and artwork in separate bursts,
        // sometimes also clearing metadata momentarily. The reveal is owned
        // exclusively by our transport click timer or the 5-s cover hover.
        // Never cancel or restart those timers from asynchronous metadata.
    }
    onControlsPinnedChanged: {
        if (controlsPinned) {
            temporaryTitleVisible = false
            artworkHoverReady = false
            artworkHoverTimer.stop()
            titleHideTimer.stop()
        }
    }
    onInteractionActiveChanged: {
        // Control hover only reveals the pin tooltip; never hide/replace the
        // transport row or restart title timing.
        if (!compactMode) expanded = true
    }
    // Hover state is direct, not timed. While the pointer remains over the
    // cover, automatic track-change timeouts must not hide the title.
    Timer {
        id: artworkHoverTimer
        interval: 5000
        repeat: false
        onTriggered: root.artworkHoverReady = !!coverHover.hovered
            && root.available && !root.controlsPinned
    }
    Timer {
        id: manualChangeTimeout
        interval: 5000
        repeat: false
        onTriggered: root.manualTrackChangePending = false
    }
    Timer {
        id: titleHideTimer
        interval: 5000
        repeat: false
        onTriggered: root.temporaryTitleVisible = false
    }
    signal contextMenuRequested(bool keyboardInvoked)
    signal hoverChanged(bool hovered)
    signal expansionChanged(bool expanded, int transitionDuration)
    signal launchRequested()
    signal playbackLaunchRequested()
    signal interactionActivated()
    property bool externalClickFeedback: false
    readonly property bool interactionPressed: compactLaunchTap.pressed
        || artworkLaunchTap.pressed || previousButton.pressed
        || playPauseButton.pressed || nextButton.pressed

    Accessible.role: Accessible.Grouping
    Accessible.name: i18nc("@info:accessible", "Media player controls")
    Accessible.description: accessibleDescription

    property real clickScale: !externalClickFeedback && interactionPressed ? 0.94 : 1.0

    Behavior on clickScale {
        enabled: root.motionEnabled && Kirigami.Units.longDuration > 1
        NumberAnimation {
            duration: Math.round(Kirigami.Units.shortDuration * 1.2
                * 100 / root.resolvedMotionSpeedPercent)
            easing.type: Easing.OutQuad
        }
    }

    Behavior on collapseProgress {
        enabled: root.motionEnabled && Kirigami.Units.longDuration > 0
        NumberAnimation {
            duration: root.currentMorphDuration
            easing.type: root.expanded ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    function formatTime(microseconds) {
        const totalSeconds = Math.max(0, Math.floor(Number(microseconds || 0) / 1000000))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60
        if (hours > 0) {
            return String(hours) + ":" + String(minutes).padStart(2, "0")
                + ":" + String(seconds).padStart(2, "0")
        }
        return String(minutes) + ":" + String(seconds).padStart(2, "0")
    }

    function resolvedMetadataText() {
        if (!available) {
            return defaultPlayerName.length > 0
                ? i18nc("@info:media", "%1 is not running", defaultPlayerName)
                : i18nc("@info:media", "No media playing")
        }
        const title = controller.track
            ? String(controller.track)
            : (controller.identity ? String(controller.identity) : i18n("Media playback"))
        const artist = controller.artist ? String(controller.artist) : ""
        if (artist.length > 0 && timeText.length > 0) {
            return i18nc("@info:media artist, title and playback time", "%1 — %2 — %3",
                artist, title, timeText)
        }
        if (artist.length > 0) {
            return i18nc("@info:media artist and title", "%1 — %2", artist, title)
        }
        if (timeText.length > 0) {
            return i18nc("@info:media title and playback time", "%1 — %2", title, timeText)
        }
        return title
    }

    function resolvedMetadataMovementKey() {
        if (!available) {
            return "inactive\u001f" + defaultPlayerName
        }
        const identity = controller.identity ? String(controller.identity) : ""
        const artist = controller.artist ? String(controller.artist) : ""
        const title = controller.track ? String(controller.track) : ""
        return "active\u001f" + identity + "\u001f" + artist + "\u001f" + title
            + "\u001f" + durationText
    }

    function syncDisplayedPosition() {
        displayedPositionUs = available && controller.lengthUs > 0
            ? Math.min(controller.lengthUs, Math.max(0, controller.positionUs))
            : 0
    }

    function focusFirstControl() {
        if (previousButton.enabled) {
            previousButton.forceActiveFocus(Qt.TabFocusReason)
            return true
        }
        if (playPauseButton.enabled) {
            playPauseButton.forceActiveFocus(Qt.TabFocusReason)
            return true
        }
        if (nextButton.enabled) {
            nextButton.forceActiveFocus(Qt.TabFocusReason)
            return true
        }
        playPauseButton.forceActiveFocus(Qt.TabFocusReason)
        return true
    }

    component MarqueeViewport: Item {
        id: marqueeRoot

        required property string displayText
        required property string movementKey
        property bool verticalFlow: false
        property bool movementAllowed: true
        property bool movementPaused: false
        property real offset: 0
        readonly property real travel: Math.max(0,
            movingLabel.implicitWidth - movementSurface.width)
        readonly property bool overflowing: travel > 1
        readonly property bool shouldMove: overflowing
            && movementAllowed
            && !movementPaused
            && visible
        readonly property int travelDuration: Math.max(1800,
            Math.min(14000, Math.round(travel * 38)))

        clip: true
        Accessible.ignored: true

        onShouldMoveChanged: {
            if (!shouldMove) {
                marqueeAnimation.stop()
                offset = 0
            } else {
                marqueeAnimation.restart()
            }
        }
        onMovementKeyChanged: {
            offset = 0
            Qt.callLater(function() {
                if (marqueeRoot.shouldMove) {
                    marqueeAnimation.restart()
                }
            })
        }

        Item {
            id: movementSurface

            anchors.centerIn: parent
            width: marqueeRoot.verticalFlow ? marqueeRoot.height : marqueeRoot.width
            height: marqueeRoot.verticalFlow ? marqueeRoot.width : marqueeRoot.height
            rotation: marqueeRoot.verticalFlow ? 90 : 0

            Controls.Label {
                id: movingLabel

                x: -marqueeRoot.offset
                y: 0
                width: marqueeRoot.movementAllowed
                    ? implicitWidth
                    : movementSurface.width
                height: movementSurface.height
                text: marqueeRoot.displayText
                textFormat: Text.PlainText
                wrapMode: Text.NoWrap
                elide: marqueeRoot.movementAllowed
                    ? Text.ElideNone
                    : Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: root.available ? 0.92 : 0.68
            }
        }

        SequentialAnimation {
            id: marqueeAnimation
            loops: Animation.Infinite
            alwaysRunToEnd: false

            PauseAnimation { duration: 900 }
            NumberAnimation {
                target: marqueeRoot
                property: "offset"
                from: 0
                to: marqueeRoot.travel
                duration: marqueeRoot.travelDuration
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: 900 }
            NumberAnimation {
                target: marqueeRoot
                property: "offset"
                to: 0
                duration: Math.max(500, Math.min(1200,
                    Math.round(marqueeRoot.travelDuration * 0.2)))
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: root.hoverChanged(hovered)
    }

    Timer {
        id: collapseTimer
        interval: Math.max(1, root.resolvedAutoCollapseDelaySeconds * 1000)
        repeat: false
        running: root.visible && root.compactMode && root.expanded
            && root.resolvedAutoCollapseDelaySeconds > 0
            && !root.interactionActive
        onTriggered: {
            if (!root.interactionActive) {
                root.expanded = false
            }
        }
    }


    onCompactModeChanged: {
        expanded = !compactMode
        expansionChanged(expanded, currentMorphDuration)
    }

    onExpandedChanged: expansionChanged(expanded, currentMorphDuration)

    function toggleDetails() {
        root.interactionActivated()
        if (mediaDetailsPopup.visible) {
            mediaDetailsPopup.closeSafely()
        } else {
            mediaDetailsPopup.openSafely()
        }
    }

    Item {
        id: mediaPopupAnchor
        width: 1
        height: 1
        x: root.width / 2
        // Anchor outside the panel; the KDE Dialog owns native popup placement.
        y: root.panelLocation === PlasmaCore.Types.BottomEdge ? -4
            : root.panelLocation === PlasmaCore.Types.TopEdge ? root.height
            : root.height / 2
    }

    GuardedPopupDialog {
        id: mediaDetailsPopup
        objectName: "mediaDockExpandedPopup"
        // Anchor to the dock item rather than the animated artwork; the
        // artwork's transform can otherwise pull the popup across the dock.
        location: root.panelLocation
        readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
            sourceAnchor: mediaPopupAnchor
            popup: mediaDetailsPopup
            gap: Math.max(16, Kirigami.Units.largeSpacing)
            location: root.panelLocation
            preserveHorizontalAnchorCenter: true
            preserveVerticalAnchorCenter: true
        }
        hideOnWindowDeactivate: true
        function avoidDockOverlap() {
            if (!visible || !isX11Session) return
            try {
                const center = root.mapToGlobal(Qt.point(root.width / 2, root.height / 2))
                const host = root.Window.window
                const screen = host && host.screen ? host.screen.availableGeometry : null
                if (!screen || width <= 0 || height <= 0) return
                const gap = Math.max(6, Kirigami.Units.smallSpacing)
                let nx = center.x - width / 2
                let ny = center.y - height / 2
                if (root.panelLocation === PlasmaCore.Types.BottomEdge)
                    ny = center.y - root.height / 2 - height - gap
                else if (root.panelLocation === PlasmaCore.Types.TopEdge)
                    ny = center.y + root.height / 2 + gap
                else if (root.panelLocation === PlasmaCore.Types.LeftEdge)
                    nx = center.x + root.width / 2 + gap
                else if (root.panelLocation === PlasmaCore.Types.RightEdge)
                    nx = center.x - root.width / 2 - width - gap
                x = Math.round(Math.max(screen.x + 4,
                    Math.min(nx, screen.x + screen.width - width - 4)))
                y = Math.round(Math.max(screen.y + 4,
                    Math.min(ny, screen.y + screen.height - height - 4)))
            } catch (error) {
                // Keep Plasma's automatic placement as the fallback.
            }
        }
        onVisibleChanged: {
            if (visible) popupSpacing.scheduleRefresh()
            if (visible && isX11Session) Qt.callLater(avoidDockOverlap)
        }
        onWidthChanged: { if (visible) Qt.callLater(avoidDockOverlap) }
        onHeightChanged: { if (visible) Qt.callLater(avoidDockOverlap) }
        mainItem: MediaDetailsPanel {
            controller: root.controller
            popupVisible: mediaDetailsPopup.visible
            fallbackIcon: root.defaultPlayerIcon.length > 0
                ? root.defaultPlayerIcon : "emblem-music-symbolic"
            motionEnabled: root.motionEnabled
            motionSpeedPercent: root.resolvedMotionSpeedPercent
            showCover: root.showCover
            showTitle: root.showTitle
            showControls: root.showControls
            showProgress: root.showProgress && root.progressReliable
            showVolume: root.showVolume
            backgroundStyle: root.backgroundStyle
            onCloseRequested: mediaDetailsPopup.closeSafely()
            onStopSourceRequested: {
                if (root.controller) root.controller.requestClosePlayback()
                mediaDetailsPopup.closeSafely()
            }
        }
    }

    // Intentionally no hover tooltip: it used to cover the dock and its icons.

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: root.contextMenuEnabled
        onTapped: root.contextMenuRequested(false)
    }

    Keys.onPressed: function(event) {
        if (root.contextMenuEnabled && (event.key === Qt.Key_Menu
                || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))) {
            root.contextMenuRequested(true)
            event.accepted = true
        }
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true
        function onStateChanged() {
            root.syncDisplayedPosition()
            if ((!root.controller.available || !root.controller.playing)
                    && mediaDetailsPopup.visible) {
                mediaDetailsPopup.closeSafely()
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.available && root.controller.playing
            && root.controller.lengthUs > 0
        onTriggered: root.displayedPositionUs = Math.min(
            root.controller.lengthUs, root.displayedPositionUs + 1000000)
    }

    onControllerChanged: syncDisplayedPosition()
    Component.onCompleted: syncDisplayedPosition()

    Rectangle {
        anchors.fill: parent
        visible: opacity > 0.01
        radius: Math.max(4, Math.round(Math.min(width, height) * 0.16))
        color: Kirigami.Theme.alternateBackgroundColor
        opacity: root.expandedContentOpacity
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
            Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.18)
    }

    // The art supplies a low-contrast tint underneath the controls, never a
    // full-opacity image that reduces legibility. No CPU pixel extraction.
    Item {
        id: dynamicArtworkBackground
        anchors.fill: parent
        visible: root.expandedContentOpacity > 0.01
            && root.available && root.artUrl.length > 0
        opacity: Math.min(0.22, 0.22 * root.expandedContentOpacity)
        clip: true
        Image {
            anchors.fill: parent
            source: root.artUrl
            asynchronous: true
            cache: true
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
        Rectangle {
            anchors.fill: parent
            color: "#A010141C"
        }
        Behavior on opacity {
            enabled: root.motionEnabled
            NumberAnimation { duration: 260; easing.type: Easing.InOutCubic }
        }
    }

    Kirigami.Icon {
        id: compactPlayerIcon
        objectName: "compactMediaPlayerIcon"
        anchors.centerIn: parent
        width: root.compactIconRenderSize
        height: root.compactIconRenderSize
        source: root.defaultPlayerIcon.length > 0
            ? root.defaultPlayerIcon
            : "emblem-music-symbolic"
        fallback: "emblem-music-symbolic"
        roundToIconSize: false
        isMask: String(source).indexOf("-symbolic") >= 0
        opacity: root.compactContentOpacity
            * (root.showCover && compactArtwork.status === Image.Ready ? 0 : 1)
        visible: opacity > 0.01
        scale: root.compactIconBaseScale * root.compactIconMorphScale
        Accessible.ignored: true

        HoverHandler {
            cursorShape: root.launchAvailable && !root.available && root.compactMode
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor
        }

        TapHandler {
            id: compactLaunchTap
            acceptedButtons: Qt.LeftButton
            enabled: root.compactMode
            onTapped: {
                if (root.available) { root.toggleDetails() }
                else if (root.launchAvailable) {
                    root.interactionActivated()
                    root.launchRequested()
                }
            }
        }
    }

    Image {
        id: compactArtwork
        objectName: "compactMediaCoverArtwork"
        anchors.centerIn: parent
        width: root.iconSize - 4
        height: width
        source: root.artUrl
        asynchronous: true
        cache: true
        sourceSize: Qt.size(Math.min(256, Math.max(64, Math.ceil(width * 2))),
            Math.min(256, Math.max(64, Math.ceil(height * 2))))
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectCrop
        opacity: root.compactContentOpacity
        visible: root.compactMode && root.available && root.showCover
            && status === Image.Ready && opacity > 0.01
        Accessible.ignored: true
        TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: root.compactMode && root.available
            onTapped: root.toggleDetails()
        }
    }

    GridLayout {
        id: mediaLayout
        z: 3 // The cover masks the title drawer sliding out to its right.
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2
        width: root.vertical ? parent.width - 4 : root.basePlayerLength - 4
        // Fixed-width leading section: transport controls THEN album artwork.
        // The animated metadata drawer grows beyond it toward the right.
        // Match the artwork's vertical breathing room at the leading edge.
        // Move the layout so text and controls retain their spacing to artwork.
        anchors.rightMargin: root.showCover && !root.vertical && root.iconSize > 42
            ? Math.max(2, (root.height - root.coverExtent) / 2) : 2
        visible: opacity > 0.01
        opacity: root.expandedContentOpacity
        columns: root.vertical ? 1 : 2
        rows: root.vertical ? (root.metadataVisible ? 3 : 2) : (root.metadataVisible ? 2 : 1)
        rowSpacing: 2
        columnSpacing: (!root.vertical && !root.metadataVisible) ? 6 : 4

        Item {
            id: coverSlot
            Layout.preferredWidth: root.showCover ? root.coverExtent : 0
            Layout.preferredHeight: root.showCover ? root.coverExtent : 0
            visible: root.showCover
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: root.vertical ? 0 : 1
            Layout.rowSpan: (!root.vertical && root.metadataVisible) ? 2 : 1

            Rectangle {
                id: coverFrame
                objectName: "mediaCoverFrame"
                width: coverSlot.width
                height: coverSlot.height
                // The slot retains the existing layout contract. In the larger
                // horizontal presentation, center artwork on the visible item,
                // independently of the text and controls' combined minimum height.
                y: !root.vertical && root.iconSize > 42
                    ? (root.height - height) / 2 - mediaLayout.y - coverSlot.y : 0
                radius: Math.max(3, Math.round(width * 0.16))
                color: Kirigami.Theme.backgroundColor

                Image {
                    id: artworkSource
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(Math.min(256, Math.max(64, Math.ceil(width * 2))),
                        Math.min(256, Math.max(64, Math.ceil(height * 2))))
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                    layer.enabled: visible
                    layer.effect: Effects.MultiEffect {
                        maskEnabled: true
                        maskSource: artworkMask
                    }
                }

                Item {
                    id: artworkMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: coverFrame.radius
                        color: "white"
                    }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.max(16, parent.width * 0.64)
                    height: width
                    source: root.defaultPlayerIcon.length > 0
                        ? root.defaultPlayerIcon
                        : "emblem-music-symbolic"
                    fallback: "emblem-music-symbolic"
                    visible: artworkSource.status !== Image.Ready
                    isMask: String(source).indexOf("-symbolic") >= 0
                }

                HoverHandler {
                    id: coverHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        artworkHoverTimer.stop()
                        root.artworkHoverReady = false
                        if (hovered && root.available && !root.controlsPinned) {
                            artworkHoverTimer.restart()
                        }
                        // The hover-exit contract takes priority over the
                        // automatic track-change timer: hide inline metadata
                        // when the pointer leaves the artwork.
                        if (!hovered && !root.temporaryTitleVisible) {
                            titleHideTimer.stop()
                        }
                    }
                }

                TapHandler {
                    id: artworkLaunchTap
                    acceptedButtons: Qt.LeftButton
                    enabled: true
                    onTapped: {
                        if (root.available) { root.toggleDetails() }
                        else if (root.launchAvailable) {
                            root.interactionActivated()
                            root.launchRequested()
                        }
                    }
                }
            }

        }

        ColumnLayout {
            id: metadataArea
            Layout.fillWidth: !root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: root.vertical ? root.coverExtent : -1
            Layout.preferredHeight: root.vertical ? Math.max(root.controlExtent * 1.8,
                root.height - root.coverExtent - transportControls.implicitHeight - 8) : -1
            Layout.row: root.vertical ? 1 : 0
            Layout.column: root.vertical ? 0 : 1
            spacing: 1
            visible: root.metadataVisible

            MarqueeViewport {
                id: metadataViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.max(14, Kirigami.Units.gridUnit)
                visible: root.metadataVisible && root.showTitle
                displayText: root.metadataText
                movementKey: root.metadataMovementKey
                verticalFlow: root.vertical
                movementAllowed: root.motionEnabled
                movementPaused: root.interactionPaused
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.max(14, Kirigami.Units.gridUnit)
                visible: (!root.metadataVisible || !root.showTitle)
                    && root.showProgress && root.progressReliable

                Controls.ProgressBar {
                    anchors.centerIn: parent
                    width: root.vertical ? parent.height : parent.width
                    height: Math.max(4, Kirigami.Units.smallSpacing)
                    rotation: root.vertical ? 90 : 0
                    from: 0
                    to: root.available && root.controller.lengthUs > 0
                        ? root.controller.lengthUs
                        : 1
                    value: root.available && root.controller.lengthUs > 0
                        ? root.displayedPositionUs
                        : 0
                    Accessible.ignored: true
                }
            }


        }

        GridLayout {
            id: transportControls
            visible: root.showControls
            // The transport row stays visible during the inline expansion;
            // the title is outside this GridLayout and never consumes its width.
            opacity: 1
            enabled: true
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: !root.vertical && !root.metadataVisible
            Layout.row: root.vertical
                ? (root.metadataVisible ? 2 : 1)
                : (root.metadataVisible ? 1 : 0)
            Layout.column: 0
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columns: root.vertical ? 1 : 4
            rows: root.vertical ? 4 : 1
            rowSpacing: 1
            columnSpacing: 1

            PlasmaComponents.ToolButton {
                id: previousButton
                objectName: "mediaPreviousButton"
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: root.controlExtent
                Layout.preferredHeight: root.controlExtent
                text: i18nc("@action:button", "Previous track")
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-forward"
                    : "media-skip-backward"
                enabled: root.available && root.controller.canControl
                    && root.controller.canGoPrevious
                Accessible.name: text
                onClicked: {
                    root.interactionActivated()
                    root.requestManualTrackChange()
                    root.controller.previous()
                }
                KeyNavigation.tab: playPauseButton
            }

            PlasmaComponents.ToolButton {
                id: playPauseButton
                objectName: "mediaPlayPauseButton"
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: root.controlExtent
                Layout.preferredHeight: root.controlExtent
                text: root.available && root.controller.playing
                    ? i18nc("@action:button", "Pause")
                    : i18nc("@action:button", "Play")
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: root.available && root.controller.playing
                    ? "media-playback-pause"
                    : "media-playback-start"
                enabled: (!root.available && root.launchAvailable)
                    || (root.available && root.controller.canControl
                        && ((root.controller.playing && root.controller.canPause)
                            || (!root.controller.playing && root.controller.canPlay)))
                Accessible.name: text
                Accessible.description: !root.available && root.launchAvailable
                    ? root.launchActionText
                    : ""
                onClicked: {
                    root.interactionActivated()
                    if (!root.available && root.launchAvailable) {
                        root.playbackLaunchRequested()
                    } else {
                        root.controller.togglePlaying()
                    }
                }
                KeyNavigation.tab: nextButton
            }

            PlasmaComponents.ToolButton {
                id: nextButton
                objectName: "mediaNextButton"
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: root.controlExtent
                Layout.preferredHeight: root.controlExtent
                text: i18nc("@action:button", "Next track")
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-backward"
                    : "media-skip-forward"
                enabled: root.available && root.controller.canControl
                    && root.controller.canGoNext
                Accessible.name: text
                onClicked: {
                    root.interactionActivated()
                    root.requestManualTrackChange()
                    root.controller.next()
                }
                KeyNavigation.tab: miniPinButton
            }
            PlasmaComponents.ToolButton {
                id: miniPinButton
                objectName: "reaMiniPlayerPin"
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: 21
                Layout.preferredHeight: Math.max(21, root.controlExtent)
                padding: 0
                display: PlasmaComponents.AbstractButton.IconOnly
                text: root.controlsPinned
                    ? i18nc("@action:button", "Show titles automatically")
                    : i18nc("@action:button", "Pin playback controls")
                icon.name: root.controlsPinned ? "pin" : "pin-off"
                icon.width: 14
                icon.height: 14
                icon.color: root.controlsPinned ? Kirigami.Theme.highlightColor
                    : Kirigami.Theme.textColor
                enabled: root.available
                Accessible.name: text
                // Tooltip belongs to the native Plasma popup below, not to
                // an overlay inside the narrow mini-player control row.
                onClicked: root.pinPreferenceChanged(root.pinIdentity, !root.controlsPinned)
                KeyNavigation.tab: previousButton
            }
        }
    }

    PlasmaCore.Dialog {
        id: miniPinTooltip
        objectName: "reaMiniPlayerPinTooltip"
        type: PlasmaCore.Dialog.Tooltip
        visualParent: miniPinButton
        location: root.panelLocation
        visible: miniPinButton.hovered && !pinTooltipDelay.running
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        mainItem: Controls.Label {
            text: miniPinButton.text
            padding: Kirigami.Units.smallSpacing
        }
    }
    Timer {
        id: pinTooltipDelay
        interval: Kirigami.Units.toolTipDelay
        running: miniPinButton.hovered
    }

    // R21: info-only slide-up card. Playback buttons and the original cover
    // remain in the dock at fixed coordinates throughout the animation.
    // A separate transient Plasma window never participates in dock layout.
    GuardedPopupDialog {
        id: hoverTrackPopup
        objectName: "reaMiniPlayerHoverTrackPopup"
        location: root.panelLocation
        // Anchor the card to the full mini player: centering on coverSlot
        // shifted wide metadata cards to the right of the transport controls.
        visualParent: root
        hideOnWindowDeactivate: false
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
            | Qt.WindowTransparentForInput
        readonly property NativePopupSpacing popupSpacing: NativePopupSpacing {
            sourceAnchor: root
            popup: hoverTrackPopup
            gap: Math.max(12, Kirigami.Units.largeSpacing)
            location: root.panelLocation
            preserveHorizontalAnchorCenter: true
            preserveVerticalAnchorCenter: true
        }
        onOpenFailed: console.warn("Oger Dock: R21 mini info popup lacks geometry")
        onVisibleChanged: {
            if (visible) {
                hoverSlideProgress = 0
                popupSpacing.scheduleRefresh()
                Qt.callLater(function() {
                    if (hoverTrackPopup.visible) hoverTrackPopup.hoverSlideProgress = 1
                })
            } else {
                hoverSlideProgress = 0
            }
        }
        property real hoverSlideProgress: 0
        Behavior on hoverSlideProgress {
            enabled: root.motionEnabled
            NumberAnimation {
                duration: Math.round(250 * 100 / root.resolvedMotionSpeedPercent)
                easing.type: Easing.OutCubic
            }
        }
        mainItem: Item {
            id: hoverTrackInfoCard
            objectName: "reaMiniPlayerTrackInfoCard"
            readonly property string trackTitle: root.controller && root.controller.track
                ? String(root.controller.track) : i18n("Now playing")
            readonly property string trackArtist: root.controller && root.controller.artist
                ? String(root.controller.artist) : ""
            TextMetrics {
                id: titleMeasure
                text: hoverTrackInfoCard.trackTitle
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            TextMetrics {
                id: artistMeasure
                text: hoverTrackInfoCard.trackArtist
                font.pixelSize: 13
            }
            // Adapt to real metadata, cap width to the available popup budget;
            // no redundant transport controls or progress are included here.
            readonly property real textAreaWidth: Math.min(324,
                Math.max(145, Math.ceil(Math.max(titleMeasure.advanceWidth,
                    artistMeasure.advanceWidth)) + 8))
            readonly property bool titleNeedsWrap: titleMeasure.advanceWidth > textAreaWidth
            implicitWidth: Math.round(16 + 56 + 13 + textAreaWidth + 20)
            implicitHeight: titleNeedsWrap ? 112 : 92
            width: implicitWidth
            height: implicitHeight

            // Both shadow and surface have the SAME rounded geometry. The
            // blurred artwork is inset to avoid square image pixels extending
            // past the radius; the original R21 card had irregular corners.
            Rectangle {
                x: 4
                y: 5 + (1 - hoverTrackPopup.hoverSlideProgress) * 17
                width: parent.width - 8
                height: parent.height - 8
                radius: 14
                color: "#19000000"
                opacity: hoverTrackPopup.hoverSlideProgress
            }
            Rectangle {
                id: hoverSlideSurface
                x: 2
                y: 1 + (1 - hoverTrackPopup.hoverSlideProgress) * 17
                width: parent.width - 6
                height: parent.height - 9
                radius: 14
                color: "#1B202B"
                border.width: 0
                opacity: hoverTrackPopup.hoverSlideProgress
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 11
                    source: root.artUrl
                    sourceSize: Qt.size(480, 160)
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    opacity: 0.30
                    layer.enabled: visible
                    layer.effect: Effects.MultiEffect {
                        blurEnabled: true
                        blur: 0.8
                        blurMax: 24
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "#CA10151F"
                    enabled: false
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 17
                    anchors.topMargin: 11
                    anchors.bottomMargin: 11
                    spacing: 13
                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: "#29313B"
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: root.artUrl
                            sourceSize: Qt.size(160, 160)
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        spacing: 4
                        Item { Layout.fillHeight: true }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: hoverTrackInfoCard.trackTitle
                            textFormat: Text.PlainText
                            renderType: Text.QtRendering
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            visible: hoverTrackInfoCard.trackArtist.length > 0
                            text: hoverTrackInfoCard.trackArtist
                            textFormat: Text.PlainText
                            renderType: Text.QtRendering
                            font.pixelSize: 13
                            color: "#E5E9F4"
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    onShowTitleCardChanged: {
        if (showTitleCard) {
            if (!hoverTrackPopup.visible && !hoverTrackPopup.preparingToShow)
                hoverTrackPopup.openSafely()
        } else {
            hoverTrackPopup.closeSafely()
        }
    }
    Component.onDestruction: hoverTrackPopup.closeSafely()

}
// qmllint enable unqualified
