/// The three shapes the island can take.
enum IslandState: Sendable, Equatable {
    /// Hidden inside the physical notch (or a small fake notch on screens without one).
    case idle
    /// Music is playing: the notch grows two wings (artwork left, equalizer right).
    case compact
    /// Hovered: the full player.
    case expanded
}
