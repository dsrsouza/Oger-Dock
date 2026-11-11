// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import ".."
import "../code/adaptiveDialogSizing.js" as DialogSizing

// Thin wrapper of `ControlCenterOptionsPanel`.
//
// The panel owns the layout, the list of modes and their texts; this dialog keeps
// only what makes it a dialog—title, modality, close button and size—plus the
// public API it already had, so every existing caller keeps working. It forwards
// what the panel announces and updates its own state, and writes nothing else.
//
// Translation helpers are supplied by the KCM context.
// qmllint disable unqualified
Controls.Dialog {
    id: root

    objectName: "controlCenterConfigDialog"

    // Public API kept as it was: the panel owns the value it shows, so this
    // wrapper only mirrors it and announces what the user asked for.
    property string controlCenterMode: "floating"
    property real selectorWidth: Kirigami.Units.gridUnit * 16
    readonly property alias modeOptions: optionsPanel.modeOptions

    signal controlCenterModeSelected(string mode)

    function modeIndex(mode) {
        return optionsPanel.modeIndex(mode)
    }

    function synchronizeModeSelection() {
        optionsPanel.synchronizeSelection()
    }

    title: i18nc("@title:window", "Configure Control Center")
    modal: true
    standardButtons: Controls.Dialog.Close
    // R50: fit the actual options panel and cap at the available KCM area.
    // The dialog is not manually resizable; the form scrolls when it grows.
    // R52: all settings dialogs size from the actual options panel. Removing
    // the former 42-unit ceiling lets future fields expand the natural width;
    // the host KCM viewport is still the absolute maximum.
    readonly property real requiredFormWidth: DialogSizing.preferredFormWidth(
        [optionsPanel.implicitWidth], Kirigami.Units.gridUnit * 4,
        Kirigami.Units.gridUnit * 30)
    implicitWidth: DialogSizing.kdePreferredWidth(root.requiredFormWidth,
        parent ? parent.width : 0, Kirigami.Units.largeSpacing,
        Kirigami.Units.gridUnit * 43, Kirigami.Units.gridUnit * 43)
    readonly property real requiredFormHeight: Math.max(0, optionsPanel.implicitHeight) + (
(root.header ? root.header.implicitHeight : Kirigami.Units.gridUnit * 2)
            + (root.footer ? root.footer.implicitHeight : Kirigami.Units.gridUnit * 3)
            + root.topPadding + root.bottomPadding + Kirigami.Units.gridUnit)
    implicitHeight: DialogSizing.boundedHeight(
        root.requiredFormHeight, 0,
        parent ? parent.height : 0, Kirigami.Units.gridUnit,
        Kirigami.Units.gridUnit * 33, Kirigami.Units.gridUnit * 11)
    width: implicitWidth
    height: implicitHeight
    x: parent ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent ? Math.max(0, Math.round((parent.height - height) / 2)) : 0

    // A value set from outside is the state of the dialog, never a choice of the
    // user: showing it again must not announce an intention.
    onOpened: optionsPanel.synchronizeSelection()

    contentItem: Controls.ScrollView {
        id: optionsScroll
        clip: true
        contentWidth: availableWidth
        implicitWidth: optionsPanel.implicitWidth
        implicitHeight: optionsPanel.implicitHeight
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        ControlCenterOptionsPanel {
            id: optionsPanel
            width: optionsScroll.contentWidth

        controlCenterMode: root.controlCenterMode
        selectorWidth: root.selectorWidth
        onControlCenterModeSelected: function(mode) {
            root.controlCenterMode = String(mode)
            root.controlCenterModeSelected(root.controlCenterMode)
        }
        }
    }
}
// qmllint enable unqualified
