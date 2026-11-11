import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import ".."
import "../code/adaptiveDialogSizing.js" as DialogSizing

// Thin wrapper of `MediaPlayerOptionsPanel`.
//
// The panel owns the layout, the list of options it shows and the rules that
// compose it; this dialog keeps only what makes it a dialog—modality and its close
// button, plus the title the page gives it—and the public API it already had, so
// every existing caller keeps working. It updates its own state with what the panel
// announces and forwards it; it writes nothing else.
//
Controls.Dialog {
    id: root

    property var applications: []
    property string selectedStorageId: ""
    property string mediaTextMode: "automatic"
    property string mediaDisplayMode: "normal"
    property bool openPlayerMinimized: false
    property int autoCollapseDelaySeconds: 3
    property string mediaIdleVisibility: "sound"
    property int mediaSoundShowDelayMs: 650
    property int mediaSoundHideDelayMs: 4000
    property string mediaEntranceAnimation: "fade"
    property string mediaBackgroundStyle: "artwork"
    property bool mediaShowCover: true
    property bool mediaShowTitle: true
    property bool mediaShowControls: true
    property bool mediaShowProgress: true
    property bool mediaShowVolume: true
    property real selectorWidth: Kirigami.Units.gridUnit * 16
    property alias playerOptions: optionsPanel.playerOptions
    readonly property alias textModeOptions: optionsPanel.textModeOptions
    readonly property alias displayModeOptions: optionsPanel.displayModeOptions

    signal playerSelected(var application)
    signal mediaTextModeSelected(string mode)
    signal mediaDisplayModeSelected(string mode)
    signal openPlayerMinimizedSelected(bool enabled)
    signal autoCollapseDelaySecondsSelected(int seconds)
    signal mediaCustomOptionSelected(string key, var value)

    // The dialog keeps these helpers because they were part of its API; the work
    // belongs to the panel, so no rule is repeated here.
    function rebuildOptions() {
        optionsPanel.rebuildOptions()
    }

    function syncSelection() {
        optionsPanel.syncSelection()
    }

    function syncTextModeSelection() {
        optionsPanel.syncTextModeSelection()
    }

    function syncDisplayModeSelection() {
        optionsPanel.syncDisplayModeSelection()
    }

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
        Kirigami.Units.gridUnit * 44, Kirigami.Units.gridUnit * 15)
    width: implicitWidth
    height: implicitHeight
    x: parent ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent ? Math.max(0, Math.round((parent.height - height) / 2)) : 0

    contentItem: Controls.ScrollView {
        id: mediaOptionsScroll
        clip: true
        implicitHeight: optionsPanel.implicitHeight
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        implicitWidth: optionsPanel.implicitWidth
        contentWidth: availableWidth
        MediaPlayerOptionsPanel {
        id: optionsPanel
        width: mediaOptionsScroll.contentWidth

        applications: root.applications
        selectedStorageId: root.selectedStorageId
        mediaTextMode: root.mediaTextMode
        mediaDisplayMode: root.mediaDisplayMode
        openPlayerMinimized: root.openPlayerMinimized
        autoCollapseDelaySeconds: root.autoCollapseDelaySeconds
        mediaIdleVisibility: root.mediaIdleVisibility
        mediaSoundShowDelayMs: root.mediaSoundShowDelayMs
        mediaSoundHideDelayMs: root.mediaSoundHideDelayMs
        mediaEntranceAnimation: root.mediaEntranceAnimation
        mediaBackgroundStyle: root.mediaBackgroundStyle
        mediaShowCover: root.mediaShowCover
        mediaShowTitle: root.mediaShowTitle
        mediaShowControls: root.mediaShowControls
        mediaShowProgress: root.mediaShowProgress
        mediaShowVolume: root.mediaShowVolume
        onMediaCustomOptionSelected: function(key, value) {
            root.mediaCustomOptionSelected(key, value)
        }
        selectorWidth: root.selectorWidth
        // Choosing a player also moves the shown selection, exactly as it did
        // before: the value belongs to the dialog and the panel only announces.
        onPlayerSelected: function(application) {
            const selected = application || ({})
            root.selectedStorageId = String(selected.storageId || "")
            root.playerSelected(application)
        }
        onMediaTextModeSelected: function(mode) {
            root.mediaTextModeSelected(String(mode))
        }
        onMediaDisplayModeSelected: function(mode) {
            root.mediaDisplayModeSelected(String(mode))
        }
        onOpenPlayerMinimizedSelected: function(enabled) {
            root.openPlayerMinimizedSelected(Boolean(enabled))
        }
        onAutoCollapseDelaySecondsSelected: function(seconds) {
            root.autoCollapseDelaySecondsSelected(Number(seconds))
        }
        }
    }
}
