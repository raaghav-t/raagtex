import Core
import Foundation
import XCTest

final class CompileRunnerIntegrationTests: XCTestCase {
    func testLatexmkCompileSampleProject() async throws {
        guard commandExists("latexmk") else {
            throw XCTSkip("latexmk is not installed on this machine")
        }

        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sampleRoot = packageRoot.appendingPathComponent("Examples/SampleProject", isDirectory: true)
        let mainFile = sampleRoot.appendingPathComponent("main.tex")

        guard FileManager.default.fileExists(atPath: mainFile.path) else {
            throw XCTSkip("Sample project not present at expected path")
        }

        let request = CompileRequest(
            projectRoot: sampleRoot,
            mainFileRelativePath: "main.tex",
            engine: .pdfLaTeX,
            autoCompile: false
        )

        let result = try await LatexmkCompileRunner().compile(request)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(result.pdfURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleRoot.appendingPathComponent("main.pdf").path))
    }

    func testSpeedCompileUsesPlaceholdersForMissingFigures() async throws {
        guard commandExists("latexmk") else {
            throw XCTSkip("latexmk is not installed on this machine")
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("raagtex-speedcompile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let mainFile = temporaryRoot.appendingPathComponent("main.tex")
        let source = """
        \\documentclass{article}
        \\usepackage{graphicx}
        \\begin{document}
        Missing figure placeholder:
        \\includegraphics[width=1in,height=1in]{missing-figure.pdf}
        \\end{document}
        """
        try source.write(to: mainFile, atomically: true, encoding: .utf8)

        let request = CompileRequest(
            projectRoot: temporaryRoot,
            mainFileRelativePath: "main.tex",
            engine: .pdfLaTeX,
            autoCompile: false,
            speedCompileEnabled: true
        )

        let result = try await LatexmkCompileRunner().compile(request)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(result.pdfURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryRoot.appendingPathComponent("main.pdf").path))
    }

    func testSpeedCompileOverridesExplicitGraphicxFinalOption() async throws {
        guard commandExists("latexmk") else {
            throw XCTSkip("latexmk is not installed on this machine")
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("raagtex-speedcompile-final-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let mainFile = temporaryRoot.appendingPathComponent("main.tex")
        let source = """
        \\documentclass{article}
        \\usepackage[final]{graphicx}
        \\begin{document}
        Missing figure placeholder:
        \\includegraphics[width=1in,height=1in]{missing-figure.pdf}
        \\end{document}
        """
        try source.write(to: mainFile, atomically: true, encoding: .utf8)

        let request = CompileRequest(
            projectRoot: temporaryRoot,
            mainFileRelativePath: "main.tex",
            engine: .pdfLaTeX,
            autoCompile: false,
            speedCompileEnabled: true,
            forceRebuild: true
        )

        let result = try await LatexmkCompileRunner().compile(request)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(result.pdfURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryRoot.appendingPathComponent("main.pdf").path))
    }

    private func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", command]

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
