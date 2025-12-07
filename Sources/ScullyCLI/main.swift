import ArgumentParser
import Foundation
import Logging
import ScullyCore
import ScullyTypes

@main
struct ScullyCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scully",
        abstract: "Swift ecosystem analysis and documentation tool",
        discussion: """
        Scully helps you explore Swift packages, access documentation, and analyze project dependencies.

        Examples:
          scully list                           # List current project dependencies
          scully docs Alamofire                 # Get documentation for a package
          scully examples Combine               # Find code examples
          scully summary SwiftCharts           # Generate documentation summary
        """,
        subcommands: [
            List.self,
            Docs.self,
            Examples.self,
            Summary.self,
            Patterns.self
        ],
        defaultSubcommand: List.self
    )
}

// MARK: - List Command

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List dependencies in the current project"
    )

    @Option(help: "Path to the project directory")
    var path: String = "."

    @Flag(help: "Show detailed information")
    var detailed = false

    @Option(help: "Output format (json, table)")
    var format: OutputFormat = .table

    enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
        case json
        case table
    }

    mutating func run() async throws {
        let logger = Logger(label: "scully.list")
        logger.info("Analyzing project at \(path)")

        let scully = ScullyEngine()
        let result = try await scully.listDependencies(at: path)

        switch format {
        case .json:
            try printJSON(result)
        case .table:
            printTable(result: result, detailed: detailed)
        }
    }

    private func printJSON(_ result: ProjectAnalysisResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(result)
        print(String(data: json, encoding: .utf8)!)
    }

    private func printTable(result: ProjectAnalysisResult, detailed: Bool) {
        print("\n📦 Dependencies for \(result.manifest.name)")
        print(String(repeating: "─", count: 50))

        if result.manifest.dependencies.isEmpty {
            print("No dependencies found")
            return
        }

        for dep in result.manifest.dependencies {
            var line = "• \(dep.name)"

            if let version = dep.version {
                line += " (\(version))"
            } else if let branch = dep.branch {
                line += " [branch: \(branch)]"
            } else if let revision = dep.revision {
                line += " [\(revision.prefix(8))]"
            }

            if detailed {
                if let url = dep.url {
                    line += "\n  📍 \(url)"
                }
                line += "\n  🏷️  \(dep.type.rawValue)"
            }

            print(line)

            if detailed {
                print("")
            }
        }

        if !detailed {
            print("\nUse --detailed for more information")
        }
    }
}

// MARK: - Docs Command

struct Docs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Access documentation for a package"
    )

    @Argument(help: "Package name")
    var packageName: String

    @Option(help: "Specific version")
    var version: String?

    @Flag(help: "Include code examples")
    var examples = false

    mutating func run() async throws {
        let logger = Logger(label: "scully.docs")
        logger.info("Fetching documentation for \(packageName)")

        let scully = ScullyEngine()
        let docs = try await scully.fetchDocumentation(
            for: packageName,
            version: version,
            includeExamples: examples
        )

        print("\n📚 Documentation for \(packageName)")
        print(String(repeating: "─", count: 50))
        print(docs.content)

        if let url = docs.url {
            print("\n🔗 Source: \(url)")
        }
    }
}

// MARK: - Examples Command

struct Examples: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Find code examples for a package"
    )

    @Argument(help: "Package name")
    var packageName: String

    @Option(help: "Filter by keyword")
    var filter: String?

    @Option(help: "Maximum number of examples")
    var limit: Int = 10

    mutating func run() async throws {
        let logger = Logger(label: "scully.examples")
        logger.info("Finding examples for \(packageName)")

        let scully = ScullyEngine()
        let examples = try await scully.findExamples(
            for: packageName,
            filter: filter,
            limit: limit
        )

        if examples.isEmpty {
            print("No examples found for \(packageName)")
            return
        }

        print("\n💡 Code Examples for \(packageName)")
        print(String(repeating: "─", count: 50))

        for (index, example) in examples.enumerated() {
            print("\n\(index + 1). \(example.title)")
            if let description = example.description {
                print("   \(description)")
            }
            print("   Source: \(example.source)")
            print("\n```swift")
            print(example.code)
            print("```")
        }
    }
}

// MARK: - Summary Command

struct Summary: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a summary of package documentation"
    )

    @Argument(help: "Package name")
    var packageName: String

    @Option(help: "Specific version")
    var version: String?

    mutating func run() async throws {
        let logger = Logger(label: "scully.summary")
        logger.info("Generating summary for \(packageName)")

        let scully = ScullyEngine()
        let summary = try await scully.generateSummary(
            for: packageName,
            version: version
        )

        print("\n📝 Summary for \(packageName)")
        print(String(repeating: "─", count: 50))
        print(summary.summary)

        print("\n✨ Key Features:")
        for feature in summary.keyFeatures {
            print("  • \(feature)")
        }

        print("\n🎯 Common Use Cases:")
        for useCase in summary.commonUseCases {
            print("  • \(useCase)")
        }

        print("\n📈 Learning Curve: \(summary.learningCurve.rawValue)")
    }
}

// MARK: - Patterns Command

struct Patterns: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extract common usage patterns for a package"
    )

    @Argument(help: "Package name")
    var packageName: String

    @Option(help: "Minimum frequency threshold")
    var threshold: Int = 2

    mutating func run() async throws {
        let logger = Logger(label: "scully.patterns")
        logger.info("Extracting patterns for \(packageName)")

        let scully = ScullyEngine()
        let patterns = try await scully.extractPatterns(
            for: packageName,
            threshold: threshold
        )

        if patterns.isEmpty {
            print("No common patterns found for \(packageName)")
            return
        }

        print("\n🔍 Usage Patterns for \(packageName)")
        print(String(repeating: "─", count: 50))

        for pattern in patterns.sorted(by: { $0.frequency > $1.frequency }) {
            print("\n\(pattern.pattern) (used \(pattern.frequency) times)")
            if let description = pattern.description {
                print("  \(description)")
            }

            if !pattern.examples.isEmpty {
                print("  Examples:")
                for example in pattern.examples.prefix(3) {
                    print("    • \(example)")
                }
            }
        }
    }
}