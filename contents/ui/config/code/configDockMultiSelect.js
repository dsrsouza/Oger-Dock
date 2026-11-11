// SPDX-License-Identifier: GPL-2.0-or-later
// R61: pure, deterministic group move. Indices reference the original dock.
// The drop target is a visible original index; a drop beyond the last item
// is handled by callers as the last original target, with after=true.
function normalizedIndexes(indexes, count) {
    const unique = []
    for (const raw of indexes || []) {
        const index = Number(raw)
        if (Number.isInteger(index) && index >= 0 && index < count
                && unique.indexOf(index) < 0) unique.push(index)
    }
    return unique.sort((a, b) => a - b)
}

function moveGroup(items, indexes, targetIndex, after) {
    const count = Array.isArray(items) ? items.length : 0
    const selected = normalizedIndexes(indexes, count)
    const target = Number(targetIndex)
    if (selected.length === 0 || !Number.isInteger(target)
            || target < 0 || target >= count || selected.includes(target)) {
        return {changed: false, items: items, order: [], selected: selected}
    }
    const order = Array.from({length: count}, (_, i) => i)
    const remainder = order.filter(i => !selected.includes(i))
    let destination = remainder.filter(i => i < target).length
    if (Boolean(after)) destination++
    destination = Math.max(0, Math.min(remainder.length, destination))
    const reordered = remainder.slice(0, destination).concat(selected,
        remainder.slice(destination))
    if (reordered.every((original, index) => original === index)) {
        return {changed: false, items: items, order: order, selected: selected}
    }
    return {
        changed: true,
        items: reordered.map(i => items[i]),
        order: reordered,
        selected: selected.map(i => reordered.indexOf(i)).sort((a, b) => a - b)
    }
}
