// SPDX-License-Identifier: GPL-2.0-or-later
// R62.2: active-eye overlay; paths follow the exact white eyes in the 562x591
// transparent OgerMenu icon. No polling, animation loops or layout resizing.
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: root
    property bool active: false
    property color eyeColor: Kirigami.Theme.highlightColor
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        enabled: Kirigami.Units.shortDuration > 0
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }
    Shape {
        // Kirigami.Icon preserves the portrait PNG aspect ratio within its
        // square viewport; preserve the same view box when drawing the eyes.
        anchors.centerIn: parent
        width: 562
        height: 591
        scale: Math.min(root.width / 562, root.height / 591)
        visible: root.visible
        antialiasing: true
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.eyeColor
                PathSvg { path: "M 129,235 L150,230 L156,231 L157,232 L158,253 L162,262 L171,273 L183,280 L195,283 L211,283 L224,280 L232,276 L234,277 L232,281 L224,290 L212,299 L202,304 L210,304 L219,302 L231,297 L241,291 L258,275 L264,265 L267,256 L267,245 L266,244 L258,253 L249,256 L227,246 L188,221 L173,215 L163,214 L151,217 L138,225 Z" }
            }

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.eyeColor
                PathSvg { path: "M 431,236 L426,229 L409,217 L404,215 L388,215 L373,221 L352,233 L333,246 L314,255 L309,256 L303,254 L294,244 L293,244 L292,252 L295,264 L299,271 L306,280 L323,294 L336,300 L347,303 L358,304 L341,294 L328,281 L327,278 L330,277 L343,282 L358,282 L359,283 L370,282 L380,279 L389,273 L397,263 L403,248 L403,236 L405,231 L416,231 Z" }
            }
    }
}
