//
//  DatabaseService.swift
//  VinillyApp
//
//  Final merged database layer for vinilly_offline_v6.db
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?

    private init() {
        openDatabase()
    }

    // MARK: - Database

    private func openDatabase() {
        guard let dbURL = Bundle.main.url(
            forResource: "vinilly_offline",
            withExtension: "db"
        ) else {
            print("❌ vinilly_offline.db was not found in the app bundle.")
            return
        }

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(dbURL.path, &db, flags, nil) != SQLITE_OK {
            printSQLiteError(prefix: "❌ Could not open vinilly_offline.db")
            sqlite3_close(db)
            db = nil
            return
        }

        print("✅ Vinilly offline database is ready.")
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Barcode Search

    func searchByBarcode(_ code: String) -> Vinyl? {
        guard db != nil else { return nil }

        let rawCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeBarcode(rawCode)

        guard !normalized.isEmpty else { return nil }

        // 1. Exact canonical barcode.
        if let vinyl = findVinyl(barcode: normalized) {
            return vinyl
        }

        // 2. UPC-A <-> EAN-13 alternative.
        if let alternative = alternativeBarcode(for: normalized),
           let vinyl = findVinyl(barcode: alternative) {
            return vinyl
        }

        // 3. Alias lookup using the raw scanner value.
        if let canonical = findCanonicalBarcode(forAlias: rawCode),
           let vinyl = findVinyl(barcode: canonical) {
            return vinyl
        }

        // 4. Alias lookup using our normalized value.
        if let canonical = findCanonicalBarcode(forAlias: normalized),
           let vinyl = findVinyl(barcode: canonical) {
            return vinyl
        }

        // 5. Alias lookup for UPC/EAN alternative.
        if let alternative = alternativeBarcode(for: normalized),
           let canonical = findCanonicalBarcode(forAlias: alternative),
           let vinyl = findVinyl(barcode: canonical) {
            return vinyl
        }

        return nil
    }

    private func findVinyl(barcode: String) -> Vinyl? {
        guard let db else { return nil }

        let sql = """
        SELECT
            barcode,
            title,
            artist,
            genre,
            year,
            source_cover_url
        FROM vinyls
        WHERE barcode = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError(prefix: "❌ Barcode query could not be prepared")
            return nil
        }

        bindText(barcode, to: statement, at: 1)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return makeVinyl(from: statement)
    }

    private func findCanonicalBarcode(forAlias alias: String) -> String? {
        guard let db else { return nil }

        let sql = """
        SELECT canonical_barcode
        FROM barcode_aliases
        WHERE raw_barcode = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            // Alias lookup is optional. If the table is unavailable,
            // direct barcode search can still continue normally.
            return nil
        }

        bindText(alias, to: statement, at: 1)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return columnString(statement, index: 0)
    }

    // MARK: - Manual Search

    func searchByText(query: String) -> [Vinyl] {
        guard let db else { return [] }

        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }

        // Prefix search is intentionally used instead of "%query%".
        // With ~795k records this is much friendlier to the offline DB.
        let pattern = "\(cleanQuery)%"

        let sql = """
        SELECT
            barcode,
            title,
            artist,
            genre,
            year,
            source_cover_url
        FROM vinyls
        WHERE
            artist LIKE ? COLLATE NOCASE
            OR title LIKE ? COLLATE NOCASE
        ORDER BY
            artist COLLATE NOCASE,
            title COLLATE NOCASE
        LIMIT 25;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError(prefix: "❌ Manual search query could not be prepared")
            return []
        }

        bindText(pattern, to: statement, at: 1)
        bindText(pattern, to: statement, at: 2)

        var results: [Vinyl] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let vinyl = makeVinyl(from: statement) {
                results.append(vinyl)
            }
        }

        return results
    }

    // MARK: - More by Artist

    func fetchOtherVinylsByArtist(
        artist: String,
        excludingBarcode: String
    ) -> [Vinyl] {
        guard let db else { return [] }

        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtist.isEmpty else { return [] }

        let sql = """
        SELECT
            barcode,
            title,
            artist,
            genre,
            year,
            source_cover_url
        FROM vinyls
        WHERE
            artist = ? COLLATE NOCASE
            AND barcode != ?
        ORDER BY
            title COLLATE NOCASE
        LIMIT 20;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError(prefix: "❌ Artist query could not be prepared")
            return []
        }

        bindText(cleanArtist, to: statement, at: 1)
        bindText(excludingBarcode, to: statement, at: 2)

        var results: [Vinyl] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let vinyl = makeVinyl(from: statement) {
                results.append(vinyl)
            }
        }

        return results
    }

    // MARK: - Row Mapping

    private func makeVinyl(from statement: OpaquePointer?) -> Vinyl? {
        guard let barcode = columnString(statement, index: 0),
              let title = columnString(statement, index: 1),
              let artist = columnString(statement, index: 2) else {
            return nil
        }

        let genre = normalizedMetadataValue(
            columnString(statement, index: 3)
        )

        let year = normalizedMetadataValue(
            columnString(statement, index: 4)
        )

        // v6 stores the legacy/network cover reference under source_cover_url.
        // We map it to Vinyl.coverUrl for compatibility with the existing UI.
        let coverURL = columnString(statement, index: 5)

        return Vinyl(
            barcode: barcode,
            title: title,
            artist: artist,
            genre: genre,
            year: year,
            coverUrl: coverURL
        )
    }

    private func normalizedMetadataValue(_ value: String?) -> String {
        guard let value else { return "Unknown" }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }

        let lowered = trimmed.lowercased()
        if ["unknown", "n/d", "n/a", "null", "none", "0"].contains(lowered) {
            return "Unknown"
        }

        return trimmed
    }

    // MARK: - Barcode Helpers

    private func normalizeBarcode(_ code: String) -> String {
        var result = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        while result.hasSuffix(">") {
            result.removeLast()
        }

        return result
    }

    private func alternativeBarcode(for code: String) -> String? {
        if code.count == 13, code.hasPrefix("0") {
            return String(code.dropFirst())
        }

        if code.count == 12 {
            return "0" + code
        }

        return nil
    }

    // MARK: - SQLite Helpers

    private func bindText(
        _ value: String,
        to statement: OpaquePointer?,
        at index: Int32
    ) {
        value.withCString { pointer in
            sqlite3_bind_text(
                statement,
                index,
                pointer,
                -1,
                SQLITE_TRANSIENT
            )
        }
    }

    private func columnString(
        _ statement: OpaquePointer?,
        index: Int32
    ) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    private func printSQLiteError(prefix: String) {
        if let db {
            print("\(prefix): \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print(prefix)
        }
    }
}
