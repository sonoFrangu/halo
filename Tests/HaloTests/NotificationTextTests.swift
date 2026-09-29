import Testing
@testable import Halo

struct NotificationTextTests {
    @Test func senderAndMessage() {
        let text = NotificationText.make(title: "Giulia", subtitle: nil, body: "Ci vediamo alle 8?", appName: "WhatsApp")
        #expect(text == NotificationText(headline: "Giulia", detail: nil, message: "Ci vediamo alle 8?"))
    }

    @Test func groupSubtitleGoesNextToTheSender() {
        let text = NotificationText.make(title: "Giulia", subtitle: "Calcetto", body: "Io ci sono", appName: "WhatsApp")
        #expect(text == NotificationText(headline: "Giulia", detail: "Calcetto", message: "Io ci sono"))
    }

    @Test func titleEqualToTheAppNameIsDropped() {
        let text = NotificationText.make(title: " whatsapp ", subtitle: nil, body: "Giulia\nCi vediamo alle 8?", appName: "WhatsApp")
        #expect(text == NotificationText(headline: "Giulia", detail: nil, message: "Ci vediamo alle 8?"))
    }

    @Test func subtitleBecomesTheHeadlineWhenTheTitleIsTheApp() {
        let text = NotificationText.make(title: "WhatsApp", subtitle: "Calcetto", body: "Io ci sono", appName: "WhatsApp")
        #expect(text == NotificationText(headline: "Calcetto", detail: nil, message: "Io ci sono"))
    }

    @Test func runsOfSpacesAndLineBreaksCollapse() {
        let text = NotificationText.make(title: "Anna", subtitle: nil, body: "Riga uno\n\n  riga   due ", appName: "Messaggi")
        #expect(text.message == "Riga uno riga due")
    }

    @Test func nothingToShowFallsBackToTheAppName() {
        let text = NotificationText.make(title: "  ", subtitle: nil, body: "\n", appName: "WhatsApp")
        #expect(text == NotificationText(headline: "WhatsApp", detail: nil, message: nil))
    }
}
