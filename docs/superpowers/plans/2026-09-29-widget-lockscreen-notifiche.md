# Widget, schermata di blocco e notifiche in stile Apple — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widget desktop medio e card del lock screen in stile widget di macOS 26, card che sparisce allo sblocco anche col main thread bloccato, notifiche della notch in stile Dynamic Island con testo curato e miniatura della foto.

**Architecture:** Un solo `PlayerWidgetView` (vetro sobrio `WidgetBackdrop`) serve desktop e lock screen; sul lock screen aggiunge `LyricsStrip`. `LockScreenSpace` diventa thread-safe e `UnlockWatch` (notifica Darwin su coda privata) nasconde lo spazio allo sblocco. Le notifiche passano per `NotificationText` (regole pure) e `NotificationThumbnail` (ImageIO off-main); `NotificationPayload` trova l'allegato immagine.

**Tech Stack:** Swift 6.2, SwiftUI + AppKit, SkyLight privato (già usato), `notify` (Darwin), ImageIO, Swift Testing. Build: `swift build -c release`, test: `swift test`, app: `scripts/bundle.sh` → `build/Halo.app`.

Spec: `docs/superpowers/specs/2026-09-29-widget-lockscreen-notifiche-design.md`.

## Global Constraints

- Niente macro SwiftUI (`@State`, `@Entry`, `#Preview`, `@Previewable`): non si espandono con i Command Line Tools; lo stato delle viste sta fuori (es. `CardState`).
- Consumo: Halo sotto l'1% di CPU; nessuna animazione continua nuova. Misurare Halo e WindowServer con musica in riproduzione e risparmio energetico spento.
- Nessuna chiamata di sistema che può bloccarsi sul main thread.
- Commenti e messaggi di commit in inglese; testi dell'interfaccia in italiano ("ora", "Apri l'app in riproduzione").
- Stile del codice: file piccoli, un compito ciascuno, doc comment `///` che spiegano il perché; `ponytail:` per le scorciatoie volute.
- Scostamenti accettati dalla spec (per non toccare viste condivise con l'isola): `ScrubberView` tiene i tempi ai lati della barra; `LyricsPanel` tiene la riga corrente sfumata nei colori della copertina.
- Commit alla fine di ogni task, messaggi con la riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Nome delle app e testo delle notifiche

**Files:**
- Create: `Sources/Halo/App/AppName.swift`
- Create: `Sources/Halo/Notifications/NotificationText.swift`
- Modify: `Sources/Halo/Notifications/NotificationMirror.swift` (via `applicationName(for:)`, usa `AppName.of`)
- Test: `Tests/HaloTests/NotificationTextTests.swift`

**Interfaces:**
- Produces: `AppName.of(_ bundleIdentifier: String) -> String` (`@MainActor`); `struct NotificationText: Sendable, Equatable { var headline: String; var detail: String?; var message: String?; static func make(title: String?, subtitle: String?, body: String?, appName: String) -> NotificationText; static func clean(_ text: String?) -> String? }`

- [ ] **Step 1: Write the failing test** — `Tests/HaloTests/NotificationTextTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotificationTextTests`
Expected: FAIL, "cannot find 'NotificationText' in scope".

- [ ] **Step 3: Write the implementation**

`Sources/Halo/Notifications/NotificationText.swift`:

```swift
import Foundation

/// The lines of a notification banner, Dynamic Island style: a bold headline (usually the
/// sender), a dimmed detail on the same line (the subtitle, e.g. a group chat) and the
/// message under it.
///
/// Apps fill title, subtitle and body inconsistently: some put their own name in the title,
/// some send the sender only as the first line of the body. `make` turns them into lines
/// that read well, and collapses runs of spaces and line breaks.
struct NotificationText: Sendable, Equatable {
    var headline: String
    var detail: String?
    var message: String?

    static func make(title: String?, subtitle: String?, body: String?, appName: String) -> NotificationText {
        let subtitle = clean(subtitle)
        var title = clean(title)
        if let current = title, current.lowercased() == clean(appName)?.lowercased() {
            title = nil
        }
        if let title {
            return NotificationText(headline: title, detail: subtitle, message: clean(body))
        }
        if let subtitle {
            return NotificationText(headline: subtitle, detail: nil, message: clean(body))
        }
        // No title: the body's first line is the headline (often the sender), the rest the message.
        let lines = (body ?? "").split(whereSeparator: \.isNewline).compactMap { clean(String($0)) }
        guard let first = lines.first else {
            return NotificationText(headline: appName, detail: nil, message: nil)
        }
        return NotificationText(headline: first, detail: nil, message: clean(lines.dropFirst().joined(separator: " ")))
    }

    /// Runs of spaces and line breaks become one space; blank text becomes `nil`.
    static func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }
}
```

`Sources/Halo/App/AppName.swift`:

```swift
import AppKit

/// Display name of an installed app from its bundle identifier ("Spotify", not
/// "com.spotify.client"), cached; the identifier itself when the app is not installed.
@MainActor
enum AppName {
    private static var names: [String: String] = [:]

    static func of(_ bundleIdentifier: String) -> String {
        if let cached = names[bundleIdentifier] {
            return cached
        }
        var name = bundleIdentifier
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let display = FileManager.default.displayName(atPath: url.path)
            name = display.hasSuffix(".app") ? String(display.dropLast(4)) : display
        }
        names[bundleIdentifier] = name
        return name
    }
}
```

In `NotificationMirror.swift` delete `private static func applicationName(for:)` and replace its only call `let appName = applicationName(for: record.bundleIdentifier)` with `let appName = AppName.of(record.bundleIdentifier)`.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: all tests pass, including the 6 new ones.

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/App/AppName.swift Sources/Halo/Notifications/NotificationText.swift Sources/Halo/Notifications/NotificationMirror.swift Tests/HaloTests/NotificationTextTests.swift
git commit -m "feat(notifications): tidy banner text rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Allegato immagine nel payload

**Files:**
- Modify: `Sources/Halo/Notifications/NotificationPayload.swift`
- Modify: `Tests/HaloTests/NotificationPayloadTests.swift`

**Interfaces:**
- Produces: `NotificationPayload.imageURL: URL?` (file URL of an image attachment). Removes `NotificationPayload.message`.

- [ ] **Step 1: Find the real shape of an attachment (manual, needs the user)**

Ask the user to grant **Accesso completo al disco** to Halo and to the terminal app running the commands (Impostazioni di Sistema › Privacy e sicurezza › Accesso completo al disco), then to send themselves a photo on WhatsApp (or iMessage) so a notification with a photo arrives on the Mac. Then run:

```bash
DB="$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db"
OUT="$TMPDIR/halo-notification.plist"
sqlite3 -readonly "$DB" "select hex(r.data) from record r join app a on a.app_id = r.app_id order by r.delivered_date desc limit 1" | xxd -r -p > "$OUT"
plutil -p "$OUT"
```

Expected: the `req` dictionary. Look for a string that is a `file://` URL or an absolute path ending in an image extension (e.g. under a key like `atta`). Write the finding in one line in the spec's "Parte 4 — Miniatura" section. If the attachment is not a readable path (only binary data or no attachment at all), note it in the spec's "Limiti noti", skip Task 3 and the thumbnail parts of Task 4 (the banner keeps "ora" on the right), and continue.

- [ ] **Step 2: Write the failing tests** — in `NotificationPayloadTests.swift` replace the two `payload.message` expectations and the last test, and add two tests:

```swift
    @Test func readsTitleSubtitleAndBody() throws {
        let data = try encode([
            "app": "com.apple.MobileSMS",
            "req": ["titl": "Anna", "subt": "Gruppo", "body": "Ci vediamo alle 8?"],
        ])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.title == "Anna")
        #expect(payload.subtitle == "Gruppo")
        #expect(payload.body == "Ci vediamo alle 8?")
        #expect(payload.imageURL == nil)
    }

    @Test func blankAndMissingFieldsAreNil() throws {
        let data = try encode(["req": ["titl": "  ", "body": "Solo testo"]])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.title == nil)
        #expect(payload.subtitle == nil)
        #expect(payload.body == "Solo testo")
    }

    @Test func emptyPayloadIsEmpty() {
        #expect(NotificationPayload().isEmpty)
    }

    @Test func findsAnImageAttachmentAnywhereInTheRequest() throws {
        let data = try encode([
            "req": [
                "titl": "Giulia",
                "atta": [["uniq": "A1", "url": "file:///Users/x/Library/Group%20Containers/att/photo.JPG"]],
            ],
        ])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.imageURL == URL(fileURLWithPath: "/Users/x/Library/Group Containers/att/photo.JPG"))
    }

    @Test func ignoresFilesThatAreNotImagesAndPlainText() throws {
        let data = try encode(["req": ["body": "/tmp/notes.txt is ready", "path": "/tmp/notes.txt", "link": "https://example.com/a.png"]])
        let payload = try #require(NotificationPayload.parse(data))
        #expect(payload.imageURL == nil)
    }
```

If Step 1 found a different real shape, add one more test that encodes exactly that shape and expects its URL.

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter NotificationPayloadTests`
Expected: FAIL, "value of type 'NotificationPayload' has no member 'imageURL'".

- [ ] **Step 4: Implement** — in `NotificationPayload.swift`: add the property, fill it in `parse`, delete `var message`, add the search:

```swift
    var title: String?
    var subtitle: String?
    var body: String?
    /// A photo attached to the notification: the first file URL or absolute path anywhere in
    /// the request that names an image. Searched rather than read from one key because the
    /// format is private; a change degrades to no thumbnail.
    var imageURL: URL?
```

```swift
        return NotificationPayload(
            title: text(request["titl"]),
            subtitle: text(request["subt"]),
            body: text(request["body"]),
            imageURL: imageURL(in: request)
        )
```

```swift
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"]

    private static func imageURL(in value: Any) -> URL? {
        switch value {
        case let string as String:
            return imageFileURL(string)
        case let dictionary as [String: Any]:
            for key in dictionary.keys.sorted() {
                if let url = dictionary[key].flatMap(imageURL(in:)) { return url }
            }
            return nil
        case let array as [Any]:
            return array.lazy.compactMap(imageURL(in:)).first
        default:
            return nil
        }
    }

    private static func imageFileURL(_ string: String) -> URL? {
        let url: URL
        if string.hasPrefix("file://") {
            guard let parsed = URL(string: string) else { return nil }
            url = parsed
        } else if string.hasPrefix("/") {
            url = URL(fileURLWithPath: string)
        } else {
            return nil
        }
        return imageExtensions.contains(url.pathExtension.lowercased()) ? url : nil
    }
```

`isEmpty` stays `title == nil && subtitle == nil && body == nil`.

- [ ] **Step 5: Build and run tests**

Run: `swift build -c release 2>&1 | grep -E "error|warning: " | grep -v "search path"; swift test`
Expected: the build fails only where `payload.message` was used in `NotificationMirror.swift` (fixed in Task 4). To keep this commit green, change that line now to `body: payload.body` (the subtitle moves to `NotificationText` in Task 4). Then all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Halo/Notifications/NotificationPayload.swift Sources/Halo/Notifications/NotificationMirror.swift Tests/HaloTests/NotificationPayloadTests.swift docs/superpowers/specs/2026-09-29-widget-lockscreen-notifiche-design.md
git commit -m "feat(notifications): find a photo attached to a notification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Miniature con ImageIO

**Files:**
- Create: `Sources/Halo/Notifications/NotificationThumbnail.swift`
- Test: `Tests/HaloTests/NotificationThumbnailTests.swift`

**Interfaces:**
- Produces: `@MainActor enum NotificationThumbnail { nonisolated static let maxPixelSize: Int; static func cached(_ id: Int64) -> NSImage?; static func load(_ id: Int64, from url: URL) async -> NSImage?; nonisolated static func make(from url: URL) -> CGImage? }`

- [ ] **Step 1: Write the failing test**

```swift
import AppKit
import Testing
@testable import Halo

@MainActor
struct NotificationThumbnailTests {
    private func writePNG(width: Int, height: Int) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("halo-thumb-\(UUID()).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func thumbnailIsSmallAndKeepsTheAspect() throws {
        let url = try writePNG(width: 1200, height: 800)
        let image = try #require(NotificationThumbnail.make(from: url))
        #expect(image.width == NotificationThumbnail.maxPixelSize)
        #expect(image.height == 59)
    }

    @Test func missingFileGivesNoThumbnail() {
        #expect(NotificationThumbnail.make(from: URL(fileURLWithPath: "/nonexistent/photo.jpg")) == nil)
    }

    @Test func loadCachesByNotification() async throws {
        let url = try writePNG(width: 300, height: 300)
        #expect(NotificationThumbnail.cached(424242) == nil)
        let image = await NotificationThumbnail.load(424242, from: url)
        #expect(image != nil)
        #expect(NotificationThumbnail.cached(424242) != nil)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter NotificationThumbnailTests`
Expected: FAIL, "cannot find 'NotificationThumbnail' in scope".

- [ ] **Step 3: Implement** — `Sources/Halo/Notifications/NotificationThumbnail.swift`:

```swift
import AppKit
import ImageIO

/// Small previews of notification photos. ImageIO decodes straight at thumbnail size (never
/// the full photo) on a background task; the last few are kept by notification id so the
/// banner can read them synchronously once posted.
@MainActor
enum NotificationThumbnail {
    /// Longest side in pixels: a 44-point square on a 2x display.
    nonisolated static let maxPixelSize = 88
    private static let limit = 10
    private static var images: [Int64: NSImage] = [:]
    private static var order: [Int64] = []

    static func cached(_ id: Int64) -> NSImage? {
        images[id]
    }

    /// The thumbnail of notification `id`, made once; `nil` when the file cannot be read.
    static func load(_ id: Int64, from url: URL) async -> NSImage? {
        if let image = images[id] {
            return image
        }
        guard let cgImage = await Task.detached(priority: .utility, operation: { make(from: url) }).value else {
            Diagnostics.shared.record("notifica \(id): miniatura non leggibile")
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / 2, height: CGFloat(cgImage.height) / 2))
        images[id] = image
        order.append(id)
        if order.count > limit {
            images[order.removeFirst()] = nil
        }
        return image
    }

    nonisolated static func make(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
```

If the compiler rejects returning `CGImage` from the detached task as non-Sendable, wrap it: `struct SendableImage: @unchecked Sendable { let image: CGImage }` in this file (a `CGImage` is immutable) and return that.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: all pass. (1200×800 → 88×59: ImageIO rounds 58.67 up; if it yields 58, change the expectation to `(58...59).contains(image.height)`.)

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/Notifications/NotificationThumbnail.swift Tests/HaloTests/NotificationThumbnailTests.swift
git commit -m "feat(notifications): thumbnails of attached photos with ImageIO

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Banner in stile Dynamic Island

**Files:**
- Modify: `Sources/Halo/Alerts/IslandAlert.swift:124-130` (`NotificationAlert`)
- Modify: `Sources/Halo/Notifications/NotificationMirror.swift` (`databaseChanged`, `alert(for:)`)
- Modify: `Sources/Halo/UI/Alerts/NotificationBanner.swift` (layout)
- Modify: `Tests/HaloTests/AlertTests.swift:8`

**Interfaces:**
- Consumes: `NotificationText.make`, `AppName.of`, `NotificationPayload.imageURL`, `NotificationThumbnail.load/cached`.
- Produces: `struct NotificationAlert: Sendable, Equatable { var id: Int64; var bundleIdentifier: String; var text: NotificationText; var imageURL: URL? }`

- [ ] **Step 1: Update the alert model and the test helper**

`IslandAlert.swift`, replace `NotificationAlert`:

```swift
/// A mirrored system notification.
struct NotificationAlert: Sendable, Equatable {
    var id: Int64
    var bundleIdentifier: String
    var text: NotificationText
    /// Photo attached to the notification; its thumbnail is loaded before the banner is posted.
    var imageURL: URL?
}
```

`AlertTests.swift` line 8:

```swift
        .notification(NotificationAlert(id: id, bundleIdentifier: "com.example", text: NotificationText(headline: "T\(id)")))
```

- [ ] **Step 2: Build the alert in the mirror, loading the thumbnail first**

In `NotificationMirror.swift` replace the posting loop at the end of `databaseChanged()`:

```swift
        let shown = records.count > Self.burstLimit ? [newest] : records
        for record in shown {
            guard let alert = Self.alert(for: record) else { continue }
            guard let imageURL = alert.imageURL else {
                alerts.post(.notification(alert))
                continue
            }
            // The banner reads the thumbnail synchronously, so it is made before posting.
            Task { [weak self] in
                _ = await NotificationThumbnail.load(alert.id, from: imageURL)
                self?.alerts.post(.notification(alert))
            }
        }
```

and `alert(for:)`:

```swift
    private static func alert(for record: NotificationRecord) -> NotificationAlert? {
        guard
            record.bundleIdentifier != Bundle.main.bundleIdentifier,
            !isFromWebsite(record.bundleIdentifier)
        else { return nil }
        let payload = NotificationPayload.parse(record.data) ?? NotificationPayload()
        return NotificationAlert(
            id: record.id,
            bundleIdentifier: record.bundleIdentifier,
            text: NotificationText.make(
                title: payload.title,
                subtitle: payload.subtitle,
                body: payload.body,
                appName: AppName.of(record.bundleIdentifier)
            ),
            imageURL: payload.imageURL
        )
    }
```

- [ ] **Step 3: New banner layout** — replace the `NotificationBanner` struct (keep `AppIcon` and `AppIconCache` below it unchanged):

```swift
/// Banner of a mirrored system notification, Dynamic Island style: app icon, sender with the
/// group or subtitle dimmed beside it, up to two lines of message, and on the right the
/// attached photo or "ora". Clicking opens the app.
struct NotificationBanner: View {
    let alert: NotificationAlert

    var body: some View {
        let text = alert.text
        let corner = RoundedRectangle(cornerRadius: 10, style: .continuous)

        HStack(spacing: 12) {
            AppIcon(bundleIdentifier: alert.bundleIdentifier)
                .frame(width: 44, height: 44)
                .clipShape(corner)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(text.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                    if let detail = text.detail {
                        Text(" · \(detail)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .lineLimit(1)

                if let message = text.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let thumbnail = NotificationThumbnail.cached(alert.id) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(corner)
                    .accessibilityLabel("Foto")
            } else {
                Text("ora")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 4: Build and test**

Run: `swift build -c release 2>&1 | grep -E "error|warning: " | grep -v "search path"; swift test`
Expected: no errors, all tests pass.

- [ ] **Step 5: Check on the Mac (manual)**

Run: `scripts/bundle.sh && pkill -x Halo; open build/Halo.app`. With Full Disk Access granted to Halo, send yourself a text message and a photo. Expected: the island opens as before; icon, bold sender, message on up to 2 lines; "ora" for the text, the photo's thumbnail for the photo. A Safari site notification does not appear.

- [ ] **Step 6: Commit**

```bash
git add Sources/Halo/Alerts/IslandAlert.swift Sources/Halo/Notifications/NotificationMirror.swift Sources/Halo/UI/Alerts/NotificationBanner.swift Tests/HaloTests/AlertTests.swift
git commit -m "feat(notifications): Dynamic Island style banner with photo thumbnail

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Widget medio sul desktop

**Files:**
- Create: `Sources/Halo/UI/Widgets/WidgetBackdrop.swift`
- Create: `Sources/Halo/UI/Widgets/PlayerWidgetView.swift`
- Create: `Sources/Halo/UI/Widgets/LyricsStrip.swift`
- Delete: `Sources/Halo/UI/Widgets/PlayerCardView.swift`, `Sources/Halo/UI/Widgets/CardBackdrop.swift`
- Modify: `Sources/Halo/UI/Widgets/DesktopWidgetView.swift`, `Sources/Halo/UI/Widgets/ClockCardView.swift`, `Sources/Halo/UI/Widgets/LockScreenView.swift:16`, `Sources/Halo/Widgets/DesktopWidgetController.swift`, `Sources/Halo/Widgets/LockScreenController.swift:25`, `Sources/Halo/App/AppDelegate.swift:75-80`

**Interfaces:**
- Consumes: `AppName.of` (Task 1).
- Produces: `struct WidgetBackdrop: View { let cornerRadius: CGFloat }`; `struct PlayerWidgetView: View { struct Metrics { width, artworkSide, cornerRadius, padding; static let desktop, lockScreen }; init(player: NowPlayingModel, lyrics: LyricsModel?, card: CardState, actions: PlayerActions, metrics: Metrics) }`; `struct LyricsStrip: View { init(player: NowPlayingModel, lyrics: LyricsModel, isVisible: Bool, onSeek: @escaping (TimeInterval) -> Void) }`.

- [ ] **Step 1: `WidgetBackdrop.swift`**

```swift
import SwiftUI

/// Background of the floating widgets, macOS 26 widget style: plain Liquid Glass, lightly
/// darkened so white text stays readable on any wallpaper, and a hairline border; nothing
/// tinted by the artwork. Solid with Reduce Transparency.
struct WidgetBackdrop: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if reduceTransparency {
                shape.fill(Color(white: 0.12))
            } else {
                Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.22)), in: shape)
            }
        }
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2: `LyricsStrip.swift`**

```swift
import SwiftUI

/// The lock screen card's lyrics under the player: a hairline, then three lines of
/// `LyricsPanel` with the sung line in the middle.
struct LyricsStrip: View {
    let player: NowPlayingModel
    let lyrics: LyricsModel
    let isVisible: Bool
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
            LyricsPanel(
                lines: lyrics.lines,
                timeline: player.timeline,
                lead: lyrics.lead,
                palette: player.palette,
                isVisible: isVisible,
                onSeek: onSeek
            )
            .frame(height: 3 * LyricsPanel.lineHeight)
        }
    }
}
```

- [ ] **Step 3: `PlayerWidgetView.swift`**

```swift
import SwiftUI

/// Now Playing widget in the style of a macOS 26 medium widget: artwork on the left; source
/// app, title, artist and album, progress and controls on the right. The desktop widget
/// shows it alone; the lock screen passes `lyrics` and gets the synced lyrics under it,
/// inside the same glass.
struct PlayerWidgetView: View {
    struct Metrics: Equatable {
        var width: CGFloat
        var artworkSide: CGFloat
        var cornerRadius: CGFloat
        var padding: CGFloat

        static let desktop = Metrics(width: 360, artworkSide: 142, cornerRadius: 22, padding: 14)
        static let lockScreen = Metrics(width: 380, artworkSide: 150, cornerRadius: 26, padding: 16)

        /// Height of the widget without lyrics.
        var height: CGFloat { artworkSide + 2 * padding }
    }

    let player: NowPlayingModel
    let lyrics: LyricsModel?
    let card: CardState
    let actions: PlayerActions
    let metrics: Metrics

    var body: some View {
        let showsLyrics = lyrics.map { $0.status == .synced && !$0.lines.isEmpty } ?? false

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(image: player.artworkImage, palette: player.palette, cornerRadius: 12, isProminent: false)
                    .frame(width: metrics.artworkSide, height: metrics.artworkSide)
                    .onTapGesture { actions.openSource() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Apri l'app in riproduzione")

                details
            }
            .frame(height: metrics.artworkSide)

            if showsLyrics, let lyrics {
                LyricsStrip(player: player, lyrics: lyrics, isVisible: card.isVisible, onSeek: actions.seek)
                    .transition(.opacity)
            }
        }
        .padding(metrics.padding)
        .frame(width: metrics.width)
        .background {
            WidgetBackdrop(cornerRadius: metrics.cornerRadius)
        }
        .animation(.spring(duration: 0.45, bounce: 0.15), value: showsLyrics)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let source = player.snapshot?.sourceBundleIdentifier {
                HStack(spacing: 4) {
                    SourceIconView(icon: player.sourceIcon)
                        .frame(width: 12, height: 12)
                    Text(AppName.of(source))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(.bottom, 6)
            }
            Text(player.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ScrubberView(
                timeline: player.timeline,
                isActive: card.isVisible,
                tint: player.palette.primary.color,
                isHovering: card.isScrubberHovered,
                onHoverChanged: { hovering in card.setScrubberHovered(hovering) },
                onScrubbingChanged: actions.setInteracting,
                onSeek: actions.seek,
                minimumInterval: 1
            )
            .frame(height: 20)

            TransportControls(
                isPlaying: player.isPlaying,
                tint: player.palette.primary.color,
                hasLyrics: false,
                showsLyrics: false,
                actions: actions
            )
            .frame(height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "Artist — Album", or whichever of the two exists.
    private var subtitle: String? {
        let parts = [player.artist, player.snapshot?.album].compactMap { part -> String? in
            guard let part, !part.isEmpty else { return nil }
            return part
        }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }
}
```

- [ ] **Step 4: Wire it in**

`DesktopWidgetView.swift`: remove the `lyrics` property; body:

```swift
        let metrics = PlayerWidgetView.Metrics.desktop

        ZStack(alignment: .topLeading) {
            if player.hasMedia {
                PlayerWidgetView(player: player, lyrics: nil, card: card, actions: actions, metrics: metrics)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                ClockCardView(weather: weather.report, width: metrics.width)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
```

(rest unchanged). `DesktopWidgetController.swift`: remove `private let lyrics: LyricsModel`, the `lyrics:` init parameter and assignment, pass `DesktopWidgetView(player: player, weather: weather, card: card, actions: actions)`, and set the size:

```swift
    /// Widget plus the transparent margin for its shadow.
    static let size = CGSize(
        width: PlayerWidgetView.Metrics.desktop.width + 2 * DesktopWidgetView.shadowMargin,
        height: PlayerWidgetView.Metrics.desktop.height + 2 * DesktopWidgetView.shadowMargin
    )
```

`AppDelegate.swift` lines 75-80: drop the `lyrics: lyrics.model,` argument of `DesktopWidgetController(`.

`ClockCardView.swift`: `.padding(22)` → `.padding(16)`, and the background:

```swift
        .background {
            WidgetBackdrop(cornerRadius: 22)
        }
```

`LockScreenView.swift` line 16:

```swift
        PlayerWidgetView(player: player, lyrics: lyrics, card: card, actions: actions, metrics: .lockScreen)
```

`LockScreenController.swift` line 25: `PlayerCardView.Metrics.lockScreen.width` → `PlayerWidgetView.Metrics.lockScreen.width`.

Delete the old files: `git rm Sources/Halo/UI/Widgets/PlayerCardView.swift Sources/Halo/UI/Widgets/CardBackdrop.swift`.

- [ ] **Step 5: Build and test**

Run: `swift build -c release 2>&1 | grep -E "error|warning: " | grep -v "search path"; swift test`
Expected: no errors (grep for leftovers: `grep -rn "PlayerCardView\|CardBackdrop" Sources` prints nothing), all tests pass.

- [ ] **Step 6: Check on the Mac (manual)**

Enable the desktop widget if off (Impostazioni › Musica › Widget sul desktop), `scripts/bundle.sh && pkill -x Halo; open build/Halo.app`. Expected: with music, a 360×170 glass widget, artwork left, "Spotify" with icon, title, artist — album, bar and controls; buttons work; dragging moves it. Paused and no media: the clock card in the same glass. With Low Power Mode off, measure: `top -pid $(pgrep -x Halo) -l 10 -s 1 -stats cpu` while playing → about 0% after the first seconds.

- [ ] **Step 7: Commit**

```bash
git add -A Sources/Halo/UI/Widgets Sources/Halo/Widgets/DesktopWidgetController.swift Sources/Halo/Widgets/LockScreenController.swift Sources/Halo/App/AppDelegate.swift
git commit -m "feat(widgets): macOS 26 style medium widget for desktop and lock screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: La card del lock screen sparisce allo sblocco anche col main thread bloccato

**Files:**
- Create: `Sources/Halo/System/UnlockWatch.swift`
- Modify: `Sources/Halo/System/LockScreenSpace.swift` (whole file)
- Modify: `Sources/Halo/Widgets/LockScreenController.swift` (`show()`, `hide()`, properties)

**Interfaces:**
- Produces: `final class LockScreenSpace: @unchecked Sendable { init?(); func show(); func hide(); @MainActor func add(_ window: NSWindow) }`; `final class UnlockWatch { init(onUnlock: @escaping @Sendable () -> Void) }`.

- [ ] **Step 1: Check that the Darwin unlock notification reaches a user process (manual)**

Run in a terminal: `notifyutil -1 com.apple.sessionagent.screenIsUnlocked`, lock with ⌃⌘Q, unlock.
Expected: the command prints `com.apple.sessionagent.screenIsUnlocked` and exits. If it never fires, stop this task and report it: the fallback is out of this plan's scope.

- [ ] **Step 2: `LockScreenSpace.swift`** — replace the file:

```swift
import AppKit

/// Shows windows above the lock screen through the private SkyLight window-server API.
///
/// The lock screen is a system space with a high absolute level; a space created by the app
/// with an even higher level, shown and holding the app's windows, is drawn over it. The
/// space is created hidden. `show()` and `hide()` work from any thread, so the unlock can
/// hide it at once even while the main thread is stalled (see `UnlockWatch`). Every symbol
/// is resolved at run time with `dlopen`, so a macOS release without them disables the lock
/// screen card instead of breaking launch.
///
/// `@unchecked Sendable`: only immutable values; the SkyLight calls are requests to the
/// window server that touch no app state.
final class LockScreenSpace: @unchecked Sendable {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int, Int) -> UInt64
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias SetSpacesVisible = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32

    /// Above the lock screen's own level (300).
    static let absoluteLevel: Int32 = 400
    /// "Remove from every other space" option of the add call.
    private static let moveOption: Int32 = 7

    private let connection: Int32
    private let space: UInt64
    private let showSpaces: SetSpacesVisible
    private let hideSpaces: SetSpacesVisible
    private let addWindows: SpaceAddWindowsAndRemoveFromSpaces

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            Log.app.error("SkyLight unavailable: no lock screen card")
            return nil
        }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        guard
            let mainConnectionID = symbol("SLSMainConnectionID", as: MainConnectionID.self),
            let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreate.self),
            let setAbsoluteLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevel.self),
            let showSpaces = symbol("SLSShowSpaces", as: SetSpacesVisible.self),
            let hideSpaces = symbol("SLSHideSpaces", as: SetSpacesVisible.self),
            let addWindows = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: SpaceAddWindowsAndRemoveFromSpaces.self)
        else {
            Log.app.error("SkyLight space API missing: no lock screen card")
            return nil
        }

        let connection = mainConnectionID()
        let space = spaceCreate(connection, 1, 0)
        guard space != 0 else {
            Log.app.error("SkyLight refused to create a space: no lock screen card")
            return nil
        }
        _ = setAbsoluteLevel(connection, space, Self.absoluteLevel)

        self.connection = connection
        self.space = space
        self.showSpaces = showSpaces
        self.hideSpaces = hideSpaces
        self.addWindows = addWindows
    }

    func show() {
        _ = showSpaces(connection, [NSNumber(value: space)] as CFArray)
    }

    func hide() {
        _ = hideSpaces(connection, [NSNumber(value: space)] as CFArray)
    }

    /// Moves `window` into the space above the lock screen. The window needs a window
    /// number, i.e. it must have been ordered in once.
    @MainActor
    func add(_ window: NSWindow) {
        guard window.windowNumber > 0 else { return }
        _ = addWindows(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, Self.moveOption)
    }
}
```

- [ ] **Step 3: `UnlockWatch.swift`**

```swift
import Foundation
import notify

/// Calls `onUnlock` on a private queue the moment the session unlocks, from the Darwin
/// notification loginwindow posts (`com.apple.sessionagent.screenIsUnlocked`). It does not
/// go through the main thread, so it still fires while the main thread is stalled: after a
/// wake on 2026-09-29 a stalled main thread kept the lock screen card over the desktop for
/// 29 s.
final class UnlockWatch {
    private static let name = "com.apple.sessionagent.screenIsUnlocked"
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.unlock", qos: .userInteractive)
    private var token: Int32 = NOTIFY_TOKEN_INVALID

    init(onUnlock: @escaping @Sendable () -> Void) {
        let status = notify_register_dispatch(Self.name, &token, queue) { _ in
            onUnlock()
        }
        if status != NOTIFY_STATUS_OK {
            Log.app.error("unlock watch unavailable: notify status \(status)")
        }
    }

    deinit {
        if token != NOTIFY_TOKEN_INVALID {
            notify_cancel(token)
        }
    }
}
```

- [ ] **Step 4: Use them in `LockScreenController.swift`**

Add the property under `private var spaceUnavailable = false`:

```swift
    /// Hides the space on unlock without waiting for the main thread.
    private var unlockWatch: UnlockWatch?
```

In `show()`, replace the space creation and the ordering:

```swift
        if space == nil && !spaceUnavailable {
            space = LockScreenSpace()
            spaceUnavailable = space == nil
            if let space {
                unlockWatch = UnlockWatch { space.hide() }
            }
        }
        guard let space else { return }
```

```swift
        space.show()
        panel.orderFrontRegardless()
        space.add(panel)
```

In `hide()`:

```swift
    private func hide() {
        card.setVisible(false)
        panel?.orderOut(nil)
        space?.hide()
    }
```

- [ ] **Step 5: Build and test**

Run: `swift build -c release 2>&1 | grep -E "error|warning: " | grep -v "search path"; swift test`
Expected: no errors, all tests pass.

- [ ] **Step 6: Stall test (manual, temporary code, NOT committed)**

In `LockScreenController.lockChanged(_:)` add as the first line `if !locked { Thread.sleep(forTimeInterval: 10) }`. Run `scripts/bundle.sh && pkill -x Halo; open build/Halo.app`, start music, lock (⌃⌘Q), check the card is on the lock screen, unlock with Touch ID.
Expected: the card disappears together with the lock screen, not 10 s later; `/usr/bin/log show --last 2m --style compact --predicate 'process == "Halo" AND category == "Window"'` shows `order window: … op: 0` about 10 s after unlocking (the main thread catching up), but nothing was visible in between. Then remove the line (`git diff Sources/Halo/Widgets/LockScreenController.swift` must show only Step 4's changes), rebuild and repeat without the sleep: the card appears on lock and disappears on unlock.

- [ ] **Step 7: Commit**

```bash
git add Sources/Halo/System/LockScreenSpace.swift Sources/Halo/System/UnlockWatch.swift Sources/Halo/Widgets/LockScreenController.swift
git commit -m "fix(lock screen): hide the card on unlock even with a stalled main thread

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Documentazione e misura finale

**Files:**
- Modify: `docs/design.md` (sections "Estetica", "Notifiche", "Widget sul desktop e schermata di blocco", "File")
- Modify: `README.md` (feature table rows "Widget sul desktop", "Schermata di blocco", "Notifiche")

- [ ] **Step 1: Update `docs/design.md`**

- "Estetica": replace the bullet "Card desktop/lock screen: vetro + copertina sfocata come campo di colore, bordo sottile." with "Widget desktop e card del lock screen in stile widget di macOS 26: Liquid Glass appena scurito, bordo da 0,5 pt, niente copertina sfocata; widget medio 360×170 (copertina 142 pt, app sorgente, titolo, artista — album, barra, controlli); sul lock screen sotto un separatore le 3 righe del testo."
- "Notifiche": append "Il banner è in stile Dynamic Island: icona dell'app, mittente in grassetto con sottotitolo attenuato accanto, testo su 2 righe (`NotificationText`, testato), a destra la miniatura della foto allegata (`NotificationPayload.imageURL`, `NotificationThumbnail` con ImageIO fuori dal main thread) o \"ora\". Le notifiche dei siti (`_WEB_CENTER_…`) sono escluse."
- "Widget sul desktop e schermata di blocco": append "Allo sblocco `UnlockWatch` (notifica Darwin `com.apple.sessionagent.screenIsUnlocked` su una coda privata) nasconde subito lo spazio SkyLight, anche con il main thread bloccato."
- "File": in the `UI/Widgets/` line replace `CardBackdrop, PlayerCardView` with `WidgetBackdrop, PlayerWidgetView, LyricsStrip`; add `UnlockWatch` to the `System/` line; add `NotificationText, NotificationThumbnail` to the notifications line; add `AppName` to the `App/` line.

- [ ] **Step 2: Update `README.md`** — in the feature table set the "Note" of "Widget sul desktop" to "widget medio in vetro come quelli di macOS 26, oppure orologio e meteo", of "Schermata di blocco" to "player e testi mentre il Mac è bloccato; sparisce subito allo sblocco", of "Notifiche" to "stile Dynamic Island con miniatura delle foto; clic = apre l'app; niente notifiche dei siti".

- [ ] **Step 3: Final measurement (manual)**

With Low Power Mode off and Spotify at volume 0: run the A/B used on 2026-09-29, four rounds of "Halo closed / Halo open" while playing, desktop widget on:

```bash
avg(){ top -pid 411 -l 9 -s 1 -stats cpu | grep -E "^[0-9]" | tail -8 | awk '{s+=$NF} END {printf "%.1f", s/NR}'; }
for i in 1 2 3 4; do pkill -x Halo; sleep 2; a=$(avg); open build/Halo.app; sleep 12; b=$(avg); echo "$a -> $b"; done
```

(411 is WindowServer's PID on this Mac; check with `pgrep -x WindowServer`.) Expected: Halo ~0%, WindowServer delta within noise (about ±5) once the equalizer burst is over. Report the numbers to the user.

- [ ] **Step 4: Commit**

```bash
git add docs/design.md README.md
git commit -m "docs: Apple-style widgets, lock screen card and notification banner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
