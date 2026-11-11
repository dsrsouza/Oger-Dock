import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Accessible KDE-style disclosure with real height interpolation.
// Kirigami duration becomes zero when the desktop disables animations.
Item {
    id: root
    property string title: ""
    property string description: ""
    property bool expanded: false
    implicitHeight: header.implicitHeight + contents.height
    implicitWidth: Kirigami.Units.gridUnit * 12

    Controls.ToolButton {
        id: header
        anchors.top: parent.top
        width: parent.width
        text: root.title
        icon.name: root.expanded ? "arrow-up" : "arrow-down"
        display: Controls.AbstractButton.TextBesideIcon
        onClicked: root.expanded = !root.expanded
        Accessible.name: root.title
        Accessible.description: root.expanded
            ? i18nc("@info:accessibility", "Collapse details")
            : i18nc("@info:accessibility", "Expand details") // qmllint disable unqualified
    }

    Item {
        id: contents
        width: parent.width
        anchors.top: header.bottom
        height: root.expanded && root.description.length > 0
            ? detail.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
        clip: true
        Behavior on height {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
        Controls.Label {
            id: detail
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            text: root.description
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            Accessible.name: String(root.description).replace(/<\/?b>/g, "")
        }
    }
}
