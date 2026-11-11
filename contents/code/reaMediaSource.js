// Browser-backed MPRIS players often report an unreliable seek timeline.
function isBrowser(controller) {
    if (!controller) return false
    if (controller.browserPlayer === true) return true
    const identity = String(controller.identity || "")
    const app = String(controller.applicationId || "")
    const service = String(controller.serviceName || "")
    return /firefox|librewolf|waterfox|floorp|zen.browser|chromium|chrome|brave|vivaldi|opera|edge|epiphany|falkon|qutebrowser|tor.browser|mozilla|plasma.browser|web.browser|browser.integration/i.test(identity + " " + app + " " + service)
}
