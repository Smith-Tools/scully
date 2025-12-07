import Foundation
import NIOCore
import NIOPosix
import Logging
import ScullyTypes

/// Fetches package list from Swift Package Index
public actor PackageListFetcher {
    private let logger = Logger(label: "scully.packagelist")
    private let session: URLSession
    private let packageListURL = URL(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json")!
    private let fileManager = FileManager.default
    private let cacheExpiry: TimeInterval = 86400 // 24 hours
    
    // In-memory cache
    private var cachedPackages: [String]?
    private var cacheTimestamp: Date?
    
    // Disk cache location
    private var cacheFileURL: URL {
        let libraryPath = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let cacheDir = libraryPath.appendingPathComponent("Scully/Cache")
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir.appendingPathComponent("package_list.json")
    }

    public init() {
        self.session = URLSession.shared
    }

    /// Fetches the complete package list from SPI (with caching)
    public func fetchPackageList() async throws -> [String] {
        // Check memory cache first
        if let cached = cachedPackages,
           let timestamp = cacheTimestamp,
           !isExpired(timestamp) {
            logger.debug("Package list memory cache hit (\(cached.count) packages)")
            return cached
        }
        
        // Check disk cache
        if let diskCached = try? loadPackageListFromDisk(),
           !diskCached.isEmpty {
            logger.debug("Package list disk cache hit (\(diskCached.count) packages)")
            cachedPackages = diskCached
            cacheTimestamp = Date()
            return diskCached
        }
        
        // Fetch from network
        logger.info("Fetching package list from Swift Package Index (cache miss)")

        let (data, response) = try await session.data(from: packageListURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScullyError.networkError("Failed to fetch package list")
        }

        // The packages.json contains an array of package URLs
        guard let packageURLs = try? JSONDecoder().decode([String].self, from: data) else {
            throw ScullyError.parseError("Failed to decode package list")
        }

        logger.info("Fetched \(packageURLs.count) packages from Swift Package Index")
        
        // Cache the result
        cachedPackages = packageURLs
        cacheTimestamp = Date()
        try? savePackageListToDisk(packageURLs)
        
        return packageURLs
    }
    
    // MARK: - Cache Helpers
    
    private func isExpired(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) > cacheExpiry
    }
    
    private func loadPackageListFromDisk() throws -> [String]? {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return nil
        }
        
        // Check if file is expired
        let attributes = try fileManager.attributesOfItem(atPath: cacheFileURL.path)
        if let modificationDate = attributes[.modificationDate] as? Date,
           isExpired(modificationDate) {
            try? fileManager.removeItem(at: cacheFileURL)
            return nil
        }
        
        let data = try Data(contentsOf: cacheFileURL)
        return try JSONDecoder().decode([String].self, from: data)
    }
    
    private func savePackageListToDisk(_ packages: [String]) throws {
        let data = try JSONEncoder().encode(packages)
        try data.write(to: cacheFileURL)
        logger.debug("Saved package list to disk cache")
    }

    /// Searches for packages by name
    public func searchPackages(query: String, limit: Int = 20) async throws -> [PackageSearchResult] {
        let packages = try await fetchPackageList()

        let filtered = packages.filter { packageURL in
            // Extract package name from URL for matching
            let name = extractPackageName(from: packageURL)
            return name.localizedCaseInsensitiveContains(query)
        }.prefix(limit)

        var results: [PackageSearchResult] = []

        for packageURL in filtered {
            let name = extractPackageName(from: packageURL)
            let relevanceScore = calculateRelevanceScore(for: name, query: query)

            results.append(PackageSearchResult(
                package: PackageInfo(
                    name: name,
                    url: packageURL,
                    repositoryType: .github
                ),
                relevanceScore: relevanceScore
            ))
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    /// Gets package information from the package list
    public func getPackageInfo(_ name: String) async throws -> PackageInfo? {
        let packages = try await fetchPackageList()

        // Find exact match first
        if let packageURL = packages.first(where: { extractPackageName(from: $0) == name }) {
            return PackageInfo(
                name: name,
                url: packageURL,
                repositoryType: .github
            )
        }

        // Find partial matches
        if let packageURL = packages.first(where: {
            extractPackageName(from: $0).localizedCaseInsensitiveContains(name)
        }) {
            let actualName = extractPackageName(from: packageURL)
            return PackageInfo(
                name: actualName,
                url: packageURL,
                repositoryType: .github
            )
        }

        return nil
    }

    // MARK: - Private Helpers

    private func extractPackageName(from url: String) -> String {
        guard let components = URLComponents(string: url) else {
            return "Unknown"
        }

        // Handle GitHub URLs
        if components.host?.contains("github.com") == true {
            let pathComponents = components.path.split(separator: "/")
            if pathComponents.count >= 2 {
                return String(pathComponents[1])
            }
        }

        // Fallback: extract from path
        let pathComponents = components.path.split(separator: "/")
        return pathComponents.last?.replacingOccurrences(of: ".git", with: "") ?? "Unknown"
    }

    private func calculateRelevanceScore(for name: String, query: String) -> Double {
        let lowerName = name.lowercased()
        let lowerQuery = query.lowercased()

        // Exact match gets highest score
        if lowerName == lowerQuery {
            return 1.0
        }

        // Starts with query gets high score
        if lowerName.hasPrefix(lowerQuery) {
            return 0.9
        }

        // Contains query gets medium score
        if lowerName.contains(lowerQuery) {
            // Score based on how much of the string matches
            let matchLength = Double(lowerQuery.count)
            let nameLength = Double(lowerName.count)
            return 0.5 + (matchLength / nameLength) * 0.3
        }

        // Fuzzy match based on character similarity
        return fuzzyMatch(name: name, query: query)
    }

    private func fuzzyMatch(name: String, query: String) -> Double {
        let nameChars = Array(name.lowercased())
        let queryChars = Array(query.lowercased())

        var matches = 0
        var queryIndex = 0

        for char in nameChars {
            if queryIndex < queryChars.count && char == queryChars[queryIndex] {
                matches += 1
                queryIndex += 1
            }
        }

        guard !queryChars.isEmpty else { return 0 }

        return Double(matches) / Double(queryChars.count) * 0.4
    }
}