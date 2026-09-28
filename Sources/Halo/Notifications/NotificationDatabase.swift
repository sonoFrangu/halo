import Foundation
import SQLite3

/// One delivered notification as stored by Notification Center.
struct NotificationRecord: Sendable, Equatable {
    let id: Int64
    let bundleIdentifier: String
    let data: Data
}

/// Read-only access to Notification Center's private SQLite database.
///
/// On current macOS the database lives in `usernoted`'s group container, which only
/// processes with Full Disk Access may read. Halo never writes to it: the connection is
/// opened read-only and only `SELECT`s run. Not thread-safe: its owner uses it from one
/// actor.
final class NotificationDatabase {
    enum OpenError: Error, Equatable {
        case notFound
        case permissionDenied
        case sqlite(String)
    }

    private var handle: OpaquePointer?

    /// `~/Library/Group Containers/group.com.apple.usernoted/db2/db`.
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/group.com.apple.usernoted/db2/db", directoryHint: .notDirectory)
    }

    /// Checks the file can actually be opened. `access(2)` and `isReadableFile` ignore
    /// privacy protection (TCC), so this opens the file and looks at `errno`.
    static func checkAccess(to url: URL) -> OpenError? {
        let descriptor = open(url.path, O_RDONLY)
        if descriptor >= 0 {
            close(descriptor)
            return nil
        }
        switch errno {
        case ENOENT, ENOTDIR: return .notFound
        case EPERM, EACCES: return .permissionDenied
        default: return .sqlite(String(cString: strerror(errno)))
        }
    }

    init(url: URL) throws(OpenError) {
        if let error = Self.checkAccess(to: url) {
            throw error
        }
        var connection: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY, nil)
        guard status == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed (\(status))"
            sqlite3_close(connection)
            throw .sqlite(message)
        }
        // usernoted may hold a write lock for a moment while it inserts.
        sqlite3_busy_timeout(connection, 250)
        handle = connection
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Highest record id so far; new notifications get larger ids.
    func latestID() throws(OpenError) -> Int64 {
        var latest: Int64 = 0
        try query("SELECT IFNULL(MAX(rec_id), 0) FROM record", row: { statement in
            latest = sqlite3_column_int64(statement, 0)
        })
        return latest
    }

    /// Records newer than `id`, oldest first.
    func records(after id: Int64, limit: Int) throws(OpenError) -> [NotificationRecord] {
        let sql = """
            SELECT record.rec_id, app.identifier, record.data
            FROM record JOIN app ON app.app_id = record.app_id
            WHERE record.rec_id > ?1
            ORDER BY record.rec_id ASC
            LIMIT ?2
            """
        var records: [NotificationRecord] = []
        try query(sql, bind: { statement in
            sqlite3_bind_int64(statement, 1, id)
            sqlite3_bind_int64(statement, 2, Int64(limit))
        }, row: { statement in
            let recordID = sqlite3_column_int64(statement, 0)
            guard let identifier = sqlite3_column_text(statement, 1) else { return }
            let bytes = sqlite3_column_blob(statement, 2)
            let count = Int(sqlite3_column_bytes(statement, 2))
            let data = bytes.map { Data(bytes: $0, count: count) } ?? Data()
            records.append(NotificationRecord(id: recordID, bundleIdentifier: String(cString: identifier), data: data))
        })
        return records
    }

    private func query(
        _ sql: String,
        bind: (OpaquePointer) -> Void = { _ in },
        row: (OpaquePointer) -> Void
    ) throws(OpenError) {
        guard let handle else { throw .sqlite("closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw .sqlite(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                row(statement)
            } else if status == SQLITE_DONE {
                return
            } else {
                throw .sqlite(String(cString: sqlite3_errmsg(handle)))
            }
        }
    }
}
