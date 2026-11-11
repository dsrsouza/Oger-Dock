import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import ".."
import "../code/adaptiveDialogSizing.js" as DialogSizing

// Thin wrapper of `TrashOptionsPanel`.
//
// The panel owns the layout, the controls and their texts; this dialog keeps only
// what makes it a dialog—title, modality and its close button—plus the public API it
// already had, so every existing caller and the form helpers that read it keep
// working. It resolves with the page controller the two values the panel shows as
// names and forwards what the panel announces; it writes nothing else.
//
// Translation helpers are supplied by the KCM context.
// qmllint disable unqualified
Controls.Dialog {
    id: root

    // Page the dialog reads its context from: the selected type gates the form and
    // the sounds are shown with the name its helper resolves. It is not handed to
    // the panel, which receives plain values and stays passive.
    property var controller

    property alias nameText: optionsPanel.nameText
    property alias emptyIconText: optionsPanel.emptyIconText
    property alias fullIconText: optionsPanel.fullIconText
    property alias showStateChecked: optionsPanel.showStateChecked
    property alias acceptDropsChecked: optionsPanel.acceptDropsChecked
    property alias soundPath: optionsPanel.soundPath

    signal formChanged()
    signal emptyIconPickerRequested()
    signal fullIconPickerRequested()
    signal soundPreviewRequested()
    signal soundResetRequested()
    signal soundPickerRequested()

    function hasController() {
        return root.controller !== undefined && root.controller !== null
    }

    function defaultSoundPath() {
        return root.hasController()
            ? String(root.controller.defaultTrashEmptySound || "") : ""
    }

    function resolvedSoundName(path) {
        return root.hasController()
            ? String(root.controller.fileName(path)) : String(path)
    }

    function selectedTypeIsTrash() {
        return root.hasController()
            && String(root.controller.selectedItemType) === "trash"
    }

    // A sound that was cleared falls back to the one a new element ships with, and
    // the same default is what the dialog starts with. The rule lives here because
    // this wrapper is the one that knows the default.
    onSoundPathChanged: {
        if (root.soundPath.length === 0 && root.defaultSoundPath().length > 0) {
            root.soundPath = root.defaultSoundPath()
        }
    }
    Component.onCompleted: {
        if (root.soundPath.length === 0) {
            root.soundPath = root.defaultSoundPath()
        }
    }

    modal: true
    title: i18n("Configure trash")
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
        Kirigami.Units.gridUnit * 43, Kirigami.Units.gridUnit * 14)
    width: implicitWidth
    height: implicitHeight
    x: parent ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent ? Math.max(0, Math.round((parent.height - height) / 2)) : 0


    contentItem: Controls.ScrollView {
        id: optionsScroll
        clip: true
        contentWidth: availableWidth
        implicitWidth: optionsPanel.implicitWidth
        implicitHeight: optionsPanel.implicitHeight
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        TrashOptionsPanel {
            id: optionsPanel
            width: optionsScroll.contentWidth

        objectName: "trashOptionsPanel"

        editable: root.selectedTypeIsTrash()
        soundFileName: root.resolvedSoundName(root.soundPath)
        defaultSoundFileName: root.resolvedSoundName(root.defaultSoundPath())
        onFormChanged: root.formChanged()
        onEmptyIconPickerRequested: root.emptyIconPickerRequested()
        onFullIconPickerRequested: root.fullIconPickerRequested()
        onSoundPreviewRequested: root.soundPreviewRequested()
        onSoundResetRequested: root.soundResetRequested()
        onSoundPickerRequested: root.soundPickerRequested()
        }
    }
}
// qmllint enable unqualified
