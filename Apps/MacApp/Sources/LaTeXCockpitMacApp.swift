import AppKit
import SwiftUI

@main
struct RaagtexMacApp: App {
    @StateObject private var viewModel = MacRootViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project…") {
                    viewModel.promptForProject()
                }
                .keyboardShortcut("o", modifiers: [.command])

                if viewModel.recentProjects.isEmpty == false {
                    Menu("Open Recent") {
                        ForEach(viewModel.recentProjects.prefix(10)) { project in
                            Button(project.name) {
                                viewModel.openRecent(project)
                            }
                        }
                    }
                }

                Button("Close Project") {
                    viewModel.closeProject()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(viewModel.projectRoot == nil)

                Divider()

                Button("Reveal Project in Finder") {
                    viewModel.openProjectInFinder()
                }
                .disabled(viewModel.projectRoot == nil)

                Button("Open Project in Terminal") {
                    viewModel.openProjectInTerminal()
                }
                .disabled(viewModel.projectRoot == nil)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    viewModel.saveEditorToDisk()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(viewModel.canSaveDocument == false || viewModel.isCompiling)
            }

            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export PDF…") {
                    viewModel.exportCompiledPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(viewModel.documentState.pdfURL == nil)

                Button("Reveal PDF in Finder") {
                    viewModel.revealCompiledPDFInFinder()
                }
                .disabled(viewModel.documentState.pdfURL == nil)
            }

            CommandMenu("Build") {
                Button("Recompile") {
                    viewModel.compileNow(trigger: .manual)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isCompiling || viewModel.projectRoot == nil || viewModel.compilePreflightError != nil)
            }

            CommandMenu("Git") {
                Toggle("Enable Git Helpers", isOn: $viewModel.gitHelpersEnabled)

                Divider()

                Button("Refresh Status") {
                    viewModel.refreshGitStatus()
                }
                .disabled(viewModel.projectRoot == nil || viewModel.gitOperationInProgress)

                Button("Stage All Changes") {
                    viewModel.gitStageAll()
                }
                .disabled(viewModel.canUseGitTools == false || viewModel.gitOperationInProgress)

                Button("Commit…") {
                    viewModel.promptForCommit()
                }
                .disabled(viewModel.canCommitWithGit == false)

                Divider()

                Button("Pull (Rebase)") {
                    viewModel.gitPullRebase()
                }
                .disabled(viewModel.canRunGitSync == false)

                Button("Push") {
                    viewModel.gitPush()
                }
                .disabled(viewModel.canRunGitSync == false)

                Button("Sync (Pull + Push)") {
                    viewModel.gitSync()
                }
                .disabled(viewModel.canRunGitSync == false)
            }
        }

        WindowGroup("Viewer", id: ViewerWindow.sceneID) {
            ViewerWindowView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 900, height: 700)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
