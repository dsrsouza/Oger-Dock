// SPDX-License-Identifier: GPL-3.0-or-later
// R62.5: low-cost page entrance for native KCM pages.
// Do not animate opacity of a full page: QQuickItem opacity makes large pages
// more expensive to composite and cannot reduce time spent creating controls.
// A tiny position-only animation is enough; no blank overlay or forced delay.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property Item pageItem: null
    property var pageOffset: null
    readonly property bool motionEnabled: Kirigami.Units.longDuration > 1
    readonly property int durationMs: motionEnabled
        ? Math.min(100, Math.max(60, Kirigami.Units.shortDuration)) : 0

    function enter() {
        if (!pageItem || !pageItem.visible) return
        motion.stop()
        if (!motionEnabled || !pageOffset) {
            if (pageOffset) pageOffset.y = 0
            return
        }
        // The KCM and its controls stay opaque at every point of the gesture.
        // This only translates 2–4 px and does not create an opacity layer.
        pageOffset.y = Math.min(4, Kirigami.Units.smallSpacing / 2)
        motion.start()
    }

    Connections {
        target: root.pageItem
        function onVisibleChanged() {
            if (root.pageItem && root.pageItem.visible)
                Qt.callLater(root.enter)
        }
    }

    NumberAnimation {
        id: motion
        target: root.pageOffset
        property: "y"
        from: Math.min(4, Kirigami.Units.smallSpacing / 2)
        to: 0
        duration: root.durationMs
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.pageOffset) root.pageOffset.y = 0
        }
    }
    Component.onCompleted: Qt.callLater(root.enter)
}
