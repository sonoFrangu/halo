import Testing
@testable import Halo

struct NotificationRulesTests {
    private func decide(
        _ bundleIdentifier: String = "net.whatsapp.WhatsApp",
        mode: NotificationAppMode = .show,
        focusSilencing: Bool = false,
        bypassesFocus: Bool = false
    ) -> NotificationDecision {
        NotificationRules.decide(
            bundleIdentifier: bundleIdentifier,
            ownBundleIdentifier: "io.github.sonofrangu.halo",
            mode: mode,
            focusSilencing: focusSilencing,
            bypassesFocus: bypassesFocus
        )
    }

    @Test func modesWithoutFocus() {
        #expect(decide(mode: .show) == .full)
        #expect(decide(mode: .appOnly) == .appOnly)
        #expect(decide(mode: .hidden) == .drop)
    }

    @Test func focusSilencesAppsThatDoNotBypassIt() {
        #expect(decide(mode: .show, focusSilencing: true) == .drop)
        #expect(decide(mode: .appOnly, focusSilencing: true) == .drop)
    }

    @Test func bypassPassesFocusButKeepsTheMode() {
        #expect(decide(mode: .show, focusSilencing: true, bypassesFocus: true) == .full)
        #expect(decide(mode: .appOnly, focusSilencing: true, bypassesFocus: true) == .appOnly)
        #expect(decide(mode: .hidden, focusSilencing: true, bypassesFocus: true) == .drop)
    }

    @Test func websitesAndHaloAreNeverShown() {
        #expect(decide("_WEB_CENTER_:web.com.example", bypassesFocus: true) == .drop)
        #expect(decide("io.github.sonofrangu.halo") == .drop)
    }

    @Test func bluetoothBannersAreLeftToTheHeadphonesAlert() {
        #expect(decide("com.apple.bluetoothuserd.UserNotification", bypassesFocus: true) == .drop)
        #expect(decide("_SYSTEM_CENTER_:com.apple.BluetoothUIServer") == .drop)
        #expect(decide("com.apple.controlcenter.notifications.low-battery") == .full)
    }
}
