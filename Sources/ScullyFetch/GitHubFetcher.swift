import Foundation
import Logging
import ScullyTypes

/// Fetches package information from GitHub using direct HTTP API calls
public actor GitHubFetcher {
    private let logger = Logger(label: "scully.github")
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // 30 second timeout
        config.timeoutIntervalForResource = 60  // 60 second timeout
        self.session = URLSession(configuration: config)
    }

    /// Fetches repository information using GitHub API
    public func fetchRepositoryInfo(from url: String) async throws -> PackageInfo {
        logger.info("Fetching repository info for \(url)")

        // Extract owner and repo from URL
        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        guard owner != "unknown", repoName != "unknown" else {
            throw ScullyError.parseError("Invalid GitHub URL: \(url)")
        }

        // Check if gh CLI is available and use it for better rate limit handling
        if await isGHAvailable() {
            return try await fetchWithGHCLI(owner: owner, repo: repoName)
        } else {
            return try await fetchWithHTTPAPI(owner: owner, repo: repoName)
        }
    }

    /// Fetches documentation from a repository
    public func fetchDocumentation(
        from url: String,
        version: String? = nil
    ) async throws -> PackageDocumentation {
        logger.info("Fetching documentation for \(url)")

        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        guard owner != "unknown", repoName != "unknown" else {
            throw ScullyError.parseError("Invalid GitHub URL: \(url)")
        }

        // First try to find documentation files using GitHub API
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
            throw ScullyError.networkError("No documentation found for \(repoName)")
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
        logger.info("Finding examples for \(url)")

        let components = extractRepoComponents(from: url)
        let owner = components.owner
        let repoName = components.repo

        guard owner != "unknown", repoName != "unknown" else {
            return []
        }

        // Search for common example file patterns
        let patterns = [
            "Examples/*.swift",
            "Examples/**/*.swift",
            "Examples/*.md",
            "Examples/**/*.md",
            "Sample/*.swift",
            "Sample/**/*.swift",
            "Demo/*.swift",
            "Demo/**/*.swift",
            "Tests/**/*.swift"
        ]

        var examples: [CodeExample] = []

        // Use GitHub API to get file tree
        let treeData = try await fetchGitHubAPI(
            endpoint: "repos/\(owner)/\(repoName)/git/trees/main?recursive=true"
        )

        guard let treeDict = try JSONSerialization.jsonObject(with: treeData) as? [String: Any],
              let tree = treeDict["tree"] as? [[String: Any]] else {
            return []
        }

        // Find matching files
        let matchingFiles = tree.filter { item in
            guard let path = item["path"] as? String,
                  let type = item["type"] as? String else { return false }
            return type == "blob" && patterns.contains { path.matches(pattern: $0) }
        }

        // Fetch content for matching files
        for item in matchingFiles.prefix(limit) {
            guard let path = item["path"] as? String,
                  let sha = item["sha"] as? String else { continue }

            if let content = try await fetchFileContent(owner: owner, repo: repoName, sha: sha) {
                let language = path.hasSuffix(".swift") ? "swift" :
                              path.hasSuffix(".md") ? "markdown" : "text"

                examples.append(CodeExample(
                    packageName: repoName,
                    title: path.components(separatedBy: "/").last ?? path,
                    code: content,
                    language: language,
                    source: path
                ))
            }
        }

        return examples
    }

    // MARK: - Private Methods

    private func fetchWithGHCLI(owner: String, repo: String) async throws -> PackageInfo {
        logger.debug("Using gh CLI for \(owner)/\(repo)")

        // Try to get basic repo info
        let repoOutput = try await runGHCommand([
            "repo", "view", "\(owner)/\(repo)",
            "--json", "name,description,defaultBranchRef,licenseInfo,owner,stargazerCount,forkCount,updatedAt"
        ])

        guard let data = repoOutput.data(using: .utf8),
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

        // Get latest release
        var version: String? = nil
        do {
            let releaseOutput = try await runGHCommand([
                "release", "view", "--repo", "\(owner)/\(repo)", "--json", "tagName"
            ])
            if let releaseData = releaseOutput.data(using: .utf8),
               let releaseDict = try JSONSerialization.jsonObject(with: releaseData) as? [String: Any],
               let tagName = releaseDict["tagName"] as? String {
                version = tagName
            }
        } catch {
            logger.debug("No releases found for \(owner)/\(repo)")
        }

        let readmeURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(defaultBranch ?? "main")/README.md"
        let doccURL = "https://github.com/\(owner)/\(repo)/tree/\(defaultBranch ?? "main")/Documentation.docc"

        return PackageInfo(
            name: name,
            url: "https://github.com/\(owner)/\(repo)",
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

    private func fetchWithHTTPAPI(owner: String, repo: String) async throws -> PackageInfo {
        logger.debug("Using HTTP API for \(owner)/\(repo)")

        let data = try await fetchGitHubAPI(endpoint: "repos/\(owner)/\(repo)")

        guard let repoDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = repoDict["name"] as? String,
              let author = repoDict["owner"] as? [String: Any],
              let authorLogin = author["login"] as? String else {
            throw ScullyError.parseError("Failed to parse repository info")
        }

        let description = repoDict["description"] as? String
        let defaultBranch = repoDict["default_branch"] as? String
        let license = (repoDict["license"] as? [String: Any])?["name"] as? String
        let stars = repoDict["stargazers_count"] as? Int
        let forks = repoDict["forks_count"] as? Int
        let updatedAtString = repoDict["updated_at"] as? String
        let lastUpdated = updatedAtString.flatMap { ISO8601DateFormatter().date(from: $0) }

        // Try to get latest release
        var version: String? = nil
        do {
            let releaseData = try await fetchGitHubAPI(endpoint: "repos/\(owner)/\(repo)/releases/latest")
            if let releaseDict = try JSONSerialization.jsonObject(with: releaseData) as? [String: Any] {
                version = releaseDict["tag_name"] as? String
            }
        } catch {
            logger.debug("No releases found for \(owner)/\(repo)")
        }

        let readmeURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(defaultBranch ?? "main")/README.md"
        let doccURL = "https://github.com/\(owner)/\(repo)/tree/\(defaultBranch ?? "main")/Documentation.docc"

        return PackageInfo(
            name: name,
            url: "https://github.com/\(owner)/\(repo)",
            description: description,
            version: version,
            license: license,
            author: authorLogin,
            tags: nil,
            stars: stars,
            forks: forks,
            lastUpdated: lastUpdated,
            readmeURL: readmeURL,
            documentationURL: doccURL,
            repositoryType: .github
        )
    }

    private func findDocumentationFiles(owner: String, repo: String) async throws -> (
        readme: String?, docc: String?, doccURL: String?, otherMarkdown: String?, otherMarkdownURL: String?
    ) {
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

        // Look for DocC documentation using GitHub API
        do {
            let treeData = try await fetchGitHubAPI(endpoint: "repos/\(owner)/\(repo)/git/trees/main")
            guard let treeDict = try JSONSerialization.jsonObject(with: treeData) as? [String: Any],
                  let tree = treeDict["tree"] as? [[String: Any]] else {
                return (readme, docc, doccURL, otherMarkdown, otherMarkdownURL)
            }

            // Look for .docc directories
            for item in tree {
                if let path = item["path"] as? String,
                   path.hasSuffix(".docc"),
                   let type = item["type"] as? String,
                   type == "tree" {
                    doccURL = "https://github.com/\(owner)/\(repo)/tree/main/\(path)"
                    docc = "DocC documentation found at \(path)"
                    break
                }
            }

            // Look for other markdown files
            var markdownFiles: [String] = []
            for item in tree {
                if let path = item["path"] as? String,
                   path.hasSuffix(".md"),
                   !path.contains("README"),
                   let type = item["type"] as? String,
                   type == "blob" {
                    markdownFiles.append(path)
                }
            }

            if let firstFile = markdownFiles.first,
               let content = try? await fetchFileContent(owner: owner, repo: repo, path: firstFile) {
                otherMarkdown = content
                otherMarkdownURL = "https://github.com/\(owner)/\(repo)/blob/main/\(firstFile)"
            }
        } catch {
            logger.debug("Could not find documentation files: \(error)")
        }

        return (readme, docc, doccURL, otherMarkdown, otherMarkdownURL)
    }

    private func fetchFileContent(owner: String, repo: String, sha: String) async throws -> String? {
        let data = try await fetchGitHubAPI(endpoint: "repos/\(owner)/\(repo)/git/blobs/\(sha)")

        guard let blobDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64Content = blobDict["content"] as? String,
              let content = Data(base64Encoded: base64Content),
              let contentString = String(data: content, encoding: .utf8) else {
            return nil
        }

        return contentString
    }

    private func fetchFileContent(owner: String, repo: String, path: String) async throws -> String? {
        let data = try await fetchGitHubAPI(endpoint: "repos/\(owner)/\(repo)/contents/\(path)")

        guard let fileDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64Content = fileDict["content"] as? String,
              let content = Data(base64Encoded: base64Content),
              let contentString = String(data: content, encoding: .utf8) else {
            return nil
        }

        return contentString
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

    private func isGHAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["gh", "--version"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func runGHCommand(_ arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["gh"] + arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ScullyError.networkError("gh command failed: \(errorMessage)"))
                    }
                } catch {
                    continuation.resume(throwing: ScullyError.networkError("Failed to run gh command: \(error)"))
                }
            }
        }
    }

    private func fetchGitHubAPI(endpoint: String) async throws -> Data {
        guard let url = URL(string: "https://api.github.com/\(endpoint)") else {
            throw ScullyError.networkError("Invalid URL for endpoint: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Smith-Tools/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScullyError.networkError("Invalid response from GitHub API")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ScullyError.networkError("GitHub API returned status \(httpResponse.statusCode)")
            }
            
            return data
        } catch let error as ScullyError {
            throw error
        } catch {
            throw ScullyError.networkError("Failed to fetch from GitHub API: \(error)")
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
