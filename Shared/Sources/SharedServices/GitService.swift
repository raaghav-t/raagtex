import Foundation

public struct GitRepositoryStatus: Equatable, Sendable {
    public var branchName: String
    public var aheadCount: Int
    public var behindCount: Int
    public var hasUncommittedChanges: Bool
    public var hasConflicts: Bool

    public init(
        branchName: String,
        aheadCount: Int,
        behindCount: Int,
        hasUncommittedChanges: Bool,
        hasConflicts: Bool
    ) {
        self.branchName = branchName
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.hasUncommittedChanges = hasUncommittedChanges
        self.hasConflicts = hasConflicts
    }
}

public enum GitServiceError: LocalizedError {
    case commandFailed(String)
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidOutput(let message):
            return message
        }
    }
}

public protocol GitServicing {
    func isRepository(at rootURL: URL) -> Bool
    func status(at rootURL: URL) throws -> GitRepositoryStatus
    func stageAll(at rootURL: URL) throws
    func commit(at rootURL: URL, message: String) throws
    func pullRebase(at rootURL: URL) throws
    func push(at rootURL: URL) throws
}

public final class GitService: GitServicing {
    public init() {}

    public func isRepository(at rootURL: URL) -> Bool {
        do {
            let result = try runGit(["rev-parse", "--is-inside-work-tree"], at: rootURL)
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }

    public func status(at rootURL: URL) throws -> GitRepositoryStatus {
        let result = try runGit(["status", "--porcelain", "--branch"], at: rootURL)
        let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)

        guard let header = lines.first, header.hasPrefix("## ") else {
            throw GitServiceError.invalidOutput("Unable to parse git status output.")
        }

        let (branchName, ahead, behind) = parseBranchHeader(header)

        let statusLines = lines.dropFirst()
        var hasUncommittedChanges = false
        var hasConflicts = false

        for line in statusLines {
            guard line.count >= 2 else { continue }
            let code = String(line.prefix(2))
            if code != "??" && code != "  " {
                hasUncommittedChanges = true
            }
            if isConflictCode(code) {
                hasConflicts = true
                hasUncommittedChanges = true
            }
            if code == "??" {
                hasUncommittedChanges = true
            }
        }

        return GitRepositoryStatus(
            branchName: branchName,
            aheadCount: ahead,
            behindCount: behind,
            hasUncommittedChanges: hasUncommittedChanges,
            hasConflicts: hasConflicts
        )
    }

    public func stageAll(at rootURL: URL) throws {
        _ = try runGit(["add", "-A"], at: rootURL)
    }

    public func commit(at rootURL: URL, message: String) throws {
        _ = try runGit(["commit", "-m", message], at: rootURL)
    }

    public func pullRebase(at rootURL: URL) throws {
        _ = try runGit(["pull", "--rebase"], at: rootURL)
    }

    public func push(at rootURL: URL) throws {
        _ = try runGit(["push"], at: rootURL)
    }

    private func parseBranchHeader(_ header: String) -> (String, Int, Int) {
        let trimmed = String(header.dropFirst(3))
        let branchPart = trimmed.components(separatedBy: " [").first ?? trimmed
        let branchName = branchPart.components(separatedBy: "...").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        var ahead = 0
        var behind = 0
        if let rangeStart = trimmed.range(of: "["),
           let rangeEnd = trimmed.range(of: "]", range: rangeStart.upperBound..<trimmed.endIndex) {
            let tracking = String(trimmed[rangeStart.upperBound..<rangeEnd.lowerBound])
            for part in tracking.split(separator: ",") {
                let chunk = part.trimmingCharacters(in: .whitespaces)
                if chunk.hasPrefix("ahead ") {
                    ahead = Int(chunk.replacingOccurrences(of: "ahead ", with: "")) ?? 0
                }
                if chunk.hasPrefix("behind ") {
                    behind = Int(chunk.replacingOccurrences(of: "behind ", with: "")) ?? 0
                }
            }
        }

        return (branchName, ahead, behind)
    }

    private func isConflictCode(_ code: String) -> Bool {
        let conflicts: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]
        return conflicts.contains(code)
    }

    @discardableResult
    private func runGit(_ arguments: [String], at rootURL: URL) throws -> (stdout: String, stderr: String) {
        let process = Process()
        process.currentDirectoryURL = rootURL
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let detail = stderr.isEmpty ? stdout : stderr
            throw GitServiceError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return (stdout, stderr)
    }
}
