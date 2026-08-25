@testable import MacApp
import XCTest

final class ProjectScannerTests: XCTestCase {
    func testScanKeepsStyleFilesOutOfMainFileCandidates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("raagtex-project-scanner-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try """
        \\documentclass[11pt]{article}
        \\IfFileExists{note_style.tex}{\\input{note_style.tex}}{}
        \\begin{document}
        Hello.
        \\end{document}
        """.write(to: root.appendingPathComponent("main.tex"), atomically: true, encoding: .utf8)

        try """
        \\usepackage{xcolor}
        \\newcommand{\\topic}[1]{\\section*{#1}}
        """.write(to: root.appendingPathComponent("note_style.tex"), atomically: true, encoding: .utf8)

        let snapshot = ProjectScanner.scan(projectRoot: root)

        XCTAssertEqual(snapshot.texFiles, ["main.tex"])
        XCTAssertTrue(snapshot.fileTree.contains { $0.relativePath == "note_style.tex" })
    }
}
