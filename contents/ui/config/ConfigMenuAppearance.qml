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
        diagnosticCategory: "Menus"
    }
    implicitWidth: settings.implicitWidth
    implicitHeight: settings.implicitHeight
    property alias cfg_contextMenuTransitionSpeed: settings.cfg_contextMenuTransitionSpeed
    property alias cfg_contextMenuVisibleRows: settings.cfg_contextMenuVisibleRows
    property alias cfg_contextMenuRowHeight: settings.cfg_contextMenuRowHeight
    property alias cfg_contextMenuIconSize: settings.cfg_contextMenuIconSize
    property alias cfg_contextMenuWidth: settings.cfg_contextMenuWidth
    property alias cfg_contextMenuDistancePercent: settings.cfg_contextMenuDistancePercent
    property alias cfg_contextMenuTransitionDirection: settings.cfg_contextMenuTransitionDirection
    property alias cfg_contextMenuBackgroundOpacityPercent: settings.cfg_contextMenuBackgroundOpacityPercent
    property alias cfg_contextMenuBackgroundBlurEnabled: settings.cfg_contextMenuBackgroundBlurEnabled
    property alias cfg_menuTextShadowsEnabled: settings.cfg_menuTextShadowsEnabled
    property alias cfg_showConfigureDockAction: settings.cfg_showConfigureDockAction
    property alias cfg_menuAnimation: settings.cfg_menuAnimation
    property alias cfg_menuAnimationSpeedPercent: settings.cfg_menuAnimationSpeedPercent
    property alias cfg_menuAnimationIntensity: settings.cfg_menuAnimationIntensity

    ConfigMenus {
        id: settings
        width: page.width
        height: implicitHeight
    }
}
