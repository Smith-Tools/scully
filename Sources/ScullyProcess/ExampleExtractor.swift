import Foundation
import Logging
import SwiftSoup
import ScullyTypes

/// Extracts code examples from documentation
public actor ExampleExtractor {
    private let logger = Logger(label: "scully.examples")

    /// Extracts code examples from documentation content
    public func extractExamples(
        from content: String,
        source: String,
        packageName: String
    ) async throws -> [CodeExample] {
        logger.info("Extracting examples from \(source)")

        var examples: [CodeExample] = []
        let lines = content.components(separatedBy: .newlines)
        var inCodeBlock = false
        var currentCode: [String] = []
        var currentTitle = ""

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("```swift") {
                inCodeBlock = true
                currentCode = []
                currentTitle = generateTitle(from: lines, beforeIndex: index)
                continue
            }

            if line == "```" && inCodeBlock {
                inCodeBlock = false
                if !currentCode.isEmpty {
                    let example = CodeExample(
                        packageName: packageName,
                        title: currentTitle,
                        code: currentCode.joined(separator: "\n"),
                        language: "swift",
                        source: source
                    )
                    examples.append(example)
                }
                continue
            }

            if inCodeBlock {
                currentCode.append(line)
            }
        }

        return examples
    }

    private func generateTitle(from lines: [String], beforeIndex: Int) -> String {
        // Look backwards from the code block to find a title
        for i in (0..<beforeIndex).reversed() {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                continue
            }

            if line.hasPrefix("#") {
                // This is a header, use it as title
                return line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            }

            if line.hasPrefix("-") || line.hasPrefix("*") {
                continue
            }

            // Use the line as title if it's not too long
            if line.count < 100 {
                return line
            }
        }

        return "Code Example"
    }
}