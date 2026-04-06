import Core
import Foundation

public struct ProjectReference: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var rootPath: String
    public var lastOpenedAt: Date

    public init(id: UUID = UUID(), name: String, rootPath: String, lastOpenedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.lastOpenedAt = lastOpenedAt
    }

    public var rootURL: URL {
        URL(fileURLWithPath: rootPath)
    }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var mainTexRelativePath: String?
    public var latexEngine: CompileEngine
    public var autoCompileEnabled: Bool

    public init(
        mainTexRelativePath: String? = nil,
        latexEngine: CompileEngine = .pdfLaTeX,
        autoCompileEnabled: Bool = false
    ) {
        self.mainTexRelativePath = mainTexRelativePath
        self.latexEngine = latexEngine
        self.autoCompileEnabled = autoCompileEnabled
    }
}
