pragma ComponentBehavior: Bound

import QtQuick
import "../../code/reaMediaSource.js" as MediaSource
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Effects as Effects
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Native popup content: never grows the dock's layout rectangle.
// MPRIS is the single source of truth for playback and audio state.
FocusScope {
    id: root
    property var controller: null
    property string fallbackIcon: "emblem-music-symbolic"
    property bool motionEnabled: true
    property bool showCover: true
    property bool showTitle: true
    property bool showControls: true
    property bool showProgress: true
    property bool showVolume: true
    property string backgroundStyle: "artwork"
    property int motionSpeedPercent: 100
    readonly property bool available: !!controller && controller.available
    // Browser MPRIS metadata can be stale or inaccurate for web videos.
    readonly property bool browserSource: available && MediaSource.isBrowser(controller)
    readonly property bool progressReliable: available && !browserSource
    readonly property bool seekAvailable: progressReliable && controller.canSeek
        && controller.lengthUs > 0
    readonly property string titleText: available && controller.track
        ? String(controller.track) : i18nc("@info", "No media playing")
    readonly property string artistText: available && controller.artist
        ? String(controller.artist) : (available && controller.identity
            ? String(controller.identity) : "")
    property real displayedPositionUs: 0
    property bool popupVisible: false
    property real revealProgress: popupVisible ? 1.0 : 0.0
    readonly property int transitionTime: motionEnabled
        ? Math.round(21000 / Math.max(50, Math.min(150, motionSpeedPercent))) : 0
    signal closeRequested()
    signal stopSourceRequested()

    objectName: "mediaExpandedDetailsPanel"
    implicitWidth: 354
    implicitHeight: root.browserSource ? 430 : 510
    width: implicitWidth
    height: implicitHeight
    Accessible.role: Accessible.Dialog
    Accessible.name: i18nc("@title", "Media player")

    // Clip the complete popup, not only its artwork. Rectangular clipping
    // on QtQuick Rectangle alone still lets layer effects leave square
    // corners around a rounded Plasma surface on some Wayland compositors.
    layer.enabled: true
    layer.effect: Effects.MultiEffect {
        maskEnabled: true
        maskSource: popupRoundedMask
    }
    Item {
        id: popupRoundedMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: Math.max(10, Kirigami.Units.cornerRadius * 1.6)
            antialiasing: true
            color: "white"
        }
    }

    function timeString(microseconds) {
        const seconds = Math.max(0, Math.floor(Number(microseconds || 0) / 1000000))
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        const s = seconds % 60
        return (h > 0 ? String(h) + ":" + String(m).padStart(2, "0") : String(m))
            + ":" + String(s).padStart(2, "0")
    }

    function syncPosition() {
        if (!positionSlider.pressed) {
            displayedPositionUs = available
                ? Math.min(controller.lengthUs, Math.max(0, controller.positionUs)) : 0
        }
    }
    onControllerChanged: syncPosition()
    Component.onCompleted: syncPosition()
    Connections {
        target: root.controller
        ignoreUnknownSignals: true
        function onStateChanged() { root.syncPosition() }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.popupVisible && root.available && root.controller.playing
            && root.controller.lengthUs > 0 && !positionSlider.pressed
        onTriggered: root.displayedPositionUs = Math.min(
            root.controller.lengthUs, root.displayedPositionUs + 1000000)
    }

    Rectangle {
        id: panelBackground
        anchors.fill: parent
        radius: Math.max(10, Kirigami.Units.cornerRadius * 1.6)
        color: Kirigami.Theme.backgroundColor
        border.width: 0
        opacity: 1.0
        clip: true
        Image {
            anchors.fill: parent
            source: root.backgroundStyle === "artwork" && root.available
                ? String(root.controller.artUrl || "") : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(384, 512)
            visible: status === Image.Ready
            opacity: 0.22
            // Rounded rectangle above clips image before blur/compositing.
            layer.enabled: visible
            layer.effect: Effects.MultiEffect {
                blurEnabled: true
                blur: 0.85
                blurMax: 32
                maskEnabled: true
                maskSource: artworkCornerMask
            }
        }
        Item {
            id: artworkCornerMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: panelBackground.radius
                antialiasing: true
                color: "white"
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "applications-multimedia"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }
            Controls.Label {
                Layout.fillWidth: true
                text: i18nc("@title", "Playing now")
                font.bold: true
                font.pixelSize: 15
            }
            Controls.ToolButton {
                objectName: "mediaDetailsCloseButton"
                icon.name: "window-close-symbolic"
                text: i18nc("@action:button", "Close player")
                display: Controls.AbstractButton.IconOnly
                onClicked: root.stopSourceRequested()
            }
        }

        Rectangle {
            id: coverFrame
            objectName: "mediaExpandedCover"
            visible: root.showCover
            Layout.preferredWidth: 166
            Layout.preferredHeight: 166
            Layout.alignment: Qt.AlignHCenter
            radius: 14
            color: Kirigami.Theme.alternateBackgroundColor
            clip: true
            Image {
                id: albumArtwork
                anchors.fill: parent
                source: root.available && root.controller.artUrl
                    ? String(root.controller.artUrl) : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.min(512, Math.ceil(width * 2)),
                    Math.min(512, Math.ceil(height * 2)))
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 76
                height: 76
                source: root.fallbackIcon
                visible: albumArtwork.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: root.showTitle
            Controls.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.titleText
                textFormat: Text.PlainText
                font.bold: true
                font.pixelSize: 15
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Controls.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.artistText
                textFormat: Text.PlainText
                opacity: 0.72
                elide: Text.ElideRight
            }
        }

        Controls.Slider {
            id: positionSlider
            objectName: "mediaDetailsProgressSlider"
            visible: root.showProgress && root.progressReliable
            Layout.fillWidth: true
            from: 0
            to: root.available && root.controller.lengthUs > 0
                ? root.controller.lengthUs : 1
            enabled: root.seekAvailable
            Accessible.name: i18nc("@label:slider", "Playback position")
            onMoved: root.displayedPositionUs = value
            onPressedChanged: {
                if (!pressed && root.seekAvailable) {
                    root.controller.seekTo(Math.round(value))
                }
            }
            Binding {
                target: positionSlider
                property: "value"
                when: !positionSlider.pressed
                value: root.displayedPositionUs
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.showProgress && root.progressReliable
            Controls.Label {
                text: root.timeString(root.displayedPositionUs)
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Controls.Label {
                text: root.available ? root.timeString(root.controller.lengthUs) : "0:00"
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.showControls
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            Controls.ToolButton {
                objectName: "mediaDetailsShuffleButton"
                visible: !root.browserSource
                icon.name: "media-playlist-shuffle"
                text: i18nc("@action", "Shuffle")
                display: Controls.AbstractButton.IconOnly
                enabled: root.available && root.controller.canControl
                    && root.controller.shuffleAvailable
                readonly property bool playbackModeActive:
                    root.available && root.controller.shuffle
                highlighted: playbackModeActive
                icon.color: playbackModeActive
                    ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                background: Rectangle {
                    radius: 9
                    color: parent.playbackModeActive
                        ? Kirigami.Theme.highlightColor
                        : Qt.alpha(Kirigami.Theme.textColor, parent.hovered ? 0.11 : 0.045)
                    border.width: parent.playbackModeActive ? 2 : 1
                    border.color: parent.playbackModeActive
                        ? Kirigami.Theme.highlightedTextColor
                        : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
                Accessible.name: playbackModeActive
                    ? i18nc("@info", "Shuffle on") : i18nc("@info", "Shuffle off")
                Accessible.description: playbackModeActive
                    ? i18nc("@info", "Shuffle is on")
                    : i18nc("@info", "Shuffle is off")
                onClicked: root.controller.setShuffle(!root.controller.shuffle)
            }
            Controls.ToolButton {
                icon.name: "media-skip-backward"
                text: i18nc("@action", "Previous")
                display: Controls.AbstractButton.IconOnly
                enabled: root.available && root.controller.canGoPrevious
                onClicked: root.controller.previous()
            }
            Controls.Button {
                id: playPause
                objectName: "mediaDetailsPlayPauseButton"
                icon.name: root.available && root.controller.playing
                    ? "media-playback-pause" : "media-playback-start"
                text: root.available && root.controller.playing
                    ? i18nc("@action", "Pause") : i18nc("@action", "Play")
                display: Controls.AbstractButton.IconOnly
                implicitWidth: 52
                implicitHeight: 43
                enabled: root.available && root.controller.canControl
                    && (root.controller.playing ? root.controller.canPause
                        : root.controller.canPlay)
                onClicked: root.controller.togglePlaying()
            }
            Controls.ToolButton {
                icon.name: "media-skip-forward"
                text: i18nc("@action", "Next")
                display: Controls.AbstractButton.IconOnly
                enabled: root.available && root.controller.canGoNext
                onClicked: root.controller.next()
            }
            Controls.ToolButton {
                objectName: "mediaDetailsRepeatButton"
                visible: !root.browserSource
                icon.name: root.available && root.controller.loopStatus === "Track"
                    ? "media-playlist-repeat-song" : "media-playlist-repeat"
                text: i18nc("@action", "Repeat")
                display: Controls.AbstractButton.IconOnly
                enabled: root.available && root.controller.canControl
                    && root.controller.loopStatus.length > 0
                readonly property bool playbackModeActive:
                    root.available && root.controller.loopStatus !== "None"
                highlighted: playbackModeActive
                icon.color: playbackModeActive
                    ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                background: Rectangle {
                    radius: 9
                    color: parent.playbackModeActive
                        ? Kirigami.Theme.highlightColor
                        : Qt.alpha(Kirigami.Theme.textColor, parent.hovered ? 0.11 : 0.045)
                    border.width: parent.playbackModeActive ? 2 : 1
                    border.color: parent.playbackModeActive
                        ? Kirigami.Theme.highlightedTextColor
                        : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
                Accessible.name: playbackModeActive
                    ? i18nc("@info", "Repeat on") : i18nc("@info", "Repeat off")
                Accessible.description: playbackModeActive
                    ? i18nc("@info", "Repeat is on")
                    : i18nc("@info", "Repeat is off")
                onClicked: root.controller.cycleLoopStatus()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.showControls && !root.browserSource
            spacing: 8
            Controls.Button {
                objectName: "mediaShuffleModeChip"
                Layout.fillWidth: true
                checkable: true
                checked: root.available && !!root.controller.shuffle
                enabled: root.available && root.controller.shuffleAvailable
                icon.name: "media-playlist-shuffle"
                text: checked ? i18n("Shuffle ON") : i18n("Shuffle OFF")
                highlighted: checked
                onClicked: root.controller.setShuffle(checked)
            }
            Controls.Button {
                objectName: "mediaRepeatModeChip"
                Layout.fillWidth: true
                checked: root.available && root.controller.loopStatus !== "None"
                icon.name: "media-playlist-repeat"
                text: checked ? i18n("Repeat ON") : i18n("Repeat OFF")
                highlighted: checked
                enabled: root.available && root.controller.canControl
                    && root.controller.loopStatus.length > 0
                onClicked: root.controller.cycleLoopStatus()
            }
        }

        MediaVolumeControl {
            visible: root.showVolume
            Layout.fillWidth: true
            controller: root.controller
        }
        Item { Layout.fillHeight: true }
    }

    // Only the popup content slides; the dock dimensions remain constant.
    opacity: revealProgress
    transform: Translate { y: (1.0 - root.revealProgress) * 18 }
    Behavior on revealProgress {
        enabled: root.motionEnabled
        NumberAnimation { duration: root.transitionTime; easing.type: Easing.OutCubic }
    }
}
// qmllint enable unqualified
