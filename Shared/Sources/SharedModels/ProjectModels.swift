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
    case clearLight
    case clearDark
    // Legacy value kept for backward compatibility with existing saved settings.
    case clear

    public static var allCases: [InterfaceTheme] {
        [.light, .dark, .clearLight, .clearDark]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "light":
            self = .light
        case "dark":
            self = .dark
        case "clearLight":
            self = .clearLight
        case "clearDark":
            self = .clearDark
        case "clear":
            self = .clear
        case "custom":
            self = .dark
        default:
            self = .dark
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension InterfaceTheme {
    var isClearVariant: Bool {
        switch self {
        case .clear, .clearLight, .clearDark:
            return true
        case .light, .dark:
            return false
        }
    }
}

public enum InterfaceMode: String, CaseIterable, Codable, Hashable, Sendable {
    case zen
    case debug
}


public enum EditorPreviewLayout: String, CaseIterable, Codable, Hashable, Sendable {
    case leftRight
    case rightLeft
    case topBottom
    case bottomTop
    case editorOnly

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "leftRight":
            self = .leftRight
        case "rightLeft":
            self = .rightLeft
        case "topBottom":
            self = .topBottom
        case "bottomTop":
            self = .bottomTop
        case "editorOnly":
            self = .editorOnly
        case "sideBySide":
            self = .leftRight
        case "stacked":
            self = .topBottom
        default:
            self = .leftRight
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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

public enum BackgroundBlurMaterial: String, CaseIterable, Codable, Hashable, Sendable {
    case underWindowBackground
    case hudWindow
    case sidebar
    case windowBackground
}

public enum BackgroundRendererPreference: String, CaseIterable, Codable, Hashable, Sendable {
    case nativeMaterialBlur
    case cssBackdropBlur
    case frameworkBlur
    case tintOnlyFallback
}

public enum BackgroundBlurBlendMode: String, CaseIterable, Codable, Hashable, Sendable {
    case behindWindow
    case withinWindow
}

public struct BackgroundTint: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double = 0.79, green: Double = 0.70, blue: Double = 0.64) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct EditorShortcutCommand: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var key: String
    public var usesShift: Bool
    public var template: String

    public init(
        id: UUID = UUID(),
        key: String,
        usesShift: Bool = false,
        template: String
    ) {
        self.id = id
        self.key = key
        self.usesShift = usesShift
        self.template = template
    }

    public static var defaultCommands: [EditorShortcutCommand] {
        [
            .init(key: "b", usesShift: false, template: "\\textbf{$SELECTION$}"),
            .init(key: "i", usesShift: false, template: "\\mathbf{$SELECTION$}"),
            .init(key: "u", usesShift: false, template: "\\underline{$SELECTION$}"),
            .init(key: "c", usesShift: true, template: "\\mathcal{$SELECTION$}"),
            .init(key: "b", usesShift: true, template: "\\mathbb{$SELECTION$}"),
            .init(key: "f", usesShift: true, template: "\\frac{$SELECTION$}{}"),
            .init(key: "r", usesShift: true, template: "\\sqrt{$SELECTION$}"),
            .init(key: "s", usesShift: true, template: "^{$SELECTION$}"),
            .init(key: "d", usesShift: true, template: "_{$SELECTION$}"),
            .init(key: "a", usesShift: true, template: "\\left( $SELECTION$ \\right)"),
            .init(key: "m", usesShift: true, template: "\\begin{bmatrix}\n$SELECTION$\n\\end{bmatrix}"),
            .init(key: "e", usesShift: true, template: "\\begin{equation}\n$SELECTION$\n\\end{equation}"),
            .init(key: "l", usesShift: true, template: "\\begin{align}\n$SELECTION$\n\\end{align}")
        ]
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
    public var editorSyntaxColoringEnabled: Bool
    public var editorLineNumbersEnabled: Bool
    public var editorFontSize: Double
    public var customPalette: CustomThemePalette
    public var gitHelpersEnabled: Bool
    public var gitStageOnSave: Bool
    public var gitAutoPullEnabled: Bool
    public var enableBackgroundBlur: Bool
    public var backgroundBlurMaterial: BackgroundBlurMaterial
    public var backgroundBlurBlendMode: BackgroundBlurBlendMode
    public var backgroundRendererPreference: BackgroundRendererPreference
    public var backgroundTint: BackgroundTint
    public var backgroundTintOpacity: Double
    public var fallbackBlurRadius: Double
    public var editorShortcutCommands: [EditorShortcutCommand]

    public init(
        mainTexRelativePath: String? = nil,
        latexEngine: CompileEngine = .pdfLaTeX,
        autoCompileEnabled: Bool = false,
        interfaceTheme: InterfaceTheme = .dark,
        interfaceMode: InterfaceMode = .debug,
        interfaceTransparency: Double = 0.78,
        editorPreviewLayout: EditorPreviewLayout = .leftRight,
        editorAutoCorrectEnabled: Bool = true,
        editorSyntaxColoringEnabled: Bool = true,
        editorLineNumbersEnabled: Bool = false,
        editorFontSize: Double = 15.0,
        customPalette: CustomThemePalette = .init(),
        gitHelpersEnabled: Bool = true,
        gitStageOnSave: Bool = false,
        gitAutoPullEnabled: Bool = false,
        enableBackgroundBlur: Bool = true,
        backgroundBlurMaterial: BackgroundBlurMaterial = .underWindowBackground,
        backgroundBlurBlendMode: BackgroundBlurBlendMode = .behindWindow,
        backgroundRendererPreference: BackgroundRendererPreference = .nativeMaterialBlur,
        backgroundTint: BackgroundTint = .init(),
        backgroundTintOpacity: Double = 0.06,
        fallbackBlurRadius: Double = 18.0,
        editorShortcutCommands: [EditorShortcutCommand] = EditorShortcutCommand.defaultCommands
    ) {
        self.mainTexRelativePath = mainTexRelativePath
        self.latexEngine = latexEngine
        self.autoCompileEnabled = autoCompileEnabled
        self.interfaceTheme = interfaceTheme
        self.interfaceMode = interfaceMode
        self.interfaceTransparency = interfaceTransparency
        self.editorPreviewLayout = editorPreviewLayout
        self.editorAutoCorrectEnabled = editorAutoCorrectEnabled
        self.editorSyntaxColoringEnabled = editorSyntaxColoringEnabled
        self.editorLineNumbersEnabled = editorLineNumbersEnabled
        self.editorFontSize = editorFontSize
        self.customPalette = customPalette
        self.gitHelpersEnabled = gitHelpersEnabled
        self.gitStageOnSave = gitStageOnSave
        self.gitAutoPullEnabled = gitAutoPullEnabled
        self.enableBackgroundBlur = enableBackgroundBlur
        self.backgroundBlurMaterial = backgroundBlurMaterial
        self.backgroundBlurBlendMode = backgroundBlurBlendMode
        self.backgroundRendererPreference = backgroundRendererPreference
        self.backgroundTint = backgroundTint
        self.backgroundTintOpacity = backgroundTintOpacity
        self.fallbackBlurRadius = fallbackBlurRadius
        self.editorShortcutCommands = editorShortcutCommands
    }

    private enum CodingKeys: String, CodingKey {
        case mainTexRelativePath
        case latexEngine
        case autoCompileEnabled
        case interfaceTheme
        case interfaceMode
        case interfaceTransparency
        case editorPreviewLayout
        case editorAutoCorrectEnabled
        case editorSyntaxColoringEnabled
        case editorLineNumbersEnabled
        case editorFontSize
        case customPalette
        case gitHelpersEnabled
        case gitStageOnSave
        case gitAutoPullEnabled
        case enableBackgroundBlur
        case backgroundBlurMaterial
        case backgroundBlurBlendMode
        case backgroundRendererPreference
        case backgroundTint
        case backgroundTintOpacity
        case fallbackBlurRadius
        case editorShortcutCommands
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTexRelativePath = try container.decodeIfPresent(String.self, forKey: .mainTexRelativePath)
        latexEngine = try container.decodeIfPresent(CompileEngine.self, forKey: .latexEngine) ?? .pdfLaTeX
        autoCompileEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoCompileEnabled) ?? false
        interfaceTheme = try container.decodeIfPresent(InterfaceTheme.self, forKey: .interfaceTheme) ?? .dark
        interfaceMode = try container.decodeIfPresent(InterfaceMode.self, forKey: .interfaceMode) ?? .debug
        interfaceTransparency = try container.decodeIfPresent(Double.self, forKey: .interfaceTransparency) ?? 0.78
        editorPreviewLayout = try container.decodeIfPresent(EditorPreviewLayout.self, forKey: .editorPreviewLayout) ?? .leftRight
        editorAutoCorrectEnabled = try container.decodeIfPresent(Bool.self, forKey: .editorAutoCorrectEnabled) ?? true
        editorSyntaxColoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .editorSyntaxColoringEnabled) ?? true
        editorLineNumbersEnabled = try container.decodeIfPresent(Bool.self, forKey: .editorLineNumbersEnabled) ?? false
        editorFontSize = try container.decodeIfPresent(Double.self, forKey: .editorFontSize) ?? 15.0
        customPalette = try container.decodeIfPresent(CustomThemePalette.self, forKey: .customPalette) ?? .init()
        gitHelpersEnabled = try container.decodeIfPresent(Bool.self, forKey: .gitHelpersEnabled) ?? true
        gitStageOnSave = try container.decodeIfPresent(Bool.self, forKey: .gitStageOnSave) ?? false
        gitAutoPullEnabled = try container.decodeIfPresent(Bool.self, forKey: .gitAutoPullEnabled) ?? false
        enableBackgroundBlur = try container.decodeIfPresent(Bool.self, forKey: .enableBackgroundBlur) ?? true
        backgroundBlurMaterial = try container.decodeIfPresent(BackgroundBlurMaterial.self, forKey: .backgroundBlurMaterial) ?? .underWindowBackground
        backgroundBlurBlendMode = try container.decodeIfPresent(BackgroundBlurBlendMode.self, forKey: .backgroundBlurBlendMode) ?? .behindWindow
        backgroundRendererPreference = try container.decodeIfPresent(BackgroundRendererPreference.self, forKey: .backgroundRendererPreference) ?? .nativeMaterialBlur
        backgroundTint = try container.decodeIfPresent(BackgroundTint.self, forKey: .backgroundTint) ?? .init()
        backgroundTintOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundTintOpacity) ?? 0.06
        fallbackBlurRadius = try container.decodeIfPresent(Double.self, forKey: .fallbackBlurRadius) ?? 18.0
        editorShortcutCommands = try container.decodeIfPresent([EditorShortcutCommand].self, forKey: .editorShortcutCommands) ?? EditorShortcutCommand.defaultCommands
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mainTexRelativePath, forKey: .mainTexRelativePath)
        try container.encode(latexEngine, forKey: .latexEngine)
        try container.encode(autoCompileEnabled, forKey: .autoCompileEnabled)
        try container.encode(interfaceTheme, forKey: .interfaceTheme)
        try container.encode(interfaceMode, forKey: .interfaceMode)
        try container.encode(interfaceTransparency, forKey: .interfaceTransparency)
        try container.encode(editorPreviewLayout, forKey: .editorPreviewLayout)
        try container.encode(editorAutoCorrectEnabled, forKey: .editorAutoCorrectEnabled)
        try container.encode(editorSyntaxColoringEnabled, forKey: .editorSyntaxColoringEnabled)
        try container.encode(editorLineNumbersEnabled, forKey: .editorLineNumbersEnabled)
        try container.encode(editorFontSize, forKey: .editorFontSize)
        try container.encode(customPalette, forKey: .customPalette)
        try container.encode(gitHelpersEnabled, forKey: .gitHelpersEnabled)
        try container.encode(gitStageOnSave, forKey: .gitStageOnSave)
        try container.encode(gitAutoPullEnabled, forKey: .gitAutoPullEnabled)
        try container.encode(enableBackgroundBlur, forKey: .enableBackgroundBlur)
        try container.encode(backgroundBlurMaterial, forKey: .backgroundBlurMaterial)
        try container.encode(backgroundBlurBlendMode, forKey: .backgroundBlurBlendMode)
        try container.encode(backgroundRendererPreference, forKey: .backgroundRendererPreference)
        try container.encode(backgroundTint, forKey: .backgroundTint)
        try container.encode(backgroundTintOpacity, forKey: .backgroundTintOpacity)
        try container.encode(fallbackBlurRadius, forKey: .fallbackBlurRadius)
        try container.encode(editorShortcutCommands, forKey: .editorShortcutCommands)
    }
}
