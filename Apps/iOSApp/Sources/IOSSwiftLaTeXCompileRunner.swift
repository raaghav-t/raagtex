import Core
import Foundation
import WebKit

struct IOSSwiftLaTeXCompileRunner: IOSOnDeviceCompileRunning {
    private let parser: any CompileLogParsing

    init(parser: any CompileLogParsing = CompileLogParser()) {
        self.parser = parser
    }

    func compileOnDevice(_ request: CompileRequest) async throws -> CompileResult {
        let startedAt = Date()

        guard FileManager.default.fileExists(atPath: request.mainFileURL.path) else {
            throw CompileRunnerError.missingMainFile(request.mainFileURL)
        }

        let engineSelection = SwiftLaTeXEngineSelection(for: request.engine)
        let inputFiles = try collectProjectInputs(for: request)
        let payload = SwiftLaTeXCompilePayload(
            engine: engineSelection.runtimeName,
            mainFile: request.mainFileRelativePath,
            files: inputFiles
        )

        let payloadData = try JSONEncoder().encode(payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw CompileRunnerError.launchFailed("Failed to encode compile payload")
        }

        let bridgeResult = try await IOSSwiftLaTeXBridge.shared.compile(payloadJSON: payloadJSON)
        let finishedAt = Date()

        let logPrefix = engineSelection.note.map { "[raagtex] \($0)\n" } ?? ""
        let rawLog = logPrefix + bridgeResult.log
        let diagnostics = parser.parse(rawLog)

        let success = bridgeResult.status == 0 && bridgeResult.pdfData != nil
        let status: CompileStatus = success ? .succeeded : .failed

        var pdfURL: URL?
        if let pdfData = bridgeResult.pdfData, success {
            let outputURL = request.expectedPDFURL
            try pdfData.write(to: outputURL, options: [.atomic])
            pdfURL = outputURL
        }

        return CompileResult(
            status: status,
            request: request,
            startedAt: startedAt,
            finishedAt: finishedAt,
            exitCode: Int32(bridgeResult.status),
            rawLog: rawLog,
            diagnostics: diagnostics,
            pdfURL: pdfURL
        )
    }

    private func collectProjectInputs(for request: CompileRequest) throws -> [SwiftLaTeXInputFile] {
        let fileManager = FileManager.default
        let rootURL = request.projectRoot.standardizedFileURL
        let rootPath = rootURL.path
        let rootPathWithSlash = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        let excludedDirectoryNames: Set<String> = [".git", ".build", ".swiftpm", "DerivedData"]
        let generatedExtensions: Set<String> = [
            "aux", "log", "out", "toc", "fls", "fdb_latexmk", "synctex", "gz", "xdv", "dvi", "blg", "bbl", "bcf", "run.xml"
        ]

        let expectedOutput = request.expectedPDFURL.standardizedFileURL.path
        var files: [SwiftLaTeXInputFile] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CompileRunnerError.launchFailed("Could not enumerate project files")
        }

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if excludedDirectoryNames.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let standardized = fileURL.standardizedFileURL
            if standardized.path == expectedOutput { continue }

            let ext = standardized.pathExtension.lowercased()
            if generatedExtensions.contains(ext) { continue }

            let relativePath: String
            if standardized.path.hasPrefix(rootPathWithSlash) {
                relativePath = String(standardized.path.dropFirst(rootPathWithSlash.count))
            } else {
                continue
            }

            let data = try Data(contentsOf: standardized)
            files.append(
                SwiftLaTeXInputFile(
                    path: relativePath,
                    base64: data.base64EncodedString()
                )
            )
        }

        let mainExists = files.contains { $0.path == request.mainFileRelativePath }
        if mainExists == false {
            let data = try Data(contentsOf: request.mainFileURL)
            files.append(
                SwiftLaTeXInputFile(
                    path: request.mainFileRelativePath,
                    base64: data.base64EncodedString()
                )
            )
        }

        return files
    }
}

private struct SwiftLaTeXCompilePayload: Encodable {
    let engine: String
    let mainFile: String
    let files: [SwiftLaTeXInputFile]
}

private struct SwiftLaTeXInputFile: Encodable {
    let path: String
    let base64: String
}

private struct SwiftLaTeXBridgeResult {
    let status: Int
    let log: String
    let pdfData: Data?
}

private struct SwiftLaTeXEngineSelection {
    let runtimeName: String
    let note: String?

