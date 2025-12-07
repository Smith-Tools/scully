import Foundation
import Logging
import NIOCore
import NIOPosix
import ScullyTypes
import ScullyAnalysis
import ScullyFetch
import ScullyProcess
import ScullyDatabase

/// Main engine for Scully operations
public actor ScullyEngine {
    private let logger = Logger(label: "scully.engine")
    private let configuration: ScullyConfiguration
    private let manifestAnalyzer: ManifestAnalyzer
    private let gitHubFetcher: GitHubFetcher
    private let packageListFetcher: PackageListFetcher
    private let cacheManager: CacheManager

    public init(configuration: ScullyConfiguration = ScullyConfiguration()) {
        self.configuration = configuration
        self.manifestAnalyzer = ManifestAnalyzer()
        self.gitHubFetcher = GitHubFetcher()
        self.packageListFetcher = PackageListFetcher()
        self.cacheManager = CacheManager(configuration: configuration)
    }

    // MARK: - Package Operations

    /// Lists dependencies in a project
    public func listDependencies(at path: String) async throws -> ProjectAnalysisResult {
        logger.info("Listing dependencies at path: \(path)")

        let manifest = try await manifestAnalyzer.analyze(at: path)
        var dependencies: [PackageInfo] = []
        var issues: [AnalysisIssue] = []

        // Fetch information for each dependency
        for dep in manifest.dependencies {
            do {
                if let url = dep.url {
                    let info = try await fetchPackageInfo(from: url)
                    dependencies.append(info)
                } else {
                    // Try to find package by name
                    if let info = try await searchPackage(byName: dep.name) {
                        dependencies.append(info)
                    }
                }
            } catch {
                logger.warning("Failed to fetch info for \(dep.name): \(error)")
                issues.append(AnalysisIssue(
                    severity: .warning,
                    message: "Could not fetch information for \(dep.name)",
                    suggestion: "Check if the package URL is correct"
                ))
            }
        }

        return ProjectAnalysisResult(
            projectPath: path,
            manifest: manifest,
            dependencies: dependencies,
            issues: issues
        )
    }

    /// Fetches documentation for a package
    public func fetchDocumentation(
        for packageName: String,
        version: String? = nil,
        includeExamples: Bool = false
    ) async throws -> PackageDocumentation {
        logger.info("Fetching documentation for \(packageName)")

        // First try to find the package
        let packageInfo = try await searchPackage(byName: packageName)
        guard let packageInfo = packageInfo else {
            throw ScullyError.packageNotFound(packageName)
        }

        // Check cache first
        let cacheKey = "docs_\(packageName)_\(version ?? "latest")"
        if let cached = await cacheManager.getDocumentations(key: cacheKey) {
            logger.info("Returning cached documentation for \(packageName)")
            return cached
        }

        // Fetch from GitHub
        let doc = try await gitHubFetcher.fetchDocumentation(
            from: packageInfo.url,
            version: version
        )

        // Cache the result
        if configuration.cacheEnabled {
            await cacheManager.storeDocumentation(doc, key: cacheKey)
        }

        return doc
    }

    /// Finds code examples for a package
    public func findExamples(
        for packageName: String,
        filter: String? = nil,
        limit: Int = 10
    ) async throws -> [CodeExample] {
        logger.info("Finding examples for \(packageName)")

        let packageInfo = try await searchPackage(byName: packageName)
        guard let packageInfo = packageInfo else {
            throw ScullyError.packageNotFound(packageName)
        }

        let examples = try await gitHubFetcher.findExamples(
            from: packageInfo.url,
            filter: filter
        )

        return Array(examples.prefix(limit))
    }

    /// Generates a summary of package documentation
    public func generateSummary(
        for packageName: String,
        version: String? = nil
    ) async throws -> DocumentationSummary {
        logger.info("Generating summary for \(packageName)")

        let docs = try await fetchDocumentation(for: packageName, version: version)
        let examples = try await findExamples(for: packageName, limit: 20)

        // Use the process module to generate summary
        let summarizer = Summarizer()
        return try await summarizer.generateSummary(
            documentation: docs,
            examples: examples
        )
    }

    /// Extracts usage patterns from documentation and examples
    public func extractPatterns(
        for packageName: String,
        threshold: Int = 2
    ) async throws -> [UsagePattern] {
        logger.info("Extracting patterns for \(packageName)")

        let docs = try await fetchDocumentation(for: packageName)
        let examples = try await findExamples(for: packageName, limit: 50)

        let patternExtractor = PatternExtractor()
        let patterns = try await patternExtractor.extractPatterns(
            from: docs,
            examples: examples
        )

        return patterns.filter { $0.frequency >= threshold }
    }

    // MARK: - Private Helpers

    private func fetchPackageInfo(from url: String) async throws -> PackageInfo {
        // Check cache first
        if configuration.cacheEnabled,
           let cached = await cacheManager.getPackageInfo(url: url) {
            return cached
        }

        let info = try await gitHubFetcher.fetchRepositoryInfo(from: url)

        // Cache the result
        if configuration.cacheEnabled {
            await cacheManager.storePackageInfo(info, url: url)
        }

        return info
    }

    private func searchPackage(byName name: String) async throws -> PackageInfo? {
        logger.info("Searching for package: \(name)")

        // Try to find in package list first
        let packages = try await packageListFetcher.fetchPackageList()
        let matchingPackages = packages.filter { $0.lowercased().contains(name.lowercased()) }

        if let packageURL = matchingPackages.first {
            return try await fetchPackageInfo(from: packageURL)
        }

        // Fallback: try common GitHub patterns
        let commonPatterns = [
            "https://github.com/\(name)/\(name)",
            "https://github.com/apple/\(name)",
            "https://github.com/Alamofire/\(name)",
        ]

        for pattern in commonPatterns {
            if let info = try? await fetchPackageInfo(from: pattern) {
                return info
            }
        }

        return nil
    }
}