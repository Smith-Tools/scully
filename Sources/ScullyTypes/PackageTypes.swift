import Foundation

// MARK: - Package Models

/// Represents a Swift package dependency
public struct PackageDependency: Codable, Hashable, Sendable {
    public let name: String
    public let url: String?
    public let version: String?
    public let branch: String?
    public let revision: String?
    public let type: DependencyType

    public enum DependencyType: String, Codable, Sendable {
        case sourceControl
        case local
        case registry
    }

    public init(name: String, url: String? = nil, version: String? = nil, branch: String? = nil, revision: String? = nil, type: DependencyType = .sourceControl) {
        self.name = name
        self.url = url
        self.version = version
        self.branch = branch
        self.revision = revision
        self.type = type
    }
}

/// Represents a parsed Package.swift manifest
public struct PackageManifest: Codable, Sendable {
    public let name: String
    public let version: String?
    public let dependencies: [PackageDependency]
    public let platforms: [String]?
    public let products: [Product]?
    public let targets: [Target]?

    public init(name: String, version: String? = nil, dependencies: [PackageDependency] = [], platforms: [String]? = nil, products: [Product]? = nil, targets: [Target]? = nil) {
        self.name = name
        self.version = version
        self.dependencies = dependencies
        self.platforms = platforms
        self.products = products
        self.targets = targets
    }
}

/// Represents a product defined in Package.swift
public struct Product: Codable, Sendable {
    public let name: String
    public let type: ProductType

    public enum ProductType: String, Codable, Sendable {
        case executable
        case library
        case plugin
    }

    public init(name: String, type: ProductType) {
        self.name = name
        self.type = type
    }
}

/// Represents a target defined in Package.swift
public struct Target: Codable, Sendable {
    public let name: String
    public let type: TargetType
    public let dependencies: [String]?

    public enum TargetType: String, Codable, Sendable {
        case executable
        case regular
        case test
        case plugin
    }

    public init(name: String, type: TargetType, dependencies: [String]? = nil) {
        self.name = name
        self.type = type
        self.dependencies = dependencies
    }
}

// MARK: - Package Information Models

@_exported import SmithDocs


/// Code example extracted from playgrounds or documentation
public struct CodeExample: Codable, Sendable {
    public let packageName: String
    public let title: String
    public let code: String
    public let language: String
    public let description: String?
    public let source: String
    public let extractedAt: Date

    public init(packageName: String, title: String, code: String, language: String = "swift", description: String? = nil, source: String) {
        self.packageName = packageName
        self.title = title
        self.code = code
        self.language = language
        self.description = description
        self.source = source
        self.extractedAt = Date()
    }
}

/// Usage pattern extracted from documentation and examples
public struct UsagePattern: Codable, Sendable {
    public let packageName: String
    public let pattern: String
    public let frequency: Int
    public let examples: [String]
    public let description: String?

    public init(packageName: String, pattern: String, frequency: Int, examples: [String], description: String? = nil) {
        self.packageName = packageName
        self.pattern = pattern
        self.frequency = frequency
        self.examples = examples
        self.description = description
    }
}

/// Documentation summary
public struct DocumentationSummary: Codable, Sendable {
    public let packageName: String
    public let summary: String
    public let keyFeatures: [String]
    public let commonUseCases: [String]
    public let learningCurve: LearningCurve
    public let generatedAt: Date

    public enum LearningCurve: String, Codable, Sendable {
        case easy
        case moderate
        case steep
    }

    public init(packageName: String, summary: String, keyFeatures: [String], commonUseCases: [String], learningCurve: LearningCurve) {
        self.packageName = packageName
        self.summary = summary
        self.keyFeatures = keyFeatures
        self.commonUseCases = commonUseCases
        self.learningCurve = learningCurve
        self.generatedAt = Date()
    }
}

public struct PackageInfo: Codable, Sendable {
    public let name: String
    public let url: String
    public let description: String?
    public let version: String?
    public let license: String?
    public let author: String?
    public let tags: [String]?
    public let stars: Int?
    public let forks: Int?
    public let lastUpdated: Date?
    public let readmeURL: String?
    public let documentationURL: String?
    public let repositoryType: RepositoryType

    public enum RepositoryType: String, Codable, Sendable {
        case github
        case gitlab
        case bitbucket
        case other
    }

    public init(name: String, url: String, description: String? = nil, version: String? = nil, license: String? = nil, author: String? = nil, tags: [String]? = nil, stars: Int? = nil, forks: Int? = nil, lastUpdated: Date? = nil, readmeURL: String? = nil, documentationURL: String? = nil, repositoryType: RepositoryType = .github) {
        self.name = name
        self.url = url
        self.description = description
        self.version = version
        self.license = license
        self.author = author
        self.tags = tags
        self.stars = stars
        self.forks = forks
        self.lastUpdated = lastUpdated
        self.readmeURL = readmeURL
        self.documentationURL = documentationURL
        self.repositoryType = repositoryType
    }
}
