pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../components" as DockComponents
import "../../code/folderAccent.js" as FolderAccent

// R58 - Interactive configuration preview (not a screenshot or live task tray).
// The canonical configured dockItems model is rendered once. No duplicate list,
// passive inspector, or shadow copy of the model. Runtime rendering is untouched.
ColumnLayout {
    id: root
    property var controller
    property var itemModel
    property var folderCategoryColors: ({})
    property var statusHideTimer
    property alias statusText: statusLabel.text

    // R60: keep this surface on the KDE/Kirigami palette. Mix actual themed
    // colors (not RGB channel multipliers), so Breeze Light, Breeze Dark,
    // high-contrast and custom accent colors remain readable and update live.
    function blendThemeColor(background, accent, fraction) {
        const w = Math.max(0, Math.min(1, Number(fraction)))
        return Qt.rgba(background.r * (1 - w) + accent.r * w,
            background.g * (1 - w) + accent.g * w,
            background.b * (1 - w) + accent.b * w,
            1)
    }

    property bool dragInProgress: false
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    // Original indices of all right-click marked items. Nothing is persisted
    // until a drop; KCM Apply/Cancel still owns the saved configuration.
    property var multiSelectedIndices: []
    readonly property int multipleCount: multiSelectedIndices.length

    function isMultiSelected(index) {
        return root.multiSelectedIndices.indexOf(index) >= 0
    }
    function toggleMultiSelection(index) {
        if (!root.itemModel || index < 0 || index >= root.itemModel.count) return
        const next = root.multiSelectedIndices.slice()
        const position = next.indexOf(index)
        if (position >= 0) next.splice(position, 1)
        else next.push(index)
        root.multiSelectedIndices = next.sort((a, b) => a - b)
        root.controller.selectItem(next.length > 0 ? next[next.length - 1] : -1)
    }
    function clearMultiSelection() { root.multiSelectedIndices = [] }
    function effectiveDragGroup(sourceIndex) {
        return root.isMultiSelected(sourceIndex)
            ? root.multiSelectedIndices.slice() : [sourceIndex]
    }
    function dragGhostSourceIndices(sourceIndex) {
        const group = root.effectiveDragGroup(sourceIndex)
        return group.filter(index => index !== sourceIndex).slice(0, 4)
    }

    function previewIconSource(itemType, iconName) {
        return itemType === "punchimenu"
                && (!iconName || iconName === "start-here-kde")
            ? Qt.resolvedUrl("../../images/oger-menu-symbolic.png")
            : (root.controller ? root.controller.iconPreviewSource(iconName) : iconName)
    }
    // R59: fit every configured launcher inside the available viewport whenever
    // possible. Only exceptionally long docks scroll at a readable minimum size.
    readonly property real previewItemUnits: {
        if (!root.controller || !root.controller.items) return 1
        let units = 0
        for (const entry of root.controller.items) {
            const kind = String(entry.type || "app")
            units += kind === "separator" ? 0.42 : (kind === "spacer" ? 0.65 : 1)
        }
        return Math.max(1, units)
    }
    readonly property real tileSpacing: Math.max(2, Kirigami.Units.smallSpacing / 2)
    readonly property real tileSize: {
        const count = Math.max(root.itemModel ? root.itemModel.count : 0,
            root.controller ? root.controller.previewModelTargetCount : 0)
        const available = Math.max(0, dockBackdrop.width - Kirigami.Units.largeSpacing * 2)
        const natural = (available - Math.max(0, count - 1) * root.tileSpacing)
            / root.previewItemUnits
        return Math.max(Kirigami.Units.gridUnit * 1.5,
            Math.min(Kirigami.Units.gridUnit * 3.6, natural))
    }
    readonly property real previewHeight: Math.max(Kirigami.Units.gridUnit * 3.5,
        tileSize + Kirigami.Units.gridUnit)
    readonly property real viewportScrollStep: tileSize * 4
    readonly property bool hasSelectedItem: controller && controller.selectedIndex >= 0
        && controller.selectedIndex < controller.items.length
    readonly property string selectedTitle: {
        if (!root.hasSelectedItem || !root.itemModel
                || root.controller.selectedIndex >= root.itemModel.count) return ""
        return String(root.itemModel.get(root.controller.selectedIndex).title || "")
    }

    readonly property bool protectedPunchiMenu: root.hasSelectedItem
        && String(root.controller.items[root.controller.selectedIndex].type || "") === "punchimenu"

    signal addItemRequested()

    function showStatus(text, type) {
        statusLabel.type = type
        statusLabel.text = text
    }
    function clearStatus() { statusLabel.text = "" }
    function positionAtIndex(index) {
        if (root.itemModel && index >= 0 && index < root.itemModel.count)
            dockList.positionViewAtIndex(index, ListView.Contain)
    }
    function focusItemAtIndex(index) {
        positionAtIndex(index)
        // Do not transfer keyboard focus into an offscreen/uncreated delegate.
        const item = dockList.itemAtIndex(index)
        if (item) item.forceActiveFocus()
        else dockList.forceActiveFocus()
    }
    function focusAddItemButton() { addItemButton.forceActiveFocus() }
    function scrollPreview(direction) {
        if (root.dragInProgress) return
        const maximum = Math.max(0, dockList.contentWidth - dockList.width)
        dockList.contentX = Math.max(0, Math.min(maximum,
            dockList.contentX + direction * root.viewportScrollStep))
    }
    // Use exact positions of visible delegates: separators/spacers may have a
    // different width, so a guessed index from the X coordinate is unsafe.
    function closestVisibleIndex(viewportX) {
        if (!root.itemModel || root.itemModel.count === 0) return -1
        let closest = -1
        let distance = Number.POSITIVE_INFINITY
        for (let i = 0; i < root.itemModel.count; i++) {
            const delegate = dockList.itemAtIndex(i)
            if (!delegate) continue
            const point = dockList.mapFromItem(delegate, delegate.width / 2,
                delegate.height / 2)
            const currentDistance = Math.abs(point.x - viewportX)
            if (currentDistance < distance) {
                distance = currentDistance
                closest = i
            }
        }
        return closest
    }
    function finishDrag(sourceIndex, targetIndex) {
        root.dragSourceIndex = -1
        root.dragTargetIndex = -1
        root.dragInProgress = false
        if (sourceIndex === targetIndex || !root.controller || targetIndex < 0)
            return
        const selection = root.effectiveDragGroup(sourceIndex)
        const changed = selection.length > 1
            ? root.controller.moveItemGroupToIndex(selection, targetIndex,
                targetIndex > selection[selection.length - 1])
            : root.controller.moveItemToIndex(sourceIndex, targetIndex)
        if (changed) {
            if (selection.length > 1)
                root.multiSelectedIndices = root.controller.lastMovedGroupIndices.slice()
            else root.clearMultiSelection()
            root.showStatus(i18nc("@info:status", "Dock order changed. Apply or OK to save."),
                Kirigami.MessageType.Information) // qmllint disable unqualified
        }
    }
    function setKeyboardSelection(index) {
        if (!root.controller || !root.itemModel
                || index < 0 || index >= root.itemModel.count) return
        root.controller.selectItem(index)
        positionAtIndex(index)
    }

    spacing: Kirigami.Units.largeSpacing
    anchors.fill: parent

    Controls.Frame {
        objectName: "interactiveDockItemsEditor"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 15
        Layout.minimumWidth: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Kirigami.Units.smallSpacing
                Controls.Label {
                    text: i18nc("@title:group", "Organize your Dock") // qmllint disable unqualified
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Controls.Button {
                    id: addItemButton
                    objectName: "dockPreviewAddItem"
                    text: i18nc("@action:button", "Add item") // qmllint disable unqualified
                    icon.name: "list-add-symbolic"
                    Accessible.name: i18nc("@action:button", "Add item to Dock") // qmllint disable unqualified
                    onClicked: root.addItemRequested()
                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: Accessible.name
                }
                Controls.Button {
                    objectName: "dockPreviewRemoveItem"
                    text: i18nc("@action:button", "Remove item") // qmllint disable unqualified
                    icon.name: "list-remove-symbolic"
                    enabled: root.hasSelectedItem && !root.protectedPunchiMenu
                        && root.multipleCount <= 1 && !root.dragInProgress
                    Accessible.name: root.protectedPunchiMenu
                        ? i18nc("@info:tooltip", "Oger Dock menu cannot be removed") // qmllint disable unqualified
                        : i18nc("@action:button", "Remove selected dock item") // qmllint disable unqualified
                    onClicked: root.controller.removeSelectedItem()
                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: Accessible.name
                }

            }

            Controls.Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: i18nc("@info", "Left click: select · Right click: mark several · Drag: move together · Double click: configure") // qmllint disable unqualified
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: Kirigami.Units.gridUnit }

            Rectangle {
                id: previewSurface
                objectName: "dockPreviewSurface"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 18
                Layout.minimumHeight: Kirigami.Units.gridUnit * 13
                radius: Kirigami.Units.cornerRadius
                // A view is a content area, not the window chrome. This color
                // set is supplied by Plasma and changes with the user's theme.
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                readonly property color themeBackground: Kirigami.Theme.backgroundColor
                readonly property color themeText: Kirigami.Theme.textColor
                readonly property color themeAccent: Kirigami.Theme.highlightColor
                border.width: 1
                border.color: root.blendThemeColor(
                    themeBackground, themeText, 0.24)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: root.blendThemeColor(
                            previewSurface.themeBackground,
                            previewSurface.themeAccent, 0.13)
                    }
                    GradientStop {
                        position: 1
                        color: root.blendThemeColor(
                            previewSurface.themeBackground,
                            previewSurface.themeAccent, 0.045)
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    id: dockBackdrop
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.previewHeight
                    radius: Kirigami.Units.cornerRadius
                    border.width: 1
                    // Keep sufficient contrast in light and dark color schemes.
                    border.color: root.blendThemeColor(
                        previewSurface.themeBackground,
                        previewSurface.themeText, 0.38)
                    color: root.blendThemeColor(
                        previewSurface.themeBackground,
                        previewSurface.themeAccent, 0.025)
                    clip: true

                    // This draws configured item identities from the canonical
                    // KCM model, not a static image of the user's wallpaper.
                    ListView {
                        id: dockList
                        objectName: "dockInteractivePreviewList"
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        orientation: ListView.Horizontal
                        layoutDirection: Qt.LeftToRight
                        verticalLayoutDirection: ListView.TopToBottom
                        spacing: root.tileSpacing
                        model: root.itemModel
                        clip: true
                        interactive: !root.dragInProgress
                        boundsBehavior: Flickable.StopAtBounds
                        activeFocusOnTab: true
                        Accessible.name: i18nc("@label", "Interactive Dock item order") // qmllint disable unqualified
                        currentIndex: root.controller ? root.controller.selectedIndex : -1
                        move: Transition {
                            NumberAnimation {
                                properties: "x"
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        moveDisplaced: Transition {
                            NumberAnimation {
                                properties: "x"
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: function(event) {
                                if (root.dragInProgress) return
                                const direction = event.angleDelta.y > 0 ? -1 : 1
                                root.scrollPreview(direction)
                                event.accepted = true
                            }
                        }
                        Keys.onPressed: function(event) {
                            if (!root.controller || !root.itemModel) return
                            const current = root.controller.selectedIndex
                            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                const delta = event.key === Qt.Key_Left ? -1 : 1
                                if (event.modifiers & Qt.ControlModifier) {
                                    if (current >= 0 && root.controller.moveItemToIndex(current, current + delta))
                                        root.setKeyboardSelection(current + delta)
                                } else {
                                    root.setKeyboardSelection(current < 0 ? 0 : current + delta)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.hasSelectedItem) root.controller.configureSelectedItem()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Delete) {
                                if (root.multipleCount <= 1 && root.hasSelectedItem
                                        && !root.protectedPunchiMenu) root.controller.removeSelectedItem()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape && root.multipleCount > 0) {
                                root.clearMultiSelection()
                                event.accepted = true
                            }
                        }

                        delegate: Item {
                            id: dockDelegate
                            required property int index
                            required property int sourceIndex
                            required property string title
                            required property string subtitle
                            required property string iconName
                            readonly property string itemType: {
                                if (!root.controller || !root.controller.items
                                        || sourceIndex < 0 || sourceIndex >= root.controller.items.length)
                                    return "app"
                                return String(root.controller.items[sourceIndex].type || "app")
                            }
                            // Pull the actual folder object, not the icon-name-only
                            // ListModel projection. This is precisely the array
                            // that DockItem passes to FolderStackIcon at runtime.
                            readonly property var configuredFolder: {
                                if (itemType !== "folder" || !root.controller
                                        || !root.controller.items
                                        || sourceIndex < 0
                                        || sourceIndex >= root.controller.items.length)
                                    return ({})
                                return root.controller.items[sourceIndex] || ({})
                            }
                            readonly property var folderPreviewApps:
                                configuredFolder.apps || []
                            readonly property color folderPreviewAccent:
                                FolderAccent.resolvedColor(
                                    configuredFolder.folderAccentColor,
                                    configuredFolder.sourceType === "category"
                                        ? configuredFolder.sourceCategory : "",
                                    root.folderCategoryColors,
                                    Kirigami.Theme.highlightColor)
                            property bool didDrag: false
                            readonly property var dragGhosts: root.dragGhostSourceIndices(sourceIndex)
                            readonly property bool selected: root.isMultiSelected(sourceIndex)
                                || (root.controller && root.controller.selectedIndex === sourceIndex)
                            readonly property bool partOfDraggedGroup: root.dragInProgress
                                && root.effectiveDragGroup(root.dragSourceIndex).indexOf(sourceIndex) >= 0
                            readonly property bool dragLeader: root.dragInProgress
                                && root.dragSourceIndex === sourceIndex
                            width: itemType === "separator" ? root.tileSize * 0.42
                                : itemType === "spacer" ? root.tileSize * 0.65
                                : root.tileSize
                            height: dockList.height
                            z: root.dragSourceIndex === sourceIndex ? 100 : 0
                            activeFocusOnTab: true
                            Accessible.name: title
                            Accessible.description: subtitle

                            Rectangle {
                                id: tile
                                x: 0
                                y: (parent.height - height) / 2
                                width: dockDelegate.width
                                height: root.tileSize
                                radius: Kirigami.Units.smallSpacing
                                color: dockDelegate.selected
                                    ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                        Kirigami.Theme.highlightColor.g,
                                        Kirigami.Theme.highlightColor.b, 0.32)
                                    : (dragMouse.containsMouse
                                        ? root.blendThemeColor(
                                            previewSurface.themeBackground,
                                            previewSurface.themeAccent, 0.13)
                                        : "transparent")
                                border.width: (dockDelegate.selected ||
                                    (root.dragInProgress && root.dragTargetIndex === dockDelegate.sourceIndex)) ? 2 : 0
                                border.color: Kirigami.Theme.highlightColor
                                opacity: dockDelegate.didDrag ? 0.9
                                    : (dockDelegate.partOfDraggedGroup && !dockDelegate.dragLeader ? 0.28 : 1)
                                Behavior on x {
                                    enabled: !dragMouse.drag.active
                                    NumberAnimation {
                                        duration: Kirigami.Units.veryShortDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    visible: dockDelegate.itemType === "separator"
                                    anchors.centerIn: parent
                                    width: 2
                                    height: Kirigami.Units.iconSizes.medium
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.5
                                }
                                Rectangle {
                                    visible: dockDelegate.itemType === "spacer"
                                    anchors.centerIn: parent
                                    width: Math.max(Kirigami.Units.gridUnit, parent.width / 2)
                                    height: 1
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                Kirigami.Icon {
                                    visible: dockDelegate.itemType !== "separator"
                                        && dockDelegate.itemType !== "spacer"
                                        && dockDelegate.itemType !== "folder"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: dockDelegate.itemType === "dynamic-applications" ? "window-duplicate"
                                        : root.previewIconSource(dockDelegate.itemType, dockDelegate.iconName)
                                    width: Math.max(12, Math.min(root.tileSize * 0.73,
                                        Kirigami.Units.iconSizes.large))
                                    height: width
                                }
                                // Load the *same* lightweight thumbnail component
                                // as the real DockItem. Non-folder delegates do not
                                // instantiate it; six folders cost six previews,
                                // not an extra rendering tree for every launcher.
                                Loader {
                                    id: folderStackLoader
                                    objectName: "configDockFolderStackLoader"
                                    // R62.6: instantiate icon mosaics asynchronously,
                                    // AFTER the complete dock item projection exists.
                                    // Never asynchronously build the canonical ListModel.
                                    asynchronous: true
                                    active: dockDelegate.itemType === "folder"
                                    visible: active
                                    anchors.centerIn: parent
                                    width: Math.max(12, Math.min(root.tileSize * 0.73,
                                        Kirigami.Units.iconSizes.large))
                                    height: width
                                    sourceComponent: Component {
                                        DockComponents.FolderStackIcon {
                                            objectName: "configDockFolderStackPreview"
                                            iconExtent: Math.round(folderStackLoader.width)
                                            entries: dockDelegate.folderPreviewApps
                                            fallbackIcon: String(dockDelegate.iconName || "folder")
                                            categoryAccent: dockDelegate.folderPreviewAccent
                                            // The preview represents configured state,
                                            // not an opened runtime popup. Hover/move
                                            // is handled by the existing ListView.
                                            opened: false
                                            motionEnabled: false
                                        }
                                    }
                                }
                                // A folder always has a visible placeholder while
                                // its real, shared mosaic component is being created.
                                // This prevents another blank-preview regression.
                                Kirigami.Icon {
                                    visible: dockDelegate.itemType === "folder"
                                        && folderStackLoader.status !== Loader.Ready
                                    anchors.centerIn: parent
                                    width: Math.max(12, Math.min(root.tileSize * 0.73,
                                        Kirigami.Units.iconSizes.large))
                                    height: width
                                    source: root.previewIconSource("folder", dockDelegate.iconName)
                                }
                                Repeater {
                                    model: dockDelegate.dragLeader ? dockDelegate.dragGhosts : []
                                    delegate: Rectangle {
                                        required property int modelData
                                        required property int index
                                        readonly property var ghostRow: root.itemModel
                                            && modelData >= 0 && modelData < root.itemModel.count
                                            ? root.itemModel.get(modelData) : ({})
                                        width: parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        x: (index + 1) * Math.max(6, parent.width * 0.24)
                                        y: -(index + 1) * Math.max(4, parent.height * 0.14)
                                        z: -1 - index
                                        color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                            Kirigami.Theme.highlightColor.g,
                                            Kirigami.Theme.highlightColor.b, 0.18)
                                        border.width: 1
                                        border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                            Kirigami.Theme.highlightColor.g,
                                            Kirigami.Theme.highlightColor.b, 0.45)
                                        visible: dockDelegate.dragLeader
                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: Math.max(10, Math.min(root.tileSize * 0.56,
                                                Kirigami.Units.iconSizes.medium))
                                            height: width
                                            source: root.previewIconSource(
                                                root.controller && root.controller.items
                                                    && modelData < root.controller.items.length
                                                    ? String(root.controller.items[modelData].type || "app")
                                                    : "app",
                                                String(ghostRow.iconName || "application-x-executable"))
                                            opacity: 0.82
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: dockDelegate.dragLeader && dockDelegate.dragGhosts.length > 0
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: -Kirigami.Units.smallSpacing
                                    anchors.topMargin: -Kirigami.Units.smallSpacing
                                    width: Math.max(Kirigami.Units.gridUnit * 1.25,
                                        groupCountText.implicitWidth + Kirigami.Units.smallSpacing * 2)
                                    height: Kirigami.Units.gridUnit * 1.25
                                    radius: height / 2
                                    color: Kirigami.Theme.highlightColor
                                    border.color: Kirigami.Theme.highlightedTextColor
                                    border.width: 1
                                    z: 10
                                    Controls.Label {
                                        id: groupCountText
                                        anchors.centerIn: parent
                                        text: String(root.effectiveDragGroup(dockDelegate.sourceIndex).length)
                                        color: Kirigami.Theme.highlightedTextColor
                                        font.bold: true
                                        font.pixelSize: Math.max(9, Kirigami.Units.gridUnit * 0.65)
                                    }
                                }
                                Kirigami.Icon {
                                    visible: root.isMultiSelected(dockDelegate.sourceIndex)
                                    source: "emblem-ok-symbolic"
                                    width: Math.max(12, root.tileSize * 0.27)
                                    height: width
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    color: Kirigami.Theme.highlightColor
                                }
                                Rectangle {
                                    visible: dockDelegate.selected
                                    width: Math.max(12, parent.width / 3)
                                    height: Kirigami.Units.smallSpacing / 2
                                    radius: height / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
                                    color: Kirigami.Theme.highlightColor
                                }
                            }

                            MouseArea {
                                id: dragMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor
                                    : Qt.PointingHandCursor
                                // MouseArea drag target is detached on right press,
                                // so context selection never initiates a move.
                                drag.target: tile
                                drag.axis: Drag.XAxis
                                drag.threshold: Qt.styleHints.startDragDistance
                                onPressed: function(mouse) {
                                    dockDelegate.didDrag = false
                                    if (mouse.button === Qt.RightButton) {
                                        drag.target = null
                                        root.toggleMultiSelection(dockDelegate.sourceIndex)
                                        return
                                    }
                                    drag.target = tile
                                    root.dragSourceIndex = -1
                                    root.dragTargetIndex = -1
                                }
                                onPositionChanged: {
                                    if (!(pressedButtons & Qt.LeftButton) || !drag.active) return
                                    dockDelegate.didDrag = true
                                    root.dragInProgress = true
                                    root.dragSourceIndex = dockDelegate.sourceIndex
                                    const center = dockList.mapFromItem(tile,
                                        tile.width / 2, tile.height / 2)
                                    root.dragTargetIndex = root.closestVisibleIndex(center.x)
                                }
                                onReleased: function(mouse) {
                                    if (mouse.button !== Qt.LeftButton) {
                                        drag.target = tile
                                        return
                                    }
                                    const dragged = dockDelegate.didDrag
                                    const from = dockDelegate.sourceIndex
                                    const to = root.dragTargetIndex
                                    tile.x = 0
                                    if (dragged) root.finishDrag(from, to)
                                }
                                onCanceled: {
                                    tile.x = 0
                                    root.finishDrag(-1, -1)
                                }
                                onClicked: function(mouse) {
                                    if (mouse.button !== Qt.LeftButton || dockDelegate.didDrag
                                            || !root.controller) return
                                    if (!root.isMultiSelected(dockDelegate.sourceIndex))
                                        root.clearMultiSelection()
                                    root.controller.selectItem(dockDelegate.sourceIndex)
                                    dockDelegate.forceActiveFocus()
                                }
                                onDoubleClicked: function(mouse) {
                                    if (mouse.button !== Qt.LeftButton || dockDelegate.didDrag
                                            || !root.controller) return
                                    root.clearMultiSelection()
                                    root.controller.selectItem(dockDelegate.sourceIndex)
                                    root.controller.configureSelectedItem()
                                }
                                Controls.ToolTip.visible: containsMouse && !root.dragInProgress
                                Controls.ToolTip.text: dockDelegate.title + (root.isMultiSelected(dockDelegate.sourceIndex)
                                    ? i18nc("@info:tooltip", " (marked for group move)") : "") // qmllint disable unqualified
                            }
                        }
                    }

                    Controls.Label {
                        anchors.centerIn: parent
                        visible: !root.itemModel || root.itemModel.count === 0
                        text: i18nc("@info", "No configured items. Use Add item to begin.") // qmllint disable unqualified
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }


            }

                    Item { Layout.fillHeight: true }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing
                Controls.Label {
                    objectName: "dockReorderInstruction"
                    text: root.multipleCount > 0
                        ? i18nc("@info:label", "%1 marked · Drag one marked icon to move them together", root.multipleCount) // qmllint disable unqualified
                        : i18nc("@info:label", "Click and drag to reorder") // qmllint disable unqualified
                    color: Kirigami.Theme.textColor
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: implicitWidth + Kirigami.Units.gridUnit * 2
                    Layout.maximumWidth: root.width * 0.7
                    elide: Text.ElideRight
                }
                Controls.ToolButton {
                    visible: dockList.contentWidth > dockList.width + 1
                    enabled: !root.dragInProgress && dockList.contentX > 0
                    icon.name: "go-previous-symbolic"
                    Accessible.name: i18nc("@action:button", "Scroll dock preview left") // qmllint disable unqualified
                    onClicked: root.scrollPreview(-1)
                }
                Controls.ToolButton {
                    visible: dockList.contentWidth > dockList.width + 1
                    enabled: !root.dragInProgress && dockList.contentX + dockList.width
                        < dockList.contentWidth - 1
                    icon.name: "go-next-symbolic"
                    Accessible.name: i18nc("@action:button", "Scroll dock preview right") // qmllint disable unqualified
                    onClicked: root.scrollPreview(1)
                }
            }

            Controls.Frame {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.largeSpacing
                    Controls.Label {
                        text: i18nc("@title:group", "How it works") // qmllint disable unqualified
                        font.weight: Font.DemiBold
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        Controls.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: i18nc("@info", "Select: left click once; double click to configure. Right click to mark multiple icons.") // qmllint disable unqualified
                            wrapMode: Text.WordWrap
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: i18nc("@info", "Reorder: drag any marked icon to move the entire selection together.") // qmllint disable unqualified
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            Controls.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "This preview shows configured items; changes are saved with Apply or OK.") // qmllint disable unqualified
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
        }
    }

    Kirigami.InlineMessage {
        id: statusLabel
        Layout.fillWidth: true
        visible: text.length > 0
        text: ""
        onTextChanged: {
            if (!root.statusHideTimer) return
            if (text.length > 0 && type !== Kirigami.MessageType.Error)
                root.statusHideTimer.restart()
            else
                root.statusHideTimer.stop()
        }
        onTypeChanged: {
            if (!root.statusHideTimer) return
            if (text.length > 0 && type !== Kirigami.MessageType.Error)
                root.statusHideTimer.restart()
            else
                root.statusHideTimer.stop()
        }
    }
}
