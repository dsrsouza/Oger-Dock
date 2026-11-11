import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami


GridLayout {
    id: root

    property string selectedItemType: "app"
    // R57: stack each visible label above its field when the viewport shrinks.
    // The popup's available width, not maximized/restored window state, decides.
    readonly property bool compactForm: width > 0
        && width < Kirigami.Units.gridUnit * 35
    // The type of the element can be chosen from outside (the type selector of the
    // add dialog) or from this panel's own selector (the action dialog of an
    // existing element). When it is chosen outside, the panel hides its selector
    // so the flow never shows two of them, and the caller drives itemModeIndex.
    property bool showTypeSelector: true
    property alias appNameText: appName.text
    property alias appAliasText: appAlias.text
    property alias appDescriptionText: appDescription.text
    property alias appIconText: appIconName.text
    property alias appCommandText: appCommand.text
    readonly property bool dynamicApplicationsItem:
        selectedItemType === "dynamic-applications"
    readonly property string itemModeValue: dynamicApplicationsItem
        ? "dynamic-applications" : (itemMode.currentValue || "app")
    property alias itemModeIndex: itemMode.currentIndex
    readonly property string containerLayoutValue: containerLayout.currentValue || "grid"
    property alias containerLayoutIndex: containerLayout.currentIndex
    property alias spacerSizeValue: spacerSize.value
    readonly property string separatorAppearanceSourceValue:
        separatorOptions.separatorAppearanceSourceValue
    readonly property string separatorStyleValue: separatorOptions.separatorStyleValue
    readonly property real separatorThicknessValue: separatorOptions.separatorThicknessValue
    readonly property real separatorLengthRatioValue: separatorOptions.separatorLengthRatioValue
    readonly property real separatorOpacityValue: separatorOptions.separatorOpacityValue
    readonly property bool separatorGlowEnabled: separatorOptions.separatorGlowEnabled
    readonly property bool separatorVisibleChecked:
        separatorVisibleCheckBox.checked
    property bool separatorControlsSyncing: false
    readonly property bool syncing: separatorControlsSyncing
    readonly property string containerSourceValue: containerSource.currentValue || "manual"
    property alias containerSourceIndex: containerSource.currentIndex
    property alias containerPathText: containerPath.text
    property alias folderAccentColorText: folderAccentField.text
    property alias containerBrowseSubfoldersChecked: browseSubfolders.checked
    readonly property string containerCategoryValue: containerCategory.currentValue || "Development"
    property alias containerCategoryIndex: containerCategory.currentIndex
    property string containerLoadStatusText: ""
    property int containerLoadStatusType: Kirigami.MessageType.Warning

    property string nameLabel: i18n("Name:") // qmllint disable unqualified
    property string aliasLabel: i18n("Alias:") // qmllint disable unqualified
    property string descLabel: i18n("Description:") // qmllint disable unqualified
    property string aliasPlaceholder: i18n("Type name or alias... then search") // qmllint disable unqualified
    property string itemTypeLabel: i18n("Type:") // qmllint disable unqualified
    property string launchAppText: i18n("Launch app") // qmllint disable unqualified
    property string containerText: i18n("Container") // qmllint disable unqualified
    property string viewLabel: i18n("View:") // qmllint disable unqualified
    property string gridText: i18n("Grid") // qmllint disable unqualified
    property string listText: i18n("List") // qmllint disable unqualified
    property string detailedText: i18n("Detailed") // qmllint disable unqualified
    property string fanText: i18nc("@item:inlistbox Folder popup layout", "Fan") // qmllint disable unqualified
    property string noteText: i18n("Note") // qmllint disable unqualified
    property string separatorText: i18n("Separator") // qmllint disable unqualified
    property string spacerText: i18n("Spacer") // qmllint disable unqualified
    property string containerSourceLabel: i18n("Content:") // qmllint disable unqualified
    property string manualContainerText: i18n("Manual") // qmllint disable unqualified
    property string folderContainerText: i18n("Folder") // qmllint disable unqualified
    property string categoryContainerText: i18n("Application category") // qmllint disable unqualified
    property string folderPathLabel: i18n("Folder:") // qmllint disable unqualified
    property string categoryLabel: i18n("Category:") // qmllint disable unqualified
    property string refreshContentText: i18n("Load content") // qmllint disable unqualified
    property string iconLabel: i18n("Icon:") // qmllint disable unqualified
    property string commandLabel: i18n("Command:") // qmllint disable unqualified
    property string spacerSizeLabel: i18n("Spacer size:") // qmllint disable unqualified
    property string chooseIconText: i18n("Choose icon") // qmllint disable unqualified

    signal formChanged()
    signal itemModeChanged(string mode)
    signal containerLayoutChanged(string layout)
    signal containerSourceChanged(string source)
    signal containerCategoryChanged(string category)
    signal containerPathEdited()
    signal folderPickerRequested()
    signal containerRefreshRequested()
    signal appCommandEdited()
    signal autofillRequested(string alias)
    signal iconPickerRequested(string target)
    signal browseApplicationsRequested()

    function sourceIndexFor(value) {
        return Math.max(0, containerSource.indexOfValue(value || "manual"))
    }

    function categoryIndexFor(value) {
        return Math.max(0, containerCategory.indexOfValue(value || "Development"))
    }

    function layoutIndexFor(value) {
        return Math.max(0, containerLayout.indexOfValue(value || "grid"))
    }

    function setSeparatorStyleValue(value) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorStyleValue(value)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorAppearanceSourceValue(value) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorAppearanceSourceValue(value)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorThicknessValue(value) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorThicknessValue(value)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorLengthRatioValue(value) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorLengthRatioValue(value)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorOpacityValue(value) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorOpacityValue(value)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorGlowEnabled(enabled) {
        root.separatorControlsSyncing = true
        try {
            separatorOptions.setSeparatorGlowEnabled(enabled)
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function setSeparatorVisibleChecked(visible) {
        root.separatorControlsSyncing = true
        try {
            separatorVisibleCheckBox.checked = visible !== false
        } finally {
            root.separatorControlsSyncing = false
        }
    }

    function applyItemForm() {
        if (!root.separatorControlsSyncing) {
            root.formChanged()
        }
    }

    function iconPreview(value, fallback) {
        var text = String(value || "")
        return text.length > 0 ? text : fallback
    }

    // R52: all callers (existing and new items) use the same measured form
    // columns. Visible labels determine the first column, and the desired field
    // width is shared across item types. Adding another visible label automatically
    // updates the width hint without a new per-item-type size constant.
    function longestVisibleLabel() {
        let longest = 0
        for (let i = 0; i < root.children.length; ++i) {
            const child = root.children[i]
            if (child && child.visible && typeof child.text === "string"
                    && Number.isFinite(child.implicitWidth)) {
                longest = Math.max(longest, child.implicitWidth)
            }
        }
        return longest
    }
    property real sharedLabelWidth: 0
    function widestVisibleField() {
        let widest = 0
        for (let i = 0; i < root.children.length; ++i) {
            const child = root.children[i]
            // Direct RowLayouts and input controls supply their *intrinsic* width.
            // Never read root.implicitWidth or a delegate width: those can depend
            // on the viewport and would create a sizing feedback loop.
            if (child && child.visible && typeof child.text !== "string"
                    && Number.isFinite(child.implicitWidth)) {
                widest = Math.max(widest, child.implicitWidth)
            }
        }
        return widest
    }
    readonly property real adaptiveLabelWidth: Math.max(
        Kirigami.Units.gridUnit * 8, root.sharedLabelWidth,
        root.longestVisibleLabel())
    readonly property real preferredFormWidth: root.adaptiveLabelWidth
        + Math.max(Kirigami.Units.gridUnit * 28, root.widestVisibleField())
        + root.columnSpacing

    // Allow the KCM's ScrollView to give this form a narrower viewport.
    // Long values live in TextFields and must not increase the entire popup width.
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    columns: root.compactForm ? 1 : 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Math.max(Kirigami.Units.smallSpacing, 7)

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.showTypeSelector && !root.dynamicApplicationsItem
        text: root.itemTypeLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        objectName: "itemEditorTypeRow"

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.columnSpan: root.compactForm ? 1 : (root.showTypeSelector ? 1 : 2)
        // The caller may own the type, as the add dialog does. When it does, the
        // row disappears so the two-column grid gains no empty cell. Every other
        // choice of the type lives in its own row below, so a single row never
        // carries two unrelated choices.
        visible: !root.dynamicApplicationsItem && root.showTypeSelector
        spacing: Kirigami.Units.smallSpacing

        Controls.ComboBox {
            id: itemMode
            Layout.fillWidth: true
            visible: root.showTypeSelector
            enabled: root.selectedItemType === "app" || root.selectedItemType === "folder" || root.selectedItemType === "note" || root.selectedItemType === "separator" || root.selectedItemType === "spacer"
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": root.launchAppText, "value": "app" },
                { "text": root.containerText, "value": "container" },
                { "text": root.noteText, "value": "note" },
                { "text": root.separatorText, "value": "separator" },
                { "text": root.spacerText, "value": "spacer" }
            ]
            onActivated: root.itemModeChanged(currentValue)
        }
    }

    Controls.Label {
        objectName: "itemEditorAliasLabel"

        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "app"
        text: root.aliasLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        objectName: "itemEditorAliasRow"

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "app"
        enabled: root.selectedItemType === "app"
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: appAlias
            Layout.fillWidth: true
            placeholderText: root.aliasPlaceholder
            onAccepted: root.autofillRequested(text)
        }

        Controls.Button {
            icon.name: "search"
            display: Controls.AbstractButton.IconOnly
            onClicked: root.autofillRequested(appAlias.text)
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    Controls.Label {
        objectName: "itemEditorNameLabel"

        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "app" || root.itemModeValue === "container" || root.itemModeValue === "note"
        text: root.nameLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        objectName: "itemEditorNameRow"

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "app" || root.itemModeValue === "container" || root.itemModeValue === "note"
        enabled: root.selectedItemType === "app" || root.selectedItemType === "folder" || root.selectedItemType === "note"
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: appName
            Layout.fillWidth: true
            onAccepted: root.formChanged()
            onEditingFinished: root.formChanged()
        }
    }

    // The icon gets its own row, aligned with the labels above, instead of a
    // caption pinned to the right of the name field. The value is editable, as in
    // the trash options, and the button opens the shared picker.
    Controls.Label {
        objectName: "itemEditorIconLabel"

        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "app" || root.itemModeValue === "container" || root.itemModeValue === "note"
        text: root.iconLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        objectName: "itemEditorIconRow"

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "app" || root.itemModeValue === "container" || root.itemModeValue === "note"
        enabled: root.selectedItemType === "app" || root.selectedItemType === "folder" || root.selectedItemType === "note"
        spacing: Kirigami.Units.smallSpacing

        Controls.Button {
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            icon.name: root.iconPreview(appIconName.text, "application-x-executable")
            icon.source: root.iconPreview(appIconName.text, "application-x-executable")
            display: Controls.AbstractButton.IconOnly
            onClicked: root.iconPickerRequested("item")

            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: root.chooseIconText
        }

        Controls.TextField {
            id: appIconName
            Layout.fillWidth: true
            placeholderText: "firefox"
            onEditingFinished: root.formChanged()
        }
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "app"
        text: root.descLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    Controls.TextField {
        id: appDescription
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "app"
        enabled: root.selectedItemType === "app"
        onAccepted: root.formChanged()
        onEditingFinished: root.formChanged()
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "app"
        text: root.commandLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "app"
        enabled: root.selectedItemType === "app"
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: appCommand
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root.selectedItemType === "app"
            placeholderText: "firefox"
            onAccepted: root.appCommandEdited()
            onEditingFinished: root.appCommandEdited()
        }

        Controls.Button {
            id: browseInstalledApplicationsButton
            enabled: root.selectedItemType === "app"
            icon.name: "view-list-icons"
            text: i18nc("@action:button", "Browse") // qmllint disable unqualified
            display: Controls.AbstractButton.TextBesideIcon
            onClicked: root.browseApplicationsRequested()
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18nc("@info:tooltip",
                "Choose an installed application and fill the fields automatically.") // qmllint disable unqualified
        }
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "spacer"
        text: root.spacerSizeLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    Controls.SpinBox {
        id: spacerSize
        Layout.fillWidth: root.compactForm
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "spacer"
        enabled: root.selectedItemType === "spacer"
        from: 0
        to: 600
        stepSize: 4
        textFromValue: function(value) { return value + " px" }
        valueFromText: function(text) { return Number.fromLocaleString(Qt.locale(), text.replace("px", "")) }
        onValueModified: root.formChanged()
    }

    Controls.CheckBox {
        id: separatorVisibleCheckBox
        objectName: "dynamicApplicationsSeparatorVisibleCheckBox"
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.dynamicApplicationsItem
        checked: true
        text: i18n("Show separator") // qmllint disable unqualified
        Accessible.name: text
        onToggled: root.applyItemForm()
    }

    SeparatorOptions {
        id: separatorOptions
        objectName: "dynamicApplicationsSeparatorOptions"
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "separator"
            || root.dynamicApplicationsItem
        enabled: !root.dynamicApplicationsItem
            || separatorVisibleCheckBox.checked
        controller: root
    }

    Kirigami.Separator {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: root.itemModeValue === "container"
    }
    Controls.Label {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
        text: i18nc("@title:group folder appearance", "Appearance") // qmllint disable unqualified
        font.weight: Font.DemiBold
    }

    Controls.Label {
        objectName: "itemEditorViewLabel"

        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container"
        text: root.viewLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    Controls.ComboBox {
        id: containerLayout
        Layout.fillWidth: root.compactForm
        Layout.alignment: Qt.AlignLeft
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container"
        enabled: root.selectedItemType === "folder"
        textRole: "text"
        valueRole: "value"
        model: [
            { "text": root.gridText, "value": "grid" },
            { "text": root.listText, "value": "list" },
            { "text": root.detailedText, "value": "detailed" },
            { "text": root.fanText, "value": "fan" }
        ]
        onActivated: root.containerLayoutChanged(currentValue)
    }

    Kirigami.Separator {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: root.itemModeValue === "container"
    }
    Controls.Label {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
        text: i18nc("@title:group folder content", "Folder content") // qmllint disable unqualified
        font.weight: Font.DemiBold
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container"
        text: root.containerSourceLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
        spacing: Kirigami.Units.smallSpacing

        Controls.ComboBox {
            id: containerSource
            Layout.fillWidth: true
            enabled: root.selectedItemType === "folder"
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": root.manualContainerText, "value": "manual" },
                { "text": root.folderContainerText, "value": "folder" },
                { "text": root.categoryContainerText, "value": "category" }
            ]
            onActivated: root.containerSourceChanged(currentValue)
        }

        // A reload only makes sense for a content source that is discovered; with
        // the manual source it would only sit disabled, so it is hidden.
        Controls.Button {
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            visible: root.selectedItemType === "folder" && containerSource.currentValue !== "manual"
            text: root.refreshContentText
            icon.name: "view-refresh-symbolic"
            enabled: root.selectedItemType === "folder" && containerSource.currentValue !== "manual"
            onClicked: root.containerRefreshRequested()
        }
    }

    Kirigami.Separator {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: root.itemModeValue === "container"
    }
    Controls.Label {
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
        text: i18nc("@title:group folder customization", "Customization") // qmllint disable unqualified
        font.weight: Font.DemiBold
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container"
        text: i18nc("@label", "Folder accent:") // qmllint disable unqualified
        opacity: 0.75
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
        spacing: Kirigami.Units.smallSpacing
        Controls.TextField {
            id: folderAccentField
            objectName: "folderAccentHexColor"
            Layout.fillWidth: true
            enabled: root.selectedItemType === "folder"
            placeholderText: i18nc("@info:placeholder", "Theme/category color")
            maximumLength: 7
            validator: RegularExpressionValidator {
                regularExpression: /(^$|^#[a-fA-F0-9]{0,6}$)/
            }
            onEditingFinished: root.formChanged()
        }
        Controls.Button {
            id: pickFolderAccent
            objectName: "reaFolderAccentPicker"
            enabled: root.selectedItemType === "folder"
            text: i18nc("@action:button", "Choose color")
            icon.name: "color-picker"
            display: Controls.AbstractButton.IconOnly
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: text
            onClicked: {
                folderAccentPicker.selectedColor =
                    /^#[a-fA-F0-9]{6}$/.test(folderAccentField.text)
                    ? folderAccentField.text : Kirigami.Theme.highlightColor
                folderAccentPicker.open()
            }
        }
        Controls.ToolButton {
            text: i18nc("@action:button", "Use category/theme")
            icon.name: "edit-undo"
            display: Controls.AbstractButton.IconOnly
            enabled: root.selectedItemType === "folder"
            onClicked: {
                folderAccentField.text = ""
                root.formChanged()
            }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: text
        }
    }
    ColorDialog {
        id: folderAccentPicker
        title: i18nc("@title:window", "Folder accent color")
        onAccepted: {
            const c = selectedColor
            function hex(value) {
                return Math.round(Math.max(0, Math.min(255, value * 255)))
                    .toString(16).padStart(2, "0")
            }
            folderAccentField.text = "#" + hex(c.r) + hex(c.g) + hex(c.b)
            root.formChanged()
        }
    }

    Controls.CheckBox {
        id: browseSubfolders
        objectName: "containerBrowseSubfoldersCheckBox"
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
            && root.containerSourceValue === "folder"
            && (root.containerLayoutValue === "list"
                || root.containerLayoutValue === "detailed")
        enabled: root.selectedItemType === "folder"
        text: i18nc("@option:check folder container", "Browse subfolders") // qmllint disable unqualified
        onToggled: root.formChanged()
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container" && containerSource.currentValue === "folder"
        text: root.folderPathLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container" && containerSource.currentValue === "folder"
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: containerPath
            objectName: "containerPathField"
            Layout.fillWidth: true
            enabled: root.selectedItemType === "folder"
            onTextEdited: root.containerPathEdited()
            onAccepted: root.formChanged()
            onEditingFinished: root.formChanged()
        }

        Controls.Button {
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            display: Controls.AbstractButton.IconOnly
            icon.name: "document-open-folder-symbolic"
            enabled: root.selectedItemType === "folder"
            onClicked: root.folderPickerRequested()
        }
    }

    Controls.Label {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.compactForm ? -1 : root.adaptiveLabelWidth
        visible: root.itemModeValue === "container" && containerSource.currentValue === "category"
        text: root.categoryLabel
        horizontalAlignment: Text.AlignLeft
        opacity: 0.75
    }

    Controls.ComboBox {
        id: containerCategory
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container" && containerSource.currentValue === "category"
        enabled: root.selectedItemType === "folder"
        textRole: "text"
        valueRole: "value"
        model: [
            { "text": "Development", "value": "Development" },
            { "text": "Games", "value": "Game" },
            { "text": "Multimedia", "value": "AudioVideo" },
            { "text": "Internet", "value": "Network" },
            { "text": "Office", "value": "Office" },
            { "text": "System", "value": "System" },
            { "text": "Utilities", "value": "Utility" },
            { "text": "Graphics", "value": "Graphics" }
        ]
        onActivated: root.containerCategoryChanged(currentValue)
    }

    Kirigami.InlineMessage {
        objectName: "containerLoadStatusMessage"
        Layout.columnSpan: root.compactForm ? 1 : 2
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.itemModeValue === "container"
            && root.containerSourceValue !== "manual"
            && root.containerLoadStatusText.length > 0
        text: root.containerLoadStatusText
        type: root.containerLoadStatusType
    }
}
