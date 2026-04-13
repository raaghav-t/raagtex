import AppKit
import Core
import Combine
import Foundation
import Shared
import UniformTypeIdentifiers

@MainActor
final class MacRootViewModel: ObservableObject {
    @Published private(set) var recentProjects: [ProjectReference]
    @Published private(set) var projectRoot: URL?
    @Published private(set) var texFiles: [String] = []
    @Published private(set) var projectFileTree: [ProjectFileNode] = []

    @Published var selectedMainTex: String = "" {
        didSet {
            guard oldValue != selectedMainTex else { return }
            if selectedEditorTex.isEmpty {
                selectedEditorTex = selectedMainTex
            }
            persistSettings()
        }
    }

    @Published var selectedEditorTex: String = "" {
        didSet {
            guard oldValue != selectedEditorTex else { return }
            loadSelectedEditorFileIntoEditor()
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
            let minimum = minimumInterfaceAmount(for: interfaceTheme)
            if interfaceTransparency < minimum {
                interfaceTransparency = minimum
            }
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
            let clamped = min(max(interfaceTransparency, minimumInterfaceAmount(for: interfaceTheme)), 1.0)
            if clamped != interfaceTransparency {
                interfaceTransparency = clamped
                return
            }
            guard oldValue != interfaceTransparency else { return }
            persistSettings()
        }
    }

    @Published var enableBackgroundBlur: Bool = true {
        didSet {
            guard oldValue != enableBackgroundBlur else { return }
            persistSettings()
        }
    }

    @Published var backgroundBlurMaterial: BackgroundBlurMaterial = .underWindowBackground {
        didSet {
            guard oldValue != backgroundBlurMaterial else { return }
            persistSettings()
        }
    }

    @Published var backgroundBlurBlendMode: BackgroundBlurBlendMode = .behindWindow {
        didSet {
            guard oldValue != backgroundBlurBlendMode else { return }
            persistSettings()
        }
    }

    @Published var backgroundRendererPreference: BackgroundRendererPreference = .nativeMaterialBlur {
        didSet {
            guard oldValue != backgroundRendererPreference else { return }
            persistSettings()
        }
    }

    @Published var backgroundTintRed: Double = 0.79 {
        didSet {
            let clamped = min(max(backgroundTintRed, 0.0), 1.0)
            if clamped != backgroundTintRed {
                backgroundTintRed = clamped
                return
            }
            guard oldValue != backgroundTintRed else { return }
            persistSettings()
        }
    }
    @Published var backgroundTintGreen: Double = 0.70 {
        didSet {
            let clamped = min(max(backgroundTintGreen, 0.0), 1.0)
            if clamped != backgroundTintGreen {
                backgroundTintGreen = clamped
                return
            }
            guard oldValue != backgroundTintGreen else { return }
            persistSettings()
        }
    }
    @Published var backgroundTintBlue: Double = 0.64 {
        didSet {
            let clamped = min(max(backgroundTintBlue, 0.0), 1.0)
            if clamped != backgroundTintBlue {
                backgroundTintBlue = clamped
                return
            }
            guard oldValue != backgroundTintBlue else { return }
            persistSettings()
        }
    }
    @Published var backgroundTintOpacity: Double = 0.06 {
        didSet {
            let clamped = min(max(backgroundTintOpacity, 0.0), 0.35)
            if clamped != backgroundTintOpacity {
                backgroundTintOpacity = clamped
                return
            }
            guard oldValue != backgroundTintOpacity else { return }
            persistSettings()
        }
    }
    @Published var fallbackBlurRadius: Double = 18.0 {
        didSet {
            let clamped = min(max(fallbackBlurRadius, 0.0), 48.0)
            if clamped != fallbackBlurRadius {
                fallbackBlurRadius = clamped
                return
            }
            guard oldValue != fallbackBlurRadius else { return }
            persistSettings()
        }
    }

