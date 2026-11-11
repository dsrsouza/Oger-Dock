import org.kde.plasma.configuration

// R62.8: Plasma ConfigModel owns one independent KCM page per subject.
// The old five-tab Appearance megacomponent was split into standalone pages
// to avoid repeatedly constructing dozens of unrelated QML controls.
ConfigModel {
    ConfigCategory {
        name: i18n("Items")
        icon: "kmenuedit"
        source: "config/ConfigItems.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "systemsettings"
        source: "config/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAspect.qml"
    }
    ConfigCategory {
        name: i18nc("@title:settings-category", "Folders")
        icon: "folder"
        source: "config/ConfigFolderAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Menus")
        icon: "open-menu-symbolic"
        source: "config/ConfigMenuAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Window previews")
        icon: "preferences-system-windows"
        source: "config/ConfigWindowPreviews.qml"
    }
    ConfigCategory {
        name: i18n("Audio visualizer")
        icon: "audio-volume-high"
        source: "config/ConfigAudioAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Mouse")
        icon: "input-mouse"
        source: "config/ConfigMouse.qml"
    }
    ConfigCategory {
        name: i18n("Windows")
        icon: "window"
        source: "config/ConfigWindows.qml"
    }
    ConfigCategory {
        name: i18n("Files")
        icon: "text-json"
        source: "config/ConfigFiles.qml"
    }
    ConfigCategory {
        name: i18n("Additional Shortcuts")
        icon: "input-keyboard"
        source: "config/ConfigAdditionalShortcuts.qml"
    }
}
