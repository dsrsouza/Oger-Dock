import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "components"

// R62.8: One KCM per category, in the style of Plasma System Settings.
// The configuration shell reads/writes the cfg_ properties from this root.
KCM.SimpleKCM {
    id: page
    ConfigMaximizedWindowGuard {
        hostWindow: page.Window.window
        diagnosticCategory: "Prévias"
    }
    implicitWidth: settings.implicitWidth
    implicitHeight: settings.implicitHeight
    property string cfg_windowPreviewStyle: "card"
    property string cfg_mediaControlsMode: ""
    property bool cfg_mediaControlsOnHover: false
    readonly property string effectiveMediaControlsMode: {
        const mode = String(cfg_mediaControlsMode || "")
        if (["none", "card", "fullCard", "overlay"].indexOf(mode) >= 0)
            return mode === "overlay" && cfg_windowPreviewStyle === "none" ? "none" : mode
        return cfg_mediaControlsOnHover ? "card" : "none"
    }
    signal configurationChanged()
    property alias cfg_windowPreviewScale: settings.cfg_windowPreviewScale
    property alias cfg_windowPreviewBackgroundOpacityPercent: settings.cfg_windowPreviewBackgroundOpacityPercent
    property alias cfg_mediaCardBackgroundOpacityPercent: settings.cfg_mediaCardBackgroundOpacityPercent
    property alias cfg_windowPreviewFrameSize: settings.cfg_windowPreviewFrameSize
    property alias cfg_windowPreviewInfoMode: settings.cfg_windowPreviewInfoMode
    property alias cfg_windowPreviewTextShadowsEnabled: settings.cfg_windowPreviewTextShadowsEnabled
    property alias cfg_maxPopupRows: settings.cfg_maxPopupRows
    property alias cfg_windowPreviewAnimation: settings.cfg_windowPreviewAnimation
    property alias cfg_windowPreviewAnimationSpeedPercent: settings.cfg_windowPreviewAnimationSpeedPercent
    property alias cfg_windowPreviewAnimationIntensity: settings.cfg_windowPreviewAnimationIntensity

    ConfigPopups {
        id: settings
        width: page.width
        height: implicitHeight
        previewStyle: page.cfg_windowPreviewStyle
        mediaControlsMode: page.effectiveMediaControlsMode
        onPreviewStyleSelected: function(style) {
            if (page.cfg_windowPreviewStyle === style) return
            const disableOverlay = style === "none"
                && page.effectiveMediaControlsMode === "overlay"
            page.cfg_windowPreviewStyle = style
            if (disableOverlay) {
                page.cfg_mediaControlsMode = "none"
                page.cfg_mediaControlsOnHover = false
            }
            page.configurationChanged()
        }
        onMediaControlsModeSelected: function(mode) {
            if (page.cfg_mediaControlsMode === mode) return
            page.cfg_mediaControlsMode = mode
            page.cfg_mediaControlsOnHover = mode !== "none"
            page.configurationChanged()
        }
    }
}
