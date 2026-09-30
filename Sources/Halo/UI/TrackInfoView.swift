import AppKit
import SwiftUI

struct TrackInfoView: View {
    let title: String
    let artist: String?
    /// Titles too long for the space scroll while this is true (the player is on screen);
    /// otherwise they are truncated.
    var scrolls = false

    static let titleSize = Typography.titleSize
    static let titleTracking: CGFloat = -0.2

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { proxy in
                let width = Self.titleWidth(title)
                if scrolls && width > proxy.size.width {
                    MarqueeText(text: title, textWidth: width, font: titleFont, tracking: Self.titleTracking)
                        .frame(width: proxy.size.width, alignment: .leading)
                } else {
                    Text(title)
                        .font(titleFont)
                        .tracking(Self.titleTracking)
                        .frame(width: proxy.size.width, alignment: .leading)
                }
            }
            .frame(height: 19)
            .foregroundStyle(.white)

            Text(artist ?? "")
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Ink.secondary)
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentTransition(.opacity)
        .animation(Motion.content, value: title)
        .accessibilityElement(children: .combine)
    }

    private var titleFont: Font {
        Typography.title
    }

    /// Width of the title as drawn, measured with AppKit so no view state is needed.
    static func titleWidth(_ title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: titleSize, weight: .semibold)
        let size = (title as NSString).size(withAttributes: [.font: font, .kern: titleTracking])
        return ceil(size.width)
    }
}

/// A title that glides left, pauses, and loops seamlessly (two copies side by side), with
/// faded edges. It exists only while scrolling is wanted, so nothing animates otherwise.
struct MarqueeText: View {
    let text: String
    let textWidth: CGFloat
    let font: Font
    let tracking: CGFloat

    static let gap: CGFloat = 36
    /// Points per second.
    static let speed: CGFloat = 32
    static let pause: TimeInterval = 1.8

    var body: some View {
        let distance = textWidth + Self.gap
        let travel = Double(distance / Self.speed)
        let pause = Self.pause

        HStack(spacing: Self.gap) {
            Text(text).font(font).tracking(tracking)
            Text(text).font(font).tracking(tracking)
        }
        .fixedSize()
        .phaseAnimator([false, true]) { content, scrolled in
            content.offset(x: scrolled ? -distance : 0)
        } animation: { scrolled in
            scrolled ? .linear(duration: travel).delay(pause) : .linear(duration: 0.001)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.04),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .accessibilityLabel(text)
    }
}
