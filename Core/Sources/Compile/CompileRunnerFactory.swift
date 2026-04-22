import Foundation

public protocol IOSOnDeviceCompileRunning: Sendable {
    func compileOnDevice(_ request: CompileRequest) async throws -> CompileResult
}

public struct UnsupportedIOSOnDeviceCompileRunner: IOSOnDeviceCompileRunning {
    public init() {}

    public func compileOnDevice(_ request: CompileRequest) async throws -> CompileResult {
        throw CompileRunnerError.unsupportedPlatform(
            "Local iPad/iOS compile backend is not configured yet. Compile on macOS and sync output, or inject an on-device TeX backend."
        )
    }
}

public struct IOSOnDeviceCompileAdapter: CompileRunning {
    private let backend: any IOSOnDeviceCompileRunning

    public init(backend: any IOSOnDeviceCompileRunning = UnsupportedIOSOnDeviceCompileRunner()) {
        self.backend = backend
    }

    public func compile(_ request: CompileRequest) async throws -> CompileResult {
        try await backend.compileOnDevice(request)
    }
}

public enum CompileRunnerFactory {
    public static func makeDefault(
        iosBackend: (any IOSOnDeviceCompileRunning)? = nil,
        parser: any CompileLogParsing = CompileLogParser()
    ) -> any CompileRunning {
        #if os(iOS)
        return IOSOnDeviceCompileAdapter(backend: iosBackend ?? UnsupportedIOSOnDeviceCompileRunner())
        #else
        return LatexmkCompileRunner(parser: parser)
        #endif
    }
}
