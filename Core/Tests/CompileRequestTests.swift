import Core
import XCTest

final class CompileRequestTests: XCTestCase {
    func testExpectedPDFPathUsesMainFileNameInProjectRoot() {
        let root = URL(fileURLWithPath: "/tmp/project")
        let request = CompileRequest(projectRoot: root, mainFileRelativePath: "src/main.tex")

        XCTAssertEqual(request.expectedPDFURL.path, "/tmp/project/src/main.pdf")
    }

    func testSpeedCompileDefaultsOff() {
        let request = CompileRequest(projectRoot: URL(fileURLWithPath: "/tmp/project"), mainFileRelativePath: "main.tex")

        XCTAssertFalse(request.speedCompileEnabled)
        XCTAssertFalse(request.forceRebuild)
    }

    func testSpeedCompileCanBeEnabled() {
        let request = CompileRequest(
            projectRoot: URL(fileURLWithPath: "/tmp/project"),
            mainFileRelativePath: "main.tex",
            speedCompileEnabled: true
        )

        XCTAssertTrue(request.speedCompileEnabled)
    }
}
