import Core
import Combine
import Foundation
import Shared

@MainActor
final class MacRootViewModel: ObservableObject {
    @Published private(set) var recentProjects: [ProjectReference]
    @Published private(set) var projectRoot: URL?
    @Published private(set) var texFiles: [String] = []

    @Published var selectedMainTex: String = "" {
        didSet {
            guard oldValue != selectedMainTex else { return }
            loadSelectedMainFileIntoEditor()
            persistSettings()
        }
    }

    @Published var selectedEngine: CompileEngine = .pdfLaTeX {
        didSet {
            guard oldValue != selectedEngine else { return }
            persistSettings()
        }
    }

    @Published var autoCompileEnabled: Bool = false {
        didSet {
            guard oldValue != autoCompileEnabled else { return }
            persistSettings()
            configureWatcher()
        }
    }

    @Published var interfaceTheme: InterfaceTheme = .dark {
        didSet {
            guard oldValue != interfaceTheme else { return }
            persistSettings()
        }
    }

    @Published var interfaceMode: InterfaceMode = .debug {
        didSet {
            guard oldValue != interfaceMode else { return }
            persistSettings()
        }
    }

    @Published var interfaceTransparency: Double = 0.78 {
        didSet {
            let clamped = min(max(interfaceTransparency, 0.25), 1.0)
            if clamped != interfaceTransparency {
                interfaceTransparency = clamped
                return
            }
            guard oldValue != interfaceTransparency else { return }
            persistSettings()
        }
    }

    @Published var editorPreviewLayout: EditorPreviewLayout = .sideBySide {
        didSet {
            guard oldValue != editorPreviewLayout else { return }
            persistSettings()
        }
    }

    @Published var editorAutoCorrectEnabled: Bool = true {
        didSet {
            guard oldValue != editorAutoCorrectEnabled else { return }
            persistSettings()
        }
    }

    @Published var accentRed: Double = 0.24 { didSet { persistPaletteChange(from: oldValue, to: accentRed) } }
    @Published var accentGreen: Double = 0.47 { didSet { persistPaletteChange(from: oldValue, to: accentGreen) } }
    @Published var accentBlue: Double = 0.92 { didSet { persistPaletteChange(from: oldValue, to: accentBlue) } }

    @Published var editorText = "" {
        didSet {
            guard isLoadingEditorText == false, oldValue != editorText else { return }
            hasUnsavedEditorChanges = true
        }
    }

    @Published private(set) var hasUnsavedEditorChanges = false
    @Published private(set) var documentState = DocumentState()
    @Published private(set) var isCompiling = false
    @Published var selectedLogTab = LogTab.diagnostics
    @Published var bannerMessage: String?

    enum LogTab: String, CaseIterable {
        case diagnostics = "Diagnostics"
        case raw = "Raw Log"
    }

    private let recentStore: any RecentProjectsStore
    private let settingsStore: any SettingsStore
    private let compileRunner: any CompileRunning

    private var watcher: DirectoryWatcher?
    private var debounceWorkItem: DispatchWorkItem?
    private var isLoadingEditorText = false

    init(
        recentStore: any RecentProjectsStore = UserDefaultsRecentProjectsStore(),
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        compileRunner: any CompileRunning = LatexmkCompileRunner()
    ) {
        self.recentStore = recentStore
        self.settingsStore = settingsStore
        self.compileRunner = compileRunner
        self.recentProjects = recentStore.load()
    }

    var projectDisplayName: String {
        projectRoot?.lastPathComponent ?? "No Project"
    }

    var statusLine: String {
        switch documentState.compileStatus {
        case .idle:
            return "Idle"
        case .running:
            return "Compiling..."
        case .succeeded:
            return "Compile succeeded"
        case .failed:
            return "Compile failed"
        case .cancelled:
            return "Compile cancelled"
        }
    }

    func openProject(url: URL) {
        projectRoot = url
        texFiles = ProjectScanner.findTexFiles(projectRoot: url)

        let settings = settingsStore.load(projectRootPath: url.path)
        selectedEngine = settings.latexEngine
        autoCompileEnabled = settings.autoCompileEnabled
        interfaceTheme = settings.interfaceTheme
        interfaceMode = settings.interfaceMode
        interfaceTransparency = settings.interfaceTransparency
        editorPreviewLayout = settings.editorPreviewLayout
        editorAutoCorrectEnabled = settings.editorAutoCorrectEnabled
        accentRed = settings.customPalette.accentRed
        accentGreen = settings.customPalette.accentGreen
        accentBlue = settings.customPalette.accentBlue

        if let savedMain = settings.mainTexRelativePath, texFiles.contains(savedMain) {
            selectedMainTex = savedMain
        } else {
            selectedMainTex = texFiles.first ?? ""
        }

        documentState.projectRoot = url
        documentState.mainFileRelativePath = selectedMainTex
        loadSelectedMainFileIntoEditor()

        pushRecentProject(url)
        configureWatcher()

        if autoCompileEnabled {
            compileNow(trigger: .automatic)
        }
    }

    func openRecent(_ project: ProjectReference) {
        openProject(url: project.rootURL)
    }

