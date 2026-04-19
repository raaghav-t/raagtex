import AppKit
import Shared
import SwiftUI

enum WorkspaceWindow {
    static let sceneID = "workspace-window"
}

@main
struct RaagtexMacApp: App {
    @StateObject private var sessionRegistry = WindowSessionRegistry()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    private var activeViewModel: MacRootViewModel? {
        sessionRegistry.activeViewModel
    }

    var body: some Scene {
        let _ = sessionRegistry.commandRefreshTick

        WindowGroup(id: WorkspaceWindow.sceneID, for: UUID.self) { $windowID in
            WorkspaceWindowHost(windowID: $windowID)
                .environmentObject(sessionRegistry)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project…") {
                    if let activeViewModel {
                        activeViewModel.promptForProject()
                    } else {
                        promptForProjectInNewWindow()
                    }
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open Project in New Window…") {
                    promptForProjectInNewWindow()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                if let activeViewModel, activeViewModel.recentProjects.isEmpty == false {
                    Menu("Open Recent") {
                        ForEach(activeViewModel.recentProjects.prefix(10)) { project in
                            Button(project.name) {
                                activeViewModel.openRecent(project)
                            }
                        }
                    }
                }

                Button("Close Project") {
                    activeViewModel?.closeProject()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(activeViewModel?.projectRoot == nil)

                Divider()

                Button("Edit Templates…") {
                    activeViewModel?.presentTemplateManager()
                }

                Button("Add Style…") {
                    activeViewModel?.presentAddStyleSheet()
                }
                .disabled(activeViewModel?.projectRoot == nil)

                Divider()

                Button("Reveal Project in Finder") {
                    activeViewModel?.openProjectInFinder()
                }
                .disabled(activeViewModel?.projectRoot == nil)

                Button("Open Project in Terminal") {
                    activeViewModel?.openProjectInTerminal()
                }
                .disabled(activeViewModel?.projectRoot == nil)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    activeViewModel?.performSaveShortcut()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(activeViewModel?.canSaveDocument != true)
            }

            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export PDF…") {
                    activeViewModel?.exportCompiledPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(activeViewModel?.documentState.pdfURL == nil)

                Button("Reveal PDF in Finder") {
                    activeViewModel?.revealCompiledPDFInFinder()
                }
                .disabled(activeViewModel?.documentState.pdfURL == nil)
            }

            CommandMenu("Build") {
                Button("Recompile") {
                    activeViewModel?.compileNow(trigger: .manual)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(
                    activeViewModel == nil ||
                    activeViewModel?.isCompiling == true ||
                    activeViewModel?.projectRoot == nil ||
                    activeViewModel?.compilePreflightError != nil
                )
            }

            CommandMenu("Experience") {
                if let activeViewModel {
                    Menu("Theme") {
                        ForEach(themeMenuOptions, id: \.self) { theme in
                            Button {
                                activeViewModel.interfaceTheme = theme
                            } label: {
                                if activeViewModel.interfaceTheme == theme {
                                    Label(themeDisplayName(theme), systemImage: "checkmark")
                                } else {
                                    Text(themeDisplayName(theme))
                                }
                            }
                        }
                    }

                    Menu("Transparency") {
                        Button("Decrease") {
                            activeViewModel.adjustInterfaceTransparency(by: -0.05)
                        }
                        .disabled(
                            activeViewModel.interfaceTransparency <= minimumTransparency(for: activeViewModel.interfaceTheme)
                        )

                        Button("Increase") {
                            activeViewModel.adjustInterfaceTransparency(by: 0.05)
                        }
                        .disabled(activeViewModel.interfaceTransparency >= 1.0)

                        Divider()

                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { amount in
                            Button {
                                activeViewModel.setInterfaceTransparencyPreset(amount)
                            } label: {
                                if abs(activeViewModel.interfaceTransparency - amount) < 0.001 {
                                    Label("\(Int(amount * 100))%", systemImage: "checkmark")
                                } else {
                                    Text("\(Int(amount * 100))%")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        activeViewModel.interfaceMode = activeViewModel.interfaceMode == .zen ? .debug : .zen
                    } label: {
                        menuCheckLabel("Zen", isOn: activeViewModel.interfaceMode == .zen)
                    }

                    Button {
                        activeViewModel.editorAutoCorrectEnabled.toggle()
                    } label: {
                        menuCheckLabel("Spellcheck", isOn: activeViewModel.editorAutoCorrectEnabled)
                    }

                    Button {
                        activeViewModel.editorSyntaxColoringEnabled.toggle()
                    } label: {
                        menuCheckLabel("Syntax", isOn: activeViewModel.editorSyntaxColoringEnabled)
                    }

                    Button {
                        activeViewModel.editorLineNumbersEnabled.toggle()
                    } label: {
                        menuCheckLabel("Line Numbers", isOn: activeViewModel.editorLineNumbersEnabled)
                    }

                    Divider()

                    Button("Edit Syntax Colors…") {
                        activeViewModel.presentSyntaxColorEditor()
                    }

                    Button("Edit Commands…") {
                        activeViewModel.presentShortcutCommandEditor()
                    }

                    Divider()

                    Menu("Workspace Layout") {
                        ForEach(EditorPreviewLayout.allCases, id: \.self) { layout in
                            Button {
                                activeViewModel.editorPreviewLayout = layout
                            } label: {
                                if activeViewModel.editorPreviewLayout == layout {
                                    Label(layoutDisplayName(layout), systemImage: "checkmark")
                                } else {
                                    Text(layoutDisplayName(layout))
                                }
                            }
                        }
                    }
                } else {
                    Text("No active workspace window")
                }
            }
        }

        WindowGroup("Viewer", id: ViewerWindow.sceneID, for: UUID.self) { $windowID in
            ViewerWindowHost(windowID: $windowID)
                .environmentObject(sessionRegistry)
        }
        .defaultSize(width: 900, height: 700)
    }
}

private extension RaagtexMacApp {
    var themeMenuOptions: [InterfaceTheme] {
        [.light, .dark, .clear, .clearLight, .clearDark]
    }

    func promptForProjectInNewWindow() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        openProjectInNewWindow(selectedURL)
    }

    func openProjectInNewWindow(_ projectURL: URL) {
        let windowID = sessionRegistry.prepareWindow(projectURL: projectURL)
        openWindow(id: WorkspaceWindow.sceneID, value: windowID)
    }

    @ViewBuilder
    func menuCheckLabel(_ title: String, isOn: Bool) -> some View {
        if isOn {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    func themeDisplayName(_ theme: InterfaceTheme) -> String {
        switch theme {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .clearLight:
            return "Clear Light"
        case .clearDark:
            return "Clear Dark"
        case .clear:
            return "Clear (Auto)"
        }
    }

    func layoutDisplayName(_ layout: EditorPreviewLayout) -> String {
        switch layout {
        case .leftRight:
            return "Editor Left, Preview Right"
        case .rightLeft:
            return "Preview Left, Editor Right"
        case .topBottom:
            return "Editor Top, Preview Bottom"
        case .bottomTop:
            return "Preview Top, Editor Bottom"
        case .editorOnly:
            return "Editor Only"
        }
    }

    func minimumTransparency(for theme: InterfaceTheme) -> Double {
        switch theme {
        case .clear, .clearLight, .clearDark:
            return 0.0
        case .light, .dark:
            return 0.25
        }
    }
}

@MainActor
private final class WindowSessionRegistry: ObservableObject {
    @Published private(set) var commandRefreshTick = 0
    private var viewModelsByWindowID: [UUID: MacRootViewModel] = [:]
    private var pendingProjectByWindowID: [UUID: URL] = [:]
    private var keyWindowObserver: NSObjectProtocol?

    static let windowIdentifierPrefix = "raagtex.workspace."

    init() {
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.commandRefreshTick &+= 1
            }
        }
    }

    deinit {
        if let keyWindowObserver {
            NotificationCenter.default.removeObserver(keyWindowObserver)
        }
    }

    func prepareWindow(projectURL: URL?) -> UUID {
        let windowID = UUID()
        if let projectURL {
            pendingProjectByWindowID[windowID] = projectURL
        }
        return windowID
    }

    func viewModel(for windowID: UUID) -> MacRootViewModel {
        if let existing = viewModelsByWindowID[windowID] {
            return existing
        }

        let viewModel = MacRootViewModel()
        if let projectURL = pendingProjectByWindowID.removeValue(forKey: windowID) {
            viewModel.openProject(url: projectURL)
        }
        viewModelsByWindowID[windowID] = viewModel
        return viewModel
    }

    var activeViewModel: MacRootViewModel? {
        guard let activeWindowID = activeWindowID() else { return nil }
        return viewModelsByWindowID[activeWindowID]
    }

    func windowIdentifier(for windowID: UUID) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(Self.windowIdentifierPrefix + windowID.uuidString)
    }

    private func activeWindowID() -> UUID? {
        guard let rawIdentifier = NSApp.keyWindow?.identifier?.rawValue else { return nil }
        guard rawIdentifier.hasPrefix(Self.windowIdentifierPrefix) else { return nil }
        let uuidText = String(rawIdentifier.dropFirst(Self.windowIdentifierPrefix.count))
        return UUID(uuidString: uuidText)
    }
}

private struct WorkspaceWindowHost: View {
    @EnvironmentObject private var sessionRegistry: WindowSessionRegistry
    @Binding var windowID: UUID?
    @State private var generatedWindowID = UUID()

