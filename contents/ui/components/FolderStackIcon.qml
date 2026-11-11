pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami

// A compact preview of the actual apps in a dock folder. All effects stay
// inside the icon footprint so Plasma can clip the panel safely on Wayland.
Item {
    id: stack
    objectName: "dockFolderStackPreview"
    property var entries: []
    property string fallbackIcon: "folder"
    property color categoryAccent: Kirigami.Theme.highlightColor
    property bool opened: false
    property bool motionEnabled: true
    property int iconExtent: 48
    // Preview the first four *actual* apps in a tidy 2×2 arrangement.
    // Its external geometry never grows or shifts adjacent dock icons.
    readonly property int previewCount: Math.min(4,
        entries && entries.length ? entries.length : 0)
    // Reserve a real internal safe area for the neon border and its rounded corners.
    // With 48px items the old 2x2 grid was wider than the framed plate itself.
    readonly property real tileGap: Math.max(2, Math.round(iconExtent * 0.042))
    readonly property real previewInset: Math.max(3, Math.round(iconExtent * 0.12))
    readonly property real tileExtent: previewCount === 1
        ? Math.max(8, Math.floor(iconExtent * 0.56))
        : Math.max(6, Math.floor((iconExtent * 0.94 - 2 * previewInset - tileGap) / 2))
    readonly property int transitionDuration: motionEnabled ? 190 : 0

    width: iconExtent
    height: iconExtent
    Accessible.ignored: true

    // Empty folders continue to use their user-selected folder icon.
    Kirigami.Icon {
        anchors.centerIn: parent
        width: stack.iconExtent * 0.87
        height: width
        source: stack.fallbackIcon
        roundToIconSize: false
        visible: stack.previewCount === 0
    }

    Rectangle {
        id: folderPlate
        objectName: "dockFolderStackPlate"
        visible: stack.previewCount > 0
        anchors.centerIn: parent
        width: stack.iconExtent * 0.94
        height: stack.iconExtent * 0.94
        radius: Math.max(6, width * 0.20)
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.92)
        // Stronger neon frame at the dock's actual small icon size.
        border.width: stack.opened ? 3.6 : 3.0
        border.color: Qt.alpha(stack.categoryAccent,
            stack.opened ? 1.0 : 0.94)
    }

    Rectangle {
        visible: stack.previewCount > 0
        z: 1
        width: stack.iconExtent * 0.23
        height: Math.max(2, stack.iconExtent * 0.045)
        x: Math.round(stack.iconExtent * 0.17)
        y: Math.round(stack.iconExtent * 0.055)
        radius: 2
        color: stack.categoryAccent
        opacity: 0.90
    }

    Item {
        id: previewSafeRegion
        z: 2
        anchors.fill: folderPlate
        anchors.margins: stack.previewInset
        clip: true
        Repeater {
        model: stack.previewCount
        delegate: Item {
            id: tile
            required property int index
            readonly property var app: stack.entries[tile.index] || ({})
            readonly property string previewIcon: String(app.icon || app.iconName || "application-x-executable")
            readonly property int column: stack.previewCount === 1 ? 0 : tile.index % 2
            readonly property int row: stack.previewCount === 1 ? 0 : Math.floor(tile.index / 2)
            readonly property real gridExtent: stack.tileExtent * 2 + stack.tileGap
            z: tile.index + 1
            width: stack.tileExtent
            height: width
            x: stack.previewCount === 1
                ? (previewSafeRegion.width - width) / 2
                : (previewSafeRegion.width - gridExtent) / 2 + column * (width + stack.tileGap)
            y: stack.previewCount === 1
                ? (previewSafeRegion.height - height) / 2
                : Math.max(0, (previewSafeRegion.height - gridExtent) / 2)
                    + row * (height + stack.tileGap)
            rotation: 0 // Avoid sampling blur from rotating tiny raster icons.
            visible: stack.previewCount > 0
            Behavior on x { NumberAnimation { duration: stack.transitionDuration; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: stack.transitionDuration; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: stack.transitionDuration; easing.type: Easing.OutCubic } }

            Kirigami.Icon {
                anchors.centerIn: parent
                // Ask the theme provider for a 64/96-pixel source, then
                // downsample into the unchanged 24-pixel visual slot. The
                // spare resolution remains useful during dock hover zoom.
                width: Math.round(tile.width)
                height: width
                // Render once at the actual tile size and let Qt resolve
                // physical DPR. Avoid a second high-resolution Item scale:
                // Qt Quick would resample the tiny icon twice when zooming.
                source: tile.previewIcon
                fallback: "application-x-executable"
                isMask: false
                roundToIconSize: false
                smooth: true
                // Do not force a shader-effect texture for themed icons:
                // Qt 6 RHI drivers can render these tiny FBOs black or blurry.
                // Keeping the real Kirigami.Icon unlayered allows the icon
                // provider to select the correct source for the current DPR.
                layer.enabled: false
            }
        }
    }
    }

    // The rim must paint LAST, above every actual application icon. It is
    // decoration only and must not take pointer input or affect icon size.
    Rectangle {
        z: 9
        visible: stack.previewCount > 0
        anchors.fill: folderPlate
        radius: folderPlate.radius
        color: "transparent"
        border.width: folderPlate.border.width
        border.color: folderPlate.border.color
        enabled: false
        Accessible.ignored: true
    }

    // R24: remove the overlaid arrow; the neon border indicates open state.
}
