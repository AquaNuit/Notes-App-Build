import Foundation
import OSLog

// MARK: - InscribeLogger

/// Unified logging system for Inscribe.
///
/// Wraps Apple's os.log family with a clean, category-based API.
/// Automatically disables debug logs in release builds.
public struct InscribeLogger: Sendable {

    public let subsystem: String
    public let category: String

    private let logger: Logger

    public init(subsystem: String = "com.inscribe", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Log Levels

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        logger.debug("\(formatMessage(message, file: file, function: function, line: line))")
        #endif
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info("\(formatMessage(message, file: file, function: function, line: line))")
    }

    public func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.notice("\(formatMessage(message, file: file, function: function, line: line))")
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error("\(formatMessage(message, file: file, function: function, line: line))")
    }

    public func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.fault("\(formatMessage(message, file: file, function: function, line: line))")
    }

    // MARK: - Formatting

    private func formatMessage(_ message: String, file: String, function: String, line: Int) -> String {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        return "[\(fileName):\(line) \(function)] \(message)"
        #else
        return message
        #endif
    }

    // MARK: - Convenience Accessors

    public static let app = InscribeLogger(category: "app")
    public static let canvas = InscribeLogger(category: "canvas")
    public static let rendering = InscribeLogger(category: "rendering")
    public static let storage = InscribeLogger(category: "storage")
    public static let sync = InscribeLogger(category: "sync")
    public static let pencil = InscribeLogger(category: "pencil")
    public static let documents = InscribeLogger(category: "documents")
    public static let search = InscribeLogger(category: "search")
}
