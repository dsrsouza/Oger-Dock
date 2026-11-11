pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// The trash has one dock-owned popup. The confirmation is part of its layout:
// it never becomes a second window, never replaces the persistent footer,
// and always keeps the trash files and destructive action in the same context.
FocusScope {
    id: root
    objectName: "trashDockContentsPopup"

    property var trashIntegration: null
    readonly property var entries: trashIntegration ? trashIntegration.trashEntries : []
    readonly property string operationState: trashIntegration
        ? String(trashIntegration.operationState) : "idle"
    readonly property bool operationBusy: operationState === "emptying"
    readonly property bool operationFailed: operationState === "failed"
    readonly property bool operationSucceeded: operationState === "succeeded"

    // Mirrors the actual Plasma popup visibility. Hidden popups must never
    // retain a pending destructive confirmation across a new opening.
    property bool popupActive: false
    property bool confirmationVisible: false
    property bool instantConfirmationReset: false
    property bool emptyAnimationActive: false
    property var fadingEntries: []
    readonly property var displayedEntries: emptyAnimationActive
        ? fadingEntries : (operationSucceeded ? [] : entries)

    // Kirigami units scale with the user's font, DPI and Plasma theme. The
    // extra confirmation space is allocated ABOVE, not OVER, the footer.
    readonly property real confirmationPanelHeight: Math.max(152,
        Math.round(Kirigami.Units.gridUnit * (operationFailed ? 11.0 : 9.2)))
    property real animatedConfirmationHeight: confirmationVisible
        ? confirmationPanelHeight : 0
    Behavior on animatedConfirmationHeight {
        enabled: !root.instantConfirmationReset
        NumberAnimation { duration: 280; easing.type: Easing.InOutCubic }
    }

    signal closeRequested()
    signal openInFileManagerRequested()

    implicitWidth: 320
    // Stable native-window geometry: enlarging a PlasmaQuick Dialog while
    // visible may make it lose focus (and immediately close). Reserve room
    // once and animate solely the content inside this fixed surface.
    implicitHeight: Math.max(400, Math.round(Kirigami.Units.gridUnit * 23))
    // PlasmaQuick may retain the original popup window dimensions unless
    // mainItem.height changes as well as its implicitHeight. This is why the
    // confirmation formerly appeared to do nothing (clipped below the footer).
    width: implicitWidth
    height: implicitHeight

    function resetTransientState() {
        // Called by the owning window on EVERY dismissal (dock click, focus
        // loss, another popup, etc). A pending confirmation is *not* a job.
        confirmationDismissTimer.stop()
        emptyAnimationTimer.stop()
        root.emptyAnimationActive = false
        root.fadingEntries = []
        // Collapse instantly while hidden so reopening cannot display an
        // intermediate confirmation frame from the previous opening.
        root.instantConfirmationReset = true
        root.confirmationVisible = false
        root.instantConfirmationReset = false
        // An already-confirmed KIO job may continue in the background.
        // Never cancel it or clear its running operation state here.
        if (root.trashIntegration && !root.operationBusy)
            root.trashIntegration.resetOperationState()
    }

    onPopupActiveChanged: {
        // Reopening during a job may show job progress, never a stale
        // unconfirmed prompt. After the job finishes while hidden the
        // operation-state handler below returns to the normal list.
        if (root.popupActive && root.operationBusy)
            root.confirmationVisible = true
    }

    function startConfirmation() {
        if (root.operationBusy || root.entries.length === 0) return
        if (root.operationFailed && root.trashIntegration)
            root.trashIntegration.resetOperationState()
        root.confirmationVisible = true
    }

    function cancelConfirmation() {
        if (root.operationBusy) return
        root.confirmationVisible = false
        if (root.operationFailed && root.trashIntegration)
            root.trashIntegration.resetOperationState()
    }

    function confirmEmptying() {
        if (!root.trashIntegration || root.operationBusy) return
        // Keep the last known entries for an actual exit animation. KIO's
        // lister may update the live model before the job reports success.
        const snapshot = []
        for (let index = 0; index < root.entries.length; index++)
            snapshot.push(root.entries[index])
        root.fadingEntries = snapshot
        root.trashIntegration.emptyTrash()
        // Do not hide the confirmation: it is also the progress surface.
    }

    function finishSuccessfulEmptying() {
        root.emptyAnimationActive = root.fadingEntries.length > 0
        if (root.emptyAnimationActive) emptyAnimationTimer.restart()
        confirmationDismissTimer.restart()
    }

    Connections {
        target: root.trashIntegration
        ignoreUnknownSignals: true
        function onOperationStateChanged() {
            // Do not re-open a confirmation or success panel after the popup
            // has been dismissed while KIO was finishing asynchronously.
            if (!root.popupActive) {
                if (!root.operationBusy)
                    root.resetTransientState()
                return
            }
            if (root.operationSucceeded) {
                root.finishSuccessfulEmptying()
            } else if (root.operationFailed) {
                emptyAnimationTimer.stop()
                confirmationDismissTimer.stop()
                root.emptyAnimationActive = false
                root.fadingEntries = []
                root.confirmationVisible = true
            }
        }
    }

    Timer {
        id: emptyAnimationTimer
        interval: 440
        repeat: false
        onTriggered: {
            root.emptyAnimationActive = false
            root.fadingEntries = []
        }
    }
    Timer {
        id: confirmationDismissTimer
        interval: 1450
        repeat: false
        onTriggered: {
            if (!root.operationSucceeded) return
            root.confirmationVisible = false
            // Avoid showing stale entries if the asynchronous dir-lister has
            // not published the empty result yet. The next popup refreshes it.
            if (root.entries.length === 0 && root.trashIntegration)
                root.trashIntegration.resetOperationState()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Kirigami.Units.cornerRadius * 1.6)
        color: Kirigami.Theme.backgroundColor
        border.width: 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: root.operationSucceeded || (root.entries.length === 0
                    && !root.emptyAnimationActive) ? "user-trash" : "user-trash-full"
                rotation: root.emptyAnimationActive ? -9 : 0
                scale: root.emptyAnimationActive ? 1.10 : 1
                Behavior on rotation {
                    NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                }
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Controls.Label {
                Layout.fillWidth: true
                text: i18nc("@title", "Trash")
                font.bold: true
                font.pixelSize: 16
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        Controls.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.displayedEntries.length === 0
            text: i18nc("@info", "Trash is empty")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.operationSucceeded ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }

        ListView {
            id: contents
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.confirmationVisible ? 65 : 105
            visible: root.displayedEntries.length > 0
            clip: true
            spacing: 2
            model: root.displayedEntries
            boundsBehavior: Flickable.StopAtBounds
            opacity: root.emptyAnimationActive ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            delegate: Controls.ItemDelegate {
                id: entry
                required property var modelData
                width: contents.width
                height: Math.max(42, Kirigami.Units.gridUnit * 2.5)
                text: String(modelData.name || "")
                icon.name: String(modelData.icon || "unknown")
                onClicked: {
                    if (root.trashIntegration)
                        root.trashIntegration.openTrashItem(String(modelData.url || ""))
                }
            }
            Controls.ScrollBar.vertical: Controls.ScrollBar { }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Reserve a separate, animated region for confirmation while the
        // original two action buttons remain visible in a fixed footer below.
        Item {
            id: confirmSlot
            objectName: "reaTrashConfirmationSlot"
            Layout.fillWidth: true
            Layout.preferredHeight: root.animatedConfirmationHeight
            clip: true
            // The slot must participate in ColumnLayout on the FIRST frame
            // of confirmation. Using only `height > 0.5` caused a circular
            // visibility/layout dependency: it remained at zero forever.
            visible: root.confirmationVisible || root.animatedConfirmationHeight > 0.5

            Rectangle {
                id: confirmInline
                objectName: "reaTrashInlineConfirmation"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                height: root.confirmationPanelHeight - 2
                radius: Math.max(9, Kirigami.Units.cornerRadius)
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.72)
                opacity: root.confirmationVisible ? 1 : 0
                y: root.confirmationVisible ? 0 : 12
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
                }
                Behavior on y {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 21
                        Layout.preferredHeight: 21
                        source: root.operationSucceeded ? "dialog-ok-symbolic"
                            : (root.operationFailed ? "dialog-error-symbolic"
                                : "dialog-warning-symbolic")
                        color: root.operationSucceeded ? Kirigami.Theme.positiveTextColor
                            : Kirigami.Theme.negativeTextColor
                    }
                    Controls.Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.bold: true
                        text: root.operationBusy
                            ? i18nc("@info", "Emptying the trash…")
                            : root.operationSucceeded
                                ? i18nc("@info", "Trash emptied successfully.")
                                : root.operationFailed
                                    ? i18nc("@info", "Could not empty the trash.")
                                    : i18nc("@info", "Permanently empty the trash?")
                    }
                    Controls.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.82
                        maximumLineCount: root.operationFailed ? 3 : 2
                        elide: Text.ElideRight
                        text: root.operationFailed && root.trashIntegration
                            ? String(root.trashIntegration.errorMessage || "")
                            : root.operationBusy
                                ? i18nc("@info", "Please wait…")
                                : root.operationSucceeded
                                    ? i18nc("@info", "The trash is now empty.")
                                    : i18nc("@info", "This action cannot be undone.")
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        visible: !root.operationSucceeded && !root.operationBusy
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Controls.Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(32, Kirigami.Units.gridUnit * 2)
                            text: i18nc("@action:button", "Cancel")
                            onClicked: root.cancelConfirmation()
                        }
                        Controls.Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(32, Kirigami.Units.gridUnit * 2)
                            text: root.operationFailed
                                ? i18nc("@action:button", "Try again")
                                : i18nc("@action:button", "Empty")
                            icon.name: root.operationFailed ? "view-refresh" : "edit-delete"
                            onClicked: root.confirmEmptying()
                        }
                    }
                    Controls.BusyIndicator {
                        visible: root.operationBusy
                        running: visible
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                    }
                }
            }
        }

        Item {
            id: trashActionFooter
            objectName: "reaTrashFooter"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(56, Kirigami.Units.gridUnit * 3.1)
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Controls.Button {
                    id: emptyTrashAction
                    objectName: "reaEmptyTrashIconButton"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    enabled: root.entries.length > 0 && root.trashIntegration
                        && !root.operationBusy && !root.confirmationVisible
                    Accessible.name: i18nc("@action:button", "Empty trash")
                    background: Rectangle {
                        radius: 9
                        color: Qt.alpha(Kirigami.Theme.negativeTextColor,
                            emptyTrashAction.hovered ? 0.20 : 0.075)
                        border.width: 1
                        border.color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.65)
                    }
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing / 2
                        Kirigami.Icon {
                            source: root.entries.length ? "user-trash-full" : "user-trash"
                            color: Kirigami.Theme.negativeTextColor
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 23
                            Layout.preferredHeight: 23
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: i18nc("@action:button", "Empty")
                            color: Kirigami.Theme.textColor
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    onClicked: {
                        if (!root.confirmationVisible && !root.operationBusy)
                            root.startConfirmation()
                    }
                }

                Controls.Button {
                    id: openTrashFolderAction
                    objectName: "reaOpenTrashFolderButton"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    enabled: !root.operationBusy && !root.confirmationVisible
                    Accessible.name: i18nc("@action:button", "Open in Dolphin")
                    background: Rectangle {
                        radius: 9
                        color: Qt.alpha(Kirigami.Theme.highlightColor,
                            openTrashFolderAction.hovered ? 0.19 : 0.075)
                        border.width: 1
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.65)
                    }
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing / 2
                        Kirigami.Icon {
                            source: "folder-open"
                            color: Kirigami.Theme.highlightColor
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 23
                            Layout.preferredHeight: 23
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: i18nc("@action:button", "Dolphin")
                            color: Kirigami.Theme.textColor
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    onClicked: {
                        if (!root.confirmationVisible && !root.operationBusy)
                            root.openInFileManagerRequested()
                    }
                }
            }
        }
    }
}
