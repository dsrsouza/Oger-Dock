import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    property real availableWidth: 0

    readonly property int pageImplicitWidth: Kirigami.Units.gridUnit * 28
    readonly property int contentWidth: Math.max(0,
        Math.min(380, Math.max(0, availableWidth - Kirigami.Units.gridUnit * 2)))
    readonly property int selectorWidth: Math.max(0,
        Math.min(280, Math.max(0, contentWidth - Kirigami.Units.gridUnit * 2)))
    readonly property int helperIndent: Kirigami.Units.largeSpacing
}
