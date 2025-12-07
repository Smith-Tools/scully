import Foundation
import Logging
import SwiftSoup
import ScullyTypes

/// Generates summaries for package documentation
public actor Summarizer {
    public init() {}
    private let logger = Logger(label: "scully.summarizer")

    /// Generates a summary from documentation and examples
    public func generateSummary(
        documentation: PackageDocumentation,
        examples: [CodeExample]
    ) async throws -> DocumentationSummary {
        logger.info("Generating summary for \(documentation.packageName)")

        let content = documentation.content
        let summary = extractSummary(from: content)
        let features = extractKeyFeatures(from: content)
        let useCases = extractUseCases(from: content, examples: examples)
        let learningCurve = assessLearningCurve(content: content, examples: examples)

        return DocumentationSummary(
            packageName: documentation.packageName,
            summary: summary,
            keyFeatures: features,
            commonUseCases: useCases,
            learningCurve: learningCurve
        )
    }

    // MARK: - Private Methods

    private func extractSummary(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        // Look for the first paragraph that seems like a description
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            // Found first non-empty, non-header line
            var summary = line

            // Include following lines if they're part of the same paragraph
            var j = i + 1
            while j < lines.count {
                let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                if nextLine.isEmpty || nextLine.hasPrefix("#") {
                    break
                }
                summary += " " + nextLine
                j += 1
            }

            // Clean up common Markdown artifacts
            summary = summary.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
            summary = summary.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)

            // Limit length
            if summary.count > 300 {
                summary = String(summary.prefix(300)) + "..."
            }

            return summary
        }

        return "No description available"
    }

    private func extractKeyFeatures(from content: String) -> [String] {
        var features: [String] = []

        // Look for bullet points that might be features
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for bullet points or feature sections
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let feature = String(trimmed.dropFirst(2))
                    .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
                    .replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)

                if feature.count > 10 && feature.count < 100 {
                    features.append(feature)
                }
            }
        }

        // Look for "Features" section
        if let featuresSection = extractSection(content: content, heading: "Features") {
            let sectionFeatures = extractBulletPoints(from: featuresSection)
            features.append(contentsOf: sectionFeatures)
        }

        return Array(features.prefix(5)) // Limit to top 5 features
    }

    private func extractUseCases(from content: String, examples: [CodeExample]) -> [String] {
        var useCases: [String] = []

        // Extract from content
        if let useCaseSection = extractSection(content: content, heading: "Use Cases") ??
                               extractSection(content: content, heading: "Usage") ??
                               extractSection(content: content, heading: "Getting Started") {
            let sentences = useCaseSection.components(separatedBy: ".")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 && $0.count < 150 }

            useCases.append(contentsOf: sentences.prefix(3))
        }

        // Extract from example titles
        for example in examples {
            if example.title.count > 10 && example.title.count < 100 {
                useCases.append(example.title)
            }
        }

        return Array(useCases.prefix(5))
    }

    private func assessLearningCurve(content: String, examples: [CodeExample]) -> DocumentationSummary.LearningCurve {
        var score = 0

        // Check for getting started guide
        if content.lowercased().contains("getting started") ||
           content.lowercased().contains("quick start") ||
           content.lowercased().contains("tutorial") {
            score += 2
        }

        // Check for examples
        if !examples.isEmpty {
            score += 1
        }

        // Check for simple API indicators
        if content.lowercased().contains("easy to use") ||
           content.lowercased().contains("simple") ||
           content.lowercased().contains("straightforward") {
            score += 1
        }

        // Check for advanced concepts
        if content.lowercased().contains("advanced") ||
           content.lowercased().contains("complex") ||
           content.lowercased().contains("sophisticated") {
            score -= 1
        }

        // Determine learning curve
        switch score {
        case 4...:
            return .easy
        case 2...3:
            return .moderate
        default:
            return .steep
        }
    }

    private func extractSection(content: String, heading: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var inSection = false
        var sectionContent: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.lowercased().hasPrefix(heading.lowercased()) {
                inSection = true
                continue
            }

            if inSection {
                // Stop at next heading
                if trimmed.hasPrefix("#") && !trimmed.lowercased().hasPrefix(heading.lowercased()) {
                    break
                }

                if !trimmed.isEmpty {
                    sectionContent.append(trimmed)
                }
            }
        }

        return sectionContent.isEmpty ? nil : sectionContent.joined(separator: "\n")
    }

    private func extractBulletPoints(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var bullets: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let bullet = String(trimmed.dropFirst(2))
                    .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if bullet.count > 10 {
                    bullets.append(bullet)
                }
            }
        }

        return bullets
    }
}