import Foundation
import Logging
import ScullyTypes

/// Manages caching for Scully
public actor CacheManager {
    private let logger = Logger(label: "scully.cache")
    private let configuration: ScullyConfiguration
    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    // In-memory cache for faster access
    private var packageInfoCache: [String: (info: PackageInfo, timestamp: Date)] = [:]
    private var documentationCache: [String: (doc: PackageDocumentation, timestamp: Date)] = [:]

    public init(configuration: ScullyConfiguration) {
        self.configuration = configuration

        // Create cache directory in user's Library
        let libraryPath = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        self.cacheDirectory = libraryPath.appendingPathComponent("Scully/Cache")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load existing cache from disk
        Task {
            await loadCacheFromDisk()
        }
    }

    // MARK: - Package Info Caching

    /// Stores package information in cache
    public func storePackageInfo(_ info: PackageInfo, url: String) async {
        guard configuration.cacheEnabled else { return }

        let key = url
        packageInfoCache[key] = (info, Date())

        // Also save to disk for persistence
        let fileURL = cacheDirectory.appendingPathComponent("package_\(key.hash).json")
        await saveToDisk(object: info, url: fileURL)

        logger.debug("Cached package info for \(info.name)")
    }

    /// Retrieves package information from cache
    public func getPackageInfo(url: String) async -> PackageInfo? {
        guard configuration.cacheEnabled else { return nil }

        let key = url

        // Check memory cache first
        if let cached = packageInfoCache[key] {
            if !isExpired(cached.timestamp) {
                logger.debug("Package info cache hit for \(key)")
                return cached.info
            } else {
                // Remove expired entry
                packageInfoCache.removeValue(forKey: key)
            }
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("package_\(key.hash).json")
        if let cached = await loadFromDisk(type: PackageInfo.self, url: fileURL) {
            // Add to memory cache
            packageInfoCache[key] = (cached, Date())
            logger.debug("Package info disk cache hit for \(key)")
            return cached
        }

        return nil
    }

    // MARK: - Documentation Caching

    /// Stores documentation in cache
    public func storeDocumentation(_ doc: PackageDocumentation, key: String) async {
        guard configuration.cacheEnabled else { return }

        documentationCache[key] = (doc, Date())

        // Also save to disk
        let fileURL = cacheDirectory.appendingPathComponent("doc_\(key.hash).json")
        await saveToDisk(object: doc, url: fileURL)

        logger.debug("Cached documentation for \(doc.packageName)")
    }

    /// Retrieves documentation from cache
    public func getDocumentations(key: String) async -> PackageDocumentation? {
        guard configuration.cacheEnabled else { return nil }

        // Check memory cache first
        if let cached = documentationCache[key] {
            if !isExpired(cached.timestamp) {
                logger.debug("Documentation cache hit for \(key)")
                return cached.doc
            } else {
                // Remove expired entry
                documentationCache.removeValue(forKey: key)
            }
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("doc_\(key.hash).json")
        if let cached = await loadFromDisk(type: PackageDocumentation.self, url: fileURL) {
            // Add to memory cache
            documentationCache[key] = (cached, Date())
            logger.debug("Documentation disk cache hit for \(key)")
            return cached
        }

        return nil
    }

    // MARK: - Cache Management

    /// Clears all cached data
    public func clearCache() async {
        packageInfoCache.removeAll()
        documentationCache.removeAll()

        // Remove all files in cache directory
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in files {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            logger.warning("Failed to clear cache directory: \(error)")
        }

        logger.info("Cache cleared")
    }

    /// Clears expired cache entries
    public func clearExpiredCache() async {
        let now = Date()

        // Clear expired entries from memory cache
        packageInfoCache = packageInfoCache.filter { !$0.value.timestamp.addingTimeInterval(configuration.cacheExpiry).isEarlier(now) }
        documentationCache = documentationCache.filter { !$0.value.timestamp.addingTimeInterval(configuration.cacheExpiry).isEarlier(now) }

        // Clear expired files from disk
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            for fileURL in files {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = resourceValues.contentModificationDate,
                   modificationDate.addingTimeInterval(configuration.cacheExpiry).isEarlier(now) {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            logger.warning("Failed to clear expired cache: \(error)")
        }

        logger.info("Expired cache cleared")
    }

    /// Gets cache statistics
    public func getCacheStats() -> CacheStats {
        let totalSize = calculateDirectorySize()
        return CacheStats(
            packageInfoCount: packageInfoCache.count,
            documentationCount: documentationCache.count,
            totalSizeBytes: totalSize,
            cacheEnabled: configuration.cacheEnabled,
            cacheExpiry: configuration.cacheExpiry
        )
    }

    // MARK: - Private Helpers

    private func isExpired(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) > configuration.cacheExpiry
    }

    private func saveToDisk<T: Codable>(object: T, url: URL) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(object)
            try data.write(to: url)
        } catch {
            logger.error("Failed to save cache to disk: \(error)")
        }
    }

    private func loadFromDisk<T: Codable>(type: T.Type, url: URL) async -> T? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let object = try decoder.decode(type, from: data)

            // Check if expired
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modificationDate = resourceValues.contentModificationDate,
               isExpired(modificationDate) {
                // Remove expired file
                try? fileManager.removeItem(at: url)
                return nil
            }

            return object
        } catch {
            logger.debug("Failed to load cache from disk: \(error)")
            return nil
        }
    }

    private func loadCacheFromDisk() async {
        // This could be implemented to pre-load frequently used items
        // For now, we'll load on-demand
    }

    private func calculateDirectorySize() -> Int64 {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0

            for fileURL in files {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }

            return totalSize
        } catch {
            return 0
        }
    }
}

// MARK: - Cache Statistics

public struct CacheStats {
    public let packageInfoCount: Int
    public let documentationCount: Int
    public let totalSizeBytes: Int64
    public let cacheEnabled: Bool
    public let cacheExpiry: TimeInterval

    public var totalSizeFormatted: String {
        return ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}

// MARK: - Date Extension

private extension Date {
    func isEarlier(_ other: Date) -> Bool {
        return self.compare(other) == .orderedAscending
    }
}