    init(for engine: CompileEngine) {
        switch engine {
        case .pdfLaTeX:
            runtimeName = "pdftex"
            note = nil
        case .xeLaTeX:
            runtimeName = "xetex"
            note = nil
        case .luaLaTeX:
            runtimeName = "xetex"
            note = "LuaLaTeX is not available in the iPad runtime. Falling back to XeLaTeX-compatible engine."
        }
    }
}

@MainActor
private final class IOSSwiftLaTeXBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = IOSSwiftLaTeXBridge()

    private enum Constants {
        static let bridgeName = "raagtexBridge"
    }

    private var webView: WKWebView?
    private var isReady = false
    private var isLoading = false
    private var compileInFlight = false
    private var readyWaiters: [CheckedContinuation<Void, Error>] = []
    private var compileContinuation: CheckedContinuation<SwiftLaTeXBridgeResult, Error>?

    func compile(payloadJSON: String) async throws -> SwiftLaTeXBridgeResult {
        try await ensureReady()

        guard compileInFlight == false else {
            throw CompileRunnerError.launchFailed("Compile is already in progress")
        }
        guard let webView else {
            throw CompileRunnerError.launchFailed("On-device compile bridge is unavailable")
        }

        compileInFlight = true
        return try await withCheckedThrowingContinuation { continuation in
            compileContinuation = continuation
            let script = "window.raagtexCompile(\(payloadJSON));"
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    self.compileInFlight = false
                    if let continuation = self.compileContinuation {
                        self.compileContinuation = nil
                        continuation.resume(throwing: CompileRunnerError.launchFailed(error.localizedDescription))
                    }
                }
            }
        }
    }

    private func ensureReady() async throws {
        if isReady { return }
        try await withCheckedThrowingContinuation { continuation in
            readyWaiters.append(continuation)

            guard isLoading == false else { return }
            isLoading = true

            let config = WKWebViewConfiguration()
            let contentController = WKUserContentController()
            contentController.add(self, name: Constants.bridgeName)
            config.userContentController = contentController

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            self.webView = webView

            let fileManager = FileManager.default
            guard let resourceRoot = Bundle.main.resourceURL else {
                failReadyWaiters(with: CompileRunnerError.launchFailed("SwiftLaTeX runtime bundle is missing"))
                return
            }

            let nestedRuntimeRoot = resourceRoot.appendingPathComponent("SwiftLaTeXRuntime", isDirectory: true)
            let runtimeRoot: URL
            if fileManager.fileExists(atPath: nestedRuntimeRoot.path) {
                runtimeRoot = nestedRuntimeRoot
            } else if fileManager.fileExists(atPath: resourceRoot.appendingPathComponent("PdfTeXEngine.js").path) {
                runtimeRoot = resourceRoot
            } else {
                failReadyWaiters(with: CompileRunnerError.launchFailed("SwiftLaTeX runtime files are missing from app resources"))
                return
            }

            let html = Self.bootstrapHTML
            webView.loadHTMLString(html, baseURL: runtimeRoot)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Readiness is signaled via JS bridge message.
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failReadyWaiters(with: CompileRunnerError.launchFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failReadyWaiters(with: CompileRunnerError.launchFailed(error.localizedDescription))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Constants.bridgeName else { return }
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else {
            return
        }

        switch type {
        case "ready":
            isReady = true
            isLoading = false
            succeedReadyWaiters()

        case "result":
            compileInFlight = false
            guard let continuation = compileContinuation else { return }
            compileContinuation = nil

            let status = body["status"] as? Int ?? -255
            let log = body["log"] as? String ?? ""
            let pdfBase64 = body["pdfBase64"] as? String
            let pdfData = pdfBase64.flatMap { Data(base64Encoded: $0) }

            continuation.resume(returning: SwiftLaTeXBridgeResult(status: status, log: log, pdfData: pdfData))

        case "error":
            compileInFlight = false
            guard let continuation = compileContinuation else { return }
            compileContinuation = nil

            let message = body["message"] as? String ?? "Unknown runtime error"
            continuation.resume(throwing: CompileRunnerError.launchFailed(message))

        default:
            break
        }
    }

    private func succeedReadyWaiters() {
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func failReadyWaiters(with error: Error) {
        isLoading = false
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
    }

    private static let bootstrapHTML = #"""
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>raagtex iOS Compile Runtime</title>
</head>
<body>
<script src="PdfTeXEngine.js"></script>
<script src="XeTeXEngine.js"></script>
<script src="DvipdfmxEngine.js"></script>
<script>
(() => {
  const BRIDGE = 'raagtexBridge';
  const state = {
    pdfEngine: null,
    xeEngine: null,
    dviEngine: null,
    pdfReady: false,
    xeReady: false,
    dviReady: false,
  };

  function post(message) {
    window.webkit.messageHandlers[BRIDGE].postMessage(message);
  }

  function fromBase64(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  function toBase64(bytes) {
    let binary = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      const slice = bytes.subarray(i, i + chunk);
      binary += String.fromCharCode.apply(null, slice);
    }
    return btoa(binary);
  }

  function ensureDirectories(engine, path, created) {
    const parts = path.split('/');
    parts.pop();
    let current = '';
    for (const part of parts) {
      if (!part) {
        continue;
      }
      current = current ? `${current}/${part}` : part;
      if (created.has(current)) {
        continue;
      }
      engine.makeMemFSFolder(current);
      created.add(current);
    }
  }

  function writeInputs(engine, files) {
    const created = new Set();
    for (const file of files) {
      ensureDirectories(engine, file.path, created);
      engine.writeMemFSFile(file.path, fromBase64(file.base64));
    }
  }

  async function ensurePdfEngine() {
    if (!state.pdfEngine) {
      state.pdfEngine = new PdfTeXEngine();
    }
    if (!state.pdfReady) {
      await state.pdfEngine.loadEngine();
      state.pdfReady = true;
    }
    return state.pdfEngine;
  }

  async function ensureXeEngine() {
    if (!state.xeEngine) {
      state.xeEngine = new XeTeXEngine();
    }
    if (!state.xeReady) {
      await state.xeEngine.loadEngine();
      state.xeReady = true;
    }
    return state.xeEngine;
  }

  async function ensureDviEngine() {
    if (!state.dviEngine) {
      state.dviEngine = new DvipdfmxEngine();
    }
    if (!state.dviReady) {
      await state.dviEngine.loadEngine();
      state.dviReady = true;
    }
    return state.dviEngine;
  }

  async function compilePDFTeX(payload) {
    const engine = await ensurePdfEngine();
    engine.flushCache();
    writeInputs(engine, payload.files);
    engine.setEngineMainFile(payload.mainFile);
    const result = await engine.compileLaTeX();
    if (!result || result.status !== 0 || !result.pdf) {
      return {
        status: result && typeof result.status === 'number' ? result.status : -255,
        log: result && typeof result.log === 'string' ? result.log : 'PDFTeX engine failed',
        pdfBase64: null,
      };
    }

    return {
      status: result.status,
      log: result.log || '',
      pdfBase64: toBase64(result.pdf),
    };
  }

  async function compileXeTeX(payload) {
    const xeEngine = await ensureXeEngine();
    xeEngine.flushCache();
    writeInputs(xeEngine, payload.files);
    xeEngine.setEngineMainFile(payload.mainFile);

    const xeResult = await xeEngine.compileLaTeX();
    if (!xeResult || xeResult.status !== 0 || !xeResult.pdf) {
      return {
        status: xeResult && typeof xeResult.status === 'number' ? xeResult.status : -255,
        log: xeResult && typeof xeResult.log === 'string' ? xeResult.log : 'XeTeX engine failed',
        pdfBase64: null,
      };
    }

    const dviEngine = await ensureDviEngine();
    const xdvPath = payload.mainFile.replace(/\.[^.]+$/, '') + '.xdv';
    writeInputs(dviEngine, payload.files);
    dviEngine.writeMemFSFile(xdvPath, xeResult.pdf);
    dviEngine.setEngineMainFile(xdvPath);
    const dviResult = await dviEngine.compilePDF();

    const mergedLog = `${xeResult.log || ''}\n${dviResult.log || ''}`.trim();
    if (!dviResult || dviResult.status !== 0 || !dviResult.pdf) {
      return {
        status: dviResult && typeof dviResult.status === 'number' ? dviResult.status : -255,
        log: mergedLog,
        pdfBase64: null,
      };
    }

    return {
      status: dviResult.status,
      log: mergedLog,
      pdfBase64: toBase64(dviResult.pdf),
    };
  }

  window.raagtexCompile = async function(payload) {
    try {
      const mode = payload && payload.engine === 'xetex' ? 'xetex' : 'pdftex';
      const result = mode === 'xetex'
        ? await compileXeTeX(payload)
        : await compilePDFTeX(payload);
      post({
        type: 'result',
        status: typeof result.status === 'number' ? result.status : -255,
        log: typeof result.log === 'string' ? result.log : '',
        pdfBase64: result.pdfBase64 || null,
      });
    } catch (error) {
      const message = error && error.message ? error.message : String(error);
      post({ type: 'error', message });
    }
  };

  post({ type: 'ready' });
})();
</script>
</body>
</html>
"""#
}
