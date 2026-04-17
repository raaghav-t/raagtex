import Combine
import Core
import Foundation
import Shared

@MainActor
final class IOSRootViewModel: ObservableObject {
    @Published private(set) var recentProjects: [ProjectReference]
    @Published private(set) var projectRoot: URL?
    @Published private(set) var texFiles: [String] = []
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
    @Published var editorText: String = "" {
        didSet {
            guard isLoadingEditorText == false, oldValue != editorText else { return }
            hasUnsavedEditorChanges = true
        }
    }
    @Published private(set) var hasUnsavedEditorChanges = false
    @Published private(set) var documentState = DocumentState()
    @Published private(set) var isCompiling = false
    @Published var bannerMessage: String?

    private let recentStore: any RecentProjectsStore
    private let settingsStore: any SettingsStore
    private let compileRunner: any CompileRunning

    private var isLoadingEditorText = false
    private var securityScopedProjectURL: URL?

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

    func openProject(url: URL) {
        let normalized = url.standardizedFileURL
        if securityScopedProjectURL?.path != normalized.path {
            securityScopedProjectURL?.stopAccessingSecurityScopedResource()
            _ = normalized.startAccessingSecurityScopedResource()
            securityScopedProjectURL = normalized
        }
        projectRoot = normalized

        let files = IOSProjectScanner.findTexFiles(projectRoot: normalized)
        texFiles = files

        let settings = settingsStore.load(projectRootPath: normalized.path)
        selectedEngine = settings.latexEngine
        if let preferred = settings.mainTexRelativePath, files.contains(preferred) {
            selectedMainTex = preferred
        } else if files.contains("main.tex") {
            selectedMainTex = "main.tex"
        } else {
            selectedMainTex = files.first ?? ""
        }

        selectedEditorTex = selectedMainTex
        hasUnsavedEditorChanges = false
        loadSelectedEditorFileIntoEditor()

        documentState.projectRoot = normalized
        documentState.mainFileRelativePath = selectedMainTex

        pushRecentProject(url: normalized)
        bannerMessage = "Opened \(normalized.lastPathComponent)"
    }

    func openRecent(_ project: ProjectReference) {
        openProject(url: project.rootURL)
    }

    func refreshProjectFiles() {
        guard let root = projectRoot else { return }
        texFiles = IOSProjectScanner.findTexFiles(projectRoot: root)
        if texFiles.contains(selectedMainTex) == false {
            selectedMainTex = texFiles.first ?? ""
        }
        if texFiles.contains(selectedEditorTex) == false {
            selectedEditorTex = selectedMainTex
        }
    }

    func saveEditorIfNeeded() {
        guard hasUnsavedEditorChanges else { return }
        guard let fileURL = selectedEditorFileURL else { return }

        do {
            try editorText.write(to: fileURL, atomically: true, encoding: .utf8)
            hasUnsavedEditorChanges = false
            bannerMessage = "Saved \(selectedEditorTex)"
        } catch {
            bannerMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func revertEditorChanges() {
        loadSelectedEditorFileIntoEditor()
        hasUnsavedEditorChanges = false
    }

    func compileNow() {
        guard let root = projectRoot else {
            bannerMessage = "Open a project first"
            return
        }

        saveEditorIfNeeded()

        guard selectedMainTex.isEmpty == false else {
            bannerMessage = "Pick a main .tex file first"
            return
        }

        let request = CompileRequest(
            projectRoot: root,
            mainFileRelativePath: selectedMainTex,
            engine: selectedEngine,
            autoCompile: false
        )

        isCompiling = true
        documentState.compileStatus = .running
        documentState.mainFileRelativePath = selectedMainTex
        documentState.projectRoot = root

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await compileRunner.compile(request)
                documentState.compileStatus = result.status
                documentState.diagnostics = result.diagnostics
                documentState.rawCompileLog = result.rawLog
                documentState.pdfURL = result.pdfURL
                documentState.lastCompileAt = result.finishedAt
                bannerMessage = result.status == .succeeded
                    ? "Compile succeeded"
                    : "Compile finished with issues"
            } catch {
                documentState.compileStatus = .failed
                documentState.rawCompileLog = error.localizedDescription
                documentState.diagnostics = []
                bannerMessage = "Compile failed: \(error.localizedDescription)"
            }
            isCompiling = false
        }
    }

    func clearBanner() {
        bannerMessage = nil
    }

    private var selectedEditorFileURL: URL? {
        guard let projectRoot, selectedEditorTex.isEmpty == false else { return nil }
        return projectRoot.appendingPathComponent(selectedEditorTex)
    }

    private func loadSelectedEditorFileIntoEditor() {
        guard let fileURL = selectedEditorFileURL else {
            editorText = ""
            hasUnsavedEditorChanges = false
            return
        }

        isLoadingEditorText = true
        defer { isLoadingEditorText = false }

        do {
            editorText = try String(contentsOf: fileURL, encoding: .utf8)
            hasUnsavedEditorChanges = false
        } catch {
            editorText = ""
            hasUnsavedEditorChanges = false
            bannerMessage = "Could not read \(selectedEditorTex): \(error.localizedDescription)"
        }
    }

    private func pushRecentProject(url: URL) {
        var updated = recentProjects.filter { $0.rootPath != url.path }
        updated.insert(.init(name: url.lastPathComponent, rootPath: url.path), at: 0)
        if updated.count > 12 {
            updated = Array(updated.prefix(12))
        }
        recentProjects = updated
        recentStore.save(updated)
    }

    private func persistSettings() {
        guard let projectRoot else { return }
        var settings = settingsStore.load(projectRootPath: projectRoot.path)
        settings.mainTexRelativePath = selectedMainTex.isEmpty ? nil : selectedMainTex
        settings.latexEngine = selectedEngine
        settingsStore.save(settings, projectRootPath: projectRoot.path)
    }

    deinit {
        securityScopedProjectURL?.stopAccessingSecurityScopedResource()
    }
}

private enum IOSProjectScanner {
    static func findTexFiles(projectRoot: URL) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var paths: [String] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() != "tex" {
                continue
            }

            let relative = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            paths.append(relative)
        }

        return paths.sorted()
    }
}
