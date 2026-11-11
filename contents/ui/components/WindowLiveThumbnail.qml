pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects as Effects
import org.kde.kwindowsystem
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

Item {
    id: root

    property string windowUuid: ""
    property var winId: 0
    property bool minimized: false
    property real cornerRadius: 0

    readonly property bool isWayland: KWindowSystem.isPlatformWayland
    readonly property bool isX11: KWindowSystem.isPlatformX11
    property bool waylandThumbnailReady: false
    property bool x11ThumbnailReady: false

    readonly property bool hasThumbnail: (root.isWayland && root.waylandThumbnailReady)
        || (root.isX11 && root.x11ThumbnailReady)

    anchors.fill: parent

    Item {
        id: thumbnailContent

        anchors.fill: parent
        layer.enabled: root.hasThumbnail && root.cornerRadius > 0
        layer.effect: Effects.MultiEffect {
            maskEnabled: true
            maskSource: roundedMask
        }

        Loader {
            id: waylandLoader

            anchors.fill: parent
            // Plasma 6.8.2 taskmanager preloads thumbnails asynchronously
            // only when the preview is visible. Keep the PipeWire request
            // idle while the tooltip is hidden.
            active: root.visible && root.isWayland && root.windowUuid.length > 0
            asynchronous: true
            visible: root.isWayland

            sourceComponent: PipeWire.PipeWireSourceItem {
                id: waylandItem

                anchors.fill: parent
                nodeId: waylandItem.supportsObjectSerial ? 0 : screencastingRequest.nodeId
                readonly property bool supportsObjectSerial: "objectSerial" in waylandItem
                    && "objectSerial" in screencastingRequest
                // Plasma versions before objectSerial use nodeId exclusively.
                readonly property var serialRequest: screencastingRequest

                Binding {
                    target: root
                    property: "waylandThumbnailReady"
                    value: waylandItem.ready
                    restoreMode: Binding.RestoreBindingOrValue
                }

                Binding {
                    target: waylandItem
                    property: "objectSerial"
                    value: waylandItem.supportsObjectSerial
                        ? waylandItem.serialRequest.objectSerial : 0
                    when: waylandItem.supportsObjectSerial
                    restoreMode: Binding.RestoreBindingOrValue
                }

                TaskManager.ScreencastingRequest {
                    id: screencastingRequest

                    uuid: root.windowUuid
                }
            }
        }

        // Keep the X11-only PlasmaCore type in a separate QML file. QML resolves
        // types in inline sourceComponents even when their Loader is inactive;
        // that made PlasmaCore.WindowThumbnail break Wayland sessions where it
        // is not provided by the installed Plasma QML plugin.
        Loader {
            id: x11ThumbnailLoader

            anchors.fill: parent
            active: root.visible && root.isX11 && !root.minimized && Number(root.winId) > 0
            asynchronous: true
            visible: root.isX11
            source: active ? "WindowX11Thumbnail.qml" : ""

            onLoaded: {
                if (item) {
                    item.winId = Number(root.winId)
                }
            }

            Binding {
                target: root
                property: "x11ThumbnailReady"
                value: x11ThumbnailLoader.item ? x11ThumbnailLoader.item.hasThumbnail : false
                restoreMode: Binding.RestoreBindingOrValue
            }
        }
    }

    Item {
        id: roundedMask

        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 8

        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, root.cornerRadius)
            color: "white"
            antialiasing: true
        }
    }
}
