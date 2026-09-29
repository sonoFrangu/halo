import Foundation
import Testing
@testable import Halo

struct NotificationPayloadTests {
    private func encode(_ plist: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    @Test func readsTitleSubtitleAndBody() throws {
        let data = try encode([
            "app": "com.apple.MobileSMS",
            "req": ["titl": "Anna", "subt": "Gruppo", "body": "Ci vediamo alle 8?"],
        ])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.title == "Anna")
        #expect(payload.subtitle == "Gruppo")
        #expect(payload.body == "Ci vediamo alle 8?")
        #expect(payload.message == "Gruppo · Ci vediamo alle 8?")
    }

    @Test func blankAndMissingFieldsAreNil() throws {
        let data = try encode(["req": ["titl": "  ", "body": "Solo testo"]])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.title == nil)
        #expect(payload.subtitle == nil)
        #expect(payload.message == "Solo testo")
    }

    @Test func rejectsDataWithoutRequest() throws {
        #expect(NotificationPayload.parse(try encode(["app": "com.example"])) == nil)
        #expect(NotificationPayload.parse(Data("not a plist".utf8)) == nil)
    }

    @Test func emptyPayloadHasNoMessage() {
        let payload = NotificationPayload()
        #expect(payload.isEmpty)
        #expect(payload.message == nil)
    }

    @Test func websiteNotificationsAreNotMirrored() {
        #expect(NotificationMirror.isFromWebsite("_WEB_CENTER_:web.com.macos-updates.root"))
        #expect(!NotificationMirror.isFromWebsite("net.whatsapp.WhatsApp"))
        #expect(!NotificationMirror.isFromWebsite("com.apple.Safari"))
    }
}
