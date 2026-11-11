// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// One source of truth for folder accent across the dock and configuration preview.
// Deliberately pure: the current KDE highlight is supplied by the caller, so
// switching the Plasma color scheme updates both bindings automatically.
function resolvedColor(customColor, sourceCategory, categoryColors, defaultColor) {
    const custom = String(customColor || "").trim()
    if (/^#[0-9a-fA-F]{6}$/.test(custom)) return custom

    const palette = {
        Network: "#32b77c", AudioVideo: "#e6a33b",
        Graphics: "#af77dd", Development: "#3c9dd8",
        Game: "#d88b3b", Office: "#5697c5",
        System: "#4a92c4", Utility: "#5d9ccc"
    }
    const category = String(sourceCategory || "")
    const configured = categoryColors
        ? String(categoryColors[category] || "") : ""
    if (/^#[0-9a-fA-F]{6}$/.test(configured)) return configured
    return palette[category] || defaultColor
}