    @Published var editorPreviewLayout: EditorPreviewLayout = .leftRight {
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
    @Published var editorLineNumbersEnabled: Bool = false {
        didSet {
            guard oldValue != editorLineNumbersEnabled else { return }
            persistSettings()
        }
    }
    @Published var editorShortcutCommands: [EditorShortcutCommand] = EditorShortcutCommand.defaultCommands {
        didSet {
            guard editorShortcutCommands != oldValue else { return }
            persistSettings()
        }
    }
    @Published var gitHelpersEnabled: Bool = true {
        didSet {
            guard gitHelpersEnabled != oldValue else { return }
            persistSettings()
            configureGitAutoPullTimer()
        }
    }
    @Published var gitStageOnSave: Bool = false {
        didSet {
            guard gitStageOnSave != oldValue else { return }
            persistSettings()
        }
    }
    @Published var gitAutoPullEnabled: Bool = false {
        didSet {
            guard gitAutoPullEnabled != oldValue else { return }
            persistSettings()
            configureGitAutoPullTimer()
        }
    }

    @Published var accentRed: Double = 0.24 { didSet { persistPaletteChange(from: oldValue, to: accentRed) } }
    @Published var accentGreen: Double = 0.47 { didSet { persistPaletteChange(from: oldValue, to: accentGreen) } }
    @Published var accentBlue: Double = 0.92 { didSet { persistPaletteChange(from: oldValue, to: accentBlue) } }

    @Published var editorText = "" {
        didSet {
            guard isLoadingEditorText == false, oldValue != editorText else { return }
            hasUnsavedEditorChanges = true
            refreshCompilePreflightError()
        }
    }

    @Published private(set) var hasUnsavedEditorChanges = false
    @Published private(set) var compilePreflightError: String?
    @Published private(set) var documentState = DocumentState()
    @Published private(set) var isCompiling = false
    @Published var selectedLogTab = LogTab.diagnostics
    @Published var bannerMessage: String?
    @Published private(set) var isGitRepository = false
    @Published private(set) var gitBranchName = ""
    @Published private(set) var gitAheadCount = 0
    @Published private(set) var gitBehindCount = 0
    @Published private(set) var gitHasChanges = false
    @Published private(set) var gitHasConflicts = false
    @Published private(set) var gitOperationInProgress = false

    enum LogTab: String, CaseIterable {
        case diagnostics = "Diagnostics"
        case raw = "Raw Log"
    }

    private let recentStore: any RecentProjectsStore
    private let settingsStore: any SettingsStore
    private let compileRunner: any CompileRunning
    private let gitService: any GitServicing

    private var watcher: DirectoryWatcher?
    private var debounceWorkItem: DispatchWorkItem?
    private var isLoadingEditorText = false
    private var gitAutoPullTimer: Timer?

    init(
        recentStore: any RecentProjectsStore = UserDefaultsRecentProjectsStore(),
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        compileRunner: any CompileRunning = LatexmkCompileRunner(),
        gitService: any GitServicing = GitService()
    ) {
        self.recentStore = recentStore
        self.settingsStore = settingsStore
        self.compileRunner = compileRunner
        self.gitService = gitService
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

    var canUseGitTools: Bool {
        projectRoot != nil && isGitRepository && gitHelpersEnabled
    }

    var canSaveDocument: Bool {
        projectRoot != nil && selectedMainTex.isEmpty == false
    }

    var canCommitWithGit: Bool {
        canUseGitTools && gitOperationInProgress == false && gitHasChanges
    }

    var canRunGitSync: Bool {
        canUseGitTools &&
        gitOperationInProgress == false &&
        hasUnsavedEditorChanges == false &&
        isCompiling == false &&
        gitHasConflicts == false
    }

    var gitStatusSummary: String {
        guard canUseGitTools else { return "Git unavailable" }
        if gitHasConflicts {
            return "\(gitBranchName) • conflict"
        }
        if gitHasChanges {
            return "\(gitBranchName) • changes"
        }
        if gitAheadCount > 0 || gitBehindCount > 0 {
            return "\(gitBranchName) • \(gitAheadCount)↑ \(gitBehindCount)↓"
        }
        return "\(gitBranchName) • clean"
    }

    func openProject(url: URL) {
        projectRoot = url
        texFiles = ProjectScanner.findTexFiles(projectRoot: url)
        projectFileTree = ProjectScanner.buildFileTree(projectRoot: url)

        let settings = settingsStore.load(projectRootPath: url.path)
        selectedEngine = settings.latexEngine
        autoCompileEnabled = settings.autoCompileEnabled
        interfaceTheme = settings.interfaceTheme
        interfaceMode = settings.interfaceMode
        interfaceTransparency = settings.interfaceTransparency
        editorPreviewLayout = settings.editorPreviewLayout
        editorAutoCorrectEnabled = settings.editorAutoCorrectEnabled
        editorLineNumbersEnabled = settings.editorLineNumbersEnabled
        editorShortcutCommands = settings.editorShortcutCommands.isEmpty ? EditorShortcutCommand.defaultCommands : settings.editorShortcutCommands
        gitHelpersEnabled = settings.gitHelpersEnabled
        gitStageOnSave = settings.gitStageOnSave
        gitAutoPullEnabled = settings.gitAutoPullEnabled
        accentRed = settings.customPalette.accentRed
        accentGreen = settings.customPalette.accentGreen
        accentBlue = settings.customPalette.accentBlue
        enableBackgroundBlur = settings.enableBackgroundBlur
        backgroundBlurMaterial = settings.backgroundBlurMaterial
        backgroundBlurBlendMode = settings.backgroundBlurBlendMode
        backgroundRendererPreference = settings.backgroundRendererPreference
        backgroundTintRed = settings.backgroundTint.red
        backgroundTintGreen = settings.backgroundTint.green
        backgroundTintBlue = settings.backgroundTint.blue
        backgroundTintOpacity = settings.backgroundTintOpacity
        fallbackBlurRadius = settings.fallbackBlurRadius

        if
            let savedMain = settings.mainTexRelativePath,
            texFiles.contains(savedMain),
            canCompileAsMainFile(savedMain)
        {
            selectedMainTex = savedMain
        } else {
            selectedMainTex = preferredMainTexFile(from: texFiles) ?? ""
        }

        selectedEditorTex = selectedMainTex
        documentState.projectRoot = url
        documentState.mainFileRelativePath = selectedMainTex
        refreshCompilePreflightError()

        pushRecentProject(url)
        configureWatcher()
        refreshGitStatus()
        configureGitAutoPullTimer()

        if autoCompileEnabled {
            compileNow(trigger: .automatic)
        }
    }

    func openRecent(_ project: ProjectReference) {
        openProject(url: project.rootURL)
    }

    func promptForProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            openProject(url: selectedURL)
        }
    }