    func compileNow(trigger: CompileTrigger = .manual) {
        guard isCompiling == false else { return }
        guard let projectRoot else {
            bannerMessage = "Choose a LaTeX project first."
            return
        }
        guard selectedMainTex.isEmpty == false else {
            bannerMessage = "Select a main .tex file before compiling."
            return
        }

        if editorAutoCorrectEnabled {
            runAutoCorrect()
        }

        if hasUnsavedEditorChanges {
            saveEditorToDisk()
        }

        isCompiling = true
        documentState.compileStatus = .running
        documentState.mainFileRelativePath = selectedMainTex
        bannerMessage = nil

        let request = CompileRequest(
            projectRoot: projectRoot,
            mainFileRelativePath: selectedMainTex,
            engine: selectedEngine,
            autoCompile: trigger == .automatic
        )

        Task {
            defer { Task { @MainActor in self.isCompiling = false } }

            do {
                let runner = compileRunner
                let result = try await Task.detached(priority: .userInitiated) {
                    try await runner.compile(request)
                }.value

                await MainActor.run {
                    self.documentState.compileStatus = result.status
                    self.documentState.rawCompileLog = result.rawLog
                    self.documentState.diagnostics = result.diagnostics
                    self.documentState.lastCompileAt = result.finishedAt
                    self.documentState.pdfURL = result.pdfURL

                    if result.status == .failed {
                        self.bannerMessage = "Compile failed. Review diagnostics."
                    }
                }
            } catch {
                await MainActor.run {
                    self.documentState.compileStatus = .failed
                    self.documentState.rawCompileLog = error.localizedDescription
                    self.documentState.diagnostics = [
                        CompileDiagnostic(severity: .error, message: error.localizedDescription)
                    ]
                    self.bannerMessage = "Compile failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func userChangedMainFile(_ value: String) {
        selectedMainTex = value
        documentState.mainFileRelativePath = value
    }

    func saveEditorToDisk() {
        guard let target = selectedMainFileURL else { return }

        do {
            try editorText.write(to: target, atomically: true, encoding: .utf8)
            hasUnsavedEditorChanges = false
            bannerMessage = "Saved \(selectedMainTex)"
        } catch {
            bannerMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func revertEditorToDisk() {
        loadSelectedMainFileIntoEditor()
    }

    func runAutoCorrect() {
        guard editorAutoCorrectEnabled else { return }

        var updated = editorText
        let corrections: [(String, String)] = [
            ("teh", "the"),
            ("recieve", "receive"),
            ("seperate", "separate"),
            ("occurence", "occurrence"),
            ("enviroment", "environment"),
            ("langauge", "language"),
            ("definately", "definitely"),
            ("accomodate", "accommodate")
        ]

        for (typo, fix) in corrections {
            updated = updated.replacingOccurrences(
                of: "\b\(NSRegularExpression.escapedPattern(for: typo))\b",
                with: fix,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        if updated != editorText {
            editorText = updated
            bannerMessage = "AutoCorrect applied common typo fixes."
        }
    }

    func clearBanner() {
        bannerMessage = nil
    }

    var selectedMainFileURL: URL? {
        guard let projectRoot, selectedMainTex.isEmpty == false else { return nil }
        return projectRoot.appending(path: selectedMainTex)
    }

    private func pushRecentProject(_ url: URL) {
        let reference = ProjectReference(
            name: url.lastPathComponent,
            rootPath: url.path,
            lastOpenedAt: Date()
        )

        var updated = recentProjects.filter { $0.rootPath != reference.rootPath }
        updated.insert(reference, at: 0)
        updated = Array(updated.prefix(10))

        recentProjects = updated
        recentStore.save(updated)
    }

    private func persistSettings() {
        guard let projectRoot else { return }

        let settings = UserSettings(
            mainTexRelativePath: selectedMainTex.isEmpty ? nil : selectedMainTex,
            latexEngine: selectedEngine,
            autoCompileEnabled: autoCompileEnabled,
            interfaceTheme: interfaceTheme,
            interfaceMode: interfaceMode,
            interfaceTransparency: interfaceTransparency,
            editorPreviewLayout: editorPreviewLayout,
            editorAutoCorrectEnabled: editorAutoCorrectEnabled,
            customPalette: CustomThemePalette(accentRed: accentRed, accentGreen: accentGreen, accentBlue: accentBlue)
        )
        settingsStore.save(settings, projectRootPath: projectRoot.path)
    }

    private func persistPaletteChange(from oldValue: Double, to newValue: Double) {
        guard oldValue != newValue else { return }
        persistSettings()
    }

    private func configureWatcher() {
        watcher?.stop()
        watcher = nil

        guard autoCompileEnabled, let projectRoot else { return }

        watcher = DirectoryWatcher(url: projectRoot) { [weak self] in
            Task { @MainActor in
                self?.scheduleAutoCompile()
            }
        }
        watcher?.start()
    }

    private func scheduleAutoCompile() {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.autoCompileEnabled else { return }
                self.compileNow(trigger: .automatic)
            }
        }

        debounceWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func loadSelectedMainFileIntoEditor() {
        guard let source = selectedMainFileURL else {
            isLoadingEditorText = true
            editorText = ""
            isLoadingEditorText = false
            hasUnsavedEditorChanges = false
            return
        }

        do {
            let content = try String(contentsOf: source, encoding: .utf8)
            isLoadingEditorText = true
            editorText = content
            isLoadingEditorText = false
            hasUnsavedEditorChanges = false
        } catch {
            bannerMessage = "Unable to load \(selectedMainTex): \(error.localizedDescription)"
        }
    }
}

enum CompileTrigger {
    case manual
    case automatic
}
