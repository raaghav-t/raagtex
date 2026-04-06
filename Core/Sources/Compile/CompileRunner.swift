import Foundation

public enum CompileEngine: String, Codable, CaseIterable, Sendable {
    case pdfLaTeX = "pdflatex"
    case xeLaTeX = "xelatex"
    case luaLaTeX = "lualatex"

    public var latexmkFlag: String {
        switch self {
        case .pdfLaTeX:
            return "-pdf"
        case .xeLaTeX:
            return "-xelatex"
        case .luaLaTeX:
            return "-lualatex"
        }
    }
}

public enum CompileStatus: Equatable, Sendable {
    case idle
    case running
    case succeeded
    case failed
    case cancelled
}

public struct CompileRequest: Equatable, Sendable {
    public var projectRoot: URL
    public var mainFileRelativePath: String
    public var engine: CompileEngine
    public var autoCompile: Bool

    public init(
        projectRoot: URL,
        mainFileRelativePath: String,
        engine: CompileEngine = .pdfLaTeX,
        autoCompile: Bool = false
    ) {
        self.projectRoot = projectRoot
        self.mainFileRelativePath = mainFileRelativePath
        self.engine = engine
        self.autoCompile = autoCompile
    }

    public var mainFileURL: URL {
        projectRoot.appendingPathComponent(mainFileRelativePath)
    }

    public var expectedPDFURL: URL {
        mainFileURL.deletingPathExtension().appendingPathExtension("pdf")
    }
}

public struct CompileResult: Equatable, Sendable {
    public var status: CompileStatus
    public var request: CompileRequest
    public var startedAt: Date
    public var finishedAt: Date
    public var exitCode: Int32
    public var rawLog: String
    public var diagnostics: [CompileDiagnostic]
    public var pdfURL: URL?

    public init(
        status: CompileStatus,
        request: CompileRequest,
        startedAt: Date,
        finishedAt: Date,
        exitCode: Int32,
        rawLog: String,
        diagnostics: [CompileDiagnostic],
        pdfURL: URL?
    ) {
        self.status = status
        self.request = request
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.rawLog = rawLog
        self.diagnostics = diagnostics
        self.pdfURL = pdfURL
    }
}

public enum CompileRunnerError: Error, LocalizedError {
    case missingMainFile(URL)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingMainFile(let fileURL):
            return "Main TeX file does not exist: \(fileURL.path)"
        case .launchFailed(let reason):
            return "Failed to launch latexmk: \(reason)"
        }
    }
}

public protocol CompileRunning: Sendable {
    func compile(_ request: CompileRequest) async throws -> CompileResult
}

public struct LatexmkCompileRunner: CompileRunning {
    private let parser: any CompileLogParsing

    public init(parser: any CompileLogParsing = CompileLogParser()) {
        self.parser = parser
    }

    public func compile(_ request: CompileRequest) async throws -> CompileResult {
        let startedAt = Date()

        guard FileManager.default.fileExists(atPath: request.mainFileURL.path) else {
            throw CompileRunnerError.missingMainFile(request.mainFileURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = request.projectRoot
        process.arguments = [
            "latexmk",
            request.engine.latexmkFlag,
            "-interaction=nonstopmode",
            "-file-line-error",
            "-synctex=1",
            request.mainFileRelativePath
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            throw CompileRunnerError.launchFailed(error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let rawLog = String(data: outputData, encoding: .utf8) ?? ""
        let diagnostics = parser.parse(rawLog)
        let status: CompileStatus = process.terminationStatus == 0 ? .succeeded : .failed
        let pdfURL = FileManager.default.fileExists(atPath: request.expectedPDFURL.path) ? request.expectedPDFURL : nil

        return CompileResult(
            status: status,
            request: request,
            startedAt: startedAt,
            finishedAt: Date(),
            exitCode: process.terminationStatus,
            rawLog: rawLog,
            diagnostics: diagnostics,
            pdfURL: pdfURL
        )
    }
}
