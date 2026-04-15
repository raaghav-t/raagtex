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
    @FocusedValue(\.activeMacRootViewModel) private var focusedViewModel

    var body: some Scene {
        WindowGroup(id: WorkspaceWindow.sceneID, for: UUID.self) { $windowID in
            WorkspaceWindowHost(windowID: $windowID)
                .environmentObject(sessionRegistry)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project…") {
                    if let focusedViewModel {
                        focusedViewModel.promptForProject()
                    } else {
                        promptForProjectInNewWindow()
                    }
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open Project in New Window…") {
                    promptForProjectInNewWindow()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                if let focusedViewModel, focusedViewModel.recentProjects.isEmpty == false {
                    Menu("Open Recent") {
                        ForEach(focusedViewModel.recentProjects.prefix(10)) { project in
                            Button(project.name) {
                                focusedViewModel.openRecent(project)
                            }
                        }
                    }
                }

                Button("Close Project") {
                    focusedViewModel?.closeProject()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(focusedViewModel?.projectRoot == nil)

                Divider()

                Button("Reveal Project in Finder") {
                    focusedViewModel?.openProjectInFinder()
                }
                .disabled(focusedViewModel?.projectRoot == nil)

                Button("Open Project in Terminal") {
                    focusedViewModel?.openProjectInTerminal()
                }
                .disabled(focusedViewModel?.projectRoot == nil)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    focusedViewModel?.performSaveShortcut()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(focusedViewModel?.canSaveDocument != true)
            }

            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export PDF…") {
                    focusedViewModel?.exportCompiledPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(focusedViewModel?.documentState.pdfURL == nil)

                Button("Reveal PDF in Finder") {
                    focusedViewModel?.revealCompiledPDFInFinder()
                }
                .disabled(focusedViewModel?.documentState.pdfURL == nil)
            }

            CommandMenu("Build") {
                Button("Recompile") {
                    focusedViewModel?.compileNow(trigger: .manual)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(
                    focusedViewModel == nil ||
                    focusedViewModel?.isCompiling == true ||
                    focusedViewModel?.projectRoot == nil ||
                    focusedViewModel?.compilePreflightError != nil
                )
            }

            CommandMenu("Experience") {
                if let focusedViewModel {
                    Menu("Theme") {
                        ForEach(InterfaceTheme.allCases, id: \.self) { theme in
                            Button {
                                focusedViewModel.interfaceTheme = theme
                            } label: {
                                if focusedViewModel.interfaceTheme == theme {
                                    Label(themeDisplayName(theme), systemImage: "checkmark")
                                } else {
                                    Text(themeDisplayName(theme))
                                }
                            }
                        }
                    }

                    Menu("Transparency") {
                        Button("Decrease") {
                            focusedViewModel.adjustInterfaceTransparency(by: -0.05)
                        }
                        .disabled(
                            focusedViewModel.interfaceTransparency <= minimumTransparency(for: focusedViewModel.interfaceTheme)
                        )

                        Button("Increase") {
                            focusedViewModel.adjustInterfaceTransparency(by: 0.05)
                        }
                        .disabled(focusedViewModel.interfaceTransparency >= 1.0)

                        Divider()

                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { amount in
                            Button {
                                focusedViewModel.setInterfaceTransparencyPreset(amount)
                            } label: {
                                if abs(focusedViewModel.interfaceTransparency - amount) < 0.001 {
                                    Label("\(Int(amount * 100))%", systemImage: "checkmark")
                                } else {
                                    Text("\(Int(amount * 100))%")
                                }
                            }
                        }
                    }

                    Divider()

                    Toggle("Zen", isOn: zenModeBinding(for: focusedViewModel))
                    Toggle("Spellcheck", isOn: boolBinding(focusedViewModel, keyPath: \.editorAutoCorrectEnabled))
                    Toggle("Syntax", isOn: boolBinding(focusedViewModel, keyPath: \.editorSyntaxColoringEnabled))
                    Toggle("Line Numbers", isOn: boolBinding(focusedViewModel, keyPath: \.editorLineNumbersEnabled))

                    Divider()

                    Button("Edit Syntax Colors…") {
                        focusedViewModel.presentSyntaxColorEditor()
                    }

                    Button("Edit Commands…") {
                        focusedViewModel.presentShortcutCommandEditor()
                    }

                    Divider()

                    Menu("Workspace Layout") {
                        ForEach(EditorPreviewLayout.allCases, id: \.self) { layout in
                            Button {
                                focusedViewModel.editorPreviewLayout = layout
                            } label: {
                                if focusedViewModel.editorPreviewLayout == layout {
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

    func boolBinding(_ viewModel: MacRootViewModel, keyPath: ReferenceWritableKeyPath<MacRootViewModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    func zenModeBinding(for viewModel: MacRootViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.interfaceMode == .zen },
            set: { viewModel.interfaceMode = $0 ? .zen : .debug }
        )
    }

    func themeDisplayName(_ theme: InterfaceTheme) -> String {
        switch theme {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .clear:
            return "Clear"
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
        case .clear:
            return 0.0
        case .light, .dark:
            return 0.25
        }
    }
}

@MainActor
private final class WindowSessionRegistry: ObservableObject {
    private var viewModelsByWindowID: [UUID: MacRootViewModel] = [:]
    private var pendingProjectByWindowID: [UUID: URL] = [:]

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
        } else {
            ContentUnavailableView(
                "No Workspace",
                systemImage: "macwindow",
                description: Text("Open the viewer from a workspace window.")
            )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
