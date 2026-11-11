// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import ".."
import "../code/adaptiveDialogSizing.js" as DialogSizing

// Thin wrapper of `TimedOptionsPanel`.
//
// The panel owns the layout, the controls and their texts; this dialog keeps only
// what makes it a dialog—title, modality, size and close button—plus the public API
// it already had, so the page and its form helper keep working without changes. It
// reads from the page the type being configured and whether it is being synchronized,
// forwards what the panel announces and opens the colour dialog the panel only
// requests; it writes nothing else.
//
// The four colour controls of `calendarBackgroundColor`, `calendarAccentColor`,
// `calendarBorderColor` and `calendarRadius` are kept as they were: they resolve to
// null today, because nothing in the calendar or clock flow ever asks for another
// target, and the page still declares aliases to them. Removing them would change
// the public surface of this wrapper, so this session preserves them.
//
Controls.Dialog {
    id: timedDialog

    property var controller
    property alias itemNameControl: optionsPanel.itemNameControl
    property alias timedItemWidthControl: optionsPanel.timedItemWidthControl
    property alias timedTextScaleControl: optionsPanel.timedTextScaleControl
    property alias calendarItemHeightControl: optionsPanel.calendarItemHeightControl
    property alias calendarFormatControl: optionsPanel.calendarFormatControl
    property alias calendarTimeTextScaleControl:
        optionsPanel.calendarTimeTextScaleControl
    property alias calendarDateTextScaleControl:
        optionsPanel.calendarDateTextScaleControl
    property alias calendarTextShadowsControl: optionsPanel.calendarTextShadowsControl
    property alias calendarShowWeekNumbersControl:
        optionsPanel.calendarShowWeekNumbersControl
    property alias calendarPopupScaleControl: optionsPanel.calendarPopupScaleControl
    property alias calendarTextColorControl: optionsPanel.calendarTextColorControl
    property var calendarBackgroundColorControl: null
    property var calendarAccentColorControl: null
    property var calendarBorderColorControl: null
    property var calendarRadiusControl: null

    function hasController() {
        return timedDialog.controller !== undefined && timedDialog.controller !== null
    }

    function selectedType() {
        return timedDialog.hasController()
            ? String(timedDialog.controller.selectedItemType) : "calendar"
    }

    function selectedItemIsEditable() {
        return timedDialog.hasController()
            && Number(timedDialog.controller.selectedIndex) >= 0
    }

    // The page sets its own flag while it fills the form: the panel must not read a
    // synchronization as an edit of the user.
    function isSynchronizing() {
        return timedDialog.hasController()
            && timedDialog.controller.syncing === true
    }

    modal: true
    title: timedDialog.hasController()
        ? String(timedDialog.controller.selectedConfigureTitle())
        : ""
    standardButtons: Controls.Dialog.Close
    // R50: fit the actual options panel and cap at the available KCM area.
    // The dialog is not manually resizable; the form scrolls when it grows.
    // R52: all settings dialogs size from the actual options panel. Removing
    // the former 42-unit ceiling lets future fields expand the natural width;
    // the host KCM viewport is still the absolute maximum.
    readonly property real requiredFormWidth: DialogSizing.preferredFormWidth(
        [optionsPanel.implicitWidth], Kirigami.Units.gridUnit * 4,
        Kirigami.Units.gridUnit * 30)
    implicitWidth: DialogSizing.kdePreferredWidth(timedDialog.requiredFormWidth,
        parent ? parent.width : 0, Kirigami.Units.largeSpacing,
        Kirigami.Units.gridUnit * 43, Kirigami.Units.gridUnit * 43)
    readonly property real requiredFormHeight: Math.max(0, optionsPanel.implicitHeight) + (
(timedDialog.header ? timedDialog.header.implicitHeight : Kirigami.Units.gridUnit * 2)
            + (timedDialog.footer ? timedDialog.footer.implicitHeight : Kirigami.Units.gridUnit * 3)
            + timedDialog.topPadding + timedDialog.bottomPadding + Kirigami.Units.gridUnit)
    implicitHeight: DialogSizing.boundedHeight(
        timedDialog.requiredFormHeight, 0,
        parent ? parent.height : 0, Kirigami.Units.gridUnit,
        Kirigami.Units.gridUnit * 44, Kirigami.Units.gridUnit * 14)
    width: implicitWidth
    height: implicitHeight
    x: parent ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent ? Math.max(0, Math.round((parent.height - height) / 2)) : 0

    contentItem: Controls.ScrollView {
        id: optionsScroll
        clip: true
        implicitWidth: optionsPanel.implicitWidth
        implicitHeight: optionsPanel.implicitHeight
        contentWidth: availableWidth
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        TimedOptionsPanel {
            id: optionsPanel
            width: optionsScroll.contentWidth

        objectName: "timedOptionsPanel"

        selectedItemType: timedDialog.selectedType()
        editable: timedDialog.selectedItemIsEditable()
        syncingValues: timedDialog.isSynchronizing()
        onFormChanged: {
            if (timedDialog.hasController()) {
                timedDialog.controller.applyItemForm()
            }
        }
        onColorRequested: function(target) {
            if (timedDialog.hasController()) {
                timedDialog.controller.openTimedColorDialog(String(target))
            }
        }
        }
    }
}
