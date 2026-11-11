import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property bool highlighted: false
    property bool showBaseSurface: false
    property bool circular: false
    property color accentColor: "transparent"
    readonly property bool accentEnabled: accentColor.a > 0

    radius: circular ? height / 2 : Kirigami.Units.cornerRadius * 1.5
    color: accentEnabled
        ? Qt.alpha(accentColor, highlighted ? 0.22 : 0.095)
        : highlighted
        ? Kirigami.Theme.highlightColor
        : showBaseSurface
            ? Qt.alpha(Kirigami.Theme.textColor, 0.10)
            : "transparent"
    border.width: (highlighted || accentEnabled) ? 1 : 0
    border.color: accentEnabled
        ? Qt.alpha(accentColor, highlighted ? 0.85 : 0.35)
        : highlighted ? Kirigami.Theme.highlightColor : "transparent"
    antialiasing: true
    Accessible.ignored: true

    Behavior on color {
        ColorAnimation {
            duration: Math.max(80,
                Math.min(140, Kirigami.Units.shortDuration))
        }
    }
}
