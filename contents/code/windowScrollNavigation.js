// Stable Alt-Tab-like ordering while a mouse-wheel gesture is in progress.
// Keys are TaskManager window identifiers, never app IDs: several windows of
// the same application must be individually switchable.
function makeCycle(candidates, recentKeys, activeKey) {
    const ordered = []
    const items = Array.isArray(candidates) ? candidates : []
    for (let i = 0; i < items.length; ++i) {
        const key = String(items[i] && items[i].key || "")
        if (key.length > 0 && ordered.indexOf(key) < 0) ordered.push(key)
    }
    return ordered
}

function advanceCycle(cycle, currentKey, direction) {
    if (!(Array.isArray(cycle)) || cycle.length < 2) return ""
    const current = cycle.indexOf(String(currentKey || ""))
    if (current < 0) return cycle[0]
    const step = Number(direction) < 0 ? -1 : 1
    return cycle[Math.max(0, Math.min(cycle.length - 1, current + step))]
}

function recordActive(recentKeys, activeKey, availableKeys) {
    const available = Array.isArray(availableKeys) ? availableKeys : []
    const old = Array.isArray(recentKeys) ? recentKeys : []
    const next = []
    function insert(value) {
        const key = String(value || "")
        if (key.length > 0 && available.indexOf(key) >= 0 && next.indexOf(key) < 0) {
            next.push(key)
        }
    }
    insert(activeKey)
    for (let i = 0; i < old.length; ++i) insert(old[i])
    for (let i = 0; i < available.length; ++i) insert(available[i])
    return next
}

// Build a window-only transition, preserving the target window geometry.
// Minimize the previous window rather than
// leaving every switched-to window in front of the desktop. Keep all actions
// tied to stable window keys, never row numbers or application identifiers.
function planWindowTransition(candidates, previousKey, targetKey, maximizeNext) {
    const windows = Array.isArray(candidates) ? candidates : []
    let previous = null
    let target = null
    for (let i = 0; i < windows.length; ++i) {
        const candidate = windows[i]
        if (!candidate) continue
        if (candidate.key === previousKey) previous = candidate
        if (candidate.key === targetKey) target = candidate
    }
    if (!target) return null
    const oldWindow = previous && previous.key !== target.key ? previous : null
    return {
        previousKey: oldWindow && oldWindow.minimizable && !oldWindow.minimized
            ? oldWindow.key : "",
        targetKey: target.key,
        maximizeTarget: false // Legacy caller argument deliberately ignored.
    }
}

// Preserve visual order and the user's cursor when a window is added or
// removed. A focus/minimize notification must not reorder the cycle.
function reconcileCycle(previousKeys, availableKeys) {
    const previous = Array.isArray(previousKeys) ? previousKeys : []
    const available = Array.isArray(availableKeys) ? availableKeys : []
    const result = []
    for (let i = 0; i < previous.length; i++) {
        if (available.indexOf(previous[i]) >= 0 && result.indexOf(previous[i]) < 0)
            result.push(previous[i])
    }
    for (let i = 0; i < available.length; i++) {
        if (result.indexOf(available[i]) < 0) result.push(available[i])
    }
    return result
}
