import QtCore
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.plasmoid
import "../org/punchi/dock" as Punchi

import "code/configItemsController.js" as ConfigItemsControllerJS
import "code/configDockPreviewReorder.js" as DockPreviewReorderJS
import "code/configDockMultiSelect.js" as DockMultiSelectJS
import "code/configItems.js" as ConfigItemsJS
// Exposes the dependency in the shared QML scope used by WorkflowHelper.
// qmllint disable unused-imports
import "code/items.js" as ItemsJS
// qmllint enable unused-imports
import "code/configScripts.js" as ConfigScriptsJS
import "code/configItemsStateHelper.js" as StateHelper
import "code/configItemsFormHelper.js" as FormHelper
import "code/configItemsWorkflowHelper.js" as WorkflowHelper
import "../../code/logic.js" as DockLogic
import "components"

import org.kde.kcmutils as KCM

KCM.AbstractKCM {
    id: page

    // R62.6: immediate category switch; do not animate the entire KCM.
    // Whole-page transforms cannot shorten control creation and cost frames.

    // R58.1: only this applet's configuration pages request maximized mode.
    // The KDE-owned window still handles its own close/minimize/Save dialog.
    ConfigMaximizedWindowGuard {
        hostWindow: page.Window.window
        diagnosticCategory: "Itens"
    }

    // The sidebar already names the category, so the page does not repeat it as
    // a heading. The shell decides whether an empty title still reserves a band:
    // validate visually and restore i18n("Items") if it leaves empty space.
    title: ""
    // R56: Plasma System Settings layout: the KCM owns one central viewport.
    // This page contains its own ListView and fills the available KCM page;
    // a SimpleKCM would add a redundant enclosing ScrollView and clip it.
    implicitWidth: Kirigami.Units.gridUnit * 34
    implicitHeight: Kirigami.Units.gridUnit * 24

    ConfigLayoutMetrics {
        id: layoutMetrics
        availableWidth: page.width
    }

    // R54: KDE KCM convention: the host window keeps its own minimum size.
    // Dialogs fit the available content rectangle and scroll vertically when
    // required. Never change the systemsettings/kcmshell QWindow constraints
    // from an embedded page; that caused resize loops on Wayland in R53.

    property string configDirectory: ConfigScriptsJS.localPath(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/punchi-dock"
    property string configFile: ConfigScriptsJS.localPath(configDirectory + "/" + instanceConfigFileName())
    property string pendingOperation: "load"
    property string pendingContainerSource: ""
    property string pendingApplicationListTarget: ""
    property var items: []
    // R62.6: projection and canonical items are always complete together.
    // The former timer-based first build could leave the entire list blank.
    readonly property int previewModelTargetCount: items.length
    property int selectedIndex: -1
    property var lastMovedGroupIndices: []
    property var installedAppCatalog: []
    property bool installedAppCatalogLoaded: false
    property int selectedActionIndex: -1
    property string selectedItemType: "app"
    property bool syncing: false
    property bool loadingFromDisk: false
    property bool updatingConfigJson: false
    property bool diskItemsLoaded: false
    property int pendingRemovalIndex: -1
    property string timedColorTarget: "text"
    property string cfg_dockItemsJson: ""
    // Same KConfig key used by the runtime and Folder Popups page. Reading it
    // here makes saved colors and in-progress KCM changes available to the
    // preview without modifying the dock's stored item data.
    property string cfg_folderCategoryColorsJson: "{}"
    readonly property var previewFolderCategoryColors: {
        try {
            const parsed = JSON.parse(String(cfg_folderCategoryColorsJson || "{}"))
            return parsed && typeof parsed === "object" && !Array.isArray(parsed)
                ? parsed : ({})
        } catch (error) { return ({}) }
    }
    property int cfg_pendingEditDockItemIndex: -1
    property bool cfg_showActiveTasks: true
    property bool pendingEditConsumed: false
    property string iconPickerTarget: "item"
    property bool focusNewItemAfterDialogClose: false
    property int catalogExistingItemIndex: -1
    property real listRowHeight: Kirigami.Units.gridUnit * 2.4
    property real listFooterHeight: Kirigami.Units.gridUnit * 2.4
    property real listFramePadding: Kirigami.Units.largeSpacing * 2
    property real listScrollGutter: Kirigami.Units.gridUnit * 1.6
    property string defaultTrashEmptySound: "/usr/share/sounds/ocean/stereo/trash-empty.oga"
    property var fontChoices: ["Anurati", "Noto Sans", "Noto Sans Mono", "Inter", "Roboto", "Ubuntu", "Cantarell", "DejaVu Sans", "Liberation Sans", "Monospace", "Serif", "Sans Serif"]

    SystemDiscoveryManager {
        id: systemDiscovery
        onCatalogDiscovered: function(apps) {
            page.installedAppCatalog = apps || []
            page.installedAppCatalogLoaded = true
            catalogDialog.loading = false
            catalogDialog.applications = page.installedAppCatalog
        }

        onAppsDiscovered: function(apps, requestId) {
            if (requestId > 0) {
                const operation = itemDraftController.takeExternalOperation(
                    "", requestId)
                if (operation === null) {
                    return
                }
                if (String(operation.kind) === "media-applications") {
                    itemConfigurationDialog.mediaApplications = apps || []
                    return
                }
                if (String(operation.kind) === "container-applications") {
                    const details = operation.details || {}
                    const category = String(details.category || "Development")
                    const iconName = systemDiscovery.iconForCategory(category)
                        || ConfigItemsJS.categoryIcon(category)
                    itemDraftController.applyContainerApplications(
                        Number(operation.generation), apps, iconName)
                    itemConfigurationDialog.refreshEditorFields(true)
                }
                return
            }
            if (page.pendingApplicationListTarget === "media") {
                page.pendingApplicationListTarget = ""
                mediaPlayerDialog.applications = apps || []
            } else {
                page.applyContainerApps(apps)
            }
        }
        onFolderEntriesDiscovered: function(entries, requestId) {
            if (requestId > 0) {
                const operation = itemDraftController.takeExternalOperation(
                    "container-folder", requestId)
                if (operation === null) {
                    return
                }
                itemDraftController.applyContainerApplications(
                    Number(operation.generation), entries, "")
                itemConfigurationDialog.refreshEditorFields(true)
                return
            }
            page.applyContainerApps(entries)
        }
        onApplicationDiscovered: function(application, requestId) {
            if (requestId > 0) {
                const operation = itemDraftController.takeExternalOperation(
                    "application-search", requestId)
                if (operation === null) {
                    return
                }
                itemDraftController.applyDiscoveredApplication(
                    Number(operation.generation), application)
                itemConfigurationDialog.refreshEditorFields()
                return
            }
            page.applyDiscoveredApplication(application)
        }
        // qmllint disable unqualified
        onOperationFailed: function(operation, message, requestId) {
            page.showDiscoveryFailure(message, requestId)
        }
        // qmllint enable unqualified
    }

    Punchi.DockRuntimeService {
        id: runtimeService

        // qmllint disable unqualified
        onOperationFailed: function(operation, message) {
            if (operation === "playSound") {
                mainView.showStatus(i18n("The sound could not be played: %1", message), Kirigami.MessageType.Error)
            }
        }
        // qmllint enable unqualified
    }
    property alias itemName: timedDialog.itemNameControl
    property alias timedItemWidth: timedDialog.timedItemWidthControl
    property alias timedTextScale: timedDialog.timedTextScaleControl
    property alias calendarItemHeight: timedDialog.calendarItemHeightControl
    property alias calendarTimeTextScale: timedDialog.calendarTimeTextScaleControl
    property alias calendarDateTextScale: timedDialog.calendarDateTextScaleControl
    property alias calendarTextShadows: timedDialog.calendarTextShadowsControl
    property alias calendarFormat: timedDialog.calendarFormatControl
    property alias calendarShowWeekNumbers: timedDialog.calendarShowWeekNumbersControl
    property alias calendarPopupScale: timedDialog.calendarPopupScaleControl
    property alias clockColor: timedDialog.calendarTextColorControl
    property alias calendarTextColor: timedDialog.calendarTextColorControl
    property alias calendarBackgroundColor: timedDialog.calendarBackgroundColorControl
    property alias calendarAccentColor: timedDialog.calendarAccentColorControl
    property alias calendarBorderColor: timedDialog.calendarBorderColorControl
    property alias calendarRadius: timedDialog.calendarRadiusControl
    function configInstanceId() {
        var value = ""
        try {
            if (Plasmoid && Plasmoid.id !== undefined && Plasmoid.id !== null) {
                value = String(Plasmoid.id)
            }
        } catch (error) {
            value = ""
        }
        if (value.length === 0 || value === "undefined" || value === "null") {
            return "default"
        }
        return value.replace(/[^A-Za-z0-9_.-]/g, "_")
    }

    function instanceConfigFileName() {
        var instanceId = configInstanceId()
        return instanceId === "default" ? "dock_items.json" : "dock_items_" + instanceId + ".json"
    }

    // qmllint disable unqualified
    function timedChooseColorTitle() {
        if (itemDraftController.externalOperationMatches("color-picker")
                && itemDraftController.draft !== null
                && String(itemDraftController.draftType) === "calendar") {
            return i18n("Choose calendar color")
        }
        if (selectedItemType === "calendar") {
            if (timedColorTarget === "background") {
                return i18n("Choose calendar background color")
            }
            if (timedColorTarget === "accent") {
                return i18n("Choose calendar header color")
            }
            if (timedColorTarget === "border") {
                return i18n("Choose calendar border color")
            }
        }
        if (selectedItemType === "clock") {
            if (timedColorTarget === "analogAccent") {
                return i18n("Choose clock accent color")
            }
            if (timedColorTarget === "analogTick") {
                return i18n("Choose clock marker color")
            }
            if (timedColorTarget === "analogBorder") {
                return i18n("Choose clock border color")
            }
            if (timedColorTarget === "analogFace") {
                return i18n("Choose clock face color")
            }
        }
        return selectedItemType === "calendar" ? i18n("Choose calendar color") : i18n("Choose clock color")
    }
    // qmllint enable unqualified

    function timedColorValue() {
        if (timedColorTarget === "background") {
            return calendarBackgroundColor.text
        }
        if (timedColorTarget === "accent") {
            return calendarAccentColor.text
        }
        if (timedColorTarget === "border") {
            return calendarBorderColor.text
        }
        if (timedColorTarget === "analogAccent") {
        return clockColor.text
        }
        if (timedColorTarget === "analogTick") {
        return ""
        }
        if (timedColorTarget === "analogBorder") {
        return ""
        }
        if (timedColorTarget === "analogFace") {
        return ""
        }
        return ""
    }

    function timedFallbackColor() {
        if (timedColorTarget === "background") {
            return Kirigami.Theme.backgroundColor
        }
        if (timedColorTarget === "accent") {
            return Kirigami.Theme.highlightColor
        }
        if (timedColorTarget === "border") {
            return Kirigami.Theme.textColor
        }
        if (timedColorTarget === "analogAccent") {
            return Kirigami.Theme.highlightColor
        }
        if (timedColorTarget === "analogTick") {
            return Kirigami.Theme.textColor
        }
        if (timedColorTarget === "analogBorder") {
            return Kirigami.Theme.disabledTextColor
        }
        if (timedColorTarget === "analogFace") {
            return Kirigami.Theme.backgroundColor
        }
        return Kirigami.Theme.textColor
    }

    function openTimedColorDialog(target) {
        itemDraftController.clearExternalOperation()
        timedColorTarget = target || "text"
        clockColorDialog.open()
    }

    function defaultTrashSoundFolder() {
        var slash = defaultTrashEmptySound.lastIndexOf("/")
        return slash > 0 ? defaultTrashEmptySound.substring(0, slash) : "/usr/share/sounds"
    }

    function openTrashSoundPicker() {
        itemDraftController.clearExternalOperation()
        trashSoundFileDialog.open()
    }

    function setTrashEmptySound(path) {
        trashDialog.soundPath = path && String(path).length > 0 ? String(path) : defaultTrashEmptySound
        applyItemForm()
    }

    function resolvedTrashEmptySound() {
        return trashDialog.soundPath.length > 0 ? trashDialog.soundPath : defaultTrashEmptySound
    }

    function fileName(path) {
        return ConfigItemsControllerJS.fileName(path)
    }

    function playTrashEmptySoundPreview() {
        var configuredSound = resolvedTrashEmptySound()
        runtimeService.playSound(configuredSound, "trash-empty")
    }

    // qmllint disable unqualified
    function availableFonts(includeEmpty) {
        var result = []
        if (includeEmpty) {
            result.push(i18n("Automatic"))
        }
        try {
            var fonts = Qt.fontFamilies()
            if (fonts && fonts.length > 0) {
                return result.concat(fonts.sort())
            }
        } catch (error) {
        }
        return result.concat(fontChoices)
    }

    function selectedClockFontFamily() {
        return ""
    }

    function selectedComboFont(combo) {
        return ConfigItemsControllerJS.selectedComboFont(combo.editText, combo.currentText, i18n("Automatic"))
    }

    function displayFontName(value) {
        return ConfigItemsControllerJS.displayFontName(value, i18n("Automatic"))
    }
    // qmllint enable unqualified

    function shellQuote(text) {
        return ConfigScriptsJS.shellQuote(text)
    }

    function iconPreviewSource(name) {
        return ConfigItemsJS.iconPreviewSource(name)
    }

    function appIconWithCommandFallback(icon, command) {
        return ConfigItemsJS.appIconWithCommandFallback(icon, command)
    }

    function autofillAppIconFromCommand() {
        var icon = appIconWithCommandFallback(actionDialog.appIconText, actionDialog.appCommandText)
        if (icon !== actionDialog.appIconText) {
            actionDialog.appIconText = icon
        }
        var appId = ConfigItemsJS.applicationIdForCommand(actionDialog.appCommandText)
        var currentStoredId = ConfigItemsJS.normalizedApplicationId(actionDialog.appStorageId || actionDialog.appApplicationId)
        if (appId.length > 0) {
            if (actionDialog.appStorageId.length > 0 && currentStoredId !== appId) {
                actionDialog.appStorageId = ""
            }
            actionDialog.appApplicationId = appId
        } else if (actionDialog.appStorageId.length === 0) {
            actionDialog.appApplicationId = ""
        }
        if (appId.length === 0) {
            return
        }
        if (actionDialog.appIconText.length > 0 && actionDialog.appIconText !== "application-x-executable" && actionDialog.appIconText !== appId) {
            return
        }
        actionDialog.appIconText = appId
    }

    function clone(value) {
        return ConfigItemsJS.clone(value)
    }

    function hasItemType(type) {
        for (var index = 0; index < items.length; index++) {
            if (items[index] && items[index].type === type) {
                return true
            }
        }
        return false
    }

        function selectedItem() { return StateHelper.selectedItem() }

        function selectedAction() { return StateHelper.selectedAction() }

        function itemIconText() { return StateHelper.itemIconText() }

        function showSelectedItem() { StateHelper.showSelectedItem() }

        function showSelectedAction() { StateHelper.showSelectedAction() }

        function selectItem(index) { StateHelper.selectItem(index) }

        function compactListHeight(count, minRows, maxRows) { return StateHelper.compactListHeight(count, minRows, maxRows) }

    function setItems(nextItems, markAsChanged) {
        items = DockLogic.withSingletonItems(clone(nextItems))
        // Loading a non-empty model must not turn the explicit no-selection
        // state into the first row. Add, move, remove and pending-edit flows set
        // their intended index before reaching this normalization.
        selectedIndex = ConfigItemsControllerJS.normalizedItemSelectionIndex(
            selectedIndex, items.length)
        refreshFromItems(markAsChanged)
        mainView.clearMultiSelection()
        consumePendingEditRequest()
    }

    function openExistingApplicationCatalog() {
        if (selectedIndex < 0 || selectedIndex >= items.length
                || String(items[selectedIndex].type || "") !== "app") return
        catalogExistingItemIndex = selectedIndex
        openApplicationCatalog("existing-app")
    }

    function openApplicationCatalog(destination) {
        catalogDialog.applications = installedAppCatalog
        catalogDialog.loading = !installedAppCatalogLoaded
        catalogDialog.start(destination || "dock")
        if (!installedAppCatalogLoaded)
            Qt.callLater(function() { systemDiscovery.requestCatalog() })
    }

    function addSelectedCatalogApplications(apps, destination) {
        if (!apps || apps.length === 0) return
        if (destination === "existing-app") {
            if (catalogExistingItemIndex < 0
                    || selectedIndex !== catalogExistingItemIndex
                    || selectedIndex >= items.length
                    || String(items[selectedIndex].type || "") !== "app") return
            applyDiscoveredApplication(apps[0])
            return
        }
        if (destination === "draft-app") {
            if (itemDraftController.draft === null
                    || String(itemDraftController.draftType) !== "app") return
            itemDraftController.applyDiscoveredApplication(
                itemDraftController.generation, apps[0])
            itemConfigurationDialog.refreshEditorFields()
            return
        }
        if (destination === "draft-folder") {
            if (!itemDraftController.draft || itemDraftController.draftType !== "folder"
                    || String(itemDraftController.draft.sourceType || "manual") !== "manual") return
            let added = 0
            for (const app of apps) {
                const result = itemDraftController.addDroppedApplication(
                    itemDraftController.generation, app)
                if (result.changed) added++
            }
            if (added > 0)
                itemConfigurationDialog.nestedListChanged(itemDraftController.nestedCount() - 1)
            return
        }
        if (destination === "folder-existing") {
            const current = selectedItem()
            if (!current || String(current.type || "") !== "folder"
                    || String(current.sourceType || "manual") !== "manual") return
            let nextItems = items
            let changed = 0
            for (const app of apps) {
                const result = ConfigItemsJS.addApplicationToManualContainer(
                    nextItems, selectedIndex, app)
                if (result.changed) {
                    nextItems = result.items
                    changed++
                }
            }
            if (changed > 0) {
                selectedActionIndex = nextItems[selectedIndex].apps.length - 1
                items = nextItems
                refreshFromItems()
                Qt.callLater(showSelectedAction)
            }
            return
        }
        // Dock: write all selected launchers in one model/KCM transaction.
        const nextItems = clone(items)
        const seen = {}
        const seenCommands = {}
        for (const entry of nextItems) {
            if (entry.type !== "app") continue
            const key = ConfigItemsJS.normalizedApplicationId(
                entry.storageId || entry.appId
                || ConfigItemsJS.applicationIdForCommand(entry.command || "") || "").toLowerCase()
            if (key) seen[key] = true
            const command = String(entry.command || "").trim().toLowerCase()
            if (command) seenCommands[command] = true
        }
        let added = 0
        for (const app of apps) {
            const command = String(app.command || "").trim()
            const storage = String(app.storageId || "").trim()
            const key = ConfigItemsJS.normalizedApplicationId(
                storage || app.appId || "").toLowerCase()
            if (!command || !storage || !key || seen[key]
                    || seenCommands[command.toLowerCase()]) continue
            const entry = {
                type: "app", name: String(app.name || storage),
                icon: String(app.icon || "application-x-executable"),
                command: command,
                storageId: storage,
                appId: String(app.appId || key),
                launcherUrl: String(app.launcherUrl || "applications:" + storage)
            }
            if (app.description) entry.description = String(app.description)
            ConfigItemsJS.pruneApp(entry)
            nextItems.push(entry)
            seen[key] = true
            seenCommands[command.toLowerCase()] = true
            added++
        }
        if (added > 0) {
            selectedIndex = nextItems.length - 1
            setItems(nextItems)
            mainView.positionAtIndex(selectedIndex)
            mainView.showStatus(i18ncp("@info:status", "%1 application added", "%1 applications added", added),
                Kirigami.MessageType.Positive) // qmllint disable unqualified
        } else {
            mainView.showStatus(i18nc("@info:status", "No new applications were added (duplicates or invalid entries)."),
                Kirigami.MessageType.Information) // qmllint disable unqualified
        }
    }

    function openManualCatalogEntry(destination) {
        if (destination === "draft-folder") {
            itemConfigurationDialog.nestedListChanged(
                itemDraftController.addNestedEntry())
        } else if (destination === "folder-existing") {
            addAction()
        } else openAddItemDialog()
    }

    function openAddItemDialog() {
        focusNewItemAfterDialogClose = false
        itemConfigurationDialog.mediaApplications = []
        itemConfigurationDialog.openFor("app")
    }

    function acceptAddedItem(item) {
        if (!item) {
            return
        }
        const nextItems = clone(items)
        nextItems.push(clone(item))
        selectedIndex = nextItems.length - 1
        setItems(nextItems)
        const impact = ConfigItemsJS.itemAdditionImpact(item.type)
        if (impact.enableActiveTasks) {
            cfg_showActiveTasks = true
        }
        focusNewItemAfterDialogClose = true
        mainView.positionAtIndex(selectedIndex)
    }

    function finishAddItemDialog() {
        itemDraftController.clearExternalOperation()
        itemConfigurationDialog.mediaApplications = []
        if (focusNewItemAfterDialogClose && selectedIndex >= 0) {
            mainView.focusItemAtIndex(selectedIndex)
        } else {
            mainView.focusAddItemButton()
        }
        focusNewItemAfterDialogClose = false
    }

    function requestDraftApplicationSearch(text) {
        const query = String(text || "").trim()
        if (query.length === 0 || itemDraftController.draft === null
                || String(itemDraftController.draftType) !== "app") {
            return
        }
        const requestId = itemDraftController.beginExternalOperation(
            "application-search", "application", {})
        if (requestId > 0) {
            systemDiscovery.requestApplication(query, requestId)
        }
    }

    function requestDraftMediaApplications() {
        if (itemDraftController.draft === null
                || String(itemDraftController.draftType) !== "media") {
            return
        }
        itemConfigurationDialog.mediaApplications = []
        const requestId = itemDraftController.beginExternalOperation(
            "media-applications", "media", {})
        if (requestId > 0) {
            systemDiscovery.requestApplications("AudioVideo", requestId)
        }
    }

    function showDiscoveryFailure(message, requestId) {
        if (requestId > 0) {
            const operation = itemDraftController.takeExternalOperation("", requestId)
            if (operation === null) {
                return
            }
            if (String(operation.kind) === "container-folder"
                    || String(operation.kind) === "container-applications") {
                // Draft feedback belongs to its modal, never to the page below it.
                itemConfigurationDialog.showContainerLoadStatus(
                    i18n("System operation failed: %1", message), // qmllint disable unqualified
                    Kirigami.MessageType.Error)
                return
            }
        }
        mainView.showStatus(i18n("System operation failed: %1", message), // qmllint disable unqualified
            Kirigami.MessageType.Error)
    }

    function requestDraftContainerContent() {
        itemConfigurationDialog.clearContainerLoadStatus()
        const draft = itemDraftController.draft
        if (!draft || String(itemDraftController.draftType) !== "folder") {
            return
        }
        const source = String(draft.sourceType || "manual")
        if (source === "folder") {
            const path = String(draft.sourcePath || "").trim()
            if (path.length === 0) {
                // qmllint disable unqualified
                itemConfigurationDialog.showContainerLoadStatus(i18n("Choose a folder first."),
                    Kirigami.MessageType.Warning)
                // qmllint enable unqualified
                return
            }
            const requestId = itemDraftController.beginExternalOperation(
                "container-folder", "folder", {"path": path})
            if (requestId > 0) {
                systemDiscovery.requestFolderEntries(path, requestId)
            }
        } else if (source === "category") {
            const category = String(draft.sourceCategory || "Development")
            const requestId = itemDraftController.beginExternalOperation(
                "container-applications", "category", {"category": category})
            if (requestId > 0) {
                systemDiscovery.requestApplications(category, requestId)
            }
        }
    }

    function openDraftIconPicker(target) {
        const requestId = itemDraftController.beginExternalOperation(
            "icon", target, {"nestedIndex": itemConfigurationDialog.selectedActionIndex})
        if (requestId > 0) {
            iconPicker.open()
        }
    }

    function openDraftFolderPicker() {
        const requestId = itemDraftController.beginExternalOperation(
            "folder-picker", "sourcePath", {})
        if (requestId > 0) {
            containerFolderDialog.open()
        }
    }

    function openDraftSoundPicker() {
        const requestId = itemDraftController.beginExternalOperation(
            "sound-picker", "emptySound", {})
        if (requestId > 0) {
            trashSoundFileDialog.open()
        }
    }

    function openDraftColorPicker(target) {
        const requestId = itemDraftController.beginExternalOperation(
            "color-picker", target, {})
        if (requestId > 0) {
            clockColorDialog.open()
        }
    }

    function chooseFolder(path) {
        const operation = itemDraftController.takeExternalOperation(
            "folder-picker")
        if (operation !== null) {
            itemConfigurationDialog.invalidateContainerLoad()
            itemDraftController.applyExternalValue(
                Number(operation.generation), "folder", "sourcePath",
                String(path || ""))
            itemConfigurationDialog.refreshEditorFields()
            return
        }
        setContainerFolder(path)
    }

    function chooseTrashSound(path) {
        const operation = itemDraftController.takeExternalOperation(
            "sound-picker")
        if (operation !== null) {
            itemDraftController.applyExternalValue(
                Number(operation.generation), "trash", "emptySound",
                String(path || defaultTrashEmptySound))
            return
        }
        setTrashEmptySound(path)
    }

    function chooseTimedColor(value) {
        const operation = itemDraftController.takeExternalOperation(
            "color-picker")
        if (operation !== null) {
            itemDraftController.applyExternalValue(
                Number(operation.generation), "calendar", "color",
                String(value || ""))
            return
        }
        applyTimedColor(value)
    }

    function playDraftTrashSoundPreview() {
        const draft = itemDraftController.draft
        if (!draft || String(itemDraftController.draftType) !== "trash") {
            return
        }
        runtimeService.playSound(String(draft.emptySound
            || defaultTrashEmptySound), "trash-empty")
    }

    function addApplicationLauncherToDraft(urls) {
        const validation = validateApplicationLauncherDrop(urls)
        const draft = itemDraftController.draft
        const containerName = String(draft ? draft.name || "" : "")
        const applicationName = String(validation
            ? validation.name || validation.storageId || "" : "")
        const result = validation && validation.accepted
            ? itemDraftController.addDroppedApplication(
                itemDraftController.generation, validation)
            : {"changed": false, "status": "invalid-application"}
        itemConfigurationDialog.showApplicationDropResult(
            containerApplicationDropMessage(result.status,
                applicationName, containerName), !result.changed)
        if (result.changed) {
            itemConfigurationDialog.nestedListChanged(
                itemDraftController.nestedCount() - 1)
        }
        return result.changed
    }

    function consumePendingEditRequest() {
        const pendingIndex = parseInt(cfg_pendingEditDockItemIndex, 10)
        if (!diskItemsLoaded || pendingEditConsumed
                || isNaN(pendingIndex) || pendingIndex < 0) {
            return
        }

        pendingEditConsumed = true
        Plasmoid.configuration.pendingEditDockItemIndex = -1
        // KConfigPropertyMap exposes writeConfig() as Q_INVOKABLE, but its
        // generated QML type metadata does not advertise the method.
        // qmllint disable missing-property
        Plasmoid.configuration.writeConfig()
        // qmllint enable missing-property
        cfg_pendingEditDockItemIndex = -1
        if (pendingIndex >= items.length) {
            return
        }
        Qt.callLater(function() {
            page.selectItem(pendingIndex)
            page.configureSelectedItem()
        })
    }

    // R57: quick editing reuses the existing KCM draft and model refresh.
    // No disk write is performed here: Apply/OK remain the persistence boundary.
    function quickRenameSelectedItem(name) {
        const index = Number(selectedIndex)
        const proposed = String(name || "").trim()
        if (!Number.isInteger(index) || index < 0 || index >= items.length
                || proposed.length === 0) return false
        const current = items[index]
        const type = String(current.type || "app")
        if (type !== "app" && type !== "folder" && type !== "note") return false
        if (String(current.name || "") === proposed) return false
        const updated = clone(items)
        updated[index].name = proposed
        setItems(updated)
        return true
    }

    function markChanged() {
        if (!syncing) {
            updatingConfigJson = true
            cfg_dockItemsJson = JSON.stringify(items, null, 4)
            Qt.callLater(function() {
                updatingConfigJson = false
            })
        }
    }

    function syncItemsFromConfigJson() {
        if (!diskItemsLoaded || syncing || loadingFromDisk || updatingConfigJson || !cfg_dockItemsJson || cfg_dockItemsJson.length === 0) {
            return
        }

        if (JSON.stringify(items, null, 4) === cfg_dockItemsJson) {
            return
        }

        var result = ConfigItemsJS.parseJsonArrayForPreview(cfg_dockItemsJson)
        if (!result.ok) {
            return
        }

        loadingFromDisk = true
        try {
            setItems(result.items, false)
        } finally {
            loadingFromDisk = false
        }
    }

        function refreshFromItems(markAsChanged) { FormHelper.refreshFromItems(markAsChanged) }

        function refreshItemForm() { FormHelper.refreshItemForm() }

        function refreshActions() { FormHelper.refreshActions() }

        function refreshActionForm() { FormHelper.refreshActionForm() }

        function applyItemForm(force) { FormHelper.applyItemForm(force) }

    function setAppActionsEnabled(enabled) { WorkflowHelper.setAppActionsEnabled(enabled) }

    function setSelectedItemMode(mode) { WorkflowHelper.setSelectedItemMode(mode) }

    function setContainerSource(source) { WorkflowHelper.setContainerSource(source) }

    function setContainerLayout(layout) { WorkflowHelper.setContainerLayout(layout) }

    function setContainerCategory(category) { WorkflowHelper.setContainerCategory(category) }

    function openContainerFolderPicker() { WorkflowHelper.openContainerFolderPicker() }

    function setContainerFolder(path) { WorkflowHelper.setContainerFolder(path) }

    function refreshContainerContent() { WorkflowHelper.refreshContainerContent() }

    function validateApplicationLauncherDrop(urls) {
        return systemDiscovery.validateApplicationLauncherDrop(urls || [])
    }

    // qmllint disable unqualified
    function containerApplicationDropMessage(status, applicationName,
            containerName) {
        if (status === "added") {
            return i18nc("@info:status", "%1 was added to %2.",
                applicationName, containerName)
        }
        if (status === "duplicate") {
            return i18nc("@info:status", "%1 is already in %2.",
                applicationName, containerName)
        }
        if (status === "managed-container") {
            return i18nc("@info:status",
                "%1 is updated automatically. Change its content source to Manual before adding applications.",
                containerName)
        }
        if (status === "invalid-target") {
            return i18nc("@info:status",
                "The target container changed before the application could be added.")
        }
        return i18nc("@info:status",
            "The dropped launcher could not be resolved safely.")
    }
    // qmllint enable unqualified

    function addApplicationLauncherToSelectedContainer(urls) {
        const validation = page.validateApplicationLauncherDrop(urls)
        const item = page.selectedItem()
        const containerName = String(item ? item.name || "" : "")
        const applicationName = String(validation
            ? validation.name || validation.storageId || "" : "")
        const result = validation && validation.accepted
            ? WorkflowHelper.addApplicationLauncherToSelectedContainer(
                validation)
            : {
                "changed": false,
                "status": "invalid-application",
                "container": item || null
            }
        actionDialog.applicationLauncherDropMessage
            = page.containerApplicationDropMessage(result.status,
                applicationName, containerName)
        actionDialog.applicationLauncherDropMessageIsError = !result.changed
        return result.changed
    }

        function applyDiscoveredApplication(application) { FormHelper.applyDiscoveredApplication(application) }

        function applyContainerApps(apps) { FormHelper.applyContainerApps(apps) }

    function openAppActionsDialog(index) { WorkflowHelper.openAppActionsDialog(index) }

    function showFolderConfigDisabled(index) { WorkflowHelper.showFolderConfigDisabled(index) }

    function openTrashDialog(index) { WorkflowHelper.openTrashDialog(index) }

    function openTimedDialog(index) { WorkflowHelper.openTimedDialog(index) }

    function openMediaPlayerDialog(index) { WorkflowHelper.openMediaPlayerDialog(index) }

    function openPunchiMenuDialog(index) { WorkflowHelper.openPunchiMenuDialog(index) }

    function openControlCenterDialog(index) { WorkflowHelper.openControlCenterDialog(index) }

    function setPunchiMenuMode(mode) { WorkflowHelper.setPunchiMenuMode(mode) }

    function setControlCenterMode(mode) { WorkflowHelper.setControlCenterMode(mode) }

    function setPunchiMenuIcon(iconName) { WorkflowHelper.setPunchiMenuIcon(iconName) }

    function setMediaDefaultPlayer(application) { WorkflowHelper.setMediaDefaultPlayer(application) }
    function setMediaCustomOption(key, value) { WorkflowHelper.setMediaCustomOption(key, value) }

    function setMediaTextMode(mode) { WorkflowHelper.setMediaTextMode(mode) }

    function setMediaDisplayMode(mode) { WorkflowHelper.setMediaDisplayMode(mode) }

    function setMediaOpenPlayerMinimized(enabled) { WorkflowHelper.setMediaOpenPlayerMinimized(enabled) }

    function setMediaAutoCollapseDelaySeconds(seconds) { WorkflowHelper.setMediaAutoCollapseDelaySeconds(seconds) }

    function selectedConfigureTitle() { return WorkflowHelper.selectedConfigureTitle() }

    function canConfigureSelectedItem() { return WorkflowHelper.canConfigureSelectedItem() }

    function configureSelectedItem() { WorkflowHelper.configureSelectedItem() }

        function applyActionForm(force) { FormHelper.applyActionForm(force) }

    function openIconPicker(target) {
        itemDraftController.clearExternalOperation()
        iconPickerTarget = target || "item"
        iconPicker.open()
    }

    function chooseIcon(iconName) {
        var selectedIcon = String(iconName || "")
        if (selectedIcon.length === 0) {
            return
        }

        const draftOperation = itemDraftController.takeExternalOperation("icon")
        if (draftOperation !== null) {
            itemConfigurationDialog.applyPickedIcon(
                draftOperation, selectedIcon)
            return
        }

        if (iconPickerTarget === "action") {
            actionDialog.actionIconText = selectedIcon
            applyActionForm()
            return
        }

        if (iconPickerTarget === "trashFull") {
            trashDialog.fullIconText = selectedIcon
            applyItemForm()
            return
        }

        if (iconPickerTarget === "trash") {
            trashDialog.emptyIconText = selectedIcon
            applyItemForm()
            return
        }

        if (iconPickerTarget === "punchimenu") {
            setPunchiMenuIcon(selectedIcon)
            return
        }

        actionDialog.appIconText = selectedIcon
        applyItemForm()
    }

    function applyTimedColor(value) { WorkflowHelper.applyTimedColor(value) }

    function applyClockColor(value) { WorkflowHelper.applyClockColor(value) }

    function removeSelectedItem() { WorkflowHelper.removeSelectedItem() }

    function confirmDynamicApplicationsRemoval() {
        WorkflowHelper.confirmDynamicApplicationsRemoval()
    }

    // R61: move selected launchers atomically without rebuilding the model. The
    // pure helper returns original-index identities and the new contiguous group.
    function moveItemGroupToIndex(indexes, targetIndex, after) {
        const result = DockMultiSelectJS.moveGroup(items, indexes, targetIndex, after)
        if (!result.changed) return false
        const originallySelected = selectedIndex
        const arrangement = []
        for (let i = 0; i < items.length; i++) arrangement.push(i)
        selectedIndex = result.order.indexOf(originallySelected)
        lastMovedGroupIndices = result.selected.slice()
        items = result.items
        // Apply ListModel.move so the old animated delegates keep their identity.
        for (let target = 0; target < result.order.length; target++) {
            const original = result.order[target]
            const source = arrangement.indexOf(original)
            if (source === target) continue
            itemModel.move(source, target, 1)
            arrangement.splice(source, 1)
            arrangement.splice(target, 0, original)
        }
        for (let index = 0; index < itemModel.count; index++)
            itemModel.setProperty(index, "sourceIndex", index)
        refreshItemForm()
        refreshActions()
        markChanged()
        Qt.callLater(function() {
            if (result.selected.length > 0)
                mainView.positionAtIndex(result.selected[0])
        })
        return true
    }

    // R58: A single atomic drop changes the configured order, not the live
    // TaskManager runtime. Keep the selected identity even when other rows move;
    // commit to cfg_dockItemsJson only through the existing KCM save lifecycle.
    function moveItemToIndex(sourceIndex, targetIndex) {
        const from = Number(sourceIndex)
        const to = Number(targetIndex)
        if (!DockPreviewReorderJS.validMove(from, to, items.length)) return false
        const nextSelection = selectedIndex < 0 ? to
            : DockPreviewReorderJS.selectionAfterMove(selectedIndex, from, to)
        const moved = ConfigItemsJS.moveItem(items, from, to)
        selectedIndex = nextSelection
        if (itemModel.count !== moved.items.length) {
            setItems(moved.items)
            return true
        }
        items = moved.items
        itemModel.move(from, to, 1)
        for (let index = 0; index < itemModel.count; index++)
            itemModel.setProperty(index, "sourceIndex", index)
        refreshItemForm()
        refreshActions()
        markChanged()
        Qt.callLater(function() { mainView.positionAtIndex(to) })
        return true
    }

    function moveSelectedItem(delta) { WorkflowHelper.moveSelectedItem(delta) }

    function addAction() { WorkflowHelper.addAction() }

    function removeAction() { WorkflowHelper.removeAction() }

    function moveAction(delta) { WorkflowHelper.moveAction(delta) }

    function loadItems() { WorkflowHelper.loadItems() }

    // R62.2: let Plasma finish constructing/showing this configuration page
    // before populating the icon model. This avoids synchronous JSON parsing
    // and ListModel rebuild inside the category activation call stack.
    // The existing cfg_dockItemsJson and pending-edit guards still apply.
    Component.onCompleted: Qt.callLater(loadItems)

    onCfg_dockItemsJsonChanged: syncItemsFromConfigJson()
    onCfg_pendingEditDockItemIndexChanged: consumePendingEditRequest()
    onDiskItemsLoadedChanged: {
        if (diskItemsLoaded) {
            consumePendingEditRequest()
        }
    }

    Component.onDestruction: {
        if (pendingEditConsumed) {
            cfg_pendingEditDockItemIndex = -1
        }
    }

    ListModel {
        id: itemModel
    }

    ItemDraftController {
        id: itemDraftController

        items: page.items
        defaultTrashEmptySound: page.defaultTrashEmptySound
    }

    Connections {
        target: itemDraftController

        function onDraftStarted() {
            itemConfigurationDialog.mediaApplications = []
            if (String(itemDraftController.draftType) === "media") {
                Qt.callLater(page.requestDraftMediaApplications)
            }
        }

        function onItemAccepted(item) {
            page.acceptAddedItem(item)
        }
    }

    ItemConfigurationDialog {
        id: itemConfigurationDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay

        // The dialog's own implicit geometry fits its current form to the KCM.
        // R50 was inadvertently overridden by an older 40x26-grid-unit cap.
        draftController: itemDraftController
        applicationLauncherDropValidator: function(urls) {
            return page.validateApplicationLauncherDrop(urls)
        }
        onApplicationSearchRequested: function(text) {
            page.requestDraftApplicationSearch(text)
        }
        onIconPickerRequested: function(target) {
            page.openDraftIconPicker(target)
        }
        onFolderPickerRequested: page.openDraftFolderPicker()
        onContentLoadRequested: page.requestDraftContainerContent()
        onApplicationLauncherDropped: function(urls) {
            page.addApplicationLauncherToDraft(urls)
        }
        onSoundPickerRequested: page.openDraftSoundPicker()
        onSoundPreviewRequested: page.playDraftTrashSoundPreview()
        onColorPickerRequested: function(target) {
            page.openDraftColorPicker(target)
        }
        onApplicationCatalogRequested: page.openApplicationCatalog("draft-folder")
        onApplicationPickerRequested: page.openApplicationCatalog("draft-app")
        onSurfaceClosed: page.finishAddItemDialog()
    }

    ApplicationCatalogDialog {
        id: catalogDialog
        onClosed: page.catalogExistingItemIndex = -1
        onApplicationsChosen: function(apps, destination) {
            page.addSelectedCatalogApplications(apps, destination)
        }
        onManualEntryRequested: function(destination) {
            page.openManualCatalogEntry(destination)
        }
    }

    ListModel {
        id: actionModel
    }





    Timer {
        id: statusHideTimer
        interval: 3500
        repeat: false
        onTriggered: mainView.clearStatus()
    }

    KIconThemes.IconDialog {
        id: iconPicker
        title: i18n("Choose icon") // qmllint disable unqualified
        iconSize: 48
        modality: Qt.WindowModal
        onAccepted: page.chooseIcon(iconName)
        onRejected: itemDraftController.clearExternalOperation()
    }

    FolderPathDialog {
        id: containerFolderDialog
        titleText: i18n("Choose folder") // qmllint disable unqualified
        onFolderChosen: (path) => page.chooseFolder(path)
        onRejected: itemDraftController.clearExternalOperation()
    }

    Controls.Dialog {
        id: dynamicApplicationsRemovalDialog
        objectName: "dynamicApplicationsRemovalDialog"
        modal: true
        title: i18n("Remove open applications from the dock?") // qmllint disable unqualified
        standardButtons: Controls.Dialog.Cancel | Controls.Dialog.Ok
        anchors.centerIn: parent
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2,
            Kirigami.Units.gridUnit * 30)

        onAccepted: page.confirmDynamicApplicationsRemoval()
        onRejected: page.pendingRemovalIndex = -1

        Component.onCompleted: {
            standardButton(Controls.Dialog.Ok).text = i18n("Remove and disable") // qmllint disable unqualified
            standardButton(Controls.Dialog.Ok).icon.name = "edit-delete"
        }

        Controls.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18n("Removing this item will also disable Show active windows in the dock. You can enable it again from the Windows settings.") // qmllint disable unqualified
        }
    }

    ColorPaletteDialog {
        id: clockColorDialog
        title: page.timedChooseColorTitle()
        width: Math.min(page.width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 24)
        currentColor: itemDraftController.externalOperationMatches(
            "color-picker") && itemDraftController.draft !== null
            ? String(itemDraftController.draft.color || "")
            : page.timedColorValue()
        fallbackColor: page.timedFallbackColor()
        onColorChosen: (color) => page.chooseTimedColor(color)
        onCancelled: itemDraftController.clearExternalOperation()
    }

    // qmllint disable unqualified
    ActionDialog {
        id: actionDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        title: page.selectedConfigureTitle()
        // ActionDialog now calculates a per-item natural width and clamps
        // it to the viewport; no obsolete 32-grid-unit cap here.
        actionModel: actionModel
        selectedActionIndex: page.selectedActionIndex
        selectedItemIndex: page.selectedIndex
        selectedItemType: page.selectedItemType
        rowHeight: page.listRowHeight
        footerHeight: page.listFooterHeight
        framePadding: page.listFramePadding
        scrollGutter: page.listScrollGutter
        canMoveActionDown: {
            var item = page.selectedItem()
            var rows = item && item.type === "folder" ? item.apps : (item ? item.actions : [])
            return Boolean(rows) && page.selectedActionIndex >= 0
                && page.selectedActionIndex < rows.length - 1
        }
        nameLabel: i18n("Name:")
        aliasLabel: i18n("Alias/Quick Search:")
        descLabel: i18n("Description:")
        aliasPlaceholder: i18n("Type name or alias... then search")
        itemTypeLabel: i18n("Type:")
        launchAppText: i18n("Launch app")
        containerText: i18n("Container")
        viewLabel: i18n("View:")
        gridText: i18n("Grid")
        listText: i18n("List")
        detailedText: i18n("Detailed")
        fanText: i18nc("@item:inlistbox Folder popup layout", "Fan")
        noteText: i18n("Note")
        separatorText: i18n("Separator")
        spacerText: i18n("Spacer")
        iconLabel: i18n("Icon:")
        commandLabel: i18n("Command:")
        spacerSizeLabel: i18n("Spacer size:")
        chooseIconText: i18n("Choose icon")
        rightClickCommandsText: i18n("Right-click commands")
        containerApplicationsText: i18n("Container applications")
        containerSourceLabel: i18n("Content:")
        manualContainerText: i18n("Manual")
        folderContainerText: i18n("Folder")
        categoryContainerText: i18n("Application category")
        folderPathLabel: i18n("Folder:")
        categoryLabel: i18n("Category:")
        refreshContentText: i18n("Load content")
        enableRightClickMenuText: i18n("Enable right-click menu")
        limitContextMenuRowsText: i18n("Limit menu rows")
        rowsText: i18n("rows")
        rowsValueText: i18n("%1 rows", "%1")
        actionNameLabel: page.selectedItemType === "folder" ? i18n("App name:") : i18n("Action name:")
        actionIconLabel: page.selectedItemType === "folder" ? i18n("App icon:") : i18n("Action icon:")
        actionCommandLabel: page.selectedItemType === "folder" ? i18n("App command:") : i18n("Action command:")
        dropApplicationsHereText: i18nc("@info:placeholder", "Drop applications here")
        addApplicationText: i18nc("@action:button", "Add application")
        addActionText: i18nc("@action:button", "Add action")
        applicationLauncherDropValidator: function(urls) {
            return page.validateApplicationLauncherDrop(urls)
        }
        onFormChanged: page.applyItemForm()
        onItemModeChanged: function(mode) { page.setSelectedItemMode(mode) }
        onContainerLayoutChanged: function(layout) { page.setContainerLayout(layout) }
        onContainerSourceChanged: function(source) { page.setContainerSource(source) }
        onContainerCategoryChanged: function(category) { page.setContainerCategory(category) }
        onFolderPickerRequested: page.openContainerFolderPicker()
        onContainerRefreshRequested: page.refreshContainerContent()
        onAppCommandEdited: {
            page.autofillAppIconFromCommand()
            page.applyItemForm()
        }
        onAutofillRequested: function(alias) {
            if (alias && alias.length > 0) {
                systemDiscovery.requestApplication(alias)
            }
        }
        onIconPickerRequested: function(target) { page.openIconPicker(target) }
        onActionsEnabledToggled: function(checked) { page.setAppActionsEnabled(checked) }
        onActionPopupSettingsChanged: page.applyItemForm()
        onActionSelected: function(index) {
            page.selectedActionIndex = index
            page.refreshActionForm()
            page.showSelectedAction()
        }
        onAddActionRequested: page.addAction()
        onApplicationCatalogRequested: page.openApplicationCatalog("folder-existing")
        onBrowseApplicationsRequested: page.openExistingApplicationCatalog()
        onMoveActionRequested: function(delta) { page.moveAction(delta) }
        onRemoveActionRequested: page.removeAction()
        onActionFormChanged: page.applyActionForm()
        onApplicationLauncherDropped: function(urls) {
            page.addApplicationLauncherToSelectedContainer(urls)
        }
    }
    // qmllint enable unqualified

    TrashDialog {
        id: trashDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        controller: page
        onFormChanged: page.applyItemForm()
        onEmptyIconPickerRequested: page.openIconPicker("trash")
        onFullIconPickerRequested: page.openIconPicker("trashFull")
        onSoundPreviewRequested: page.playTrashEmptySoundPreview()
        onSoundResetRequested: {
            trashDialog.soundPath = page.defaultTrashEmptySound
            page.applyItemForm()
        }
        onSoundPickerRequested: page.openTrashSoundPicker()
    }

    TimedDialog {
        id: timedDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        controller: page
    }

    MediaPlayerDialog {
        id: mediaPlayerDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        title: i18n("Configure media player") // qmllint disable unqualified
        selectorWidth: layoutMetrics.selectorWidth
        onPlayerSelected: function(application) {
            page.setMediaDefaultPlayer(application)
        }
        onMediaTextModeSelected: function(mode) {
            page.setMediaTextMode(mode)
        }
        onMediaDisplayModeSelected: function(mode) {
            page.setMediaDisplayMode(mode)
        }
        onOpenPlayerMinimizedSelected: function(enabled) {
            page.setMediaOpenPlayerMinimized(enabled)
        }
        onAutoCollapseDelaySecondsSelected: function(seconds) {
            page.setMediaAutoCollapseDelaySeconds(seconds)
        }
        onMediaCustomOptionSelected: function(key, value) {
            page.setMediaCustomOption(key, value)
        }
    }

    PunchiMenuDialog {
        id: punchiMenuDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        selectorWidth: layoutMetrics.selectorWidth
        onMenuModeSelected: function(mode) { page.setPunchiMenuMode(mode) }
        onIconPickerRequested:
            page.openIconPicker("punchimenu")
    }

    ControlCenterDialog {
        id: controlCenterDialog
        // KDE/QtQuick Controls: position modal forms in the enclosing window,
        // not relative to the KCM page which can be narrower than the window.
        parent: Controls.Overlay.overlay
        selectorWidth: layoutMetrics.selectorWidth
        onControlCenterModeSelected: function(mode) {
            page.setControlCenterMode(mode)
        }
    }

    Controls.TextField {
        id: itemCommand
        visible: false
    }

    // qmllint disable unqualified
    SoundFileDialog {
        id: trashSoundFileDialog
        title: i18n("Choose sound")
        startFolder: "file://" + page.defaultTrashSoundFolder()
        audioFilesText: i18n("Audio files")
        allFilesText: i18n("All files")
        onSoundChosen: (path) => page.chooseTrashSound(path)
        onRejected: itemDraftController.clearExternalOperation()
    }
    // qmllint enable unqualified

    ConfigItemsMainView {
        id: mainView
        objectName: "itemsConfigurationMainView"
        controller: page
        itemModel: itemModel
        folderCategoryColors: page.previewFolderCategoryColors
        statusHideTimer: statusHideTimer
        onAddItemRequested: page.openAddItemDialog()
    }
}
