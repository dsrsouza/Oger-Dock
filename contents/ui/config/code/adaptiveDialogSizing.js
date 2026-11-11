// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Popup sizing in the KCM coordinate space. These pure helpers never change the
// Plasma/KWin window: only the transient settings form sizes itself.
function viewportLimit(parentSize, fallbackSize, margin) {
    const size = Number(parentSize)
    const fallback = Math.max(1, Number(fallbackSize) || 700)
    const viewport = Number.isFinite(size) && size > 0 ? size : fallback
    return Math.max(1, viewport - 2 * Math.max(0, Number(margin) || 0))
}

function boundedWidth(desired, parentWidth, margin, fallbackWidth) {
    const want = Number(desired)
    const fallback = Math.max(1, Number(fallbackWidth) || 700)
    const target = Number.isFinite(want) && want > 0 ? want : fallback
    return Math.min(target, viewportLimit(parentWidth, fallback, margin))
}

function boundedHeight(contentHeight, chromeHeight, parentHeight, margin,
                       fallbackHeight, minimumHeight) {
    const body = Math.max(0, Number(contentHeight) || 0)
    const chrome = Math.max(0, Number(chromeHeight) || 0)
    const minimum = Math.max(1, Number(minimumHeight) || 1)
    const wanted = Math.max(minimum, body + chrome)
    return Math.min(wanted, viewportLimit(parentHeight, fallbackHeight, margin))
}

// R52: single, type-agnostic sizing rule for both existing-item editors and
// add-item drafts. Each visible section provides its own intrinsic width hint.
// Do not infer a form's width from a stored item's type or saved contents: the
// currently instantiated controls are the authority. No layout-width feedback.
function preferredFormWidth(sectionWidths, chromeWidth, minimumWidth) {
    const widths = Array.isArray(sectionWidths) ? sectionWidths : []
    let contentWidth = Math.max(0, Number(minimumWidth) || 0)
    for (let i = 0; i < widths.length; ++i) {
        const candidate = Number(widths[i])
        if (Number.isFinite(candidate) && candidate > contentWidth) {
            contentWidth = candidate
        }
    }
    return Math.max(1, contentWidth + Math.max(0, Number(chromeWidth) || 0))
}


// R53: constrain the OUTER settings Window, not merely its nested Popup.
// A form requests its intrinsic dimensions; existing KCM navigation/chrome is
// added, then the result is capped to the available monitor work area.  When
// the monitor cannot fit the entire form, its existing ScrollView takes over.
// The former host minimum is snapshotted before the temporary QML Binding
// becomes active; never read the bound minimum while computing its own value.
function hostMinimumExtent(dialogExtent, hostChrome, screenExtent,
                           screenMargin, previousMinimum) {
    const form = Math.max(0, Number(dialogExtent) || 0)
    const chrome = Math.max(0, Number(hostChrome) || 0)
    const margin = Math.max(0, Number(screenMargin) || 0)
    const previous = Math.max(0, Number(previousMinimum) || 0)
    const screen = Number(screenExtent)
    const available = Number.isFinite(screen) && screen > 0
        ? Math.max(1, screen - 2 * margin) : Infinity
    const wanted = Math.max(previous, form + chrome + 2 * margin)
    return Math.ceil(Math.min(wanted, available))
}

// R54: KDE-style preferred-size dialog. The form can ask for natural space but
// the KCM viewport and a comfortable maximum determine the actual width.
// Wide row descriptions in an app list must elide, not expand the dialog or
// force a horizontal scrollbar. When the host is narrow the dialog shrinks;
// its own Controls.ScrollView gives vertical scrolling for extra controls.
function kdePreferredWidth(naturalWidth, parentWidth, margin,
                           preferredMaximum, fallbackWidth) {
    const natural = Math.max(1, Number(naturalWidth) || 1)
    const preferred = Math.max(1, Number(preferredMaximum) || 1)
    const fallback = Math.max(1, Number(fallbackWidth) || preferred)
    return Math.min(viewportLimit(parentWidth, fallback, margin),
                    Math.min(natural, preferred))
}