    private var resolvedWindowID: UUID {
        windowID ?? generatedWindowID
    }

    var body: some View {
        MacRootView(windowID: resolvedWindowID)
            .environmentObject(sessionRegistry.viewModel(for: resolvedWindowID))
            .background {
                WindowIdentityBinder(identifier: sessionRegistry.windowIdentifier(for: resolvedWindowID))
            }
            .onAppear {
                if windowID == nil {
                    windowID = generatedWindowID
                }
            }
    }
}

private struct ViewerWindowHost: View {
    @EnvironmentObject private var sessionRegistry: WindowSessionRegistry
    @Binding var windowID: UUID?

    var body: some View {
        if let windowID {
            ViewerWindowView()
                .environmentObject(sessionRegistry.viewModel(for: windowID))
                .background {
                    WindowIdentityBinder(identifier: sessionRegistry.windowIdentifier(for: windowID))
                }
        } else {
            ContentUnavailableView(
                "No Workspace",
                systemImage: "macwindow",
                description: Text("Open the viewer from a workspace window.")
            )
        }
    }
}

private struct WindowIdentityBinder: NSViewRepresentable {
    let identifier: NSUserInterfaceItemIdentifier

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.identifier = identifier
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        if window.identifier != identifier {
            window.identifier = identifier
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
