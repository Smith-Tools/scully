import Foundation
import SmithRAG
import Logging

/// Adapter for RAG operations in Scully
public actor ScullyRAGAdapter {
    private let logger = Logger(label: "scully.rag")
    private let ragEngine: RAGEngine
    private let engine: ScullyEngine
    
    public init(engine: ScullyEngine) async throws {
        self.engine = engine
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dbPath = homeDir.appendingPathComponent(".smith/rag/scully.db").path
        
        // Initialize RAG Engine
        self.ragEngine = try RAGEngine(
            databasePath: dbPath,
            embeddingModel: "mxbai-embed-large", // 1024 dims
            rerankerPath: "/Volumes/Plutonian/_models/jina-reranker/jina-rerank-cli.py" // Using local Jina wrapper
        )
    }
    
    /// Ingest a package into the RAG database
    public func ingest(packageName: String) async throws {
        logger.info("[ScullyRAG] Ingesting package: \(packageName)")
        
        // Fetch documentation using ScullyEngine
        let doc = try await engine.fetchDocumentation(for: packageName)
        
        // Prepare content
        // We focus on the README content for now
        let content = doc.content
        guard !content.isEmpty else {
            logger.warning("[ScullyRAG] No content found for \(packageName)")
            return
        }
        
        let url = doc.url ?? "https://github.com/\(packageName)"
        let title = "Package: \(packageName)"
        
        // Ingest into RAG
        try await ragEngine.ingest(
            documentId: url,
            title: title,
            url: url,
            content: content
        )
        
        logger.info("[ScullyRAG] Successfully ingested \(packageName)")
    }
    
    /// Search packages using RAG
    public func search(query: String, limit: Int = 5) async throws -> [SearchResult] {
        return try await ragEngine.search(query: query, limit: limit)
    }
    
    /// Fetch chunk or context
    public func fetch(
        id: String,
        mode: FetchMode = .chunk
    ) async throws -> FetchResult {
        return try await ragEngine.fetch(
            id: id,
            mode: mode
        )
    }
    
    /// Re-embed missing chunks
    public func embedMissing(limit: Int = 1000) async throws {
        _ = try await ragEngine.embedMissing(batchSize: limit)
    }
}
