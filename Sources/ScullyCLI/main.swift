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
        
        do {
            let result = try await scully.listDependencies(at: path)
            
            switch format {
            case .json:
                try printJSON(result)
            case .table:
                printTable(result: result, detailed: detailed)
            }
        } catch {
            logger.info("Native analysis failed (\(error.localizedDescription)). Falling back to smith...")
            try runSmith(path: path)
        }
    }
    
    private func runSmith(path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var args = ["smith", "dependencies", path]
        if format == .json {
            args.append("--format=json")
        }
        // Pass verbose if desired, or other flags
        
        process.arguments = args
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ExitCode(process.terminationStatus)
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
        abstract: "Access documentation for a package",
        discussion: """
        Get documentation for Swift packages.
        
        Single package:
          scully docs Alamofire
        
        Batch mode (pipe from smith):
          smith dependencies --format=json | scully docs
        
        Project dependencies:
          scully docs --project-deps
        """
    )

    @Argument(help: "Package name (not needed if piping from stdin or using --project-deps)")
    var packageName: String?

    @Option(help: "Specific version")
    var version: String?

    @Flag(help: "Include code examples")
    var examples = false
    
    @Flag(help: "Fetch docs for all dependencies in current project (calls smith)")
    var projectDeps = false

    mutating func run() async throws {
        let logger = Logger(label: "scully.docs")
        
        // Priority 1: --project-deps flag
        if projectDeps {
            try await runProjectDepsMode(logger: logger)
            return
        }
        
        // Priority 2: Auto-detect stdin (piped data)
        let stdinIsInteractive = isatty(FileHandle.standardInput.fileDescriptor) != 0
        
        if !stdinIsInteractive {
            // stdin has piped data - read JSON automatically
            try await runBatchMode(logger: logger)
        } else if let packageName = packageName {
            // Interactive mode with package name
            try await runSingleMode(packageName: packageName, logger: logger)
        } else {
            // Interactive mode without package name - show help
            print("Error: Package name required")
            print("")
            print("Usage:")
            print("  scully docs <package-name>              # Get docs for one package")
            print("  scully docs --project-deps              # Get docs for all project dependencies")
            print("")
            print("Or pipe from smith:")
            print("  smith dependencies --format=json | scully docs")
            throw ExitCode.validationFailure
        }
    }
    
    private func runProjectDepsMode(logger: Logger) async throws {
        logger.info("Fetching project dependencies from Package.resolved...")
        
        print("🔍 Reading project dependencies...\n")
        
        // Look for Package.resolved in current directory
        let packageResolvedPath = "./Package.resolved"
        
        guard FileManager.default.fileExists(atPath: packageResolvedPath) else {
            print("Error: Package.resolved not found in current directory")
            print("Run 'swift package resolve' first to generate Package.resolved")
            throw ExitCode.failure
        }
        
        // Read and parse Package.resolved
        guard let data = FileManager.default.contents(atPath: packageResolvedPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Error: Failed to parse Package.resolved")
            throw ExitCode.failure
        }
        
        // Extract package names from Package.resolved
        var packages: [String] = []
        
        // Handle Package.resolved v2 format (pins at root) or v1 format (object.pins)
        if let pins = json["pins"] as? [[String: Any]] {
            // v2 format
            packages = pins.compactMap { $0["identity"] as? String }
        } else if let object = json["object"] as? [String: Any],
                  let pins = object["pins"] as? [[String: Any]] {
            // v1 format
            packages = pins.compactMap { $0["identity"] as? String }
        }
        
        if packages.isEmpty {
            print("ℹ️  No dependencies found in Package.resolved")
            return
        }
        
        print("📦 Found \(packages.count) dependencies. Fetching documentation...\n")
        
        // Fetch docs for each package
        let scully = ScullyEngine()
        
        for packageName in packages {
            do {
                let docs = try await scully.fetchDocumentation(for: packageName)
                
                print("─────────────────────────────────────────────────")
                print("📚 \(packageName)")
                print("─────────────────────────────────────────────────")
                
                // Show first 500 chars of documentation
                let preview = String(docs.content.prefix(500))
                print(preview)
                if docs.content.count > 500 {
                    print("\n... (truncated, \(docs.content.count) total chars)")
                }
                
                if let url = docs.url {
                    print("\n🔗 Source: \(url)")
                }
                print("")
                
            } catch {
                print("⚠️  \(packageName): \(error.localizedDescription)\n")
            }
        }
        
        print("✅ Project documentation fetch complete")
    }
    
    private func runBatchMode(logger: Logger) async throws {
        logger.info("Reading package list from stdin...")
        
        // Read all stdin
        var input = ""
        while let line = readLine() {
            input += line + "\n"
        }
        
        guard !input.isEmpty else {
            print("Error: No input received from stdin")
            print("Expected JSON from: smith dependencies --format=json")
            throw ExitCode.validationFailure
        }
        
        // Parse JSON (expecting smith's dependency format)
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Error: Invalid JSON input")
            throw ExitCode.validationFailure
        }
        
        // Extract package names from smith's JSON format
        var packages: [String] = []
        
        // Try to extract from various possible formats
        // Try to extract from various possible formats
        if let dependencies = json["dependencies"] as? [String: Any],
           let external = dependencies["external"] as? [[String: Any]] {
            // Smith format: {"dependencies": {"external": [{"name": "Alamofire", ...}], ...}}
            packages = external.compactMap { $0["name"] as? String }
        } else if let dependencies = json["dependencies"] as? [[String: Any]] {
            // Simple array format
            packages = dependencies.compactMap { $0["name"] as? String }
        } else if let pins = json["pins"] as? [[String: Any]] {
            // Package.resolved format
            packages = pins.compactMap { $0["identity"] as? String }
        }
        
        if packages.isEmpty {
            print("Error: No packages found in JSON input")
            print("Expected format from: smith dependencies --format=json")
            throw ExitCode.validationFailure
        }
        
        print("\n📦 Fetching documentation for \(packages.count) packages...\n")
        
        let scully = ScullyEngine()
        
        for packageName in packages {
            do {
                let docs = try await scully.fetchDocumentation(for: packageName)
                
                print("─────────────────────────────────────────────────")
                print("📚 \(packageName)")
                print("─────────────────────────────────────────────────")
                
                // Show first 500 chars of documentation
                let preview = String(docs.content.prefix(500))
                print(preview)
                if docs.content.count > 500 {
                    print("\n... (truncated, \(docs.content.count) total chars)")
                }
                
                if let url = docs.url {
                    print("\n🔗 Source: \(url)")
                }
                print("")
                
            } catch {
                print("⚠️  \(packageName): \(error.localizedDescription)\n")
            }
        }
        
        print("✅ Batch documentation fetch complete")
    }
    
    private func runSingleMode(packageName: String, logger: Logger) async throws {
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