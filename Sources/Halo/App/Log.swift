import os

/// Shared loggers. `Logger` is `Sendable`, so these are safe to use from any context.
enum Log {
    private static let subsystem = "io.github.sonofrangu.halo"

    static let adapter = Logger(subsystem: subsystem, category: "adapter")
    static let island = Logger(subsystem: subsystem, category: "island")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let hud = Logger(subsystem: subsystem, category: "hud")
}
