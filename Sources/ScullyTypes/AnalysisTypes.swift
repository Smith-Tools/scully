import Foundation

// MARK: - Analysis Result Types

/// Result of a project analysis
public struct ProjectAnalysisResult: Codable, Sendable {
    public let projectPath: String
    public let manifest: PackageManifest
    public let dependencies: [PackageInfo]
    public let analyzedAt: Date
    public let issues: [AnalysisIssue]

    public init(projectPath: String, manifest: PackageManifest, dependencies: [PackageInfo] = [], issues: [AnalysisIssue] = []) {
        self.projectPath = projectPath
        self.manifest = manifest
        self.dependencies = dependencies
        self.analyzedAt = Date()
        self.issues = issues
    }
}

/// Issues found during analysis
public struct AnalysisIssue: Codable, Sendable {
    public let severity: Severity
    public let message: String
    public let suggestion: String?

    public enum Severity: String, Codable, Sendable {
        case info
        case warning
        case error
    }

    public init(severity: Severity, message: String, suggestion: String? = nil) {
        self.severity = severity
        self.message = message
        self.suggestion = suggestion
    }
}

/// Search result for packages
public struct PackageSearchResult: Codable, Sendable {
    public let package: PackageInfo
    public let relevanceScore: Double
    public let matchedContent: [String]

    public init(package: PackageInfo, relevanceScore: Double, matchedContent: [String] = []) {
        self.package = package
        self.relevanceScore = relevanceScore
        self.matchedContent = matchedContent
    }
}

/// Documentation search result
public struct DocumentationSearchResult: Codable, Sendable {
    public let documentation: PackageDocumentation
    public let relevanceScore: Double
    public let excerpts: [String]

    public init(documentation: PackageDocumentation, relevanceScore: Double, excerpts: [String] = []) {
        self.documentation = documentation
        self.relevanceScore = relevanceScore
        self.excerpts = excerpts
    }
}

/// Configuration for Scully operations
public struct ScullyConfiguration: Codable, Sendable {
    public let cacheEnabled: Bool
    public let cacheExpiry: TimeInterval
    public let maxConcurrentRequests: Int
    public let gitHubToken: String?
    public let preferredDocumentationSources: [DocumentationSource]

    public enum DocumentationSource: String, Codable, Sendable {
        case readme
        case docc
        case guides
        case examples
    }

    public init(cacheEnabled: Bool = true, cacheExpiry: TimeInterval = 3600, maxConcurrentRequests: Int = 10, gitHubToken: String? = nil, preferredDocumentationSources: [DocumentationSource] = [.readme, .docc]) {
        self.cacheEnabled = cacheEnabled
        self.cacheExpiry = cacheExpiry
        self.maxConcurrentRequests = maxConcurrentRequests
        self.gitHubToken = gitHubToken
        self.preferredDocumentationSources = preferredDocumentationSources
    }
}

// MARK: - Errors

public enum ScullyError: Error, LocalizedError {
    case packageNotFound(String)
    case invalidManifest(String)
    case networkError(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .packageNotFound(let name):
            return "Package '\(name)' not found"
        case .invalidManifest(let path):
            return "Invalid Package.swift at \(path)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}