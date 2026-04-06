import Core
import XCTest

final class CompileRequestTests: XCTestCase {
    func testExpectedPDFPathUsesMainFileNameInProjectRoot() {
        let root = URL(fileURLWithPath: "/tmp/project")
        let request = CompileRequest(projectRoot: root, mainFileRelativePath: "src/main.tex")

        XCTAssertEqual(request.expectedPDFURL.path, "/tmp/project/src/main.pdf")
    }
}
