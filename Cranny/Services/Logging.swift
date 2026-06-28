import Foundation
import OSLog

/// Centralized loggers. View web-layer logs headlessly with:
///   log stream --predicate 'subsystem == "com.alanko.cranny"'
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.alanko.cranny"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let net = Logger(subsystem: subsystem, category: "net")
    static let player = Logger(subsystem: subsystem, category: "player")
    static let playerJS = Logger(subsystem: subsystem, category: "player.js")
}
