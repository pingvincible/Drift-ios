import Foundation

/// Photos kept on disk, split by theme.
///
/// One file per picture plus a small JSON sidecar with the credit line, so the
/// author is still known with no network. There is no central index to keep in
/// sync: the directory itself is the index.
///
/// Lives in Application Support rather than Caches because the whole point of
/// it is to survive — it is what the slideshow plays when there is no network.
/// The size limit is enforced here instead.
actor ImageCache {
    struct Key: Hashable {
        let themeID: String
        let photoID: String
        /// Which screen orientation this file was downloaded for.
        let variant: String

        var fileName: String { "\(photoID.fileSafe)@\(variant.fileSafe)" }
    }

    struct Entry: Hashable {
        let key: Key
        let fileURL: URL
        let byteSize: Int
        let lastUsed: Date
    }

    struct Stats: Equatable {
        var byteSize: Int = 0
        var fileCount: Int = 0
    }

    static let defaultLimitBytes = 512 * 1024 * 1024

    private let root: URL
    private let fileManager = FileManager.default
    private var limitBytes: Int
    /// Running total, so a swap does not have to walk the whole tree.
    private var knownTotal: Int?

    init(limitBytes: Int = ImageCache.defaultLimitBytes, root: URL? = nil) {
        self.limitBytes = max(limitBytes, 16 * 1024 * 1024)
        self.root = root ?? Self.defaultRoot()
    }

    // MARK: - Reading

    func data(for key: Key) -> Data? {
        let url = imageURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        touch(url)
        return data
    }

    func attribution(for key: Key) -> PhotoAttribution? {
        guard let data = try? Data(contentsOf: sidecarURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(PhotoAttribution.self, from: data)
    }

    /// Everything cached for a theme, newest use first.
    func entries(themeID: String) -> [Entry] {
        entries(in: themeDirectory(themeID), themeID: themeID)
            .sorted { $0.lastUsed > $1.lastUsed }
    }

    /// Credits of everything cached for a theme, most recently shown first.
    func attributions(themeID: String) -> [PhotoAttribution] {
        var seen = Set<String>()
        return entries(themeID: themeID).compactMap { entry in
            guard let credit = attribution(for: entry.key),
                  seen.insert(credit.photoID).inserted
            else { return nil }
            return credit
        }
    }

    func stats(themeID: String? = nil) -> Stats {
        let all = themeID.map { entries(in: themeDirectory($0), themeID: $0) } ?? allEntries()
        return Stats(byteSize: all.reduce(0) { $0 + $1.byteSize }, fileCount: all.count)
    }

    // MARK: - Writing

    func store(_ data: Data, attribution: PhotoAttribution?, for key: Key) {
        let directory = themeDirectory(key.themeID)
        let url = imageURL(for: key)
        let replaced = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            if let attribution, let encoded = try? JSONEncoder().encode(attribution) {
                try? encoded.write(to: sidecarURL(for: key), options: .atomic)
            }
            knownTotal = (knownTotal ?? currentTotal()) - replaced + data.count
            excludeFromBackup()
            evictIfNeeded()
        } catch {
            // A cache write that fails must not break the slideshow.
            knownTotal = nil
        }
    }

    // MARK: - Housekeeping

    func setLimit(bytes: Int) {
        limitBytes = max(bytes, 16 * 1024 * 1024)
        evictIfNeeded()
    }

    func clear(themeID: String? = nil) {
        if let themeID {
            try? fileManager.removeItem(at: themeDirectory(themeID))
        } else {
            try? fileManager.removeItem(at: root)
        }
        knownTotal = nil
    }

    /// Drops the least recently used files until the cache fits the limit.
    func evictIfNeeded() {
        var total = knownTotal ?? currentTotal()
        guard total > limitBytes else {
            knownTotal = total
            return
        }
        // Oldest first.
        for entry in allEntries().sorted(by: { $0.lastUsed < $1.lastUsed }) {
            guard total > limitBytes else { break }
            try? fileManager.removeItem(at: entry.fileURL)
            try? fileManager.removeItem(at: sidecarURL(for: entry.key))
            total -= entry.byteSize
        }
        knownTotal = total
    }

    // MARK: - Paths

    private static func defaultRoot() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.cachesDirectory
        return base.appendingPathComponent("Drift/Photos", isDirectory: true)
    }

    private func themeDirectory(_ themeID: String) -> URL {
        root.appendingPathComponent(themeID.fileSafe, isDirectory: true)
    }

    private func imageURL(for key: Key) -> URL {
        themeDirectory(key.themeID).appendingPathComponent(key.fileName + ".jpg")
    }

    private func sidecarURL(for key: Key) -> URL {
        themeDirectory(key.themeID).appendingPathComponent(key.fileName + ".json")
    }

    // MARK: - Directory walking

    private func allEntries() -> [Entry] {
        let themes = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return themes.flatMap { entries(in: $0, themeID: $0.lastPathComponent) }
    }

    private func entries(in directory: URL, themeID: String) -> [Entry] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return files.compactMap { url in
            guard url.pathExtension == "jpg" else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = url.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "@", maxSplits: 1)
            guard let photoID = parts.first else { return nil }
            return Entry(
                key: Key(
                    themeID: themeID,
                    photoID: String(photoID),
                    variant: parts.count > 1 ? String(parts[1]) : ""
                ),
                fileURL: url,
                byteSize: values?.fileSize ?? 0,
                lastUsed: values?.contentModificationDate ?? .distantPast
            )
        }
    }

    private func currentTotal() -> Int {
        allEntries().reduce(0) { $0 + $1.byteSize }
    }

    /// Marks a file as just used, which is what the eviction order reads.
    private func touch(_ url: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    private func excludeFromBackup() {
        var url = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}

private extension String {
    /// Keeps a string usable as a file name without surprises.
    var fileSafe: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(scalars)
    }
}
