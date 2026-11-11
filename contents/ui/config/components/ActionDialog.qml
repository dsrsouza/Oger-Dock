import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import ".."
import "../code/adaptiveDialogSizing.js" as DialogSizing


Controls.Dialog {
    id: root

    property var actionModel
    property int selectedActionIndex: -1
    property int selectedItemIndex: -1
    property string selectedItemType: "app"
    property real rowHeight: Kirigami.Units.gridUnit * 2.4
    property real footerHeight: Kirigami.Units.gridUnit * 2.4
    property real framePadding: Kirigami.Units.largeSpacing * 2
    property real scrollGutter: Kirigami.Units.gridUnit * 1.6
    property bool canMoveActionDown: false
    property alias appNameText: itemEditor.appNameText
    property alias appAliasText: itemEditor.appAliasText
    property alias appDescriptionText: itemEditor.appDescriptionText
    property alias appIconText: itemEditor.appIconText
    property alias appCommandText: itemEditor.appCommandText
    property string appStorageId: ""
    property string appApplicationId: ""
    readonly property string itemModeValue: itemEditor.itemModeValue
    property alias itemModeIndex: itemEditor.itemModeIndex
    readonly property string containerLayoutValue: itemEditor.containerLayoutValue
    property alias containerLayoutIndex: itemEditor.containerLayoutIndex
    property alias actionsEnabledChecked: actionEditor.actionsEnabledChecked
    property alias actionPopupLimitRowsChecked: actionEditor.actionPopupLimitRowsChecked
    property alias actionPopupMaxVisibleRowsValue: actionEditor.actionPopupMaxVisibleRowsValue
    property alias actionNameText: actionEditor.actionNameText
    property alias actionIconText: actionEditor.actionIconText
    property alias actionCommandText: actionEditor.actionCommandText
    property alias spacerSizeValue: itemEditor.spacerSizeValue
    readonly property string separatorAppearanceSourceValue:
        itemEditor.separatorAppearanceSourceValue
    readonly property string separatorStyleValue: itemEditor.separatorStyleValue
    readonly property real separatorThicknessValue: itemEditor.separatorThicknessValue
    readonly property real separatorLengthRatioValue: itemEditor.separatorLengthRatioValue
    readonly property real separatorOpacityValue: itemEditor.separatorOpacityValue
    readonly property bool separatorGlowEnabled: itemEditor.separatorGlowEnabled
    readonly property bool separatorVisibleChecked:
        itemEditor.separatorVisibleChecked
    readonly property string containerSourceValue: itemEditor.containerSourceValue
    property alias containerSourceIndex: itemEditor.containerSourceIndex
    property alias containerPathText: itemEditor.containerPathText
    property alias folderAccentColorText: itemEditor.folderAccentColorText
    property alias containerBrowseSubfoldersChecked: itemEditor.containerBrowseSubfoldersChecked
    readonly property string containerCategoryValue: itemEditor.containerCategoryValue
    property alias containerCategoryIndex: itemEditor.containerCategoryIndex
    property int actionCount: actionEditor.actionCount
    readonly property bool applicationLauncherDropEnabled:
        root.selectedItemType === "folder"
        && root.containerSourceValue === "manual"
    property var applicationLauncherDropValidator: null
    property alias applicationLauncherDropMessage:
        actionEditor.applicationLauncherDropMessage
    property alias applicationLauncherDropMessageIsError:
        actionEditor.applicationLauncherDropMessageIsError

    property string nameLabel: "Name:"
    property string aliasLabel: "Alias:"
    property string descLabel: "Description:"
    property string aliasPlaceholder: "Type name or alias... then search"
    property string itemTypeLabel: "Type:"
    property string launchAppText: "Launch app"
    property string containerText: "Container"
    property string viewLabel: "View:"
    property string gridText: "Grid"
    property string listText: "List"
    property string detailedText: "Detailed"
    property string fanText: i18nc("@item:inlistbox Folder popup layout", "Fan") // qmllint disable unqualified
    property string noteText: "Note"
    property string separatorText: "Separator"
    property string spacerText: "Spacer"
    property string containerSourceLabel: "Content:"
    property string manualContainerText: "Manual"
    property string folderContainerText: "Folder"
    property string categoryContainerText: "Application category"
    property string folderPathLabel: "Folder:"
    property string categoryLabel: "Category:"
    property string refreshContentText: "Load content"
    property string iconLabel: "Icon:"
    property string commandLabel: "Command:"
    property string spacerSizeLabel: "Spacer size:"
    property string chooseIconText: "Choose icon"
    property string rightClickCommandsText: "Right-click commands"
    property string containerApplicationsText: "Container applications"
    property string enableRightClickMenuText: "Enable right-click menu"
    property string limitContextMenuRowsText: "Limit menu rows"
    property string rowsText: i18n("rows") // qmllint disable unqualified
    property string rowsValueText: i18n("%1 rows", "%1") // qmllint disable unqualified
    property string actionNameLabel: "Action name:"
    property string actionIconLabel: "Action icon:"
    property string actionCommandLabel: "Action command:"
    property string dropApplicationsHereText: "Drop applications here"
    property string addApplicationText: "Add application"
    property string addActionText: "Add action"

    signal formChanged()
    signal itemModeChanged(string mode)
    signal containerLayoutChanged(string layout)
    signal containerSourceChanged(string source)
    signal containerCategoryChanged(string category)
    signal folderPickerRequested()
    signal containerRefreshRequested()
    signal appCommandEdited()
    signal autofillRequested(string alias)
    signal iconPickerRequested(string target)
    signal actionsEnabledToggled(bool checked)
    signal actionPopupSettingsChanged()
    signal actionSelected(int index)
    signal addActionRequested()
    signal applicationCatalogRequested()
    signal browseApplicationsRequested()
    signal moveActionRequested(int delta)
    signal removeActionRequested()
    signal actionFormChanged()
    signal applicationLauncherDropped(var urls)

    function positionActionAtIndex(index) {
        actionEditor.positionActionAtIndex(index)
    }

    function sourceIndexFor(value) {
        return itemEditor.sourceIndexFor(value)
    }

    function categoryIndexFor(value) {
        return itemEditor.categoryIndexFor(value)
    }

    function layoutIndexFor(value) {
        return itemEditor.layoutIndexFor(value)
    }

    function setSeparatorStyleValue(value) {
        itemEditor.setSeparatorStyleValue(value)
    }

    function setSeparatorAppearanceSourceValue(value) {
        itemEditor.setSeparatorAppearanceSourceValue(value)
    }

    function setSeparatorThicknessValue(value) {
        itemEditor.setSeparatorThicknessValue(value)
    }

    function setSeparatorLengthRatioValue(value) {
        itemEditor.setSeparatorLengthRatioValue(value)
    }

    function setSeparatorOpacityValue(value) {
        itemEditor.setSeparatorOpacityValue(value)
    }

    function setSeparatorGlowEnabled(enabled) {
        itemEditor.setSeparatorGlowEnabled(enabled)
    }

    function setSeparatorVisibleChecked(visible) {
        itemEditor.setSeparatorVisibleChecked(visible)
    }

    function iconPreview(value, fallback) {
        var text = String(value || "")
        return text.length > 0 ? text : fallback
    }

    // R59: consistent breathing room; no clipping at the dialog border.
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    modal: true
    standardButtons: Controls.Dialog.Close
    // R52: real visible content, not the saved item's type, owns the width.
    // Both editors expose intrinsic hints without referring to ScrollView.width,
    // so bindings cannot loop through the ListView delegate widths.
    readonly property real unifiedLabelWidth: Math.max(
        Kirigami.Units.gridUnit * 8, itemEditor.longestVisibleLabel(),
        actionEditor.intrinsicLabelWidth)
    readonly property real requiredFormWidth: DialogSizing.preferredFormWidth([
        itemEditor.preferredFormWidth,
        actionEditor.preferredFormWidth
    ], root.leftPadding + root.rightPadding + Kirigami.Units.gridUnit,
        Kirigami.Units.gridUnit * 30)
    // Match the KDE FormLayout dialog sizing contract: a preferred width is
    // useful, but long application descriptions are elided in their rows.
    // Never force the containing KCM to grow to the full text width.
    implicitWidth: DialogSizing.kdePreferredWidth(root.requiredFormWidth,
        parent ? parent.width : 0, Kirigami.Units.largeSpacing,
        Kirigami.Units.gridUnit * 43, Kirigami.Units.gridUnit * 43)
    readonly property real requiredFormHeight: Math.max(0, actionContent.implicitHeight) + (
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
    onOpened: {
        root.applicationLauncherDropMessage = ""
        root.applicationLauncherDropMessageIsError = false
    }

    contentItem: Controls.ScrollView {
        id: optionsScroll
        clip: true
        implicitWidth: root.requiredFormWidth - root.leftPadding
            - root.rightPadding
        implicitHeight: actionContent.implicitHeight
        // Keep complete rows accessible when the containing KCM is narrower
        // than the editor's natural width (instead of clipping fields).
        // The viewport is authoritative. A large list must not create a second
        // horizontal coordinate system unrelated to the dialog's visible width.
        contentWidth: availableWidth
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        ColumnLayout {
            id: actionContent
            width: optionsScroll.contentWidth
            spacing: Kirigami.Units.smallSpacing

        ItemEditorPanel {
            id: itemEditor
            sharedLabelWidth: root.unifiedLabelWidth
            selectedItemType: root.selectedItemType
            nameLabel: root.nameLabel
            aliasLabel: root.aliasLabel
            descLabel: root.descLabel
            aliasPlaceholder: root.aliasPlaceholder
            itemTypeLabel: root.itemTypeLabel
            launchAppText: root.launchAppText
            containerText: root.containerText
            viewLabel: root.viewLabel
            gridText: root.gridText
            listText: root.listText
            detailedText: root.detailedText
            fanText: root.fanText
            noteText: root.noteText
            separatorText: root.separatorText
            spacerText: root.spacerText
            containerSourceLabel: root.containerSourceLabel
            manualContainerText: root.manualContainerText
            folderContainerText: root.folderContainerText
            categoryContainerText: root.categoryContainerText
            folderPathLabel: root.folderPathLabel
            categoryLabel: root.categoryLabel
            refreshContentText: root.refreshContentText
            iconLabel: root.iconLabel
            commandLabel: root.commandLabel
            spacerSizeLabel: root.spacerSizeLabel
            chooseIconText: root.chooseIconText
            onFormChanged: root.formChanged()
            onItemModeChanged: function(mode) { root.itemModeChanged(mode) }
            onContainerLayoutChanged: function(layout) { root.containerLayoutChanged(layout) }
            onContainerSourceChanged: function(source) { root.containerSourceChanged(source) }
            onContainerCategoryChanged: function(category) { root.containerCategoryChanged(category) }
            onFolderPickerRequested: root.folderPickerRequested()
            onContainerRefreshRequested: root.containerRefreshRequested()
            onAppCommandEdited: root.appCommandEdited()
            onAutofillRequested: function(alias) { root.autofillRequested(alias) }
            onIconPickerRequested: function(target) { root.iconPickerRequested(target) }
            onBrowseApplicationsRequested: root.browseApplicationsRequested()
        }

        ItemActionEditor {
            id: actionEditor
            sharedLabelWidth: root.unifiedLabelWidth
            Layout.fillWidth: true
            actionModel: root.actionModel
            selectedActionIndex: root.selectedActionIndex
            selectedItemIndex: root.selectedItemIndex
            selectedItemType: root.selectedItemType
            itemModeValue: root.itemModeValue
            appIconText: root.appIconText
            rowHeight: root.rowHeight
            footerHeight: root.footerHeight
            framePadding: root.framePadding
            scrollGutter: root.scrollGutter
            canMoveActionDown: root.canMoveActionDown
            applicationLauncherDropEnabled:
                root.applicationLauncherDropEnabled
            applicationLauncherDropValidator:
                root.applicationLauncherDropValidator
            rightClickCommandsText: root.rightClickCommandsText
            containerApplicationsText: root.containerApplicationsText
            enableRightClickMenuText: root.enableRightClickMenuText
            limitContextMenuRowsText: root.limitContextMenuRowsText
            rowsText: root.rowsText
            rowsValueText: root.rowsValueText
            actionNameLabel: root.actionNameLabel
            actionIconLabel: root.actionIconLabel
            actionCommandLabel: root.actionCommandLabel
            chooseIconText: root.chooseIconText
            dropApplicationsHereText: root.dropApplicationsHereText
            addApplicationText: root.addApplicationText
            addActionText: root.addActionText
            onActionsEnabledToggled: function(checked) { root.actionsEnabledToggled(checked) }
            onActionPopupSettingsChanged: root.actionPopupSettingsChanged()
            onActionSelected: function(index) { root.actionSelected(index) }
            onAddActionRequested: root.addActionRequested()
            onBrowseApplicationsRequested: root.applicationCatalogRequested()
            onMoveActionRequested: function(delta) { root.moveActionRequested(delta) }
            onRemoveActionRequested: root.removeActionRequested()
            onActionFormChanged: root.actionFormChanged()
            onIconPickerRequested: function(target) { root.iconPickerRequested(target) }
            onApplicationLauncherDropped: function(urls) {
                root.applicationLauncherDropped(urls)
            }
        }

        }
    }
}
