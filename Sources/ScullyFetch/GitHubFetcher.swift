import Foundation
import Logging
import ScullyTypes

/// Fetches package information using GitHub CLI (gh)
public actor GitHubFetcher {
    private let logger = Logger(label: "scully.github")
    private let session: URLSession

    public init() {
        self.session = URLSession.shared
    }

    /// Fetches repository information using gh CLI
    public func fetchRepositoryInfo(from url: String) async throws -> PackageInfo {
        logger.info("Fetching repository info using gh CLI for \(url)")

        // Extract owner and repo from URL
        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        // Use gh CLI to get repository info
        let repoInfo = try await runGHCommand(
            "repo view \(owner)/\(repoName) --json name,description,defaultBranchRef,licenseInfo,owner,stargazerCount,forkCount,updatedAt"
        )

        guard let data = repoInfo.data(using: .utf8),
              let repoDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = repoDict["name"] as? String,
              let ownerDict = repoDict["owner"] as? [String: Any],
              let author = ownerDict["login"] as? String else {
            throw ScullyError.parseError("Failed to parse gh repo output")
        }

        let description = repoDict["description"] as? String
        let defaultBranch = (repoDict["defaultBranchRef"] as? [String: Any])?["name"] as? String
        let license = (repoDict["licenseInfo"] as? [String: Any])?["name"] as? String
        let stars = repoDict["stargazerCount"] as? Int
        let forks = repoDict["forkCount"] as? Int
        let updatedAtString = repoDict["updatedAt"] as? String
        let lastUpdated = updatedAtString.flatMap { ISO8601DateFormatter().date(from: $0) }

        // Get latest release for version info
        var version: String? = nil
        do {
            let releaseOutput = try await runGHCommand("release view --repo \(owner)/\(repoName) --json tagName")
            if let releaseData = releaseOutput.data(using: .utf8),
               let releaseDict = try JSONSerialization.jsonObject(with: releaseData) as? [String: Any],
               let tagName = releaseDict["tagName"] as? String {
                version = tagName
            }
        } catch {
            logger.debug("No releases found for \(owner)/\(repoName)")
        }

        // Find documentation files
        let readmeURL = "https://raw.githubusercontent.com/\(owner)/\(repoName)/\(defaultBranch ?? "main")/README.md"
        let doccURL = "https://github.com/\(owner)/\(repoName)/tree/\(defaultBranch ?? "main")/Documentation.docc"

        return PackageInfo(
            name: name,
            url: url,
            description: description,
            version: version,
            license: license,
            author: author,
            tags: nil,
            stars: stars,
            forks: forks,
            lastUpdated: lastUpdated,
            readmeURL: readmeURL,
            documentationURL: doccURL,
            repositoryType: .github
        )
    }

    /// Fetches documentation from a repository
    public func fetchDocumentation(
        from url: String,
        version: String? = nil
    ) async throws -> PackageDocumentation {
        logger.info("Fetching documentation using gh CLI for \(url)")

        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        // First try to find documentation files
        let docFiles = try await findDocumentationFiles(owner: owner, repo: repoName)

        var content = ""
        var docType = PackageDocumentation.DocumentationType.readme
        var docURL: String? = nil

        // Try README first
        if let readme = docFiles.readme {
            content = readme
            docURL = "https://raw.githubusercontent.com/\(owner)/\(repoName)/main/README.md"
        }
        // Try DocC documentation
        else if let doccContent = docFiles.docc {
            content = doccContent
            docType = .docc
            docURL = docFiles.doccURL
        }
        // Try other markdown files
        else if let otherMD = docFiles.otherMarkdown {
            content = otherMD
            docURL = docFiles.otherMarkdownURL
        }

        if content.isEmpty {
            throw ScullyError.networkError("No documentation found")
        }

        return PackageDocumentation(
            packageName: repoName,
            version: version,
            content: content,
            type: docType,
            url: docURL
        )
    }

    /// Finds code examples in a repository
    public func findExamples(
        from url: String,
        filter: String? = nil,
        limit: Int = 20
    ) async throws -> [CodeExample] {
        logger.info("Finding code examples using gh CLI for \(url)")

        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        // Search for common example file patterns
        let patterns = [
            "Examples/*.swift",
            "Examples/**/*.swift",
            "Examples/*.md",
            "Examples/**/*.md",
            "Examples/*.playground",
            "Examples/**/*.playground",
            "Sample/*.swift",
            "Sample/**/*.swift",
            "Demo/*.swift",
            "Demo/**/*.swift",
            "Tests/**/*.swift"
        ]

        var examples: [CodeExample] = []

        for pattern in patterns {
            let fileList = try await runGHCommand(
                "api repos/\(owner)/\(repoName)/git/trees/main?recursive=true"
            )

            guard let data = fileList.data(using: .utf8),
                  let treeDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tree = treeDict["tree"] as? [[String: Any]] else {
                continue
            }

            let matchingFiles = tree.filter { item in
                guard let path = item["path"] as? String,
                      let type = item["type"] as? String else { return false }
                return type == "blob" && path.matches(pattern: pattern)
            }

            for item in matchingFiles.prefix(limit) {
                guard let path = item["path"] as? String,
                      let sha = item["sha"] as? String else { continue }

                // Get file content
                let contentURL = "https://api.github.com/repos/\(owner)/\(repoName)/git/blobs/\(sha)"
                let contentOutput = try await runGHCommand("api \(contentURL)")

                guard let contentData = contentOutput.data(using: .utf8),
                      let contentDict = try JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                      let base64Content = contentDict["content"] as? String,
                      let content = Data(base64Encoded: base64Content),
                      let contentString = String(data: content, encoding: .utf8) else { continue }

                let language = path.hasSuffix(".swift") ? "swift" :
                              path.hasSuffix(".md") ? "markdown" : "text"

                examples.append(CodeExample(
                    packageName: repoName,
                    title: path.components(separatedBy: "/").last ?? path,
                    code: contentString,
                    language: language,
                    source: path
                ))
            }
        }

        return examples
    }

    // MARK: - Private Helpers

    private func findDocumentationFiles(owner: String, repo: String) async throws -> (readme: String?, docc: String?, doccURL: String?, otherMarkdown: String?, otherMarkdownURL: String?) {
        var readme: String?
        var docc: String?
        var doccURL: String?
        var otherMarkdown: String?
        var otherMarkdownURL: String?

        // Try to get README from raw URL
        let readmeURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/main/README.md"
        if let content = try? await fetchContent(from: readmeURL) {
            readme = content
        }

        // If not found, try master branch
        if readme == nil {
            let masterReadmeURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/master/README.md"
            if let content = try? await fetchContent(from: masterReadmeURL) {
                readme = content
            }
        }

        // Look for DocC documentation
        do {
            let doccPath = try await findDocCPath(owner: owner, repo: repo)
            if let path = doccPath {
                doccURL = "https://github.com/\(owner)/\(repo)/tree/main/\(path)"
                // Try to get some documentation content from DocC
                docc = try await fetchDocCContent(owner: owner, repo: repo, path: path)
            }
        } catch {
            logger.debug("Could not find DocC documentation")
        }

        // Look for other markdown files
        do {
            let markdownFiles = try await findMarkdownFiles(owner: owner, repo: repo)
            if let firstFile = markdownFiles.first,
               let content = try await fetchFileContent(owner: owner, repo: repo, path: firstFile) {
                otherMarkdown = content
                otherMarkdownURL = "https://github.com/\(owner)/\(repo)/blob/main/\(firstFile)"
            }
        } catch {
            logger.debug("Could not find markdown files")
        }

        return (readme, docc, doccURL, otherMarkdown, otherMarkdownURL)
    }

    private func findDocCPath(owner: String, repo: String) async throws -> String? {
        let treeOutput = try await runGHCommand("api repos/\(owner)/\(repo)/git/trees/main")

        guard let data = treeOutput.data(using: .utf8),
              let treeDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tree = treeDict["tree"] as? [[String: Any]] else {
            return nil
        }

        // Look for .docc directories
        for item in tree {
            if let path = item["path"] as? String,
               path.hasSuffix(".docc"),
               let type = item["type"] as? String,
               type == "tree" {
                return path
            }
        }

        return nil
    }

    private func findMarkdownFiles(owner: String, repo: String) async throws -> [String] {
        let treeOutput = try await runGHCommand("api repos/\(owner)/\(repo)/git/trees/main")

        guard let data = treeOutput.data(using: .utf8),
              let treeDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tree = treeDict["tree"] as? [[String: Any]] else {
            return []
        }

        var markdownFiles: [String] = []

        for item in tree {
            if let path = item["path"] as? String,
               path.hasSuffix(".md"),
               !path.contains("README"), // Exclude README as we handle it separately
               let type = item["type"] as? String,
               type == "blob" {
                markdownFiles.append(path)
            }
        }

        return markdownFiles
    }

    private func fetchFileContent(owner: String, repo: String, path: String) async throws -> String? {
        return try await runGHCommand("api repos/\(owner)/\(repo)/contents/\(path)")
    }

    private func fetchDocCContent(owner: String, repo: String, path: String) async throws -> String? {
        // Try to find and read the main documentation file in the .docc directory
        _ = try await runGHCommand("api repos/\(owner)/\(repo)/git/trees/main:\(path)")

        // For now, return a simple description
        return "DocC documentation found at \(path)"
    }

    private func extractRepoComponents(from url: String) -> (owner: String, repo: String) {
        guard let components = URLComponents(string: url),
              let host = components.host,
              host.contains("github.com") else {
            return ("unknown", "unknown")
        }

        let pathComponents = components.path.split(separator: "/")
        guard pathComponents.count >= 2 else {
            return ("unknown", "unknown")
        }

        return (String(pathComponents[0]), String(pathComponents[1]).replacingOccurrences(of: ".git", with: ""))
    }

    @discardableResult
    private func runGHCommand(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // Split command while preserving quoted strings
        var components: [String] = ["gh"]
        var current = ""
        var inQuotes = false

        for char in command {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    components.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            components.append(current)
        }

        process.arguments = components

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = (process.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw ScullyError.networkError("gh command failed: \(errorMessage)")
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            throw ScullyError.networkError("Failed to run gh command: \(error)")
        }
    }

    private func fetchContent(from url: String) async throws -> String? {
        guard let contentURL = URL(string: url) else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: contentURL)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.debug("Failed to fetch content from \(url): \(error)")
            return nil
        }
    }
}

// MARK: - String Extensions

private extension String {
    func matches(pattern: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        return self.range(of: regexPattern, options: .regularExpression) != nil
    }
}