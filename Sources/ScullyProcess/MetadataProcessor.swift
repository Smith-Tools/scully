import Foundation
import Logging
import ScullyTypes

/// Processes and enriches package metadata
public actor MetadataProcessor {
    private let logger = Logger(label: "scully.metadata")

    /// Processes raw metadata and enriches it with additional information
    public func processMetadata(
        from packageInfo: PackageInfo,
        documentation: PackageDocumentation? = nil
    ) async throws -> PackageInfo {
        logger.info("Processing metadata for \(packageInfo.name)")

        // This would enrich the package info with additional metadata
        // For now, just return the original info
        return packageInfo
    }

    /// Extracts keywords from documentation for better search
    public func extractKeywords(from content: String) -> [String] {
        // Simple keyword extraction
        let words = content.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
            .map { $0.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }

        // Count frequency
        let frequency = words.reduce(into: [String: Int]()) { counts, word in
            counts[word, default: 0] += 1
        }

        // Return top keywords
        return frequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
}