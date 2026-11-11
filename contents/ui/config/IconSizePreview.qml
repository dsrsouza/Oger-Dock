import QtQuick
import org.kde.kirigami as Kirigami

// Local, reversible preview of the icon size and spacing draft in General.
// It never touches Plasmoid.configuration; KCM Apply/Cancel owns persistence.
Item {
    id: root
    property real iconSize: 48
    property real iconSpacing: 6
    implicitHeight: Kirigami.Units.gridUnit * 6
    implicitWidth: Kirigami.Units.gridUnit * 18
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.alternateBackgroundColor
        opacity: 0.7
    }

    Row {
        id: icons
        anchors.centerIn: parent
        spacing: root.iconSpacing
        scale: Math.min(1, Math.max(0.25, (root.width - Kirigami.Units.largeSpacing * 2)
            / Math.max(1, implicitWidth)))
        transformOrigin: Item.Center
        Behavior on spacing {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.veryShortDuration }
        }
        Repeater {
            model: ["folder", "internet-web-browser", "applications-games"]
            delegate: Kirigami.Icon {
                required property string modelData
                source: modelData
                width: root.iconSize
                height: width
                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
