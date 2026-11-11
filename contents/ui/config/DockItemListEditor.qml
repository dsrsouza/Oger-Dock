pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.Frame {
    id: root

    property var controller
    property var itemModel

    readonly property bool filtering: itemSearch.text.trim().length > 0

    ListModel { id: filteredItems }

    function rebuildFilteredItems() {
        if (itemSearch.text.trim().length === 0 || !root.itemModel) return
        filteredItems.clear()
        for (let index = 0; index < root.itemModel.count; index++) {
            if (!root.matchesItem(index)) continue
            const row = root.itemModel.get(index)
            filteredItems.append({
                "sourceIndex": index,
                "title": String(row.title || ""),
                "subtitle": String(row.subtitle || ""),
                "iconName": String(row.iconName || "")
            })
        }
    }

    function displayedIndexFor(sourceIndex) {
        if (!root.filtering) return sourceIndex
        for (let index = 0; index < filteredItems.count; index++) {
            if (filteredItems.get(index).sourceIndex === sourceIndex) return index
        }
        return -1
    }

    // The controller's array is authoritative; rebuild only the filtered
    // projection after source updates, never replace or mutate the source rows.
    Connections {
        target: root.controller
        function onItemsChanged() { Qt.callLater(root.rebuildFilteredItems) }
    }

    signal addItemRequested()

    function matchesItem(index) {
        if (!root.itemModel || index < 0 || index >= root.itemModel.count) return false
        const query = itemSearch.text.trim().toLocaleLowerCase()
        if (query.length === 0) return true
        const row = root.itemModel.get(index)
        return (String(row.title || "") + " " + String(row.subtitle || ""))
            .toLocaleLowerCase().includes(query)
    }

    function findVisibleItem(startIndex, delta) {
        for (let index = startIndex; index >= 0 && index < root.itemModel.count; index += delta) {
            if (root.matchesItem(index)) return index
        }
        return -1
    }

    function positionAtIndex(index) {
        const displayed = root.displayedIndexFor(index)
        if (displayed >= 0 && itemList.count > 0) {
            itemList.positionViewAtIndex(displayed, ListView.Contain)
        }
    }

    function focusAtIndex(index) {
        if (itemSearch.text.length > 0 && !root.matchesItem(index)) itemSearch.clear()
        const displayed = root.displayedIndexFor(index)
        if (displayed < 0 || displayed >= itemList.count) {
            return
        }
        itemList.currentIndex = displayed
        itemList.positionViewAtIndex(displayed, ListView.Contain)
        itemList.forceActiveFocus()
    }

    function focusAddItemButton() {
        addItemButton.forceActiveFocus()
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    // Floor derived from the existing list metrics so the frame keeps a usable
    // body when the page is short; the embedded toolbar owns the remaining row.
    Layout.minimumHeight: root.controller.listRowHeight * 4
        + root.controller.listFooterHeight
        + root.controller.listFramePadding

    ColumnLayout {
        anchors.fill: parent

        // The item actions sit in the first row of the frame, above the list, in a
        // single continuous row: first the two actions that build or edit the
        // selection, then the three that reorder or remove it. All five share the
        // same spacing and no filler stands between them, so the row reads as one
        // group and the width left over stays at its end.
        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                id: addItemButton

                objectName: "addDockItemButton"
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                text: i18nc("@action:button", "Add") // qmllint disable unqualified
                icon.name: "list-add-symbolic"
                display: root.width >= Kirigami.Units.gridUnit * 19
                    ? Controls.AbstractButton.TextBesideIcon
                    : Controls.AbstractButton.IconOnly
                activeFocusOnTab: true
                Accessible.name: i18nc("@action:button", "Add item to Dock") // qmllint disable unqualified
                onClicked: root.addItemRequested()

                Controls.ToolTip.visible: hovered || activeFocus
                // qmllint disable unqualified
                Controls.ToolTip.text: i18nc("@info:tooltip",
                    "Open the item selector to choose what to add to the Dock.")
                // qmllint enable unqualified
            }

            Controls.Button {
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                text: i18n("Configure") // qmllint disable unqualified
                icon.name: "configure-symbolic"
                display: Controls.AbstractButton.TextBesideIcon
                enabled: root.controller.canConfigureSelectedItem()
                onClicked: root.controller.configureSelectedItem()

                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: root.controller.selectedConfigureTitle()
            }

            Controls.Button {
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                icon.name: "go-up-symbolic"
                Accessible.name: i18nc("@action:button", "Move selected item up") // qmllint disable unqualified
                Controls.ToolTip.visible: hovered || activeFocus
                Controls.ToolTip.text: Accessible.name
                enabled: root.controller.selectedIndex > 0
                onClicked: root.controller.moveSelectedItem(-1)
            }

            Controls.Button {
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                icon.name: "go-down-symbolic"
                Accessible.name: i18nc("@action:button", "Move selected item down") // qmllint disable unqualified
                Controls.ToolTip.visible: hovered || activeFocus
                Controls.ToolTip.text: Accessible.name
                enabled: root.controller.selectedIndex >= 0 && root.controller.selectedIndex < root.controller.items.length - 1
                onClicked: root.controller.moveSelectedItem(1)
            }

            Controls.Button {
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                icon.name: "edit-delete-symbolic"
                Accessible.name: i18nc("@action:button", "Remove selected item") // qmllint disable unqualified
                Controls.ToolTip.visible: hovered || activeFocus
                Controls.ToolTip.text: Accessible.name
                enabled: root.controller.selectedIndex >= 0
                onClicked: root.controller.removeSelectedItem()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Controls.TextField {
                id: itemSearch
                objectName: "dockItemSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: i18nc("@info:placeholder", "Search dock items…") // qmllint disable unqualified
                Accessible.name: i18nc("@label", "Search dock items") // qmllint disable unqualified
                onTextChanged: root.rebuildFilteredItems()
            }
            Controls.ToolButton {
                visible: itemSearch.text.length > 0
                icon.name: "edit-clear"
                display: Controls.AbstractButton.IconOnly
                Accessible.name: i18nc("@action:button", "Clear search") // qmllint disable unqualified
                onClicked: itemSearch.clear()
            }
        }

        ListView {
            id: itemList
            objectName: "dockItemList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            activeFocusOnTab: true
            // The page no longer draws a heading for this list, so the name only
            // lives in the accessible tree.
            Accessible.name: i18n("Items in Dock") // qmllint disable unqualified
            model: root.filtering ? filteredItems : root.itemModel
            currentIndex: root.displayedIndexFor(root.controller.selectedIndex)
            boundsBehavior: Flickable.StopAtBounds
            // True ListModel moves keep the row's identity and animate the
            // surrounding items; disabled KDE animations yield zero duration.
            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
            moveDisplaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            // Focus alone is not a selection. Once the user presses a vertical
            // navigation key, however, choose a predictable row and keep the
            // controller (the source of truth for actions and notes) in sync.
            Keys.onPressed: function(event) {
                if (itemList.count <= 0) {
                    return
                }
                if (event.key === Qt.Key_Down) {
                    const nextIndex = root.findVisibleItem(
                        root.controller.selectedIndex < 0 ? 0
                            : root.controller.selectedIndex + 1, 1)
                    if (nextIndex >= 0) root.controller.selectItem(nextIndex)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    const previousIndex = root.findVisibleItem(
                        root.controller.selectedIndex < 0 ? root.itemModel.count - 1
                            : root.controller.selectedIndex - 1, -1)
                    if (previousIndex >= 0) root.controller.selectItem(previousIndex)
                    event.accepted = true
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            Controls.Label {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Kirigami.Units.largeSpacing * 2)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.filtering && filteredItems.count === 0
                text: i18nc("@info:status", "No matching dock items") // qmllint disable unqualified
                opacity: 0.7
            }

            delegate: Controls.ItemDelegate {
                id: itemDelegate

                required property int index
                required property string title
                required property string subtitle
                required property string iconName
                required property int sourceIndex

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                property bool hasVerticalScroll: itemList.contentHeight > itemList.height

                // The row shows only the item identity. The former description
                // column duplicated the name for most types and consumed the
                // width the reserved editor area needs; the subtitle stays
                // available to assistive technology only.
                width: itemList.width
                height: root.controller.listRowHeight
                rightPadding: Kirigami.Units.smallSpacing
                    + (hasVerticalScroll ? root.controller.listScrollGutter : 0)
                text: itemDelegate.title
                Accessible.description: itemDelegate.subtitle
                icon.name: itemDelegate.iconName
                icon.source: root.controller.iconPreviewSource(itemDelegate.iconName)
                highlighted: itemDelegate.sourceIndex === root.controller.selectedIndex
                onClicked: root.controller.selectItem(itemDelegate.sourceIndex)

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onDoubleTapped: {
                        root.controller.selectItem(itemDelegate.sourceIndex)
                        if (root.controller.canConfigureSelectedItem()) {
                            root.controller.configureSelectedItem()
                        }
                    }
                }
            }
        }
    }
}
