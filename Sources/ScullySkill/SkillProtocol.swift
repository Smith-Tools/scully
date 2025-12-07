import Foundation

/// Simplified Claude Code skill protocol for Scully
public protocol Skill {
    var name: String { get }
    var description: String { get }
    var version: String { get }
    init()
    func execute(context: SkillContext) async throws -> SkillResponse
}

/// Context passed to skill execution
public struct SkillContext {
    public let input: String
    public let currentWorkingDirectory: String?
    public var environment: [String: String]

    public init(input: String, currentWorkingDirectory: String? = nil, environment: [String: String] = [:]) {
        self.input = input
        self.currentWorkingDirectory = currentWorkingDirectory
        self.environment = environment
    }
}

/// Response from skill execution
public struct SkillResponse {
    public let content: String
    public let type: ResponseType

    public init(content: String, type: ResponseType = .text) {
        self.content = content
        self.type = type
    }

    public enum ResponseType {
        case text
        case markdown
        case json
    }
}