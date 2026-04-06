import Foundation

public struct CompileDiagnostic: Equatable, Hashable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case info
        case warning
        case error
    }

    public var severity: Severity
    public var message: String
    public var sourceFile: String?
    public var line: Int?

    public init(severity: Severity, message: String, sourceFile: String? = nil, line: Int? = nil) {
        self.severity = severity
        self.message = message
        self.sourceFile = sourceFile
        self.line = line
    }
}

public protocol CompileLogParsing: Sendable {
    func parse(_ rawLog: String) -> [CompileDiagnostic]
}

public struct CompileLogParser: CompileLogParsing {
    public init() {}

    public func parse(_ rawLog: String) -> [CompileDiagnostic] {
        let lines = rawLog
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        guard lines.isEmpty == false else { return [] }

        var diagnostics: [CompileDiagnostic] = []
        for line in lines {
            if let diagnostic = parseFileLineError(line) {
                diagnostics.append(diagnostic)
                continue
            }

            if let warning = parseWarning(line) {
                diagnostics.append(warning)
                continue
            }

            if let error = parseLatexError(line) {
                diagnostics.append(error)
            }
        }

        return diagnostics
    }

    private func parseWarning(_ line: String) -> CompileDiagnostic? {
        guard line.contains("Warning") else { return nil }
        let message = line.trimmingCharacters(in: .whitespaces)
        return CompileDiagnostic(severity: .warning, message: message)
    }

    private func parseLatexError(_ line: String) -> CompileDiagnostic? {
        guard line.hasPrefix("! ") else { return nil }
        let message = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return CompileDiagnostic(severity: .error, message: message)
    }

    private func parseFileLineError(_ line: String) -> CompileDiagnostic? {
        // Pattern emitted by `-file-line-error`: path/to/file.tex:12: message
        let pattern = #"^(.*\.tex):(\d+):\s*(.*)$"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let fileRange = Range(match.range(at: 1), in: line),
            let lineRange = Range(match.range(at: 2), in: line),
            let messageRange = Range(match.range(at: 3), in: line),
            let lineNumber = Int(line[lineRange])
        else {
            return nil
        }

        let filePath = String(line[fileRange])
        let message = String(line[messageRange])

        return CompileDiagnostic(
            severity: .error,
            message: message,
            sourceFile: filePath,
            line: lineNumber
        )
    }
}
