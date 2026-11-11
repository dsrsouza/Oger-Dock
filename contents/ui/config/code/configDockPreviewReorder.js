.pragma library

// Pure index arithmetic: moving an item must not silently change which
// OTHER item is selected. Used by the preview and regression tests.
function validMove(sourceIndex, targetIndex, count) {
    return Number.isInteger(sourceIndex) && Number.isInteger(targetIndex)
        && sourceIndex >= 0 && targetIndex >= 0 && sourceIndex < count
        && targetIndex < count && sourceIndex !== targetIndex
}

function selectionAfterMove(selectedIndex, sourceIndex, targetIndex) {
    if (selectedIndex < 0) return -1
    if (selectedIndex === sourceIndex) return targetIndex
    if (sourceIndex < targetIndex
            && selectedIndex > sourceIndex && selectedIndex <= targetIndex)
        return selectedIndex - 1
    if (sourceIndex > targetIndex
            && selectedIndex >= targetIndex && selectedIndex < sourceIndex)
        return selectedIndex + 1
    return selectedIndex
}
