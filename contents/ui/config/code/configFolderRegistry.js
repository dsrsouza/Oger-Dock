// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Folder data has one canonical source: General/dockItemsJson. Category colors
// are separate defaults; they do not describe the user's individual folders.
// A folder's *array index* is the editing locator, so duplicate names work.
function readItems(json) {
    const source = String(json || "").trim()
    if (source.length === 0) return { ok: true, items: [] }
    try {
        const parsed = JSON.parse(source)
        return Array.isArray(parsed)
            ? { ok: true, items: parsed }
            : { ok: false, items: [], error: "dockItemsJson is not an array" }
    } catch (error) {
        return { ok: false, items: [], error: "Invalid dockItemsJson" }
    }
}

function collectFolders(json) {
    const result = readItems(json)
    if (!result.ok) return [] // Never invent folders when user data is invalid.
    const rows = []
    result.items.forEach(function(item, index) {
        if (!item || item.type !== "folder") return
        const color = String(item.folderAccentColor || "").trim()
        rows.push({
            folderIndex: index,
            name: String(item.name || "").trim() || "Pasta " + (index + 1),
            icon: String(item.icon || "folder"),
            sourceType: String(item.sourceType || "manual"),
            sourceCategory: String(item.sourceCategory || ""),
            explicitColor: /^#[0-9a-fA-F]{6}$/.test(color) ? color : ""
        })
    })
    return rows
}

function updateFolderColor(json, folderIndex, expectedName, color) {
    const result = readItems(json)
    if (!result.ok || !String(json || "").trim())
        return { ok: false, error: "No valid saved dock items" }
    const index = Number(folderIndex)
    if (!Number.isInteger(index) || index < 0 || index >= result.items.length)
        return { ok: false, error: "Folder index changed" }
    const item = result.items[index]
    if (!item || item.type !== "folder"
            || String(item.name || "").trim() !== String(expectedName || "").trim())
        return { ok: false, error: "Folder changed during edit" }
    const normalized = String(color || "").trim()
    if (normalized !== "" && !/^#[0-9a-fA-F]{6}$/.test(normalized))
        return { ok: false, error: "Invalid hex color" }
    const existing = String(item.folderAccentColor || "")
    if (existing.toUpperCase() === normalized.toUpperCase())
        return { ok: true, changed: false, json: json }
    if (normalized.length > 0) item.folderAccentColor = normalized.toUpperCase()
    else delete item.folderAccentColor
    return { ok: true, changed: true, json: JSON.stringify(result.items, null, 4) }
}
