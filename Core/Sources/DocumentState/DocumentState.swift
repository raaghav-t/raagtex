import Foundation

public struct DocumentState: Equatable, Sendable {
    public var projectRoot: URL?
    public var mainFileRelativePath: String?
    public var pdfURL: URL?
    public var compileStatus: CompileStatus
    public var diagnostics: [CompileDiagnostic]
    public var rawCompileLog: String
    public var lastCompileAt: Date?

    public init(
        projectRoot: URL? = nil,
        mainFileRelativePath: String? = nil,
        pdfURL: URL? = nil,
        compileStatus: CompileStatus = .idle,
        diagnostics: [CompileDiagnostic] = [],
        rawCompileLog: String = "",
        lastCompileAt: Date? = nil
    ) {
        self.projectRoot = projectRoot
        self.mainFileRelativePath = mainFileRelativePath
        self.pdfURL = pdfURL
        self.compileStatus = compileStatus
        self.diagnostics = diagnostics
        self.rawCompileLog = rawCompileLog
        self.lastCompileAt = lastCompileAt
    }
}
