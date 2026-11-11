pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore

Item {
    id: root

    property int winId: 0
    readonly property bool hasThumbnail: thumbnail.paintedWidth > 0
        && thumbnail.paintedHeight > 0

    PlasmaCore.WindowThumbnail {
        id: thumbnail

        anchors.fill: parent
        winId: root.winId
    }
}
