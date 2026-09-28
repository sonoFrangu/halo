import CoreGraphics
import Testing
@testable import Halo

@MainActor
struct ClipboardTests {
    private func text(_ value: String) -> ClipboardItem {
        ClipboardItem(content: .text(value), thumbnail: nil)
    }

    @Test func newestComesFirst() {
        var items: [ClipboardItem] = []
        items = ClipboardItem.inserting(text("a"), into: items, limit: 20)
        items = ClipboardItem.inserting(text("b"), into: items, limit: 20)
        #expect(items.map(\.content) == [.text("b"), .text("a")])
    }

    @Test func copyingAgainMovesToTheTop() {
        var items = [text("b"), text("a")]
        items = ClipboardItem.inserting(text("a"), into: items, limit: 20)
        #expect(items.map(\.content) == [.text("a"), .text("b")])
    }

    @Test func oldestFallOffBeyondTheLimit() {
        var items: [ClipboardItem] = []
        for value in ["1", "2", "3", "4"] {
            items = ClipboardItem.inserting(text(value), into: items, limit: 3)
        }
        #expect(items.map(\.content) == [.text("4"), .text("3"), .text("2")])
    }
}

@MainActor
struct ExpandedTabsTests {
    @Test(arguments: IslandLayoutTests.layouts)
    func everyTabFitsTheWing(layout: IslandLayout) {
        let available = layout.tabsFrame.width
        for count in 1...ExpandedTab.allCases.count {
            let width = ExpandedTabsView.pillWidth(count: count, available: available)
            let needed = width * CGFloat(count) + ExpandedTabsView.spacing * CGFloat(count - 1)
            #expect(needed <= available)
            #expect(width >= 16)
        }
    }

    @Test func fullSizeWhenThereIsRoom() {
        #expect(ExpandedTabsView.pillWidth(count: 4, available: 200) == ExpandedTabsView.pillSize.width)
    }
}
