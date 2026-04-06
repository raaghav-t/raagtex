import Core
import XCTest

final class CompileLogParserTests: XCTestCase {
    func testParsesFileLineError() {
        let parser = CompileLogParser()
        let log = "chapter1.tex:42: Undefined control sequence"

        let diagnostics = parser.parse(log)

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].severity, .error)
        XCTAssertEqual(diagnostics[0].sourceFile, "chapter1.tex")
        XCTAssertEqual(diagnostics[0].line, 42)
        XCTAssertEqual(diagnostics[0].message, "Undefined control sequence")
    }

    func testParsesWarningAndBangError() {
        let parser = CompileLogParser()
        let log = "LaTeX Warning: Label(s) may have changed.\n! LaTeX Error: Missing $ inserted."

        let diagnostics = parser.parse(log)

        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(diagnostics[0].severity, .warning)
        XCTAssertEqual(diagnostics[1].severity, .error)
    }
}
