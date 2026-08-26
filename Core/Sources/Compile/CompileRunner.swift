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
    public var speedCompileEnabled: Bool
    public var forceRebuild: Bool

    public init(
        projectRoot: URL,
        mainFileRelativePath: String,
        engine: CompileEngine = .pdfLaTeX,
        autoCompile: Bool = false,
        speedCompileEnabled: Bool = false,
        forceRebuild: Bool = false
    ) {
        self.projectRoot = projectRoot
        self.mainFileRelativePath = mainFileRelativePath
        self.engine = engine
        self.autoCompile = autoCompile
        self.speedCompileEnabled = speedCompileEnabled
        self.forceRebuild = forceRebuild
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
    case unsupportedPlatform(String)

    public var errorDescription: String? {
        switch self {
        case .missingMainFile(let fileURL):
            return "Main TeX file does not exist: \(fileURL.path)"
        case .launchFailed(let reason):
            return "Failed to launch latexmk: \(reason)"
        case .unsupportedPlatform(let reason):
            return reason
        }
    }
}

public struct LatexToolchainStatus: Equatable, Sendable {
    public var requiredExecutables: [String]
    public var executablePaths: [String: String]
    public var missingExecutables: [String]
    public var searchPath: String

    public init(
        requiredExecutables: [String],
        executablePaths: [String: String],
        missingExecutables: [String],
        searchPath: String
    ) {
        self.requiredExecutables = requiredExecutables
        self.executablePaths = executablePaths
        self.missingExecutables = missingExecutables
        self.searchPath = searchPath
    }

    public var isReady: Bool {
        missingExecutables.isEmpty
    }

    public var primaryMessage: String {
        if missingExecutables.isEmpty {
            return "TeX toolchain ready."
        }
        return "Missing TeX tool: " + missingExecutables.joined(separator: ", ")
    }

    public var recoveryMessage: String {
        if missingExecutables.contains("latexmk") {
            return "Install MacTeX or BasicTeX, then reopen raagtex or recheck setup."
        }
        return "The selected compile engine is unavailable. Install the matching TeX package or choose another engine."
    }
}

public enum LatexToolchainProbe {
    public static let macTeXDownloadURL = URL(string: "https://tug.org/mactex/mactex-download.html")!
    public static let basicTeXDownloadURL = URL(string: "https://tug.org/mactex/morepackages.html")!
    public static let basicTeXInstallCommand = "brew install --cask basictex && sudo tlmgr update --self && sudo tlmgr install latexmk"

    public static func check(
        engine: CompileEngine,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeDefaultToolPaths: Bool = true
    ) -> LatexToolchainStatus {
        let searchPath = latexToolSearchPath(
            environment: environment,
            includeDefaultToolPaths: includeDefaultToolPaths
        )
        let required = uniqueExecutables(["latexmk", engine.rawValue])
        var executablePaths: [String: String] = [:]
        var missing: [String] = []

        for executable in required {
            if let path = resolveExecutable(named: executable, searchPath: searchPath) {
                executablePaths[executable] = path
            } else {
                missing.append(executable)
            }
        }

        return LatexToolchainStatus(
            requiredExecutables: required,
            executablePaths: executablePaths,
            missingExecutables: missing,
            searchPath: searchPath
        )
    }

