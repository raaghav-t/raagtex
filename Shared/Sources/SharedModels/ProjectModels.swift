import Core
import Foundation

public struct ProjectReference: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var rootPath: String
    public var lastOpenedAt: Date

    public init(id: UUID = UUID(), name: String, rootPath: String, lastOpenedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.lastOpenedAt = lastOpenedAt
    }

    public var rootURL: URL {
        URL(fileURLWithPath: rootPath)
    }
}

public enum InterfaceTheme: String, CaseIterable, Codable, Hashable, Sendable {
    case light
    case dark
    case custom
}

public enum InterfaceMode: String, CaseIterable, Codable, Hashable, Sendable {
    case zen
    case debug
}


public enum EditorPreviewLayout: String, CaseIterable, Codable, Hashable, Sendable {
    case sideBySide
    case stacked
}

public struct CustomThemePalette: Codable, Hashable, Sendable {
    public var accentRed: Double
    public var accentGreen: Double
    public var accentBlue: Double

    public init(accentRed: Double = 0.24, accentGreen: Double = 0.47, accentBlue: Double = 0.92) {
        self.accentRed = accentRed
        self.accentGreen = accentGreen
        self.accentBlue = accentBlue
    }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var mainTexRelativePath: String?
    public var latexEngine: CompileEngine
    public var autoCompileEnabled: Bool
    public var interfaceTheme: InterfaceTheme
    public var interfaceMode: InterfaceMode
    public var interfaceTransparency: Double
    public var editorPreviewLayout: EditorPreviewLayout
    public var editorAutoCorrectEnabled: Bool
    public var customPalette: CustomThemePalette

    public init(
        mainTexRelativePath: String? = nil,
        latexEngine: CompileEngine = .pdfLaTeX,
        autoCompileEnabled: Bool = false,
        interfaceTheme: InterfaceTheme = .dark,
        interfaceMode: InterfaceMode = .debug,
        interfaceTransparency: Double = 0.78,
        editorPreviewLayout: EditorPreviewLayout = .sideBySide,
        editorAutoCorrectEnabled: Bool = true,
        customPalette: CustomThemePalette = .init()
    ) {
        self.mainTexRelativePath = mainTexRelativePath
        self.latexEngine = latexEngine
        self.autoCompileEnabled = autoCompileEnabled
        self.interfaceTheme = interfaceTheme
        self.interfaceMode = interfaceMode
        self.interfaceTransparency = interfaceTransparency
        self.editorPreviewLayout = editorPreviewLayout
        self.editorAutoCorrectEnabled = editorAutoCorrectEnabled
        self.customPalette = customPalette
    }
}
