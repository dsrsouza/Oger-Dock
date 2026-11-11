// Input normalization for KDE Plasma 6.8 task switching. The official task
// manager treats 15 degrees of WheelHandler rotation as one notch (120 units
// of QWheelEvent::angleDelta). Preserve that convention for mouse wheels and
// integrate high-precision touchpad pixel events without double-counting.
.pragma library

function signedDelta(angleY, pixelY) {
    const angle = Number(angleY)
    const pixel = Number(pixelY)
    if (Number.isFinite(angle) && angle !== 0) return angle
    if (Number.isFinite(pixel) && pixel !== 0) return pixel * 3
    return 0
}

// A gesture may deliver several 120-unit notches in one packet. Report every
// whole step instead of silently dropping extra notches. Keep only a fractional
// remainder; a direction reversal discards that fraction, not queued steps.
function accumulate(previous, previousDirection, delta, threshold) {
    const amount = Number(delta)
    const limit = Math.max(1, Number(threshold) || 120)
    if (!Number.isFinite(amount) || amount === 0) {
        return { remainder: previous, direction: previousDirection, ready: false, steps: 0 }
    }
    const direction = amount > 0 ? 1 : -1
    const pending = direction === previousDirection ? Number(previous) || 0 : 0
    const total = pending + amount
    const steps = Math.floor(Math.abs(total) / limit) * direction
    return {
        remainder: total - steps * limit,
        direction: direction,
        ready: steps !== 0,
        steps: steps
    }
}
