import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// R57.1: Read-only preview of the selected folder's REAL application entries.
// The app list is supplied by ConfigItemsMainView from the same draft currently
// displayed in the folder editor, so the preview never displays placeholder
// icons belonging to unrelated applications. This does not launch anything or
// write dock_items.json. Geometry is schematic, but content/icons are real.
Item {
    id: root
    property string layoutMode: "grid"
    property var apps: []

    readonly property int totalApps: apps instanceof Array ? apps.length : 0
    readonly property int previewLimit: layoutMode === "fan" ? 5 : 8
    readonly property var previewApps: {
        const entries = root.apps instanceof Array ? root.apps : []
        const preview = []
        for (let i = 0; i < entries.length && i < root.previewLimit; i++) {
            const entry = entries[i] || {}
            preview.push({
                name: String(entry.name || entry.title || "Application"),
                icon: String(entry.icon || "application-x-executable")
            })
        }
        return preview
    }
    readonly property int count: previewApps.length
    readonly property int gridColumns: Math.max(1, Math.min(4, count))
    readonly property real gridCellWidth: Math.min(Kirigami.Units.gridUnit * 5.4,
        Math.max(Kirigami.Units.gridUnit * 3.4, root.width / gridColumns))
    readonly property real fanStep: Math.min(Kirigami.Units.gridUnit * 5.3,
        Math.max(Kirigami.Units.gridUnit * 2.6, (root.width - Kirigami.Units.gridUnit * 6) / Math.max(1, count - 1)))
    implicitHeight: layoutMode === "grid" ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 9
    implicitWidth: Kirigami.Units.gridUnit * 14
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.alternateBackgroundColor
        opacity: 0.75
    }

    Controls.Label {
        anchors.centerIn: parent
        visible: root.totalApps === 0
        text: i18nc("@info", "This folder has no applications yet.") // qmllint disable unqualified
        opacity: 0.65
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: Math.max(0, parent.width - Kirigami.Units.largeSpacing * 2)
    }

    Repeater {
        id: appRepeater
        model: root.previewApps
        delegate: Item {
            id: appDelegate
            required property int index
            required property var modelData
            readonly property bool isRow: root.layoutMode === "list" || root.layoutMode === "detailed"
            readonly property real iconSize: isRow
                ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
            width: isRow ? Math.max(0, root.width - Kirigami.Units.largeSpacing * 2)
                : root.gridCellWidth
            height: isRow ? Kirigami.Units.gridUnit * 1.65
                : Kirigami.Units.gridUnit * 3.0
            x: {
                const spacing = Kirigami.Units.gridUnit
                if (isRow) return spacing
                if (root.layoutMode === "fan") {
                    return (root.width - width) / 2
                        + (index - (root.count - 1) / 2) * root.fanStep
                }
                return (root.width - root.gridColumns * root.gridCellWidth) / 2
                    + (index % root.gridColumns) * root.gridCellWidth
            }
            y: {
                if (isRow) return Kirigami.Units.smallSpacing + index * height
                if (root.layoutMode === "fan") {
                    return Kirigami.Units.gridUnit * 1.0
                        + Math.abs(index - (root.count - 1) / 2) * Kirigami.Units.gridUnit * 0.5
                }
                return Kirigami.Units.smallSpacing
                    + Math.floor(index / root.gridColumns) * height
            }

            Kirigami.Icon {
                id: appIcon
                source: String(appDelegate.modelData.icon || "application-x-executable")
                width: appDelegate.iconSize
                height: width
                x: appDelegate.isRow ? 0 : (parent.width - width) / 2
                y: appDelegate.isRow ? (parent.height - height) / 2 : Kirigami.Units.smallSpacing
            }
            Controls.Label {
                text: String(appDelegate.modelData.name || "")
                x: appDelegate.isRow
                    ? appIcon.width + Kirigami.Units.smallSpacing : 0
                y: appDelegate.isRow ? (parent.height - height) / 2
                    : appIcon.y + appIcon.height + Kirigami.Units.smallSpacing
                width: appDelegate.isRow ? Math.max(0, parent.width - x) : parent.width
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                horizontalAlignment: appDelegate.isRow ? Text.AlignLeft : Text.AlignHCenter
            }
            Accessible.name: String(appDelegate.modelData.name || "")
            Behavior on x {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
    Controls.Label {
        visible: root.totalApps > root.previewLimit
        text: i18ncp("@info", "+%1 more application", "+%1 more applications",
            root.totalApps - root.previewLimit) // qmllint disable unqualified
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.smallSpacing
        opacity: 0.65
    }
}
