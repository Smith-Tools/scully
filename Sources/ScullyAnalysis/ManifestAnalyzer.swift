import Foundation
import Yams
import Logging
import ScullyTypes

/// Analyzes Package.swift manifests
public actor ManifestAnalyzer {
    public init() {}
    private let logger = Logger(label: "scully.manifest")

    /// Analyzes a Package.swift file at the given path
    public func analyze(at path: String) async throws -> PackageManifest {
        let packageSwiftPath = URL(fileURLWithPath: path)
            .appendingPathComponent("Package.swift")
            .path

        logger.info("Analyzing Package.swift at \(packageSwiftPath)")

        guard FileManager.default.fileExists(atPath: packageSwiftPath) else {
            throw ScullyError.invalidManifest("Package.swift not found at \(path)")
        }

        let content = try String(contentsOfFile: packageSwiftPath)

        // Try to parse using regex first for basic info
        if let manifest = try parseWithRegex(content: content, path: path) {
            logger.info("Successfully parsed manifest using regex")
            return manifest
        }

        // Fallback: try to extract minimal information
        logger.warning("Could not fully parse manifest, extracting minimal info")
        return try parseMinimal(content: content, path: path)
    }

    // MARK: - Private Parsing Methods

    private func parseWithRegex(content: String, path: String) throws -> PackageManifest? {
        // Extract package name
        let nameRegex = try NSRegularExpression(pattern: #"name:\s*"([^"]+)""#)
        let nameMatch = nameRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content))
        let name = nameMatch.map { String(content[Range($0.range(at: 1), in: content)!]) } ?? "Unknown"

        // Extract dependencies
        let dependencies = extractDependencies(from: content)

        // Extract platforms
        let platforms = extractPlatforms(from: content)

        // Extract products
        let products = extractProducts(from: content)

        return PackageManifest(
            name: name,
            dependencies: dependencies,
            platforms: platforms,
            products: products.isEmpty ? nil : products,
            targets: nil
        )
    }

    private func parseMinimal(content: String, path: String) throws -> PackageManifest {
        // Very basic extraction - just name and dependencies
        let lines = content.components(separatedBy: .newlines)

        var name = "Unknown"
        var dependencies: [PackageDependency] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("name:") {
                if let range = trimmed.range(of: "\"", options: .caseInsensitive) {
                    let startIndex = trimmed.index(after: range.lowerBound)
                    if let endIndex = trimmed.range(of: "\"", options: .caseInsensitive, range: startIndex..<trimmed.endIndex) {
                        name = String(trimmed[startIndex..<endIndex.lowerBound])
                    }
                }
            }

            if trimmed.contains(".package(") {
                if let dep = extractPackageDependency(from: trimmed) {
                    dependencies.append(dep)
                }
            }
        }

        return PackageManifest(
            name: name,
            dependencies: dependencies
        )
    }

    private func extractDependencies(from content: String) -> [PackageDependency] {
        var dependencies: [PackageDependency] = []

        // Match .package(url: "...", from: "...")
        let packageRegex = try! NSRegularExpression(
            pattern: #"\.package\(\s*url:\s*"([^"]+)"\s*,\s*(?:from:\s*"([^"]+)"|branch:\s*"([^"]+)"|revision:\s*"([^"]+)")"#
        )

        let matches = packageRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: content) else { continue }
            let url = String(content[urlRange])

            let version = match.range(at: 2).location != NSNotFound ?
                String(content[Range(match.range(at: 2), in: content)!]) : nil
            let branch = match.range(at: 3).location != NSNotFound ?
                String(content[Range(match.range(at: 3), in: content)!]) : nil
            let revision = match.range(at: 4).location != NSNotFound ?
                String(content[Range(match.range(at: 4), in: content)!]) : nil

            // Extract name from URL
            let name = extractNameFromURL(url)

            let dependency = PackageDependency(
                name: name,
                url: url,
                version: version,
                branch: branch,
                revision: revision
            )

            dependencies.append(dependency)
        }

        return dependencies
    }

    private func extractPackageDependency(from line: String) -> PackageDependency? {
        // Very basic extraction from a single line
        guard line.contains(".package(") else { return nil }

        var url: String?
        var version: String?

        let components = line.components(separatedBy: ",")

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("url:") {
                if let range = trimmed.range(of: "\"") {
                    let startIndex = trimmed.index(after: range.lowerBound)
                    if let endIndex = trimmed.range(of: "\"", range: startIndex..<trimmed.endIndex) {
                        url = String(trimmed[startIndex..<endIndex.lowerBound])
                    }
                }
            }

            if trimmed.contains("from:") {
                if let range = trimmed.range(of: "\"") {
                    let startIndex = trimmed.index(after: range.lowerBound)
                    if let endIndex = trimmed.range(of: "\"", range: startIndex..<trimmed.endIndex) {
                        version = String(trimmed[startIndex..<endIndex.lowerBound])
                    }
                }
            }
        }

        guard let urlString = url else { return nil }
        let name = extractNameFromURL(urlString)

        return PackageDependency(
            name: name,
            url: urlString,
            version: version
        )
    }

    private func extractPlatforms(from content: String) -> [String]? {
        let platformRegex = try! NSRegularExpression(
            pattern: #"platforms:\s*\[\s*([^]]+)\]"#
        )

        guard let match = platformRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let platformString = String(content[range])
        return platformString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractProducts(from content: String) -> [Product] {
        var products: [Product] = []

        // Simple regex to find .executable or .library definitions
        let productRegex = try! NSRegularExpression(
            pattern: #"\.(executable|library)\(name:\s*"([^"]+)""#
        )

        let matches = productRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: content),
                  let nameRange = Range(match.range(at: 2), in: content) else {
                continue
            }

            let typeString = String(content[typeRange])
            let name = String(content[nameRange])

            let productType: Product.ProductType = typeString == "executable" ? .executable : .library
            products.append(Product(name: name, type: productType))
        }

        return products
    }

    private func extractNameFromURL(_ url: String) -> String {
        // Extract repository name from GitHub URL
        if url.contains("github.com") {
            let components = URL(string: url)?.pathComponents ?? []
            if let last = components.last {
                return last.replacingOccurrences(of: ".git", with: "")
            }
        }

        // Fallback: extract from full path
        let components = url.components(separatedBy: "/")
        return components.last?.replacingOccurrences(of: ".git", with: "") ?? "Unknown"
    }
}

// MARK: - Dependency Lister

/// Simple dependency listing functionality
public actor DependencyLister {
    private let analyzer = ManifestAnalyzer()

    /// Lists dependencies from a Package.swift file
    public func listDependencies(at path: String) async throws -> [PackageDependency] {
        let manifest = try await analyzer.analyze(at: path)
        return manifest.dependencies
    }
}