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
    private static let fileLineErrorRegex = try! NSRegularExpression(pattern: #"^(.*\.tex):(\d+):\s*(.*)$"#)
    private static let latexLineRegex = try! NSRegularExpression(pattern: #"^l\.(\d+)\s*(.*)$"#)
    private static let warningLineRegex = try! NSRegularExpression(pattern: #"\b(?:input )?line\s+(\d+)\b"#, options: [.caseInsensitive])

    public init() {}

    public func parse(_ rawLog: String) -> [CompileDiagnostic] {
        let lines = rawLog
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        guard lines.isEmpty == false else { return [] }

        var diagnostics: [CompileDiagnostic] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if let diagnostic = parseFileLineError(line) {
                diagnostics.append(diagnostic)
                index += 1
                continue
            }

            if let warning = parseWarning(line) {
                diagnostics.append(warning)
                index += 1
                continue
            }

            if var error = parseLatexError(line) {
                if let lineContext = nextLineContext(after: index, in: lines) {
                    error.line = lineContext.line
                    if error.message.isEmpty == false, lineContext.sourceContext.isEmpty == false {
                        error.message += " " + lineContext.sourceContext
                    }
                }
                diagnostics.append(error)
            }

            index += 1
        }

        return diagnostics
    }

    private func parseWarning(_ line: String) -> CompileDiagnostic? {
        guard line.contains("Warning") else { return nil }
        let message = line.trimmingCharacters(in: .whitespaces)
        return CompileDiagnostic(severity: .warning, message: message, line: parseWarningLineNumber(from: line))
    }

    private func parseLatexError(_ line: String) -> CompileDiagnostic? {
        guard line.hasPrefix("! ") else { return nil }
        let message = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return CompileDiagnostic(severity: .error, message: message)
    }

    private func parseFileLineError(_ line: String) -> CompileDiagnostic? {
        // Pattern emitted by `-file-line-error`: path/to/file.tex:12: message
        guard
            let match = Self.fileLineErrorRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
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

    private func nextLineContext(after index: Int, in lines: [String]) -> (line: Int, sourceContext: String)? {
        let upperBound = min(lines.count, index + 6)
        guard index + 1 < upperBound else { return nil }

        for candidateIndex in (index + 1)..<upperBound {
            let candidate = lines[candidateIndex].trimmingCharacters(in: .whitespaces)
            guard
                let match = Self.latexLineRegex.firstMatch(in: candidate, range: NSRange(candidate.startIndex..., in: candidate)),
                let lineRange = Range(match.range(at: 1), in: candidate),
                let lineNumber = Int(candidate[lineRange])
            else {
                continue
            }

            let sourceContext: String
            if
                match.numberOfRanges > 2,
                let contextRange = Range(match.range(at: 2), in: candidate)
            {
                sourceContext = String(candidate[contextRange]).trimmingCharacters(in: .whitespaces)
            } else {
                sourceContext = ""
            }

            return (lineNumber, sourceContext)
        }

        return nil
    }

    private func parseWarningLineNumber(from line: String) -> Int? {
        guard
            let match = Self.warningLineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let lineRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        return Int(line[lineRange])
    }
}
