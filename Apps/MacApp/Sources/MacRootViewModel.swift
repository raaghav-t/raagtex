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
            if isApplyingLoadedSettings == false {
                configureWatcher()
            }
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
    @Published var editorSyntaxColoringEnabled: Bool = true {
        didSet {
            guard oldValue != editorSyntaxColoringEnabled else { return }
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
            if isApplyingLoadedSettings == false {
                configureGitAutoPullTimer()
            }
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
            if isApplyingLoadedSettings == false {
                configureGitAutoPullTimer()
            }
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
    @Published var editorLineJumpRequest: EditorLineJumpRequest?

    @Published private(set) var hasUnsavedEditorChanges = false
    @Published private(set) var compilePreflightError: String?
    @Published private(set) var documentState = DocumentState()
    @Published private(set) var isCompiling = false
    @Published var selectedLogTab = LogTab.diagnostics
    @Published var bannerMessage: String? {
        didSet {
            guard bannerMessage != oldValue else { return }
            scheduleBannerAutoDismiss()
        }
    }
    @Published private(set) var isGitRepository = false
    @Published private(set) var gitBranchName = ""
    @Published private(set) var gitAheadCount = 0
    @Published private(set) var gitBehindCount = 0
    @Published private(set) var gitHasChanges = false
    @Published private(set) var gitHasConflicts = false
    @Published private(set) var gitOperationInProgress = false
    @Published private(set) var hasProjectClipboardItem = false
    @Published var showsSyntaxColorEditor = false
    @Published var showsShortcutCommandEditor = false
    @Published var showsTemplateManager = false
    @Published var showsNewFileSheet = false
    @Published var showsAddStyleSheet = false
    @Published private(set) var templateFolderURL: URL?
    @Published private(set) var documentTemplates: [TemplateEntry] = []
    @Published private(set) var styleTemplates: [TemplateEntry] = []
    @Published private(set) var pendingNewFileDirectory = ""
    @Published private(set) var debugLastSaveAt: Date?
    @Published private(set) var debugLastCompileRequestedAt: Date?
    @Published private(set) var debugLastCompileStartedAt: Date?
    @Published private(set) var debugLastCompileFinishedAt: Date?
    @Published private(set) var debugLastPDFDisplayedAt: Date?

    enum LogTab: String, CaseIterable {
        case diagnostics = "Diagnostics"
        case raw = "Raw Log"
    }

    private let recentStore: any RecentProjectsStore
    private let settingsStore: any SettingsStore
    private let compileRunner: any CompileRunning
    private let gitService: any GitServicing
    private let userDefaults: UserDefaults
    private let templateFolderPreferenceKey = "templateLibrary.customRoot.v1"
    private let templateDisplayNamePreferenceKey = "templateLibrary.displayNames.v1"

    private var watcher: DirectoryWatcher?
    private var debounceWorkItem: DispatchWorkItem?
    private var projectRefreshWorkItem: DispatchWorkItem?
    private var isLoadingEditorText = false
    private var gitAutoPullTimer: Timer?
    private var queuedCompileTrigger: CompileTrigger?
    private var autoCompileSuppressedUntil = Date.distantPast
    private var lastAutoCompileInputFingerprint = ""
    private var bannerDismissWorkItem: DispatchWorkItem?
    private var pendingProjectRefreshAfterCompile = false
    private var isApplyingLoadedSettings = false
    private var projectClipboardItem: ProjectFileClipboardItem? {
        didSet {
            hasProjectClipboardItem = projectClipboardItem != nil
        }
    }

    private enum EnergyTuning {
        static let fileSystemRefreshDebounce: TimeInterval = 1.0
        static let autoCompileDebounce: TimeInterval = 0.9
        static let gitAutoPullInterval: TimeInterval = 300
        static let gitAutoPullTolerance: TimeInterval = 45
        static let bannerDisplayDuration: TimeInterval = 3.0
    }

    init(
        recentStore: any RecentProjectsStore = UserDefaultsRecentProjectsStore(),
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        compileRunner: any CompileRunning = LatexmkCompileRunner(),
        gitService: any GitServicing = GitService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.recentStore = recentStore
        self.settingsStore = settingsStore
        self.compileRunner = compileRunner
        self.gitService = gitService
        self.userDefaults = userDefaults
        self.recentProjects = recentStore.load()
        refreshTemplateLibrary(createDefaults: true)
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
        applyProjectScan(ProjectScanner.scan(projectRoot: url))

        let settings = settingsStore.load(projectRootPath: url.path)
        applyLoadedSettings(settings)
        documentState.projectRoot = url
        documentState.mainFileRelativePath = selectedMainTex
        updatePreviewFromExistingPDFIfAvailable()
        refreshCompilePreflightError()
        lastAutoCompileInputFingerprint = currentTexInputFingerprint()

        pushRecentProject(url)
        configureWatcher()

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
        projectRefreshWorkItem?.cancel()
        projectRefreshWorkItem = nil
        pendingProjectRefreshAfterCompile = false
        queuedCompileTrigger = nil
        gitAutoPullTimer?.invalidate()
        gitAutoPullTimer = nil

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
        lastAutoCompileInputFingerprint = ""
        showsSyntaxColorEditor = false
        showsShortcutCommandEditor = false
        showsTemplateManager = false
        showsNewFileSheet = false
        showsAddStyleSheet = false
        pendingNewFileDirectory = ""
        resetGitState()
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
        debugLastCompileRequestedAt = Date()
        if isCompiling {
            switch trigger {
            case .manual:
                queuedCompileTrigger = .manual
            case .automatic:
                if queuedCompileTrigger == nil {
                    queuedCompileTrigger = .automatic
                }
            }
            return
        }
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

        suppressAutoCompile(for: 1.5)
        lastAutoCompileInputFingerprint = currentTexInputFingerprint()

        isCompiling = true
        debugLastCompileStartedAt = Date()
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
            defer {
                Task { @MainActor in
                    self.isCompiling = false
                    self.suppressAutoCompile(for: 0.9)
                    if self.pendingProjectRefreshAfterCompile {
                        self.pendingProjectRefreshAfterCompile = false
                        self.refreshProjectFilesAndSelections()
                    }
                    if let queuedTrigger = self.queuedCompileTrigger {
                        self.queuedCompileTrigger = nil
                        self.compileNow(trigger: queuedTrigger)
                    }
                }
            }

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
                    self.debugLastCompileFinishedAt = result.finishedAt

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
                    self.debugLastCompileFinishedAt = Date()
                    self.bannerMessage = "Compile failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func userChangedMainFile(_ value: String) {
        selectedMainTex = value
        selectedEditorTex = value
        documentState.mainFileRelativePath = value
        updatePreviewFromExistingPDFIfAvailable()
        refreshCompilePreflightError()
    }

    func userSelectedEditorFile(_ value: String) {
        selectedEditorTex = value
        if texFiles.contains(value), selectedMainTex != value {
            selectedMainTex = value
            documentState.mainFileRelativePath = value
            updatePreviewFromExistingPDFIfAvailable()
            refreshCompilePreflightError()
        }
    }

    func openFileNode(_ node: ProjectFileNode) {
        if node.isDirectory {
            guard let directoryURL = urlForRelativePath(node.relativePath) else { return }
            openProject(url: directoryURL)
            return
        }
        if node.isTexFile {
            userSelectedEditorFile(node.relativePath)
            return
        }
        guard let fileURL = urlForRelativePath(node.relativePath) else { return }
        NSWorkspace.shared.open(fileURL)
    }

    func openParentProject(of node: ProjectFileNode) {
        guard let targetURL = urlForRelativePath(node.relativePath) else { return }
        let currentDirectoryURL: URL
        if node.isDirectory {
            currentDirectoryURL = targetURL
        } else {
            currentDirectoryURL = targetURL.deletingLastPathComponent()
        }
        let parentURL = currentDirectoryURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentURL.path) else { return }
        openProject(url: parentURL)
    }

    func canOpenParentProject(of node: ProjectFileNode) -> Bool {
        guard let targetURL = urlForRelativePath(node.relativePath) else { return false }
        let currentDirectoryURL = node.isDirectory ? targetURL : targetURL.deletingLastPathComponent()
        let parentURL = currentDirectoryURL.deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: parentURL.path)
    }

    func revealFileNodeInFinder(_ node: ProjectFileNode) {
        guard let fileURL = urlForRelativePath(node.relativePath) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func copyFileNodePath(_ node: ProjectFileNode) {
        guard let fileURL = urlForRelativePath(node.relativePath) else { return }
        writeStringsToPasteboard([fileURL.path])
        bannerMessage = "Copied path for \(node.displayName)"
    }

    func copySelectedEditorFilePath() {
        guard let fileURL = selectedEditorFileURL else { return }
        writeStringsToPasteboard([fileURL.path])
        bannerMessage = "Copied path for \(fileURL.lastPathComponent)"
    }

    func copyFileNode(_ node: ProjectFileNode) {
        guard let fileURL = urlForRelativePath(node.relativePath) else { return }
        projectClipboardItem = ProjectFileClipboardItem(relativePath: node.relativePath, mode: .copy)
        writeURLsToPasteboard([fileURL])
        bannerMessage = "Copied \(node.displayName)"
    }

    func cutFileNode(_ node: ProjectFileNode) {
        guard let fileURL = urlForRelativePath(node.relativePath) else { return }
        projectClipboardItem = ProjectFileClipboardItem(relativePath: node.relativePath, mode: .cut)
        writeURLsToPasteboard([fileURL])
        bannerMessage = "Cut \(node.displayName)"
    }

    func canPasteIntoDirectory(_ relativeDirectoryPath: String) -> Bool {
        guard let projectRoot else { return false }
        guard let item = projectClipboardItem else { return false }
        guard let sourceURL = urlForRelativePath(item.relativePath) else { return false }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return false }
        guard let destinationDirectoryURL = directoryURL(forRelativePath: relativeDirectoryPath) else { return false }
        guard destinationDirectoryURL.path.hasPrefix(projectRoot.path) else { return false }

        if item.mode == .cut {
            if let sourceIsDirectory = try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               sourceIsDirectory == true
            {
                let normalizedSource = sourceURL.standardizedFileURL.path
                let normalizedDestination = destinationDirectoryURL.standardizedFileURL.path
                if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
                    return false
                }
            }
        }

        return true
    }

    func pasteIntoDirectory(_ relativeDirectoryPath: String) {
        guard canPasteIntoDirectory(relativeDirectoryPath) else { return }
        guard let item = projectClipboardItem else { return }
        guard let sourceURL = urlForRelativePath(item.relativePath) else { return }
        guard let destinationDirectoryURL = directoryURL(forRelativePath: relativeDirectoryPath) else { return }

        let fm = FileManager.default
        let destinationURL = uniqueDestinationURL(
            in: destinationDirectoryURL,
            preferredName: sourceURL.lastPathComponent
        )

        do {
            switch item.mode {
            case .copy:
                try fm.copyItem(at: sourceURL, to: destinationURL)
                bannerMessage = "Pasted \(destinationURL.lastPathComponent)"
            case .cut:
                try fm.moveItem(at: sourceURL, to: destinationURL)
                remapPaths(afterMovingFrom: item.relativePath, to: relativePath(for: destinationURL))
                projectClipboardItem = nil
                bannerMessage = "Moved to \(destinationURL.lastPathComponent)"
            }
            refreshProjectFilesAndSelections()
        } catch {
            bannerMessage = "Paste failed: \(error.localizedDescription)"
        }
    }

    func promptRenameFileNode(_ node: ProjectFileNode) {
        let alert = NSAlert()
        alert.messageText = "Rename \"\(node.displayName)\""
        alert.informativeText = "Enter a new name."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = node.displayName
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let proposedName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        renameFileNode(node, to: proposedName)
    }

    func duplicateFileNode(_ node: ProjectFileNode) {
        guard let sourceURL = urlForRelativePath(node.relativePath) else { return }
        let destinationDirectoryURL = sourceURL.deletingLastPathComponent()
        let destinationURL = uniqueDestinationURL(
            in: destinationDirectoryURL,
            preferredName: sourceURL.lastPathComponent
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            refreshProjectFilesAndSelections()
            bannerMessage = "Duplicated \(node.displayName)"
        } catch {
            bannerMessage = "Duplicate failed: \(error.localizedDescription)"
        }
    }

    func confirmDeleteFileNode(_ node: ProjectFileNode) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete \"\(node.displayName)\"?"
        alert.informativeText = "This moves the item to Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        deleteFileNode(node)
    }

    func promptCreateFolder(in relativeDirectoryPath: String) {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter a folder name."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "New Folder"
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        createFolder(named: field.stringValue, in: relativeDirectoryPath)
    }

    func promptCreateFile(in relativeDirectoryPath: String) {
        pendingNewFileDirectory = relativeDirectoryPath
        refreshTemplateLibrary(createDefaults: true)
        showsTemplateManager = false
        showsAddStyleSheet = false
        showsNewFileSheet = true
    }

    func saveEditorToDisk() {
        guard let target = selectedEditorFileURL else { return }

        do {
            try editorText.write(to: target, atomically: false, encoding: .utf8)
            hasUnsavedEditorChanges = false
            debugLastSaveAt = Date()
            suppressAutoCompile(for: 0.8)
            bannerMessage = "Saved \(selectedEditorTex)"
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

    func performSaveShortcut() {
        if autoCompileEnabled {
            saveAndRecompile()
        } else {
            saveEditorToDisk()
        }
    }

    func notePDFDisplayed(at date: Date) {
        debugLastPDFDisplayedAt = date
    }

    func handlePDFInverseSearch(_ target: PDFInverseSearchTarget) {
        guard let projectRoot, let pdfURL = documentState.pdfURL else { return }
        guard isCompiling == false else { return }

        if hasSyncTeXMap(for: pdfURL) == false {
            bannerMessage = "Generating SyncTeX map… click PDF again in a moment."
            compileNow(trigger: .manual)
            return
        }

        Task {
            let lookupResult = await resolveSyncTeXLookup(
                target: target,
                pdfURL: pdfURL,
                projectRoot: projectRoot
            )
            guard let lookupResult else { return }

            await MainActor.run {
                let relativePath = resolveRelativePath(for: lookupResult.inputPath, projectRoot: projectRoot)
                guard let relativePath else { return }

                if selectedEditorTex != relativePath {
                    selectedEditorTex = relativePath
                }
                editorLineJumpRequest = EditorLineJumpRequest(id: UUID(), line: max(1, lookupResult.line))
            }
        }
    }

    func clearEditorLineJumpRequest(_ id: UUID) {
        guard editorLineJumpRequest?.id == id else { return }
        editorLineJumpRequest = nil
    }

    private func hasSyncTeXMap(for pdfURL: URL) -> Bool {
        let base = pdfURL.deletingPathExtension()
        let compressed = base.appendingPathExtension("synctex.gz")
        let plain = base.appendingPathExtension("synctex")
        let fm = FileManager.default
        return fm.fileExists(atPath: compressed.path) || fm.fileExists(atPath: plain.path)
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
        bannerDismissWorkItem?.cancel()
        bannerDismissWorkItem = nil
        bannerMessage = nil
    }

    func adjustInterfaceTransparency(by amount: Double) {
        interfaceTransparency += amount
    }

    func setInterfaceTransparencyPreset(_ amount: Double) {
        interfaceTransparency = amount
    }

    func presentSyntaxColorEditor() {
        showsShortcutCommandEditor = false
        showsSyntaxColorEditor = true
    }

    func presentShortcutCommandEditor() {
        showsSyntaxColorEditor = false
        showsShortcutCommandEditor = true
    }

    func presentTemplateManager() {
        refreshTemplateLibrary(createDefaults: true)
        showsNewFileSheet = false
        showsAddStyleSheet = false
        showsTemplateManager = true
    }

    func dismissTemplateManager() {
        showsTemplateManager = false
    }

    func presentAddStyleSheet() {
        guard projectRoot != nil else {
            bannerMessage = "Open a project before adding a style."
            return
        }
        refreshTemplateLibrary(createDefaults: true)
        showsTemplateManager = false
        showsNewFileSheet = false
        showsAddStyleSheet = true
    }

    func dismissAddStyleSheet() {
        showsAddStyleSheet = false
    }

    func dismissNewFileSheet() {
        showsNewFileSheet = false
    }

    func templates(for kind: TemplateKind) -> [TemplateEntry] {
        switch kind {
        case .document:
            return documentTemplates
        case .style:
            return styleTemplates
        }
    }

    func templatePreviewText(for template: TemplateEntry?) -> String {
        guard let template else {
            return "Select a template to preview."
        }
        guard let raw = try? String(contentsOf: template.fileURL, encoding: .utf8) else {
            return "Unable to load preview for \(template.fileName)."
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "(empty template)"
        }
        let limit = 22_000
        if text.count <= limit {
            return text
        }
        return String(text.prefix(limit)) + "\n\n... preview truncated ..."
    }

    func promptSelectTemplateFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            userDefaults.set(selectedURL.path, forKey: templateFolderPreferenceKey)
            refreshTemplateLibrary(createDefaults: true)
            bannerMessage = "Template folder set to \(selectedURL.lastPathComponent)."
        }
    }

    func useDefaultTemplateFolder() {
        userDefaults.removeObject(forKey: templateFolderPreferenceKey)
        refreshTemplateLibrary(createDefaults: true)
        bannerMessage = "Using default template folder."
    }

    func revealTemplateFolderInFinder() {
        guard let templateFolderURL else {
            bannerMessage = "Template folder unavailable."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([templateFolderURL])
    }

    func refreshTemplateLibrary() {
        refreshTemplateLibrary(createDefaults: true)
    }

    func importTemplates(of kind: TemplateKind) {
        guard let destinationFolder = templateDirectoryURL(for: kind, createIfNeeded: true) else {
            bannerMessage = "Unable to access template folder."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "tex")].compactMap { $0 }
        panel.prompt = "Import"

        guard panel.runModal() == .OK else { return }

        var importedCount = 0
        for sourceURL in panel.urls {
            let destinationURL = uniqueDestinationURL(in: destinationFolder, preferredName: sourceURL.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                importedCount += 1
            } catch {
                bannerMessage = "Import failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)"
            }
        }

        refreshTemplateLibrary(createDefaults: false)
        if importedCount > 0 {
            bannerMessage = "Imported \(importedCount) template file(s)."
        }
    }

    func promptCreateEmptyTemplate(of kind: TemplateKind) {
        let alert = NSAlert()
        alert.messageText = kind == .document ? "New Document Template" : "New Style Template"
        alert.informativeText = "Enter a template file name."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = kind.defaultFileName
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let proposedName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        createEmptyTemplate(named: proposedName, kind: kind)
    }

    func addStyleTemplateToCurrentProject(_ template: TemplateEntry) {
        guard let projectRoot else {
            bannerMessage = "Open a project before adding a style."
            return
        }

        do {
            let copiedStyleURL = try copyTemplateFile(template, to: projectRoot)
            refreshProjectFilesAndSelections()
            showsAddStyleSheet = false
            bannerMessage = "Added style \(copiedStyleURL.lastPathComponent) to this project."
        } catch {
            bannerMessage = "Add style failed: \(error.localizedDescription)"
        }
    }

    func createFileFromSheet(
        named proposedName: String,
        in relativeDirectoryPath: String,
        documentTemplate: TemplateEntry?,
        styleTemplate: TemplateEntry?
    ) {
        let created = createFile(
            named: proposedName,
            in: relativeDirectoryPath,
            documentTemplate: documentTemplate,
            styleTemplate: styleTemplate
        )
        if created {
            showsNewFileSheet = false
        }
    }

    func updateTemplateDisplayName(_ template: TemplateEntry, to proposedName: String) {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = template.fileURL.deletingPathExtension().lastPathComponent

        var displayNames = loadTemplateDisplayNameMap()
        if trimmed.isEmpty || trimmed == defaultName {
            displayNames.removeValue(forKey: template.id)
        } else {
            displayNames[template.id] = trimmed
        }
        saveTemplateDisplayNameMap(displayNames)
        refreshTemplateLibrary(createDefaults: false)
        bannerMessage = "Updated template name."
    }

    func resetTemplateDisplayName(_ template: TemplateEntry) {
        var displayNames = loadTemplateDisplayNameMap()
        displayNames.removeValue(forKey: template.id)
        saveTemplateDisplayNameMap(displayNames)
        refreshTemplateLibrary(createDefaults: false)
        bannerMessage = "Template name reset to file name."
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
        guard isApplyingLoadedSettings == false else { return }
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
            editorSyntaxColoringEnabled: editorSyntaxColoringEnabled,
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

    private func applyLoadedSettings(_ settings: UserSettings) {
        isApplyingLoadedSettings = true
        defer { isApplyingLoadedSettings = false }

        selectedEngine = settings.latexEngine
        autoCompileEnabled = settings.autoCompileEnabled
        interfaceTheme = settings.interfaceTheme
        interfaceMode = settings.interfaceMode
        interfaceTransparency = settings.interfaceTransparency
        editorPreviewLayout = settings.editorPreviewLayout
        editorAutoCorrectEnabled = settings.editorAutoCorrectEnabled
        editorSyntaxColoringEnabled = settings.editorSyntaxColoringEnabled
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
    }

    private func configureWatcher() {
        watcher?.stop()
        watcher = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        projectRefreshWorkItem?.cancel()
        projectRefreshWorkItem = nil

        guard autoCompileEnabled, let projectRoot else { return }

        watcher = DirectoryWatcher(url: projectRoot) { [weak self] in
            Task { @MainActor in
                self?.scheduleProjectRefresh()
                self?.scheduleAutoCompile()
            }
        }
        watcher?.start()
    }

    private func scheduleProjectRefresh() {
        projectRefreshWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.autoCompileEnabled, self.projectRoot != nil else { return }
                guard self.isCompiling == false else {
                    self.pendingProjectRefreshAfterCompile = true
                    return
                }
                self.refreshProjectFilesAndSelections()
            }
        }

        projectRefreshWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + EnergyTuning.fileSystemRefreshDebounce,
            execute: work
        )
    }

    private func scheduleAutoCompile() {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.autoCompileEnabled else { return }
                guard Date() >= self.autoCompileSuppressedUntil else { return }
                let currentFingerprint = self.currentTexInputFingerprint()
                guard currentFingerprint != self.lastAutoCompileInputFingerprint else { return }
                self.lastAutoCompileInputFingerprint = currentFingerprint
                self.compileNow(trigger: .automatic)
            }
        }

        debounceWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + EnergyTuning.autoCompileDebounce,
            execute: work
        )
    }

    private func suppressAutoCompile(for seconds: TimeInterval) {
        let until = Date().addingTimeInterval(seconds)
        if until > autoCompileSuppressedUntil {
            autoCompileSuppressedUntil = until
        }
    }

    private func currentTexInputFingerprint() -> String {
        guard let projectRoot else { return "" }
        var parts: [String] = []
        parts.reserveCapacity(max(8, texFiles.count))

        for relativePath in texFiles {
            let fileURL = projectRoot.appending(path: relativePath)
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? -1
            let size = values?.fileSize ?? -1
            parts.append("\(relativePath)|\(modified)|\(size)")
        }

        return parts.joined(separator: "\n")
    }

    private func updatePreviewFromExistingPDFIfAvailable() {
        guard let projectRoot, selectedMainTex.isEmpty == false else {
            documentState.pdfURL = nil
            documentState.lastCompileAt = nil
            return
        }

        let pdfURL = projectRoot
            .appending(path: selectedMainTex)
            .deletingPathExtension()
            .appendingPathExtension("pdf")

        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            documentState.pdfURL = nil
            documentState.lastCompileAt = nil
            return
        }

        let values = try? pdfURL.resourceValues(forKeys: [.contentModificationDateKey])
        documentState.pdfURL = pdfURL
        if let modificationDate = values?.contentModificationDate {
            documentState.lastCompileAt = modificationDate
        } else if documentState.lastCompileAt == nil {
            documentState.lastCompileAt = Date()
        }
    }

    private func configureGitAutoPullTimer() {
        gitAutoPullTimer?.invalidate()
        gitAutoPullTimer = nil

        guard gitAutoPullEnabled, canUseGitTools else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: EnergyTuning.gitAutoPullInterval, repeats: true) { [weak self] _ in
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
        timer.tolerance = EnergyTuning.gitAutoPullTolerance
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

    private func renameFileNode(_ node: ProjectFileNode, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            bannerMessage = "Rename cancelled: name cannot be empty."
            return
        }
        guard name.contains("/") == false else {
            bannerMessage = "Rename failed: names cannot contain '/'."
            return
        }
        guard let sourceURL = urlForRelativePath(node.relativePath) else { return }

        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(name, isDirectory: node.isDirectory)
        guard destinationURL.path != sourceURL.path else { return }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            bannerMessage = "Rename failed: \(name) already exists."
            return
        }

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            remapPaths(afterMovingFrom: node.relativePath, to: relativePath(for: destinationURL))
            refreshProjectFilesAndSelections()
            bannerMessage = "Renamed to \(name)"
        } catch {
            bannerMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    private func deleteFileNode(_ node: ProjectFileNode) {
        guard let sourceURL = urlForRelativePath(node.relativePath) else { return }
        do {
            var trashURL: NSURL?
            try FileManager.default.trashItem(at: sourceURL, resultingItemURL: &trashURL)
            clearSelectionsIfInside(node.relativePath)
            if let clipboard = projectClipboardItem, pathIsEqualOrChild(clipboard.relativePath, prefix: node.relativePath) {
                projectClipboardItem = nil
            }
            refreshProjectFilesAndSelections()
            bannerMessage = "Deleted \(node.displayName)"
        } catch {
            bannerMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    private func createFolder(named proposedName: String, in relativeDirectoryPath: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            bannerMessage = "Create folder cancelled: name cannot be empty."
            return
        }
        guard name.contains("/") == false else {
            bannerMessage = "Create folder failed: names cannot contain '/'."
            return
        }
        guard let directoryURL = directoryURL(forRelativePath: relativeDirectoryPath) else { return }
        let destinationURL = directoryURL.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: destinationURL.path) == false else {
            bannerMessage = "Create folder failed: \(name) already exists."
            return
        }

        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)
            refreshProjectFilesAndSelections()
            bannerMessage = "Created folder \(name)"
        } catch {
            bannerMessage = "Create folder failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func createFile(
        named proposedName: String,
        in relativeDirectoryPath: String,
        documentTemplate: TemplateEntry? = nil,
        styleTemplate: TemplateEntry? = nil
    ) -> Bool {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            bannerMessage = "Create file cancelled: name cannot be empty."
            return false
        }
        guard name.contains("/") == false else {
            bannerMessage = "Create file failed: names cannot contain '/'."
            return false
        }
        guard let directoryURL = directoryURL(forRelativePath: relativeDirectoryPath) else { return false }
        let destinationURL = directoryURL.appendingPathComponent(name, isDirectory: false)
        guard FileManager.default.fileExists(atPath: destinationURL.path) == false else {
            bannerMessage = "Create file failed: \(name) already exists."
            return false
        }
        do {
            let initialContent = try buildInitialContent(
                forFileName: name,
                destinationDirectoryURL: directoryURL,
                documentTemplate: documentTemplate,
                styleTemplate: styleTemplate
            )
            try initialContent.write(to: destinationURL, atomically: true, encoding: .utf8)
            refreshProjectFilesAndSelections()
            let createdRelativePath = relativePath(for: destinationURL)
            if createdRelativePath.lowercased().hasSuffix(".tex") {
                selectedEditorTex = createdRelativePath
            }
            bannerMessage = "Created file \(name)"
            return true
        } catch {
            bannerMessage = "Create file failed: \(error.localizedDescription)"
            return false
        }
    }

    private func refreshProjectFilesAndSelections() {
        guard let projectRoot else { return }
        applyProjectScan(ProjectScanner.scan(projectRoot: projectRoot))

        if selectedMainTex.isEmpty == false, texFiles.contains(selectedMainTex) == false {
            selectedMainTex = preferredMainTexFile(from: texFiles) ?? ""
        }

        if selectedEditorTex.isEmpty == false, fileExists(forRelativePath: selectedEditorTex) == false {
            selectedEditorTex = selectedMainTex
        }
        if selectedEditorTex.isEmpty, selectedMainTex.isEmpty == false {
            selectedEditorTex = selectedMainTex
        }

        documentState.mainFileRelativePath = selectedMainTex
        updatePreviewFromExistingPDFIfAvailable()
        refreshCompilePreflightError()
    }

    private func applyProjectScan(_ snapshot: ProjectScanner.Snapshot) {
        texFiles = snapshot.texFiles
        projectFileTree = snapshot.fileTree
    }

    private func remapPaths(afterMovingFrom sourceRelativePath: String, to destinationRelativePath: String) {
        selectedMainTex = remapRelativePath(selectedMainTex, from: sourceRelativePath, to: destinationRelativePath)
        selectedEditorTex = remapRelativePath(selectedEditorTex, from: sourceRelativePath, to: destinationRelativePath)
        if let currentMainFile = documentState.mainFileRelativePath {
            documentState.mainFileRelativePath = remapRelativePath(
                currentMainFile,
                from: sourceRelativePath,
                to: destinationRelativePath
            )
        }

        if let clipboard = projectClipboardItem {
            let updatedClipboardPath = remapRelativePath(
                clipboard.relativePath,
                from: sourceRelativePath,
                to: destinationRelativePath
            )
            projectClipboardItem = ProjectFileClipboardItem(relativePath: updatedClipboardPath, mode: clipboard.mode)
        }
    }

    private func clearSelectionsIfInside(_ deletedRelativePath: String) {
        if pathIsEqualOrChild(selectedMainTex, prefix: deletedRelativePath) {
            selectedMainTex = ""
        }
        if pathIsEqualOrChild(selectedEditorTex, prefix: deletedRelativePath) {
            selectedEditorTex = ""
        }
        if let currentMainFile = documentState.mainFileRelativePath,
           pathIsEqualOrChild(currentMainFile, prefix: deletedRelativePath)
        {
            documentState.mainFileRelativePath = nil
        }
        if let pdfURL = documentState.pdfURL, pathIsEqualOrChild(relativePath(for: pdfURL), prefix: deletedRelativePath) {
            documentState.pdfURL = nil
        }
    }

    private func remapRelativePath(_ value: String, from sourcePrefix: String, to destinationPrefix: String) -> String {
        guard value.isEmpty == false else { return value }
        if value == sourcePrefix {
            return destinationPrefix
        }
        let prefix = sourcePrefix + "/"
        guard value.hasPrefix(prefix) else { return value }
        let suffix = value.dropFirst(prefix.count)
        return destinationPrefix + "/" + suffix
    }

    private func pathIsEqualOrChild(_ value: String, prefix: String) -> Bool {
        value == prefix || value.hasPrefix(prefix + "/")
    }

    private func fileExists(forRelativePath relativePath: String) -> Bool {
        guard let url = urlForRelativePath(relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func urlForRelativePath(_ relativePath: String) -> URL? {
        guard let projectRoot else { return nil }
        if relativePath.isEmpty {
            return projectRoot
        }
        return projectRoot.appending(path: relativePath)
    }

    private func directoryURL(forRelativePath relativePath: String) -> URL? {
        guard let candidate = urlForRelativePath(relativePath) else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return candidate
    }

    private func relativePath(for url: URL) -> String {
        guard let projectRoot else { return url.lastPathComponent }
        let rootPath = projectRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == rootPath {
            return ""
        }
        if path.hasPrefix(rootPath + "/") {
            let index = path.index(path.startIndex, offsetBy: rootPath.count + 1)
            return String(path[index...])
        }
        return url.lastPathComponent
    }

    private func uniqueDestinationURL(in directory: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        let preferredURL = directory.appendingPathComponent(preferredName)
        if fm.fileExists(atPath: preferredURL.path) == false {
            return preferredURL
        }

        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var index = 2
        while index < 10_000 {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(base) copy \(index - 1)"
            } else {
                candidateName = "\(base) copy \(index - 1).\(ext)"
            }
            let candidateURL = directory.appendingPathComponent(candidateName)
            if fm.fileExists(atPath: candidateURL.path) == false {
                return candidateURL
            }
            index += 1
        }
        return directory.appendingPathComponent(UUID().uuidString + "-" + preferredName)
    }

    private func refreshTemplateLibrary(createDefaults: Bool) {
        guard let templateRoot = templateRootURL(createIfNeeded: true) else {
            templateFolderURL = nil
            documentTemplates = []
            styleTemplates = []
            return
        }

        templateFolderURL = templateRoot
        guard
            let documentDirectory = templateDirectoryURL(for: .document, createIfNeeded: true),
            let styleDirectory = templateDirectoryURL(for: .style, createIfNeeded: true)
        else {
            documentTemplates = []
            styleTemplates = []
            return
        }

        if createDefaults {
            seedDefaultTemplates(documentDirectory: documentDirectory, styleDirectory: styleDirectory)
        }

        documentTemplates = scanTemplates(in: documentDirectory, kind: .document)
        styleTemplates = scanTemplates(in: styleDirectory, kind: .style)
    }

    private func templateRootURL(createIfNeeded: Bool) -> URL? {
        let customPath = userDefaults.string(forKey: templateFolderPreferenceKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rootURL: URL
        if let customPath, customPath.isEmpty == false {
            rootURL = URL(fileURLWithPath: customPath, isDirectory: true)
        } else {
            rootURL = defaultTemplateRootURL()
        }

        if createIfNeeded {
            do {
                try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            } catch {
                bannerMessage = "Template folder setup failed: \(error.localizedDescription)"
                return nil
            }
        }
        return rootURL.standardizedFileURL
    }

    private func templateDirectoryURL(for kind: TemplateKind, createIfNeeded: Bool) -> URL? {
        guard let root = templateRootURL(createIfNeeded: createIfNeeded) else { return nil }
        let folderURL = root.appendingPathComponent(kind.folderName, isDirectory: true)
        if createIfNeeded {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                bannerMessage = "Template directory setup failed: \(error.localizedDescription)"
                return nil
            }
        }
        return folderURL.standardizedFileURL
    }

    private func defaultTemplateRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("raagtex", isDirectory: true)
            .appendingPathComponent("Templates", isDirectory: true)
    }

    private func seedDefaultTemplates(documentDirectory: URL, styleDirectory: URL) {
        let defaultDocumentURL = documentDirectory.appendingPathComponent("main.tex")
        let defaultStyleURL = styleDirectory.appendingPathComponent("note_style.tex")

        if FileManager.default.fileExists(atPath: defaultDocumentURL.path) == false {
            try? defaultDocumentTemplateText.write(to: defaultDocumentURL, atomically: true, encoding: .utf8)
        }
        if FileManager.default.fileExists(atPath: defaultStyleURL.path) == false {
            try? defaultStyleTemplateText.write(to: defaultStyleURL, atomically: true, encoding: .utf8)
        }
    }

    private func scanTemplates(in directory: URL, kind: TemplateKind) -> [TemplateEntry] {
        let displayNames = loadTemplateDisplayNameMap()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [TemplateEntry] = []
        for case let candidateURL as URL in enumerator {
            guard candidateURL.pathExtension.lowercased() == "tex" else { continue }
            let values = try? candidateURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            results.append(
                TemplateEntry(
                    kind: kind,
                    fileURL: candidateURL,
                    lastModifiedAt: values?.contentModificationDate,
                    customDisplayName: displayNames[candidateURL.standardizedFileURL.path]
                )
            )
        }

        return results.sorted { lhs, rhs in
            lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
    }

    private func createEmptyTemplate(named proposedName: String, kind: TemplateKind) {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            bannerMessage = "Template file name cannot be empty."
            return
        }

        let fileName = trimmed.lowercased().hasSuffix(".tex") ? trimmed : trimmed + ".tex"
        guard fileName.contains("/") == false else {
            bannerMessage = "Template file names cannot contain '/'."
            return
        }

        guard let folderURL = templateDirectoryURL(for: kind, createIfNeeded: true) else { return }
        let destinationURL = folderURL.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: destinationURL.path) == false else {
            bannerMessage = "\(fileName) already exists."
            return
        }

        let seedText = kind == .document ? defaultDocumentTemplateText : defaultStyleTemplateText
        do {
            try seedText.write(to: destinationURL, atomically: true, encoding: .utf8)
            refreshTemplateLibrary(createDefaults: false)
            bannerMessage = "Created template \(fileName)."
        } catch {
            bannerMessage = "Template creation failed: \(error.localizedDescription)"
        }
    }

    private func copyTemplateFile(_ template: TemplateEntry, to directoryURL: URL) throws -> URL {
        let destinationURL = uniqueDestinationURL(in: directoryURL, preferredName: template.fileName)
        try FileManager.default.copyItem(at: template.fileURL, to: destinationURL)
        return destinationURL
    }

    private func buildInitialContent(
        forFileName fileName: String,
        destinationDirectoryURL: URL,
        documentTemplate: TemplateEntry?,
        styleTemplate: TemplateEntry?
    ) throws -> String {
        let isTexFile = fileName.lowercased().hasSuffix(".tex")
        var styleFileName: String?
        if let styleTemplate {
            let copiedStyleURL = try copyTemplateFile(styleTemplate, to: destinationDirectoryURL)
            styleFileName = copiedStyleURL.lastPathComponent
        }

        var content: String
        if let documentTemplate {
            content = (try? String(contentsOf: documentTemplate.fileURL, encoding: .utf8)) ?? ""
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = isTexFile ? "% \(fileName)\n" : ""
            }
        } else if isTexFile {
            content = "% \(fileName)\n"
        } else {
            content = ""
        }

        if let styleFileName, isTexFile {
            content = applyStyleReference(styleFileName: styleFileName, to: content, createDocumentShellIfNeeded: documentTemplate == nil)
        }

        return content
    }

    private func applyStyleReference(
        styleFileName: String,
        to source: String,
        createDocumentShellIfNeeded: Bool
    ) -> String {
        let styleInclude = "\\IfFileExists{\(styleFileName)}{\\input{\(styleFileName)}}{}"

        if source.contains("\\input{note_style.tex}") {
            return source.replacingOccurrences(of: "\\input{note_style.tex}", with: styleInclude)
        }

        if let beginDocumentRange = source.range(of: "\\begin{document}") {
            var updated = source
            updated.insert(contentsOf: styleInclude + "\n\n", at: beginDocumentRange.lowerBound)
            return updated
        }

        if createDocumentShellIfNeeded {
            return """
            \\documentclass[11pt]{article}

            \(styleInclude)

            \\begin{document}

            \\end{document}
            """
        }

        if source.isEmpty {
            return styleInclude + "\n"
        }
        return source + "\n\n" + styleInclude + "\n"
    }

    private func loadTemplateDisplayNameMap() -> [String: String] {
        guard let dictionary = userDefaults.dictionary(forKey: templateDisplayNamePreferenceKey) else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            guard let name = value as? String else { continue }
            result[key] = name
        }
        return result
    }

    private func saveTemplateDisplayNameMap(_ map: [String: String]) {
        userDefaults.set(map, forKey: templateDisplayNamePreferenceKey)
    }

    private func writeStringsToPasteboard(_ values: [String]) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects(values as [NSString])
    }

    private func scheduleBannerAutoDismiss() {
        bannerDismissWorkItem?.cancel()
        bannerDismissWorkItem = nil

        guard let currentMessage = bannerMessage else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.bannerMessage == currentMessage else { return }
            self.bannerMessage = nil
        }
        bannerDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + EnergyTuning.bannerDisplayDuration, execute: work)
    }

    private func writeURLsToPasteboard(_ values: [URL]) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects(values as [NSURL])
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
        theme.isClearVariant ? 0.0 : 0.25
    }

    private func resolveSyncTeXLookup(
        target: PDFInverseSearchTarget,
        pdfURL: URL,
        projectRoot: URL
    ) async -> SyncTeXLookupResult? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.lookupSyncTeXSource(target: target, pdfURL: pdfURL, projectRoot: projectRoot)
                continuation.resume(returning: result)
            }
        }
    }

    private func resolveRelativePath(for sourcePath: String, projectRoot: URL) -> String? {
        let trimmedPath = sourcePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard trimmedPath.isEmpty == false else { return nil }

        let sourceURL: URL
        if trimmedPath.hasPrefix("/") {
            sourceURL = URL(fileURLWithPath: trimmedPath).standardizedFileURL
        } else {
            sourceURL = projectRoot.appending(path: trimmedPath).standardizedFileURL
        }
        let rootURL = projectRoot.standardizedFileURL
        let rootPath = rootURL.path
        let sourceStandardPath = sourceURL.path

        if sourceStandardPath == rootPath {
            return sourceURL.lastPathComponent
        }
        if sourceStandardPath.hasPrefix(rootPath + "/") {
            let startIndex = sourceStandardPath.index(sourceStandardPath.startIndex, offsetBy: rootPath.count + 1)
            return String(sourceStandardPath[startIndex...])
        }

        let fileName = sourceURL.lastPathComponent
        let matches = texFiles.filter { URL(fileURLWithPath: $0).lastPathComponent == fileName }
        if matches.count == 1 {
            return matches[0]
        }
        return nil
    }

    nonisolated private static func lookupSyncTeXSource(
        target: PDFInverseSearchTarget,
        pdfURL: URL,
        projectRoot: URL
    ) -> SyncTeXLookupResult? {
        let page = target.pageIndex + 1
        let x = Int(target.pagePoint.x.rounded())
        let yBottom = Int(target.pagePoint.y.rounded())
        let yTop = Int((target.pageBounds.height - target.pagePoint.y).rounded())
        let scale = 65_536.0 / 72.0
        let scaledX = Int((target.pagePoint.x * scale).rounded())
        let scaledYBottom = Int((target.pagePoint.y * scale).rounded())
        let scaledYTop = Int(((target.pageBounds.height - target.pagePoint.y) * scale).rounded())

        let coordinateCandidates: [(Int, Int)] = [
            (x, yTop),
            (x, yBottom),
            (scaledX, scaledYTop),
            (scaledX, scaledYBottom)
        ]

        for (candidateX, candidateY) in coordinateCandidates {
            let spec = "\(page):\(max(0, candidateX)):\(max(0, candidateY)):\(pdfURL.path)"
            guard let output = runSyncTeXEdit(specification: spec, currentDirectory: projectRoot) else {
                continue
            }
            if let parsed = parseSyncTeXEditOutput(output) {
                return parsed
            }
        }

        return nil
    }

    nonisolated private static func runSyncTeXEdit(specification: String, currentDirectory: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["synctex", "edit", "-o", specification]
        process.currentDirectoryURL = currentDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard data.isEmpty == false else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func parseSyncTeXEditOutput(_ output: String) -> SyncTeXLookupResult? {
        let lines = output.split(whereSeparator: \.isNewline)
        var pendingInputPath: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("Input:") {
                let value = line.dropFirst("Input:".count).trimmingCharacters(in: .whitespaces)
                if value.isEmpty == false {
                    pendingInputPath = value
                }
            } else if line.hasPrefix("Line:") {
                let value = line.dropFirst("Line:".count).trimmingCharacters(in: .whitespaces)
                if let parsed = Int(value), let pendingInputPath {
                    return SyncTeXLookupResult(inputPath: pendingInputPath, line: parsed)
                }
            }
        }

        return nil
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

    private var defaultDocumentTemplateText: String {
        """
        \\documentclass[11pt]{article}

        % Optional theme toggle expected by note_style.tex
        \\newif\\ifdarkmode
        \\darkmodetrue
        %\\darkmodefalse

        \\IfFileExists{note_style.tex}{\\input{note_style.tex}}{}

        \\subject{Course Name}
        \\notetitle{Title Here}
        \\notedate{\\today}
        \\tags{tag1, tag2}

        \\begin{document}

        {\\huge\\bfseries \\noteTitle}

        \\vspace{0.5em}
        \\textcolor{line}{\\rule{\\linewidth}{0.8pt}}

        \\topic{Section Title}

        Write your content here.

        \\end{document}
        """
    }

    private var defaultStyleTemplateText: String {
        """
        % Shared style template
        \\usepackage[margin=1in]{geometry}
        \\usepackage[T1]{fontenc}
        \\usepackage[utf8]{inputenc}
        \\usepackage{lmodern}
        \\usepackage{amsmath,amssymb,mathtools,bm}
        \\usepackage{xcolor}
        \\usepackage{hyperref}

        \\makeatletter
        \\@ifundefined{ifdarkmode}{\\newif\\ifdarkmode\\darkmodetrue}{}
        \\makeatother

        \\ifdarkmode
            \\definecolor{textmain}{HTML}{E8E6E3}
            \\definecolor{line}{HTML}{3A3A3A}
        \\else
            \\definecolor{textmain}{HTML}{2D221B}
            \\definecolor{line}{HTML}{D7B89E}
        \\fi

        \\color{textmain}
        \\newcommand{\\subject}[1]{\\def\\subjectName{#1}}
        \\newcommand{\\notetitle}[1]{\\def\\noteTitle{#1}}
        \\newcommand{\\notedate}[1]{\\def\\noteDate{#1}}
        \\newcommand{\\tags}[1]{\\def\\noteTags{#1}}
        \\newcommand{\\topic}[1]{\\section{#1}}
        """
    }
}

enum CompileTrigger {
    case manual
    case automatic
}

struct EditorLineJumpRequest: Equatable {
    let id: UUID
    let line: Int
}

private struct SyncTeXLookupResult {
    let inputPath: String
    let line: Int
}

private struct ProjectFileClipboardItem {
    let relativePath: String
    let mode: Mode

    enum Mode {
        case copy
        case cut
    }
}
