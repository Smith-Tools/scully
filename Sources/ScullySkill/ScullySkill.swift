import Foundation
import ScullyTypes

/// Claude Code skill for Scully
public struct ScullySkill: Skill {
    public let name = "scully"
    public let description = "Swift ecosystem analysis and documentation tool"
    public let version = "1.0.0"

    private let engine = ScullyEngine()

    public init() {}

    public func execute(context: SkillContext) async throws -> SkillResponse {
        let query = context.input.lowercased()

        // Check for different types of queries
        if query.contains("list") && query.contains("depend") {
            return try await handleListDependencies(context: context)
        } else if query.contains("doc") || query.contains("documentation") {
            return try await handleDocumentationQuery(context: context)
        } else if query.contains("example") {
            return try await handleExampleQuery(context: context)
        } else if query.contains("summary") {
            return try await handleSummaryQuery(context: context)
        } else if query.contains("pattern") {
            return try await handlePatternQuery(context: context)
        } else {
            return SkillResponse(
                content: "I can help with:\n• List project dependencies\n• Access package documentation\n• Find code examples\n• Generate documentation summaries\n• Extract usage patterns\n\nTry: 'List dependencies in current project' or 'Show documentation for Alamofire'",
                type: .text
            )
        }
    }

    // MARK: - Query Handlers

    private func handleListDependencies(context: SkillContext) async throws -> SkillResponse {
        let projectPath = context.currentWorkingDirectory ?? "."
        let result = try await engine.listDependencies(at: projectPath)

        var response = "## Dependencies for \(result.manifest.name)\n\n"

        if result.manifest.dependencies.isEmpty {
            response += "No dependencies found"
        } else {
            for dep in result.manifest.dependencies {
                response += "• **\(dep.name)**"

                if let version = dep.version {
                    response += " (\(version))"
                } else if let branch = dep.branch {
                    response += " [branch: \(branch)]"
                } else if let revision = dep.revision {
                    response += " [\(revision.prefix(8))]"
                }

                if let url = dep.url {
                    response += " - \(url)"
                }

                response += "\n"
            }

            if !result.issues.isEmpty {
                response += "\n⚠️ **Issues:**\n"
                for issue in result.issues {
                    response += "• \(issue.message)"
                    if let suggestion = issue.suggestion {
                        response += " (Suggestion: \(suggestion))"
                    }
                    response += "\n"
                }
            }
        }

        return SkillResponse(content: response, type: .markdown)
    }

    private func handleDocumentationQuery(context: SkillContext) async throws -> SkillResponse {
        // Extract package name from query
        let packageName = extractPackageName(from: context.input)

        guard !packageName.isEmpty else {
            return SkillResponse(
                content: "Please specify a package name. Example: 'Show documentation for Alamofire'",
                type: .text
            )
        }

        let docs = try await engine.fetchDocumentation(for: packageName)

        var response = "## Documentation for \(docs.packageName)\n\n"

        // Add a truncated version of the documentation
        let content = docs.content
        let maxLength = 2000

        if content.count <= maxLength {
            response += content
        } else {
            response += String(content.prefix(maxLength)) + "\n\n... *[truncated - full documentation available via CLI]*"
        }

        if let url = docs.url {
            response += "\n\n📖 **Source:** \(url)"
        }

        return SkillResponse(content: response, type: .markdown)
    }

    private func handleExampleQuery(context: SkillContext) async throws -> SkillResponse {
        let packageName = extractPackageName(from: context.input)

        guard !packageName.isEmpty else {
            return SkillResponse(
                content: "Please specify a package name. Example: 'Show examples for Combine'",
                type: .text
            )
        }

        let examples = try await engine.findExamples(for: packageName, limit: 5)

        if examples.isEmpty {
            return SkillResponse(
                content: "No examples found for \(packageName)",
                type: .text
            )
        }

        var response = "## Code Examples for \(packageName)\n\n"

        for (index, example) in examples.enumerated() {
            response += "### \(index + 1). \(example.title)\n"

            if let description = example.description {
                response += "\(description)\n\n"
            }

            response += "```swift\n"
            response += example.code
            response += "\n```\n\n"
        }

        return SkillResponse(content: response, type: .markdown)
    }

    private func handleSummaryQuery(context: SkillContext) async throws -> SkillResponse {
        let packageName = extractPackageName(from: context.input)

        guard !packageName.isEmpty else {
            return SkillResponse(
                content: "Please specify a package name. Example: 'Generate summary for SwiftCharts'",
                type: .text
            )
        }

        let summary = try await engine.generateSummary(for: packageName)

        var response = "## Summary for \(summary.packageName)\n\n"
        response += "\(summary.summary)\n\n"

        if !summary.keyFeatures.isEmpty {
            response += "### ✨ Key Features\n"
            for feature in summary.keyFeatures {
                response += "• \(feature)\n"
            }
            response += "\n"
        }

        if !summary.commonUseCases.isEmpty {
            response += "### 🎯 Common Use Cases\n"
            for useCase in summary.commonUseCases {
                response += "• \(useCase)\n"
            }
            response += "\n"
        }

        response += "### 📈 Learning Curve: \(summary.learningCurve.rawValue)\n"

        return SkillResponse(content: response, type: .markdown)
    }

    private func handlePatternQuery(context: SkillContext) async throws -> SkillResponse {
        let packageName = extractPackageName(from: context.input)

        guard !packageName.isEmpty else {
            return SkillResponse(
                content: "Please specify a package name. Example: 'Extract patterns from Alamofire'",
                type: .text
            )
        }

        let patterns = try await engine.extractPatterns(for: packageName)

        if patterns.isEmpty {
            return SkillResponse(
                content: "No common usage patterns found for \(packageName)",
                type: .text
            )
        }

        var response = "## Usage Patterns for \(packageName)\n\n"

        for pattern in patterns.prefix(10) {
            response += "### \(pattern.pattern) (used \(pattern.frequency) times)\n"

            if let description = pattern.description {
                response += "\(description)\n\n"
            }

            if !pattern.examples.isEmpty {
                response += "**Examples:**\n"
                for example in pattern.examples.prefix(3) {
                    response += "• \(example)\n"
                }
                response += "\n"
            }
        }

        return SkillResponse(content: response, type: .markdown)
    }

    // MARK: - Helpers

    private func extractPackageName(from input: String) -> String {
        // Simple extraction - in a real implementation, this would be more sophisticated
        let words = input.components(separatedBy: .whitespacesAndNewlines)

        // Look for capitalized words that might be package names
        for word in words {
            if word.first?.isUppercase == true && word.count > 2 {
                // Filter out common words
                if !["Show", "Get", "Find", "List", "Extract", "Generate", "The", "For", "In"].contains(word) {
                    return word.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
                }
            }
        }

        return ""
    }
}