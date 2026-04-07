import AppKit
import Core
import Shared
import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var viewModel: MacRootViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .tint(accentColor)
        .preferredColorScheme(preferredColorScheme)
    }

    private var sidebar: some View {
        List {
            Section("Workspace") {
                Button("Open Project...") {
                    openProjectPanel()
                }
                Button("Open Viewer Window") {
                    openWindow(id: ViewerWindow.sceneID)
                }
                .disabled(viewModel.documentState.pdfURL == nil)
            }

            Section("Experience") {
                Picker("Theme", selection: $viewModel.interfaceTheme) {
                    ForEach(InterfaceTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }

                Picker("Mode", selection: $viewModel.interfaceMode) {
                    ForEach(InterfaceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }

                Picker("Layout", selection: $viewModel.editorPreviewLayout) {
                    Text("Side by Side").tag(EditorPreviewLayout.sideBySide)
                    Text("Stacked").tag(EditorPreviewLayout.stacked)
                }

                Toggle("AutoCorrect", isOn: $viewModel.editorAutoCorrectEnabled)

                HStack {
                    Text("Transparency")
                    Slider(value: $viewModel.interfaceTransparency, in: 0.25 ... 1.0)
                }

                if viewModel.interfaceTheme == .custom {
                    ColorPicker(
                        "Accent",
                        selection: Binding(
                            get: { accentColor },
                            set: updateAccentColor
                        ),
                        supportsOpacity: false
                    )
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
        .navigationTitle("raagtex")
    }

    @ViewBuilder
    private var detailPane: some View {
        if viewModel.projectRoot == nil {
            ContentUnavailableView {
                Label("Open a LaTeX Project", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Choose a local folder to start writing, compiling, and previewing PDFs.")
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
            .background(.regularMaterial.opacity(viewModel.interfaceTransparency))
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

            if viewModel.interfaceMode == .debug {
                Toggle("Zen", isOn: Binding(
                    get: { viewModel.interfaceMode == .zen },
                    set: { viewModel.interfaceMode = $0 ? .zen : .debug }
                ))
                .toggleStyle(.switch)
            }

            Spacer()

            Text(viewModel.statusLine)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                viewModel.runAutoCorrect()
            } label: {
                Label("Fix Typos", systemImage: "wand.and.stars")
            }
            .disabled(viewModel.editorAutoCorrectEnabled == false)

            Button {
                viewModel.saveEditorToDisk()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(viewModel.hasUnsavedEditorChanges == false)

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
        .background(.ultraThinMaterial.opacity(viewModel.interfaceTransparency))
    }

    private var contentSplit: some View {
        HSplitView {
            editorAndPreview
                .frame(minWidth: 560, minHeight: 480)

            if viewModel.interfaceMode == .debug {
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
    }

    private var editorAndPreview: some View {
        Group {
            if viewModel.editorPreviewLayout == .stacked {
                VSplitView {
                    editorPane
                    previewPane
                }
            } else {
                HSplitView {
                    editorPane
                        .frame(minWidth: 280)
                    previewPane
                        .frame(minWidth: 280)
                }
            }
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Editor")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.hasUnsavedEditorChanges {
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Revert") {
                    viewModel.revertEditorToDisk()
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.hasUnsavedEditorChanges == false)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            TextEditor(text: $viewModel.editorText)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled(viewModel.editorAutoCorrectEnabled == false)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var previewPane: some View {
        PDFPreviewView(pdfURL: viewModel.documentState.pdfURL)
            .background(Color(nsColor: .windowBackgroundColor))
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

    private var preferredColorScheme: ColorScheme? {
        switch viewModel.interfaceTheme {
        case .light:
            return .light
        case .dark, .custom:
            return .dark
        }
    }

    private var accentColor: Color {
        Color(
            red: viewModel.accentRed,
            green: viewModel.accentGreen,
            blue: viewModel.accentBlue
        )
    }

    private func updateAccentColor(_ color: Color) {
        #if os(macOS)
            let nsColor = NSColor(color)
            let rgb = nsColor.usingColorSpace(.sRGB) ?? .systemBlue
            viewModel.accentRed = Double(rgb.redComponent)
            viewModel.accentGreen = Double(rgb.greenComponent)
            viewModel.accentBlue = Double(rgb.blueComponent)
        #endif
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
        .environmentObject(MacRootViewModel())
}