    func closeProject() {
        watcher?.stop()
        watcher = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        projectRoot = nil
        texFiles = []
        projectFileTree = []
        selectedMainTex = ""
        selectedEditorTex = ""
        documentState = DocumentState()
        isCompiling = false
        bannerMessage = nil

        isLoadingEditorText = true
        editorText = ""
        isLoadingEditorText = false
        hasUnsavedEditorChanges = false
        compilePreflightError = nil
        resetGitState()
        configureGitAutoPullTimer()
    }

    func exportCompiledPDF() {
        guard let sourceURL = documentState.pdfURL else {
            bannerMessage = "Compile once before exporting a PDF."
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultPDFExportName
        panel.allowedContentTypes = [.pdf]
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            bannerMessage = "Exported PDF to \(destinationURL.lastPathComponent)"
        } catch {
            bannerMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func revealCompiledPDFInFinder() {
        guard let pdfURL = documentState.pdfURL else {
            bannerMessage = "No compiled PDF to reveal yet."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([pdfURL])
    }

    func openProjectInFinder() {
        guard let projectRoot else { return }
        NSWorkspace.shared.activateFileViewerSelecting([projectRoot])
    }

    func openProjectInTerminal() {
        guard let projectRoot else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", projectRoot.path]
        try? process.run()
    }

    func refreshGitStatus() {
        guard let projectRoot else {
            resetGitState()
            return
        }

        Task {
            do {
                let repo = try await performGitWork { self.gitService.isRepository(at: projectRoot) }
                if repo == false {
                    await MainActor.run {
                        self.resetGitState()
                    }
                    return
                }

                let status = try await performGitWork { try self.gitService.status(at: projectRoot) }
                await MainActor.run {
                    self.applyGitStatus(status)
                }
            } catch {
                await MainActor.run {
                    self.bannerMessage = "Git status failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func gitStageAll(showBanner: Bool = true) {
        guard let projectRoot, canUseGitTools else { return }
        runGitOperation(showBanner: showBanner, successMessage: "Staged all changes.") {
            try self.gitService.stageAll(at: projectRoot)
        }
    }

    func promptForCommit() {
        guard canUseGitTools else { return }

        let alert = NSAlert()
        alert.messageText = "Commit Changes"
        alert.informativeText = "Enter a commit message."
        alert.addButton(withTitle: "Commit")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "Commit message"
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let message = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.isEmpty == false else {
            bannerMessage = "Commit message cannot be empty."
            return
        }
        gitCommit(message: message)
    }

    func gitCommit(message: String) {
        guard let projectRoot, canUseGitTools else { return }
        runGitOperation(showBanner: true, successMessage: "Committed changes.") {
            try self.gitService.stageAll(at: projectRoot)
            try self.gitService.commit(at: projectRoot, message: message)
        }
    }

    func gitPullRebase() {
        guard let projectRoot, canUseGitTools else { return }
        runGitOperation(showBanner: true, successMessage: "Pull completed.") {
            try self.gitService.pullRebase(at: projectRoot)
        }
    }

    func gitPush() {
        guard let projectRoot, canUseGitTools else { return }
        runGitOperation(showBanner: true, successMessage: "Push completed.") {
            try self.gitService.push(at: projectRoot)
        }
    }

    func gitSync() {
        guard let projectRoot, canUseGitTools else { return }
        runGitOperation(showBanner: true, successMessage: "Sync completed.") {
            try self.gitService.pullRebase(at: projectRoot)
            try self.gitService.push(at: projectRoot)
        }
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

        let mainPreflightSource = currentMainFileTextForPreflight()
        if let preflightError = evaluateCompilePreflightError(for: mainPreflightSource) {
            compilePreflightError = preflightError
            if trigger == .manual {
                bannerMessage = preflightError
            }
            return
        }
        compilePreflightError = nil

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
        selectedEditorTex = value
        documentState.mainFileRelativePath = value
        refreshCompilePreflightError()
    }

    func userSelectedEditorFile(_ value: String) {
        selectedEditorTex = value
    }

    func saveEditorToDisk() {
        guard let target = selectedEditorFileURL else { return }

        do {
            try editorText.write(to: target, atomically: false, encoding: .utf8)
            hasUnsavedEditorChanges = false
            bannerMessage = "Saved \(selectedEditorTex)"
            if gitStageOnSave && canUseGitTools {
                gitStageAll(showBanner: false)
            } else {
                refreshGitStatus()
            }
        } catch {
            bannerMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func saveAndRecompile() {
        if hasUnsavedEditorChanges {
            saveEditorToDisk()
            guard hasUnsavedEditorChanges == false else { return }
        }
        compileNow(trigger: .manual)
    }

    func revertEditorToDisk() {
        loadSelectedEditorFileIntoEditor()
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
                of: "\\b\(NSRegularExpression.escapedPattern(for: typo))\\b",
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

    var selectedEditorFileURL: URL? {
        guard let projectRoot, selectedEditorTex.isEmpty == false else { return nil }
        return projectRoot.appending(path: selectedEditorTex)
    }

    private var defaultPDFExportName: String {
        let baseName: String
        if selectedMainTex.isEmpty == false {
            baseName = URL(fileURLWithPath: selectedMainTex).deletingPathExtension().lastPathComponent
        } else {
            baseName = projectDisplayName
        }
        return "\(baseName).pdf"
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
            editorLineNumbersEnabled: editorLineNumbersEnabled,
            customPalette: CustomThemePalette(accentRed: accentRed, accentGreen: accentGreen, accentBlue: accentBlue),
            gitHelpersEnabled: gitHelpersEnabled,
            gitStageOnSave: gitStageOnSave,
            gitAutoPullEnabled: gitAutoPullEnabled,
            enableBackgroundBlur: enableBackgroundBlur,
            backgroundBlurMaterial: backgroundBlurMaterial,
            backgroundBlurBlendMode: backgroundBlurBlendMode,
            backgroundRendererPreference: backgroundRendererPreference,
            backgroundTint: BackgroundTint(red: backgroundTintRed, green: backgroundTintGreen, blue: backgroundTintBlue),
            backgroundTintOpacity: backgroundTintOpacity,
            fallbackBlurRadius: fallbackBlurRadius,
            editorShortcutCommands: editorShortcutCommands
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
                self?.refreshProjectFileTree()
                self?.scheduleAutoCompile()
                self?.refreshGitStatus()
            }
        }
        watcher?.start()
    }

    private func refreshProjectFileTree() {
        guard let projectRoot else {
            projectFileTree = []
            return
        }
        projectFileTree = ProjectScanner.buildFileTree(projectRoot: projectRoot)
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

    private func configureGitAutoPullTimer() {
        gitAutoPullTimer?.invalidate()
        gitAutoPullTimer = nil

        guard gitAutoPullEnabled, canUseGitTools else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.canUseGitTools else { return }
                guard self.hasUnsavedEditorChanges == false else { return }
                guard self.isCompiling == false else { return }
                guard self.gitHasConflicts == false else { return }
                guard self.gitOperationInProgress == false else { return }
                self.gitPullRebase()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        gitAutoPullTimer = timer
    }

    private func applyGitStatus(_ status: GitRepositoryStatus) {
        isGitRepository = true
        gitBranchName = status.branchName
        gitAheadCount = status.aheadCount
        gitBehindCount = status.behindCount
        gitHasChanges = status.hasUncommittedChanges
        gitHasConflicts = status.hasConflicts
        configureGitAutoPullTimer()
    }

    private func resetGitState() {
        isGitRepository = false
        gitBranchName = ""
        gitAheadCount = 0
        gitBehindCount = 0
        gitHasChanges = false
        gitHasConflicts = false
        gitOperationInProgress = false
    }

    private func runGitOperation(
        showBanner: Bool,
        successMessage: String,
        operation: @escaping () throws -> Void
    ) {
        guard gitOperationInProgress == false else { return }
        gitOperationInProgress = true

        Task {
            defer {
                Task { @MainActor in
                    self.gitOperationInProgress = false
                }
            }
            do {
                try await performGitWork(operation)
                await MainActor.run {
                    if showBanner {
                        self.bannerMessage = successMessage
                    }
                }
                await MainActor.run {
                    self.refreshGitStatus()
                }
            } catch {
                await MainActor.run {
                    self.bannerMessage = "Git error: \(error.localizedDescription)"
                    self.refreshGitStatus()
                }
            }
        }
    }

    private func performGitWork<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func minimumInterfaceAmount(for theme: InterfaceTheme) -> Double {
        theme == .clear ? 0.0 : 0.25
    }

    private func loadSelectedEditorFileIntoEditor() {
        guard let source = selectedEditorFileURL else {
            isLoadingEditorText = true
            editorText = ""
            isLoadingEditorText = false
            hasUnsavedEditorChanges = false
            refreshCompilePreflightError()
            return
        }

        do {
            let content = try String(contentsOf: source, encoding: .utf8)
            isLoadingEditorText = true
            editorText = content
            isLoadingEditorText = false
            hasUnsavedEditorChanges = false
            refreshCompilePreflightError()
        } catch {
            bannerMessage = "Unable to load \(selectedMainTex): \(error.localizedDescription)"
            refreshCompilePreflightError()
        }
    }

    private func currentMainFileTextForPreflight() -> String {
        if selectedEditorTex == selectedMainTex {
            return editorText
        }

        guard let projectRoot, selectedMainTex.isEmpty == false else { return "" }
        let mainURL = projectRoot.appending(path: selectedMainTex)
        return (try? String(contentsOf: mainURL, encoding: .utf8)) ?? ""
    }

    private func refreshCompilePreflightError() {
        guard selectedMainTex.isEmpty == false else {
            compilePreflightError = nil
            return
        }
        compilePreflightError = evaluateCompilePreflightError(for: currentMainFileTextForPreflight())
    }

    private func preferredMainTexFile(from files: [String]) -> String? {
        guard files.isEmpty == false else { return nil }

        if let mainTex = files.first(where: { URL(fileURLWithPath: $0).lastPathComponent.lowercased() == "main.tex" }) {
            return mainTex
        }

        if let compileable = files.first(where: { canCompileAsMainFile($0) }) {
            return compileable
        }

        return files.first
    }

    private func canCompileAsMainFile(_ relativePath: String) -> Bool {
        guard let projectRoot else { return false }
        let url = projectRoot.appending(path: relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return evaluateCompilePreflightError(for: text) == nil
    }

    private func evaluateCompilePreflightError(for text: String) -> String? {
        guard text.isEmpty == false else {
            return "Main file is empty. Add a LaTeX document before compiling."
        }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let firstMeaningfulLine = lines
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .first { line in
                line.isEmpty == false && line.hasPrefix("%") == false
            }

        guard let firstMeaningfulLine else {
            return "Main file is empty. Add a LaTeX document before compiling."
        }

        guard firstMeaningfulLine.hasPrefix("\\documentclass") else {
            return "Main file must start with \\documentclass on the first non-comment line."
        }

        let hasBeginDocument = text.range(
            of: #"\\begin\s*\{\s*document\s*\}"#,
            options: .regularExpression
        ) != nil

        guard hasBeginDocument else {
            return "Main file is missing \\begin{document}."
        }

        return nil
    }
}

enum CompileTrigger {
    case manual
    case automatic
}
