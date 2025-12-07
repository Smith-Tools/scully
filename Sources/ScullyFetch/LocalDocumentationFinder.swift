import Foundation
import Logging
import ScullyTypes

/// Searches for documentation in local build artifacts and cached clones
public actor LocalDocumentationFinder {
    private let logger = Logger(label: "scully.local")
    private let fileManager = FileManager.default
    
    public init() {}
    
    /// Searches for documentation in local sources
    /// Priority: 1) SPM checkouts, 2) Current project build artifacts, 3) Cached clones, 4) Derived data
    public func findLocalDocumentation(for packageName: String, projectPath: String = ".") async throws -> PackageDocumentation? {
        logger.info("Searching for local documentation for \(packageName)")
        
        // 1. Check SPM checkouts (highest priority - if resolved, it's here!)
        if let spmDoc = try await searchSPMCheckouts(packageName: packageName, projectPath: projectPath) {
            logger.info("Found documentation in SPM checkouts")
            return spmDoc
        }
        
        // 2. Check current project's build artifacts
        if let buildDoc = try await searchBuildArtifacts(packageName: packageName, projectPath: projectPath) {
            logger.info("Found documentation in build artifacts")
            return buildDoc
        }
        
        // 3. Check cached clones
        if let cacheDoc = try await searchCachedClones(packageName: packageName) {
            logger.info("Found documentation in cached clones")
            return cacheDoc
        }
        
        // 4. Check DerivedData (for Xcode projects)
        if let derivedDoc = try await searchDerivedData(packageName: packageName) {
            logger.info("Found documentation in DerivedData")
            return derivedDoc
        }
        
        logger.debug("No local documentation found for \(packageName)")
        return nil
    }
    
    // MARK: - SPM Checkouts Search
    
    private func searchSPMCheckouts(packageName: String, projectPath: String) async throws -> PackageDocumentation? {
        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let checkoutsURL = projectURL.appendingPathComponent(".build/checkouts")
        
        guard fileManager.fileExists(atPath: checkoutsURL.path) else {
            logger.debug("No .build/checkouts directory found")
            return nil
        }
        
        // List all checkouts
        let contents = try fileManager.contentsOfDirectory(at: checkoutsURL, includingPropertiesForKeys: nil)
        
        // Find matching package (case-insensitive)
        for checkoutURL in contents {
            let checkoutName = checkoutURL.lastPathComponent.lowercased()
            if checkoutName.contains(packageName.lowercased()) || packageName.lowercased().contains(checkoutName) {
                logger.debug("Found SPM checkout: \(checkoutURL.lastPathComponent)")
                
                // Look for DocC first
                if let doc = try await searchForDocC(in: checkoutURL, packageName: packageName) {
                    return doc
                }
                
                // Fallback to README
                if let doc = try await searchForReadme(in: checkoutURL, packageName: packageName) {
                    return doc
                }
            }
        }
        
        return nil
    }
    
    private func searchForDocC(in directory: URL, packageName: String) async throws -> PackageDocumentation? {
        // Look for .docc directories
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "docc" {
                logger.debug("Found .docc directory: \(fileURL.path)")
                if let doc = try await extractDocCDirectory(at: fileURL, packageName: packageName) {
                    return doc
                }
            }
        }
        
        return nil
    }
    
    private func searchForReadme(in directory: URL, packageName: String) async throws -> PackageDocumentation? {
        let readmeVariants = ["README.md", "Readme.md", "readme.md", "README.MD"]
        
        for variant in readmeVariants {
            let readmeURL = directory.appendingPathComponent(variant)
            if fileManager.fileExists(atPath: readmeURL.path),
               let content = try? String(contentsOf: readmeURL) {
                logger.debug("Found README: \(readmeURL.path)")
                return PackageDocumentation(
                    packageName: packageName,
                    content: content,
                    type: .readme,
                    url: readmeURL.path
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Build Artifacts Search
    
    private func searchBuildArtifacts(packageName: String, projectPath: String) async throws -> PackageDocumentation? {
        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let buildURL = projectURL.appendingPathComponent(".build")
        
        guard fileManager.fileExists(atPath: buildURL.path) else {
            return nil
        }
        
        // Search for documentation in all build configurations
        let patterns = [
            ".build/arm64-apple-macosx/debug/\(packageName).doccarchive",
            ".build/arm64-apple-macosx/release/\(packageName).doccarchive",
            ".build/x86_64-apple-macosx/debug/\(packageName).doccarchive",
            ".build/x86_64-apple-macosx/release/\(packageName).doccarchive",
            ".build/debug/\(packageName).doccarchive",
            ".build/release/\(packageName).doccarchive"
        ]
        
        for pattern in patterns {
            let doccURL = projectURL.appendingPathComponent(pattern)
            if let doc = try await extractDocCArchive(at: doccURL, packageName: packageName) {
                return doc
            }
        }
        
        return nil
    }
    
    // MARK: - Cached Clones Search
    
    private func searchCachedClones(packageName: String) async throws -> PackageDocumentation? {
        let libraryPath = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let cacheDir = libraryPath.appendingPathComponent("Scully/Cache/clones")
        
        guard fileManager.fileExists(atPath: cacheDir.path) else {
            return nil
        }
        
        // Look for cloned repositories matching the package name
        let contents = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        
        for cloneURL in contents {
            let cloneName = cloneURL.lastPathComponent.lowercased()
            if cloneName.contains(packageName.lowercased()) {
                // Check for DocC in the clone
                if let doc = try await searchCloneForDocumentation(at: cloneURL, packageName: packageName) {
                    return doc
                }
            }
        }
        
        return nil
    }
    
    private func searchCloneForDocumentation(at cloneURL: URL, packageName: String) async throws -> PackageDocumentation? {
        // Look for .docc directories
        let enumerator = fileManager.enumerator(at: cloneURL, includingPropertiesForKeys: [.isDirectoryKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "docc" {
                if let doc = try await extractDocCDirectory(at: fileURL, packageName: packageName) {
                    return doc
                }
            }
        }
        
        // Fallback: look for README
        let readmeURL = cloneURL.appendingPathComponent("README.md")
        if fileManager.fileExists(atPath: readmeURL.path),
           let content = try? String(contentsOf: readmeURL) {
            return PackageDocumentation(
                packageName: packageName,
                content: content,
                type: .readme,
                url: readmeURL.path
            )
        }
        
        return nil
    }
    
    // MARK: - DerivedData Search
    
    private func searchDerivedData(packageName: String) async throws -> PackageDocumentation? {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let derivedDataURL = homeURL.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        
        guard fileManager.fileExists(atPath: derivedDataURL.path) else {
            return nil
        }
        
        // Search through DerivedData projects
        let contents = try fileManager.contentsOfDirectory(at: derivedDataURL, includingPropertiesForKeys: nil)
        
        for projectURL in contents {
            let buildURL = projectURL.appendingPathComponent("Build/Products")
            if fileManager.fileExists(atPath: buildURL.path) {
                // Look for .doccarchive files
                let enumerator = fileManager.enumerator(at: buildURL, includingPropertiesForKeys: [.isDirectoryKey])
                
                while let fileURL = enumerator?.nextObject() as? URL {
                    if fileURL.pathExtension == "doccarchive",
                       fileURL.lastPathComponent.lowercased().contains(packageName.lowercased()) {
                        if let doc = try await extractDocCArchive(at: fileURL, packageName: packageName) {
                            return doc
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - DocC Extraction
    
    private func extractDocCArchive(at archiveURL: URL, packageName: String) async throws -> PackageDocumentation? {
        guard fileManager.fileExists(atPath: archiveURL.path) else {
            return nil
        }
        
        // Look for index.html or documentation.json
        let dataURL = archiveURL.appendingPathComponent("data/documentation")
        let indexURL = archiveURL.appendingPathComponent("index.html")
        
        var content = ""
        
        // Try to extract summary from documentation JSON
        if fileManager.fileExists(atPath: dataURL.path) {
            let jsonFiles = try fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil)
            if let firstJSON = jsonFiles.first(where: { $0.pathExtension == "json" }),
               let jsonData = try? Data(contentsOf: firstJSON),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                content = "DocC Archive found at: \(archiveURL.path)\n\nDocumentation available locally.\n\nPreview: \(jsonString.prefix(500))"
            }
        }
        
        // Fallback to index.html
        if content.isEmpty, fileManager.fileExists(atPath: indexURL.path) {
            content = "DocC Archive found at: \(archiveURL.path)\n\nOpen in browser: file://\(indexURL.path)"
        }
        
        guard !content.isEmpty else {
            return nil
        }
        
        return PackageDocumentation(
            packageName: packageName,
            content: content,
            type: .docc,
            url: archiveURL.path
        )
    }
    
    private func extractDocCDirectory(at doccURL: URL, packageName: String) async throws -> PackageDocumentation? {
        // Look for main documentation markdown file
        let contents = try fileManager.contentsOfDirectory(at: doccURL, includingPropertiesForKeys: nil)
        
        // Find the main .md file (usually named after the package)
        if let mainDoc = contents.first(where: { $0.pathExtension == "md" }),
           let content = try? String(contentsOf: mainDoc) {
            return PackageDocumentation(
                packageName: packageName,
                content: content,
                type: .docc,
                url: doccURL.path
            )
        }
        
        return nil
    }
}
