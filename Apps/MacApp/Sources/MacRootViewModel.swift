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

        if let savedMain = settings.mainTexRelativePath, texFiles.contains(savedMain) {
            selectedMainTex = savedMain
        } else {
            selectedMainTex = texFiles.first ?? ""
        }

        documentState.projectRoot = url
        documentState.mainFileRelativePath = selectedMainTex

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

    func clearBanner() {
        bannerMessage = nil
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
            autoCompileEnabled: autoCompileEnabled
        )
        settingsStore.save(settings, projectRootPath: projectRoot.path)
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
}

enum CompileTrigger {
    case manual
    case automatic
}
