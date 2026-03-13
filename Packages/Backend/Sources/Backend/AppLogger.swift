import os

/// Centralised logging for RedditOS.
///
/// Each category maps to a logical layer of the application so that logs can
/// be filtered in Console.app or `log stream` using:
///
///     log stream --predicate 'subsystem == "com.RedditOS"'
///     log stream --predicate 'subsystem == "com.RedditOS" AND category == "Network"'
public struct AppLogger {
    private static let subsystem = "com.RedditOS"

    /// Logs related to URLSession requests and responses.
    public static let network      = Logger(subsystem: subsystem, category: "Network")

    /// Logs related to OAuth flows and token lifecycle.
    public static let auth         = Logger(subsystem: subsystem, category: "Authentication")

    /// Logs related to on-disk persistence (load / save operations).
    public static let persistence  = Logger(subsystem: subsystem, category: "Persistence")

    /// Logs related to subreddit listing fetch operations.
    public static let subreddit    = Logger(subsystem: subsystem, category: "Subreddit")

    /// Logs related to post detail and comment fetch operations.
    public static let post         = Logger(subsystem: subsystem, category: "Post")

    /// Logs related to subreddit search operations.
    public static let search       = Logger(subsystem: subsystem, category: "Search")

    /// Logs related to the current authenticated user.
    public static let user         = Logger(subsystem: subsystem, category: "User")
}
