import AppKit
import Core
import SwiftUI

struct MacRootView: View {
    @StateObject private var viewModel = MacRootViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List {
            Section("Workspace") {
                Button("Open Project...") {
                    openProjectPanel()
                }
            }

            if viewModel.recentProjects.isEmpty == false {
                Section("Recent") {
                    ForEach(viewModel.recentProjects) { project in
                        Button {
                            viewModel.openRecent(project)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                Text(project.rootPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("LaTeX Cockpit")
    }

    @ViewBuilder
    private var detailPane: some View {
        if viewModel.projectRoot == nil {
            ContentUnavailableView {
                Label("Open a LaTeX Project", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Choose a local folder to start compiling and previewing PDFs.")
            } actions: {
                Button("Open Project...") {
                    openProjectPanel()
                }
            }
        } else {
            VStack(spacing: 0) {
                controlsBar
                Divider()
                contentSplit
            }
            .background(.regularMaterial)
            .overlay(alignment: .top) {
                if let banner = viewModel.bannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .onTapGesture {
                            viewModel.clearBanner()
                        }
                }
            }
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Text(viewModel.projectDisplayName)
                .font(.headline)

            Picker("Main File", selection: $viewModel.selectedMainTex) {
                if viewModel.texFiles.isEmpty {
                    Text("No .tex files found").tag("")
                } else {
                    ForEach(viewModel.texFiles, id: \.self) { path in
                        Text(path).tag(path)
                    }
                }
            }
            .labelsHidden()
            .frame(minWidth: 240)
            .onChange(of: viewModel.selectedMainTex) { _, value in
                viewModel.userChangedMainFile(value)
            }

            Picker("Engine", selection: $viewModel.selectedEngine) {
                ForEach(CompileEngine.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Toggle("Auto", isOn: $viewModel.autoCompileEnabled)
                .toggleStyle(.switch)

            Spacer()

            Text(viewModel.statusLine)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                viewModel.compileNow(trigger: .manual)
            } label: {
                if viewModel.isCompiling {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Label("Compile", systemImage: "play.fill")
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(viewModel.isCompiling)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private var contentSplit: some View {
        HSplitView {
            PDFPreviewView(pdfURL: viewModel.documentState.pdfURL)
                .frame(minWidth: 420, minHeight: 480)

            VStack(spacing: 0) {
                Picker("Output", selection: $viewModel.selectedLogTab) {
                    ForEach(MacRootViewModel.LogTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(10)

                Divider()

                switch viewModel.selectedLogTab {
                case .diagnostics:
                    diagnosticsList
                case .raw:
                    rawLogView
                }
            }
            .frame(minWidth: 320)
        }
    }

    private var diagnosticsList: some View {
        List(viewModel.documentState.diagnostics, id: \.self) { diagnostic in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(diagnostic.severity.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: diagnostic.severity))
                    Spacer()
                    if let source = diagnostic.sourceFile, let line = diagnostic.line {
                        Text("\(source):\(line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(diagnostic.message)
                    .font(.callout)
            }
            .padding(.vertical, 2)
        }
        .overlay {
            if viewModel.documentState.diagnostics.isEmpty {
                ContentUnavailableView("No Diagnostics", systemImage: "checkmark.circle")
            }
        }
    }

    private var rawLogView: some View {
        ScrollView {
            Text(viewModel.documentState.rawCompileLog.isEmpty ? "No compile output yet." : viewModel.documentState.rawCompileLog)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(for severity: CompileDiagnostic.Severity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.openProject(url: selectedURL)
        }
    }
}

#Preview {
    MacRootView()
}
