import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "../org/punchi/dock" as Punchi
import "components"

KCM.SimpleKCM {
    id: page

    // R62.6: immediate category switch; do not animate the entire KCM.
    // Whole-page transforms cannot shorten control creation and cost frames.

    // R58.1: only this applet's configuration pages request maximized mode.
    // The KDE-owned window still handles its own close/minimize/Save dialog.
    ConfigMaximizedWindowGuard {
        hostWindow: page.Window.window
        diagnosticCategory: "Aparência"
    }
    implicitWidth: layoutMetrics.pageImplicitWidth

    Punchi.PopupAppearanceDefaults {
        applet: Plasmoid
    }

    signal configurationChanged()

    ConfigLayoutMetrics {
        id: layoutMetrics
        availableWidth: page.width
    }

    QtObject {
        id: dockTextShadowPreference

        property bool value: true
    }

    property alias cfg_showLabels: showLabelsCheck.checked
    property alias cfg_dockTextShadowsEnabled: dockTextShadowPreference.value
    property alias cfg_showItemHoverBackground: showItemHoverBackgroundCheck.checked
    property alias cfg_iconReflectionsEnabled: iconReflectionsCheck.checked
    property alias cfg_iconReflectionOpacity: iconReflectionOpacitySlider.value
    property string cfg_indicatorType: "line"
    property string cfg_indicatorPosition: "bottom"
    property string cfg_indicatorColor: ""
    property alias cfg_showWindowCountBadge: showWindowCountBadgeCheck.checked
    property string cfg_windowCountBadgePosition: "top-right"
    property string cfg_windowCountEmblemColor: ""
    property alias cfg_windowCountEmblemOpacityPercent: windowCountEmblemOpacitySlider.value
    property alias cfg_windowCountEmblemScalePercent: windowCountEmblemScaleSlider.value
    property alias cfg_indicatorOpacity: indicatorOpacitySlider.value
    property alias cfg_indicatorThickness: indicatorThicknessSlider.value
    property alias cfg_indicatorNeonEnabled: indicatorNeonCheck.checked
    property alias cfg_indicatorNeonIntensity: indicatorNeonIntensitySlider.value
    property string cfg_dockThemeMode: "plasma"
    property string cfg_dockThemeCustomId: ""
    property bool cfg_dockCustomThemeDirectoryEnabled: false
    property string cfg_dockCustomThemeDirectory: ""
    property string cfg_floatingDockOrientation: "bottom"

    property var lastThemeDirectoryImport: ({})
    property string themeRemovalMessage: ""
    property bool themeRemovalFailed: false
    property var pendingThemeRemoval: ({})
    property bool themeRemovalAwaitingRefresh: false

    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool iconReflectionsSupported: !inPanel || horizontalPanel
    readonly property bool indicatorPositionApplicable: cfg_indicatorType !== "none"
    readonly property string effectiveIndicatorColor: {
        const value = String(cfg_indicatorColor || "").trim()
        return /^#[0-9a-fA-F]{6}$/.test(value) ? value : ""
    }
    readonly property string effectiveWindowCountEmblemColor: {
        const value = String(cfg_windowCountEmblemColor || "").trim()
        return /^#[0-9a-fA-F]{6}$/.test(value) ? value : ""
    }
    readonly property int contentWidthHint: layoutMetrics.contentWidth
    readonly property int selectorWidthHint: layoutMetrics.selectorWidth
    // qmllint disable unqualified
    readonly property var indicatorTypeOptions: [
        { "text": i18n("Line"), "value": "line" },
        { "text": i18n("Dot"), "value": "dot" },
        { "text": i18n("Small ring"), "value": "ring" },
        { "text": i18n("Rounded square"), "value": "square" },
        { "text": i18n("None"), "value": "none" }
    ]
    readonly property var indicatorPositionOptions: [
        { "text": i18nc("Indicator position", "Bottom"), "value": "bottom" },
        { "text": i18nc("Indicator position", "Top"), "value": "top" }
    ]
    readonly property var windowCountBadgePositionOptions: [
        { "text": i18n("Top left"), "value": "top-left" },
        { "text": i18n("Top right"), "value": "top-right" },
        { "text": i18n("Bottom left"), "value": "bottom-left" },
        { "text": i18n("Bottom right"), "value": "bottom-right" },
        { "text": i18n("Center"), "value": "center" }
    ]
    // qmllint enable unqualified

    readonly property var dockThemeModeOptions: [
        { "text": i18n("Plasma theme"), "value": "plasma" }, // qmllint disable unqualified
        { "text": i18n("External JSON theme"), "value": "custom" } // qmllint disable unqualified
    ]
    // R17: three explicit placements. The top screen edge is unsupported.
    readonly property var floatingDockOrientationOptions: [
        { "text": i18n("Inferior (horizontal)"), "value": "bottom" },
        { "text": i18n("Esquerda (vertical)"), "value": "left" },
        { "text": i18n("Direita (vertical)"), "value": "right" }
    ]

    component SectionTitle: Kirigami.Heading {
        Layout.fillWidth: true
        level: 3
        leftPadding: 0
    }

    function syncComboValue(combo, value) {
        if (!combo) {
            return
        }

        const resolvedIndex = Math.max(0, combo.indexOfValue(value))
        if (combo.currentIndex !== resolvedIndex) {
            combo.currentIndex = resolvedIndex
        }
    }

    function syncIndicatorSelectors() {
        syncComboValue(indicatorTypeCombo, page.cfg_indicatorType)
        syncComboValue(indicatorPositionCombo, page.cfg_indicatorPosition)
        syncComboValue(windowCountBadgePositionCombo, page.cfg_windowCountBadgePosition)
    }

    function syncDockThemeSelector() {
        syncComboValue(dockThemeModeCombo, page.cfg_dockThemeMode)
    }

    function syncThemeLibrarySelector() {
        if (!dockThemeLibraryCombo) {
            return
        }

        const resolvedIndex = dockThemeLibraryCombo.indexOfValue(
            page.cfg_dockThemeCustomId)
        if (dockThemeLibraryCombo.currentIndex !== resolvedIndex) {
            dockThemeLibraryCombo.currentIndex = resolvedIndex
        }
    }

    function requestThemeRemoval(allThemes) {
        if (dockThemeRepository.removalBusy) {
            return
        }
        const selectedId = String(dockThemeLibraryCombo.currentValue || "")
        if (!allThemes && selectedId.length === 0) {
            return
        }
        page.themeRemovalMessage = ""
        page.pendingThemeRemoval = dockThemeRepository.prepareRemoval(allThemes ? "" : selectedId)
        if (Number(page.pendingThemeRemoval.count || 0) > 0) {
            removeThemeDialog.open()
        }
    }

    function finishThemeRemoval(movedCount, failedCount) {
        page.lastThemeDirectoryImport = ({})
        page.themeRemovalFailed = failedCount > 0
        // qmllint disable unqualified
        page.themeRemovalMessage = i18n("Themes moved to the Trash: %1. Themes that could not be moved: %2.",
            movedCount, failedCount)
        // qmllint enable unqualified
        // R62.5: refreshThemes() is incremental. Looking at availableThemes
        // immediately after removal would inspect the OLD list. Reconcile
        // only once its complete replacement has been published.
        page.themeRemovalAwaitingRefresh = movedCount > 0
        page.pendingThemeRemoval = ({})
        if (!page.themeRemovalAwaitingRefresh) page.syncThemeLibrarySelector()
    }

    function reconcileRemovedTheme() {
        const activeThemeRemains = dockThemeRepository.availableThemes.some(function(theme) {
            return String(theme.id || "") === page.cfg_dockThemeCustomId
        })
        if (page.cfg_dockThemeCustomId.length > 0 && !activeThemeRemains) {
            page.cfg_dockThemeCustomId = ""
            page.cfg_dockThemeMode = "plasma"
        }
        page.syncThemeLibrarySelector()
    }

    // qmllint disable unqualified
    function dockThemeErrorText(errorCode) {
        switch (errorCode) {
        case "invalidSource":
            return i18n("Choose a local JSON file.")
        case "unreadableFile":
            return i18n("The selected theme file could not be read.")
        case "emptyFile":
            return i18n("The selected theme file is empty.")
        case "fileTooLarge":
            return i18n("The selected theme is larger than the 64 KiB limit.")
        case "invalidJson":
            return i18n("The selected file does not contain valid JSON.")
        case "unsupportedSchema":
            return i18n("The selected theme uses an unsupported schema version.")
        case "unsupportedRenderer":
            return i18n("This version of Oger Dock does not support the renderer requested by the theme.")
        case "themeNotFound":
            return i18n("The configured external theme is unavailable. The Plasma background will be used.")
        case "storageUnavailable":
        case "writeFailed":
            return i18n("Oger Dock could not store the imported theme.")
        case "invalidDirectory":
            return i18n("Choose a local folder containing JSON themes.")
        case "unreadableDirectory":
            return i18n("The selected theme folder could not be read.")
        case "invalidThemeId":
            return i18n("The selected installed theme has an invalid identifier.")
        case "readOnlyDirectory":
            return i18n("Oger Dock cannot import themes here for security reasons: the selected folder is read-only or requires administrator permissions.")
        case "removalChanged":
            return i18n("The theme library changed. Review the themes and try again.")
        default:
            return i18n("The selected file is not a supported Oger Dock theme.")
        }
    }

    function themeDirectoryImportText(result) {
        if (!result || result.candidateCount === undefined) {
            return ""
        }
        if (result.candidateCount === 0) {
            return i18n("The selected folder and its subfolders do not contain JSON theme files.")
        }

        if (result.scanLimitReached) {
            return i18n("Folder import reached the 256-theme safety limit — added: %1, already installed: %2, rejected: %3. Additional themes were not processed.",
                result.importedCount, result.duplicateCount, result.rejectedCount)
        }
        if (result.truncatedCount > 0) {
            return i18n("Folder import finished — added: %1, already installed: %2, rejected: %3, not processed because of the 256-theme limit: %4.",
                result.importedCount, result.duplicateCount,
                result.rejectedCount, result.truncatedCount)
        }
        return i18n("Folder import finished — added: %1, already installed: %2, rejected: %3.",
            result.importedCount, result.duplicateCount, result.rejectedCount)
    }
    // qmllint enable unqualified

    onCfg_indicatorTypeChanged: syncIndicatorSelectors()
    onCfg_indicatorPositionChanged: syncIndicatorSelectors()
    onCfg_windowCountBadgePositionChanged: syncIndicatorSelectors()
    onCfg_showWindowCountBadgeChanged: syncIndicatorSelectors()
    onCfg_dockThemeModeChanged: syncDockThemeSelector()
    onCfg_dockThemeCustomIdChanged: syncThemeLibrarySelector()
    // R62.2: avoid repeated synchronous theme-library filesystem scans when
    // this KCM is instantiated or its directory settings change. The C++
    // DockThemeRepository refreshes in its constructor and after either setter;
    // onThemesChanged below already synchronizes the selector. Repeating the
    // scan here blocked the first frame when switching sidebar categories.
    onCfg_dockCustomThemeDirectoryEnabledChanged: syncThemeLibrarySelector()
    onCfg_dockCustomThemeDirectoryChanged: syncThemeLibrarySelector()
    Component.onCompleted: {
        syncIndicatorSelectors()
        syncDockThemeSelector()
        syncThemeLibrarySelector()
    }

    Punchi.TrashIntegration {
        id: themeTrash
        onOperationFailed: function(operation, message) {
            page.themeRemovalFailed = true
            page.themeRemovalMessage = message
        }
    }

    Punchi.DockThemeRepository {
        id: dockThemeRepository
        themeId: page.inPanel ? "" : page.cfg_dockThemeCustomId
        customThemeDirectoryEnabled: page.cfg_dockCustomThemeDirectoryEnabled
        customThemeDirectory: page.cfg_dockCustomThemeDirectory

        onThemesChanged: page.syncThemeLibrarySelector()
        onThemesRefreshFinished: {
            page.syncThemeLibrarySelector()
            if (page.themeRemovalAwaitingRefresh) {
                page.themeRemovalAwaitingRefresh = false
                page.reconcileRemovedTheme()
            }
        }
        onRemovalFinished: function(movedCount, failedCount) {
            page.finishThemeRemoval(movedCount, failedCount)
        }
    }

    // qmllint disable unqualified
    ColorPaletteDialog {
        id: indicatorColorDialog
        width: Math.min(page.width - Kirigami.Units.largeSpacing * 2,
            Kirigami.Units.gridUnit * 24)
        title: i18n("Choose Indicator Color")
        currentColor: page.effectiveIndicatorColor
        fallbackColor: Kirigami.Theme.highlightColor
        onColorChosen: function(color) {
            page.cfg_indicatorColor = color
        }
    }

    ColorPaletteDialog {
        id: windowCountEmblemColorDialog
        width: Math.min(page.width - Kirigami.Units.largeSpacing * 2,
            Kirigami.Units.gridUnit * 24)
        title: i18n("Choose Window Count Badge Color")
        currentColor: page.effectiveWindowCountEmblemColor
        fallbackColor: Kirigami.Theme.highlightColor
        onColorChosen: function(color) {
            page.cfg_windowCountEmblemColor = color
        }
    }
    // qmllint enable unqualified

    // qmllint disable unqualified
    QtDialogs.FileDialog {
        id: dockThemeFileDialog
        title: i18n("Import Oger Dock Theme")
        fileMode: QtDialogs.FileDialog.OpenFile
        nameFilters: [i18n("JSON theme files") + " (*.json)", i18n("All files") + " (*)"]

        onAccepted: {
            page.themeRemovalMessage = ""
            const importedThemeId = dockThemeRepository.importTheme(selectedFile)
            if (importedThemeId.length === 0) {
                return
            }
            page.cfg_dockThemeCustomId = importedThemeId
            page.cfg_dockThemeMode = "custom"
            page.syncThemeLibrarySelector()
        }
    }

    QtDialogs.FolderDialog {
        id: dockThemeFolderDialog
        title: i18n("Import Oger Dock Theme Folder")

        onAccepted: {
            page.themeRemovalMessage = ""
            page.lastThemeDirectoryImport =
                dockThemeRepository.importThemeDirectory(selectedFolder)
            const selectedThemeId =
                page.lastThemeDirectoryImport.selectedThemeId || ""
            if (selectedThemeId.length > 0) {
                page.cfg_dockThemeCustomId = selectedThemeId
                page.cfg_dockThemeMode = "custom"
                page.syncThemeLibrarySelector()
            }
        }
    }

    Controls.Menu {
        id: importThemeMenu

        Controls.MenuItem {
            text: i18n("Import file…")
            icon.name: "document-import"
            Accessible.name: i18n("Import one Oger Dock JSON theme")
            onTriggered: {
                page.lastThemeDirectoryImport = ({})
                dockThemeRepository.clearError()
                dockThemeFileDialog.open()
            }
        }

        Controls.MenuItem {
            text: i18n("Import folder…")
            icon.name: "folder-open"
            Accessible.name: i18n("Import all Oger Dock JSON themes from a folder and its subfolders")
            onTriggered: {
                page.lastThemeDirectoryImport = ({})
                dockThemeRepository.clearError()
                dockThemeFolderDialog.open()
            }
        }
    }

    Kirigami.PromptDialog {
        id: removeThemeDialog
        parent: page
        title: i18np("Move %1 Theme to the Trash?", "Move %1 Themes to the Trash?",
            Number(page.pendingThemeRemoval.count || 0))
        subtitle: i18n("Folder: %1\nYou can recover these themes from the Trash. If the active theme is moved, the dock will use the Plasma theme.",
            String(page.pendingThemeRemoval.directory || ""))
        dialogType: Kirigami.PromptDialog.Warning
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: i18nc("@action:button", "Cancel")
                icon.name: "dialog-cancel"
                onTriggered: removeThemeDialog.reject()
            },
            Kirigami.Action {
                text: i18nc("@action:button", "Move to Trash")
                icon.name: "user-trash"
                onTriggered: removeThemeDialog.accept()
            }
        ]
        onAccepted: dockThemeRepository.confirmRemoval()
        onRejected: {
            dockThemeRepository.cancelRemoval()
            page.pendingThemeRemoval = ({})
        }
    }

    Controls.Menu {
        id: removeThemeMenu

        Controls.MenuItem {
            text: dockThemeLibraryCombo.currentIndex >= 0
                ? i18n("Move “%1” to the Trash…", dockThemeLibraryCombo.currentText)
                : i18n("Move selected theme to the Trash…")
            icon.name: "user-trash"
            enabled: !dockThemeRepository.removalBusy && dockThemeLibraryCombo.currentIndex >= 0
                && String(dockThemeLibraryCombo.currentValue || "").length > 0
            onTriggered: page.requestThemeRemoval(false)
        }

        Controls.MenuSeparator {}

        Controls.MenuItem {
            text: i18n("Move all themes to the Trash…")
            icon.name: "user-trash"
            enabled: !dockThemeRepository.removalBusy && dockThemeRepository.availableThemes.length > 0
            onTriggered: page.requestThemeRemoval(true)
        }
    }

    QtDialogs.FolderDialog {
        id: customThemeFolderDialog
        title: i18n("Choose Custom Themes Folder")
        currentFolder: page.cfg_dockCustomThemeDirectory.length > 0
            ? Qt.resolvedUrl(page.cfg_dockCustomThemeDirectory.startsWith("file://")
                ? page.cfg_dockCustomThemeDirectory
                : "file://" + page.cfg_dockCustomThemeDirectory)
            : ""

        onAccepted: {
            page.themeRemovalMessage = ""
            page.cfg_dockCustomThemeDirectory = selectedFolder.toString()
            page.cfg_dockCustomThemeDirectoryEnabled = true
        }
    }
    // qmllint enable unqualified

    // R62.8: Dock settings are their own KCM page. Other areas have separate
    // ConfigCategory sources, so inactive panels create no QML objects.
    Kirigami.FormLayout {
        id: dockAppearanceForm
        Layout.fillWidth: true

    // qmllint disable unqualified
    SectionTitle {
        Kirigami.FormData.isSection: true
        visible: !page.inPanel
        text: i18n("Dock background theme")
    }

    // qmllint disable unqualified
    RowLayout {
        Kirigami.FormData.label: i18n("Dock orientation:")
        Layout.maximumWidth: page.contentWidthHint
        visible: !page.inPanel // In panel mode Plasma owns the panel position.

        Controls.ComboBox {
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "text"
            valueRole: "value"
            model: page.floatingDockOrientationOptions
            currentIndex: Math.max(0, indexOfValue(page.cfg_floatingDockOrientation))
            onActivated: page.cfg_floatingDockOrientation = currentValue
            Accessible.name: i18n("Dock orientation")

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Background theme:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.ComboBox {
            id: dockThemeModeCombo
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "text"
            valueRole: "value"
            model: page.dockThemeModeOptions
            onActivated: {
                if (page.cfg_dockThemeMode !== currentValue) {
                    page.cfg_dockThemeMode = currentValue
                }
            }

        }
    }

    Kirigami.InlineMessage {
        visible: !page.inPanel
        type: Kirigami.MessageType.Information
        text: i18n("Imported themes are stored in the Oger Dock user library and currently apply only to a floating dock. Plasma panels keep their native background.")
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
    }
    // qmllint enable unqualified

    RowLayout {
        Kirigami.FormData.label: i18n("Installed theme:") // qmllint disable unqualified
        Layout.maximumWidth: page.contentWidthHint
        visible: page.cfg_dockThemeMode === "custom"

        Controls.ComboBox {
            id: dockThemeLibraryCombo
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "displayName"
            valueRole: "id"
            model: dockThemeRepository.availableThemes
            enabled: count > 0
            displayText: currentIndex >= 0
                ? currentText
                : count > 0
                    ? i18n("Select a theme") // qmllint disable unqualified
                    : i18n("No imported themes") // qmllint disable unqualified
            Accessible.name: i18n("Installed Oger Dock theme") // qmllint disable unqualified
            onActivated: {
                if (page.cfg_dockThemeCustomId !== currentValue) {
                    page.cfg_dockThemeCustomId = currentValue
                }
            }

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Manage themes:") // qmllint disable unqualified
        Layout.maximumWidth: page.contentWidthHint
        visible: page.cfg_dockThemeMode === "custom"

        Controls.Button {
            id: importThemeButton
            enabled: !dockThemeRepository.removalBusy
            text: i18n("Import…") // qmllint disable unqualified
            icon.name: "list-add"
            Accessible.name: i18n("Import Oger Dock JSON themes") // qmllint disable unqualified
            Accessible.description: i18n("Choose whether to import one JSON theme or all JSON themes from a folder.") // qmllint disable unqualified
            onClicked: importThemeMenu.popup(
                importThemeButton, 0, importThemeButton.height)

        }

        Controls.Button {
            id: removeThemeButton
            text: i18nc("@action:button", "Move to Trash…") // qmllint disable unqualified
            icon.name: "user-trash"
            enabled: !dockThemeRepository.removalBusy && dockThemeRepository.availableThemes.length > 0
            Accessible.name: i18n("Theme deletion options") // qmllint disable unqualified
            Accessible.description: i18n("Choose whether to move the selected theme or all installed themes to the Trash.") // qmllint disable unqualified
            onClicked: removeThemeMenu.popup(
                removeThemeButton, 0, removeThemeButton.height)

            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Move themes to the Trash…") // qmllint disable unqualified

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Custom folder:") // qmllint disable unqualified
        Layout.maximumWidth: page.contentWidthHint
        visible: page.cfg_dockThemeMode === "custom"

        Controls.CheckBox {
            id: customThemeFolderCheckBox
            enabled: !dockThemeRepository.removalBusy
            text: i18n("Use custom folder") // qmllint disable unqualified
            checked: page.cfg_dockCustomThemeDirectoryEnabled
            onToggled: page.cfg_dockCustomThemeDirectoryEnabled = checked

        }

        Controls.TextField {
            id: customThemeFolderField
            Layout.fillWidth: true
            Layout.preferredWidth: Math.max(120,
                page.selectorWidthHint - customThemeFolderCheckBox.implicitWidth
                - selectCustomThemeFolderButton.implicitWidth
                - (Kirigami.Units.smallSpacing * 2)
            )
            Layout.maximumWidth: page.selectorWidthHint
            readOnly: true
            visible: page.cfg_dockCustomThemeDirectoryEnabled
            text: dockThemeRepository.customThemeDirectoryDisplayName.length > 0
                ? dockThemeRepository.customThemeDirectoryDisplayName
                : page.cfg_dockCustomThemeDirectory.length > 0
                    ? page.cfg_dockCustomThemeDirectory
                    : i18n("No folder selected") // qmllint disable unqualified
            placeholderText: i18n("Choose a folder…") // qmllint disable unqualified

            Controls.ToolTip.visible: hovered && page.cfg_dockCustomThemeDirectory.length > 0
            Controls.ToolTip.text: page.cfg_dockCustomThemeDirectory

        }

        Controls.Button {
            id: selectCustomThemeFolderButton
            enabled: !dockThemeRepository.removalBusy
            icon.name: "list-add"
            text: "+"
            display: Controls.AbstractButton.IconOnly
            visible: page.cfg_dockCustomThemeDirectoryEnabled
            Accessible.name: i18n("Select custom themes folder") // qmllint disable unqualified
            onClicked: customThemeFolderDialog.open()

            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Select folder…") // qmllint disable unqualified

        }
    }

    Controls.Label {
        visible: page.cfg_dockThemeMode === "custom"
            && dockThemeRepository.availableThemes.length === 0
        text: i18n("Import a JSON theme to add it to your Oger Dock library.") // qmllint disable unqualified
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }

    Kirigami.InlineMessage {
        visible: page.cfg_dockThemeMode === "custom"
            && dockThemeRepository.errorCode.length > 0
        type: Kirigami.MessageType.Error
        text: page.dockThemeErrorText(dockThemeRepository.errorCode)
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
    }

    Kirigami.InlineMessage {
        visible: page.cfg_dockThemeMode === "custom"
            && page.lastThemeDirectoryImport.candidateCount !== undefined
        type: page.lastThemeDirectoryImport.candidateCount === 0
            ? Kirigami.MessageType.Information
            : (page.lastThemeDirectoryImport.rejectedCount > 0
                || page.lastThemeDirectoryImport.truncatedCount > 0)
                ? Kirigami.MessageType.Warning
                : Kirigami.MessageType.Positive
        text: page.themeDirectoryImportText(page.lastThemeDirectoryImport)
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
    }

    Kirigami.InlineMessage {
        visible: page.inPanel && page.cfg_dockThemeMode === "custom"
        type: Kirigami.MessageType.Information
        text: i18n("In panel mode, custom JSON themes automatically set the native panel to \"No background\" so the theme's custom shape, borders, and shadows are fully visible.") // qmllint disable unqualified
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
    }

    Kirigami.InlineMessage {
        visible: dockThemeRepository.removalBusy || page.themeRemovalMessage.length > 0
        type: page.themeRemovalFailed ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
        text: dockThemeRepository.removalBusy
            ? i18n("Moving themes to the Trash…") : page.themeRemovalMessage // qmllint disable unqualified
        actions: Kirigami.Action {
            text: i18n("Open Trash") // qmllint disable unqualified
            icon.name: "user-trash"
            enabled: !dockThemeRepository.removalBusy
            onTriggered: themeTrash.openTrash()
        }
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
    }
    // qmllint enable unqualified

    // qmllint disable unqualified
    SectionTitle {
        Kirigami.FormData.isSection: true
        text: i18n("Item highlight")
    }

    Controls.CheckBox {
        id: showItemHoverBackgroundCheck
        Kirigami.FormData.label: i18n("Hover background:")
        text: i18n("Show a themed background behind items")
        Accessible.description: i18n("Shows the Plasma highlight background when an item is hovered or its application is active.")

    }

    Controls.Label {
        text: i18n("Window indicators remain visible when the item background is hidden.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }
    // qmllint enable unqualified

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    SectionTitle {
        Kirigami.FormData.isSection: true
        text: i18n("Labels") // qmllint disable unqualified
    }

    Controls.CheckBox {
        id: showLabelsCheck
        Kirigami.FormData.label: i18n("Labels:") // qmllint disable unqualified
        text: i18n("Show item names in the dock") // qmllint disable unqualified

    }

    Controls.CheckBox {
        id: dockTextShadowsCheck
        Kirigami.FormData.label: i18n("Text shadows:") // qmllint disable unqualified
        text: i18n("Show subtle shadows on dock labels") // qmllint disable unqualified
        checked: showLabelsCheck.checked && dockTextShadowPreference.value
        enabled: showLabelsCheck.checked
        Accessible.description: i18n("Available when dock item names are shown.") // qmllint disable unqualified
        onClicked: dockTextShadowPreference.value = checked

    }

    Controls.Label {
        text: i18n("Labels use a compact single-line style so the dock can remain readable without turning every item into a large card.") // qmllint disable unqualified
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    SectionTitle {
        Kirigami.FormData.isSection: true
        text: i18n("Icon reflections") // qmllint disable unqualified
    }

    Controls.CheckBox {
        id: iconReflectionsCheck
        enabled: page.iconReflectionsSupported && !showLabelsCheck.checked
        Kirigami.FormData.label: i18n("Reflection:") // qmllint disable unqualified
        text: i18n("Show reflections below dock items") // qmllint disable unqualified
        // qmllint disable unqualified
        Accessible.description: !page.iconReflectionsSupported
            ? i18n("Icon reflections are unavailable in vertical panels.")
            : (page.inPanel
                ? i18n("Adds an adaptive decorative reflection below icons in a horizontal panel.")
                : i18n("Adds a short decorative reflection below icons in a floating dock."))
        // qmllint enable unqualified

    }

    // qmllint disable unqualified
    RowLayout {
        enabled: iconReflectionsCheck.checked
            && page.iconReflectionsSupported
            && !showLabelsCheck.checked
        Kirigami.FormData.label: i18n("Reflection opacity:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.Slider {
            id: iconReflectionOpacitySlider
            from: 5
            to: 50
            stepSize: 1
            snapMode: Controls.Slider.SnapAlways
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64
            Accessible.name: i18n("Reflection opacity")
            Accessible.description: i18n("Adjusts how strongly icon reflections appear.")

        }

        Controls.Label {
            text: Math.round(iconReflectionOpacitySlider.value) + "%"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 56
        }
    }
    // qmllint enable unqualified

    Controls.Label {
        // qmllint disable unqualified
        text: page.inPanel && !page.horizontalPanel
            ? i18n("Icon reflections are not available in vertical panels.")
            : (showLabelsCheck.checked
                ? i18n("Hide item names to use icon reflections.")
                : (page.inPanel
                    ? i18n("The reflection adapts to the available panel thickness and is hidden when there is not enough space.")
                    : i18n("The reflection is decorative and does not change the size or interaction area of dock items.")))
        // qmllint enable unqualified
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    SectionTitle {
        Kirigami.FormData.isSection: true
        text: i18n("Indicator") // qmllint disable unqualified
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Indicator shape:") // qmllint disable unqualified
        Layout.maximumWidth: page.contentWidthHint

        Controls.ComboBox {
            id: indicatorTypeCombo
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "text"
            valueRole: "value"
            model: page.indicatorTypeOptions
            onActivated: {
                if (page.cfg_indicatorType !== currentValue) {
                    page.cfg_indicatorType = currentValue
                }
            }

        }
    }

    // qmllint disable unqualified
    Controls.Label {
        text: page.cfg_indicatorType === "none"
            ? i18n("Disables the active-window indicator entirely.")
            : i18n("Line, dot, small ring and rounded square can be placed at the top or bottom edge of the icon.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }
    // qmllint enable unqualified

    // qmllint disable unqualified
    RowLayout {
        Kirigami.FormData.label: i18n("Indicator position:")
        Layout.maximumWidth: page.contentWidthHint
        visible: page.indicatorPositionApplicable

        Controls.ComboBox {
            id: indicatorPositionCombo
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "text"
            valueRole: "value"
            model: page.indicatorPositionOptions
            onActivated: {
                if (page.cfg_indicatorPosition !== currentValue) {
                    page.cfg_indicatorPosition = currentValue
                }
            }

        }
    }

    Controls.Label {
        visible: !page.indicatorPositionApplicable
        text: i18n("Position is not used with the current indicator shape.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Indicator color:")
        Layout.maximumWidth: page.contentWidthHint

        ColorModeControl {
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            customColor: page.effectiveIndicatorColor
            fallbackColor: Kirigami.Theme.highlightColor
            selectorWidth: page.selectorWidthHint - Kirigami.Units.iconSizes.medium
            enabled: page.indicatorPositionApplicable
            onColorRequested: indicatorColorDialog.open()
            onThemeRequested: page.cfg_indicatorColor = ""

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Indicator opacity:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.Slider {
            id: indicatorOpacitySlider
            from: 0
            to: 100
            stepSize: 5
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64

        }

        Controls.Label {
            text: Math.round(indicatorOpacitySlider.value) + "%"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 56
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Indicator thickness:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.Slider {
            id: indicatorThicknessSlider
            from: 2
            to: 10
            stepSize: 1
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64
            Accessible.name: i18n("Indicator thickness")
            Accessible.description: i18n("Adjusts the indicator thickness between 2 and 10 pixels.")

        }

        Controls.Label {
            text: Math.round(indicatorThicknessSlider.value) + " px"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 56
        }
    }

    Controls.CheckBox {
        id: indicatorNeonCheck
        Kirigami.FormData.label: i18n("Light effect:")
        text: i18n("Neon glow on open application indicators")
        enabled: page.indicatorPositionApplicable
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Neon strength:")
        Layout.maximumWidth: page.contentWidthHint
        enabled: indicatorNeonCheck.checked && page.indicatorPositionApplicable
        Controls.Slider {
            id: indicatorNeonIntensitySlider
            from: 0
            to: 100
            stepSize: 5
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64
        }
        Controls.Label {
            text: Math.round(indicatorNeonIntensitySlider.value) + "%"
            Layout.preferredWidth: 56
        }
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        level: 3
        text: i18n("Window count badge")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.CheckBox {
            id: showWindowCountBadgeCheck
            text: i18n("Show the number of open windows")

        }
    }

    Controls.Label {
        text: i18n("The badge appears from two grouped windows and is hidden when window grouping is disabled.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: page.contentWidthHint
        leftPadding: layoutMetrics.helperIndent
        color: Kirigami.Theme.disabledTextColor
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge position:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.ComboBox {
            id: windowCountBadgePositionCombo
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            textRole: "text"
            valueRole: "value"
            model: page.windowCountBadgePositionOptions
            enabled: page.cfg_showWindowCountBadge
            onActivated: {
                if (page.cfg_windowCountBadgePosition !== currentValue) {
                    page.cfg_windowCountBadgePosition = currentValue
                }
            }

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge color:")
        Layout.maximumWidth: page.contentWidthHint

        ColorModeControl {
            Layout.preferredWidth: page.selectorWidthHint
            Layout.maximumWidth: page.selectorWidthHint
            customColor: page.effectiveWindowCountEmblemColor
            fallbackColor: Kirigami.Theme.highlightColor
            selectorWidth: page.selectorWidthHint - Kirigami.Units.iconSizes.medium
            enabled: page.cfg_showWindowCountBadge
            onColorRequested: windowCountEmblemColorDialog.open()
            onThemeRequested: page.cfg_windowCountEmblemColor = ""

        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge opacity:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.Slider {
            id: windowCountEmblemOpacitySlider
            from: 60
            to: 100
            stepSize: 5
            snapMode: Controls.Slider.SnapAlways
            enabled: page.cfg_showWindowCountBadge
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64
            Accessible.name: i18n("Badge opacity")
            Accessible.description: i18n("Adjusts badge visibility between 60 and 100 percent.")

        }

        Controls.Label {
            text: Math.round(windowCountEmblemOpacitySlider.value) + "%"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 56
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge scale:")
        Layout.maximumWidth: page.contentWidthHint

        Controls.Slider {
            id: windowCountEmblemScaleSlider
            from: 80
            to: 120
            stepSize: 5
            snapMode: Controls.Slider.SnapAlways
            enabled: page.cfg_showWindowCountBadge
            Layout.fillWidth: true
            Layout.preferredWidth: page.contentWidthHint - 64
            Accessible.name: i18n("Badge scale")
            Accessible.description: i18n("Adjusts the badge scale between 80 and 120 percent of its default size.")

        }

        Controls.Label {
            text: Math.round(windowCountEmblemScaleSlider.value) + "%"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 56
        }
    }

    // qmllint enable unqualified
    }


}
