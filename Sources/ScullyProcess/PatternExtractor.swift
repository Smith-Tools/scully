import Foundation
import Logging
import ScullyTypes

/// Extracts usage patterns from documentation and examples
public actor PatternExtractor {
    public init() {}
    private let logger = Logger(label: "scully.patterns")

    /// Extracts common usage patterns
    public func extractPatterns(
        from documentation: PackageDocumentation,
        examples: [CodeExample]
    ) async throws -> [UsagePattern] {
        logger.info("Extracting patterns for \(documentation.packageName)")

        var patterns: [String: Int] = [:]
        var patternExamples: [String: [String]] = [:]

        // Extract patterns from documentation
        extractFromDocumentation(documentation.content, patterns: &patterns, examples: &patternExamples)

        // Extract patterns from code examples
        for example in examples {
            extractFromExample(example, patterns: &patterns, examples: &patternExamples)
        }

        // Convert to UsagePattern objects
        var result: [UsagePattern] = []
        for (pattern, frequency) in patterns where frequency >= 2 {
            let usagePattern = UsagePattern(
                packageName: documentation.packageName,
                pattern: pattern,
                frequency: frequency,
                examples: patternExamples[pattern] ?? [],
                description: generateDescription(for: pattern)
            )
            result.append(usagePattern)
        }

        return result.sorted { $0.frequency > $1.frequency }
    }

    // MARK: - Private Methods

    private func extractFromDocumentation(
        _ content: String,
        patterns: inout [String: Int],
        examples: inout [String: [String]]
    ) {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for code blocks
            if trimmed.hasPrefix("```") {
                continue // Skip code block markers
            }

            // Look for Swift code indicators
            if trimmed.contains("import ") {
                let importPattern = extractImportPattern(from: trimmed)
                if !importPattern.isEmpty {
                    patterns[importPattern, default: 0] += 1
                    examples[importPattern, default: []].append(trimmed)
                }
            }

            // Look for API usage patterns
            if trimmed.contains(".") && trimmed.contains("(") {
                let apiPattern = extractAPIPattern(from: trimmed)
                if !apiPattern.isEmpty {
                    patterns[apiPattern, default: 0] += 1
                    examples[apiPattern, default: []].append(trimmed)
                }
            }

            // Look for initialization patterns
            if trimmed.lowercased().contains("init") || trimmed.lowercased().contains("new") {
                let initPattern = extractInitializationPattern(from: trimmed)
                if !initPattern.isEmpty {
                    patterns[initPattern, default: 0] += 1
                    examples[initPattern, default: []].append(trimmed)
                }
            }
        }
    }

    private func extractFromExample(
        _ example: CodeExample,
        patterns: inout [String: Int],
        examples: inout [String: [String]]
    ) {
        let lines = example.code.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("//") {
                continue
            }

            // Import statements
            if trimmed.hasPrefix("import ") {
                let pattern = "import \(extractModuleName(from: trimmed))"
                patterns[pattern, default: 0] += 1
                examples[pattern, default: []].append(example.title)
            }

            // Variable declarations
            if trimmed.contains("let ") || trimmed.contains("var ") {
                let pattern = extractVariablePattern(from: trimmed)
                if !pattern.isEmpty {
                    patterns[pattern, default: 0] += 1
                    examples[pattern, default: []].append(example.title)
                }
            }

            // Function calls
            if trimmed.contains(".") && trimmed.contains("(") {
                let pattern = extractFunctionCallPattern(from: trimmed)
                if !pattern.isEmpty {
                    patterns[pattern, default: 0] += 1
                    examples[pattern, default: []].append(example.title)
                }
            }
        }
    }

    private func extractImportPattern(from line: String) -> String {
        // Extract import statement patterns
        if line.contains("import") {
            return "import statement"
        }
        return ""
    }

    private func extractAPIPattern(from line: String) -> String {
        // Extract API usage like MyClass.method()
        if let range = line.range(of: ".", options: .caseInsensitive) {
            let before = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = line[range.upperBound...].trimmingCharacters(in: .whitespaces)

            if !before.isEmpty && after.contains("(") {
                // Extract the method name
                if let parenRange = after.range(of: "(") {
                    let method = String(after[..<parenRange.lowerBound])
                    return "\(before).\(method)()"
                }
            }
        }
        return ""
    }

    private func extractInitializationPattern(from line: String) -> String {
        // Extract initialization patterns
        if line.contains("init(") {
            return "initializer"
        } else if line.contains("=") {
            return "property assignment"
        }
        return ""
    }

    private func extractModuleName(from importLine: String) -> String {
        if let range = importLine.range(of: "import ") {
            return String(importLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func extractVariablePattern(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("let ") {
            return "constant declaration"
        } else if trimmed.hasPrefix("var ") {
            return "variable declaration"
        }
        return ""
    }

    private func extractFunctionCallPattern(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Find the object and method
        if let dotRange = trimmed.range(of: "."),
           let parenRange = trimmed.range(of: "(", options: .caseInsensitive) {
            let object = String(trimmed[..<dotRange.lowerBound])
            let methodWithParen = trimmed[dotRange.upperBound...]

            if let methodEnd = methodWithParen.range(of: "(") {
                let method = String(methodWithParen[..<methodEnd.lowerBound])
                return "\(object).\(method)"
            }
        }
        return ""
    }

    private func generateDescription(for pattern: String) -> String {
        switch pattern {
        case "import statement":
            return "How to import the module"
        case "initializer":
            return "Object initialization patterns"
        case "property assignment":
            return "Setting property values"
        case "constant declaration":
            return "Creating constants with let"
        case "variable declaration":
            return "Creating variables with var"
        default:
            if pattern.contains(".") {
                return "Usage of \(pattern) API"
            }
            return "Common usage pattern"
        }
    }
}