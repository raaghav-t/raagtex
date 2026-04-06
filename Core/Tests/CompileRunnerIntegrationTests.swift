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