    public static func latexToolSearchPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeDefaultToolPaths: Bool = true
    ) -> String {
        let base = environment["PATH"] ?? ""
        var candidates = base.split(separator: ":").map(String.init)
        if includeDefaultToolPaths {
            candidates.append(contentsOf: [
                "/Library/TeX/texbin",
                "/Library/TeX/Distributions/Programs/texbin",
                "/usr/local/texlive/2026/bin/universal-darwin",
                "/usr/local/texlive/2025/bin/universal-darwin",
                "/usr/local/texlive/2024/bin/universal-darwin",
                "/usr/local/texlive/2023/bin/universal-darwin",
                "/usr/local/texlive/2022/bin/universal-darwin",
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/bin",
                "/usr/sbin",
                "/sbin"
            ])
            candidates.append(contentsOf: discoveredTeXLiveBinPaths())
        }

        var unique: [String] = []
        var seen = Set<String>()
        for candidate in candidates where candidate.isEmpty == false {
            if seen.insert(candidate).inserted {
                unique.append(candidate)
            }
        }
        return unique.joined(separator: ":")
    }

    public static func resolveExecutable(named command: String, searchPath: String) -> String? {
        let fileManager = FileManager.default
        let segments = searchPath.split(separator: ":").map(String.init)
        for segment in segments {
            let candidate = URL(fileURLWithPath: segment).appendingPathComponent(command).path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func uniqueExecutables(_ executables: [String]) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for executable in executables where seen.insert(executable).inserted {
            unique.append(executable)
        }
        return unique
    }

    private static func discoveredTeXLiveBinPaths() -> [String] {
        let fileManager = FileManager.default
        let root = "/usr/local/texlive"
        guard let years = try? fileManager.contentsOfDirectory(atPath: root) else {
            return []
        }

        return years
            .filter { $0.allSatisfy(\.isNumber) }
            .sorted(by: >)
            .flatMap { year in
                let binRoot = "\(root)/\(year)/bin"
                guard let architectures = try? fileManager.contentsOfDirectory(atPath: binRoot) else {
                    return [String]()
                }
                return architectures
                    .sorted()
                    .map { "\(binRoot)/\($0)" }
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

        let run = try runLatexmkOnce(request)
        let diagnostics = parser.parse(run.rawLog)
        let status: CompileStatus = run.exitCode == 0 ? .succeeded : .failed
        let pdfURL = resolvePDFURL(for: request, rawLog: run.rawLog)

        return CompileResult(
            status: status,
            request: request,
            startedAt: startedAt,
            finishedAt: Date(),
            exitCode: run.exitCode,
            rawLog: run.rawLog,
            diagnostics: diagnostics,
            pdfURL: pdfURL
        )
    }

    private func runLatexmkOnce(_ request: CompileRequest) throws -> (exitCode: Int32, rawLog: String) {
        #if os(iOS)
        throw CompileRunnerError.unsupportedPlatform(
            "Local latexmk execution is unavailable on iOS/iPadOS. Compile on macOS and sync the output PDF."
        )
        #else
        let toolchain = LatexToolchainProbe.check(engine: request.engine)
        let searchPath = toolchain.searchPath
        guard let latexmkExecutable = toolchain.executablePaths["latexmk"] else {
            throw CompileRunnerError.launchFailed(
                "\(toolchain.primaryMessage). \(toolchain.recoveryMessage) Effective PATH: \(searchPath)"
            )
        }
        if toolchain.isReady == false {
            throw CompileRunnerError.launchFailed(
                "\(toolchain.primaryMessage). \(toolchain.recoveryMessage) Effective PATH: \(searchPath)"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: latexmkExecutable)
        process.currentDirectoryURL = request.projectRoot
        process.environment = mergedEnvironment(path: searchPath)
        let forceRebuildForSyncTeX = needsSyncTeXRebuild(for: request)
        var arguments = [
            "-cd",
            request.engine.latexmkFlag,
            "-interaction=nonstopmode",
            "-file-line-error",
            "-synctex=1",
            request.mainFileRelativePath
        ]
        if request.forceRebuild || forceRebuildForSyncTeX {
            arguments.insert("-g", at: 1)
        }
        if request.speedCompileEnabled {
            arguments.insert("-usepretex=\(Self.speedCompilePretex)", at: arguments.count - 1)
        }
        process.arguments = arguments
        let commandLog = """
        [raagtex] latexmk: \(latexmkExecutable)
        [raagtex] engine: \(request.engine.rawValue)
        [raagtex] working directory: \(request.projectRoot.path)
        [raagtex] command: \(latexmkExecutable) \(arguments.joined(separator: " "))
        """

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            completion.signal()
        }

        do {
            try process.run()
        } catch {
            throw CompileRunnerError.launchFailed(error.localizedDescription)
        }

        let timeoutSeconds = request.autoCompile ? 45 : 120
        let timeoutResult = completion.wait(timeout: .now() + .seconds(timeoutSeconds))
        if timeoutResult == .timedOut {
            if process.isRunning {
                process.terminate()
                _ = completion.wait(timeout: .now() + .seconds(3))
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    _ = completion.wait(timeout: .now() + .seconds(1))
                }
            }
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            var rawLog = commandLog + "\n" + (String(data: outputData, encoding: .utf8) ?? "")
            if rawLog.isEmpty == false, rawLog.hasSuffix("\n") == false {
                rawLog += "\n"
            }
            rawLog += "[raagtex] Compile timed out after \(timeoutSeconds)s and was terminated.\n"
            throw CompileRunnerError.launchFailed(rawLog)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let rawLog = commandLog + "\n" + (String(data: outputData, encoding: .utf8) ?? "")
        return (process.terminationStatus, rawLog)
        #endif
    }

    private func mergedEnvironment(path: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = path
        return environment
    }

    private static let speedCompilePretex =
        "\\PassOptionsToPackage{draft}{graphicx}" +
        "\\makeatletter" +
        "\\AtBeginDocument{\\@ifpackageloaded{graphicx}{\\setkeys{Gin}{draft=true}}{}}" +
        "\\makeatother"

    private func needsSyncTeXRebuild(for request: CompileRequest) -> Bool {
        let base = request.mainFileURL.deletingPathExtension()
        let compressed = base.appendingPathExtension("synctex.gz")
        let plain = base.appendingPathExtension("synctex")
        let fm = FileManager.default
        return fm.fileExists(atPath: compressed.path) == false && fm.fileExists(atPath: plain.path) == false
    }

    private func resolvePDFURL(for request: CompileRequest, rawLog: String) -> URL? {
        let fm = FileManager.default
        let expectedPDFURL = request.expectedPDFURL
        let expectedInProjectRoot = request.projectRoot.appendingPathComponent(expectedPDFURL.lastPathComponent)
        let mainFileDirectory = request.mainFileURL.deletingLastPathComponent()
        let outputPattern = #"Output written on\s+(.+?\.pdf)\b"#
        let outputRegex = try? NSRegularExpression(pattern: outputPattern)

        var candidates: [URL] = [expectedPDFURL]
        if expectedInProjectRoot.path != expectedPDFURL.path {
            candidates.append(expectedInProjectRoot)
        }

        if let outputRegex {
            let nsLog = rawLog as NSString
            let fullRange = NSRange(location: 0, length: nsLog.length)
            outputRegex.enumerateMatches(in: rawLog, options: [], range: fullRange) { match, _, _ in
                guard
                    let match,
                    match.numberOfRanges > 1,
                    match.range(at: 1).location != NSNotFound
                else { return }

                let rawValue = nsLog
                    .substring(with: match.range(at: 1))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                let candidateURL: URL
                if rawValue.hasPrefix("/") {
                    candidateURL = URL(fileURLWithPath: rawValue)
                } else {
                    candidateURL = mainFileDirectory.appendingPathComponent(rawValue)
                }
                candidates.append(candidateURL)
            }
        }

        var seen = Set<String>()
        let uniqueCandidates = candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }

        for _ in 0..<20 {
            for candidate in uniqueCandidates {
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        return nil
    }
}
