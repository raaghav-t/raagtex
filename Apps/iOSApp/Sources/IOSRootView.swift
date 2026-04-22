import Core
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct IOSRootView: View {
    @StateObject private var viewModel = IOSRootViewModel()
    @State private var showsFolderImporter = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .fileImporter(
            isPresented: $showsFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
                _ = url.startAccessingSecurityScopedResource()
=======
>>>>>>> theirs
=======
>>>>>>> theirs
=======
>>>>>>> theirs
=======
>>>>>>> theirs
=======
>>>>>>> theirs
=======
>>>>>>> theirs
                viewModel.openProject(url: url)
            case .failure(let error):
                viewModel.bannerMessage = "Folder import failed: \(error.localizedDescription)"
            }
        }
    }

    private var sidebar: some View {
        List {
            Section("Workspace") {
                Button {
                    showsFolderImporter = true
                } label: {
                    Label("Open Project Folder", systemImage: "folder")
                }

                Button {
                    viewModel.refreshProjectFiles()
                } label: {
                    Label("Refresh Files", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.projectRoot == nil)

                Button {
                    viewModel.compileNow()
                } label: {
                    Label("Compile", systemImage: "hammer")
                }
                .disabled(viewModel.projectRoot == nil || viewModel.isCompiling)
            }

            if viewModel.projectRoot != nil {
                Section("Main File") {
                    Picker("Main .tex", selection: $viewModel.selectedMainTex) {
                        ForEach(viewModel.texFiles, id: \.self) { file in
                            Text(file).tag(file)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Engine", selection: $viewModel.selectedEngine) {
                        ForEach(CompileEngine.allCases, id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Files") {
                    ForEach(viewModel.texFiles, id: \.self) { file in
                        Button {
                            viewModel.selectedEditorTex = file
                        } label: {
                            HStack {
                                Image(systemName: file == viewModel.selectedEditorTex ? "doc.text.fill" : "doc.text")
                                Text(file)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if viewModel.recentProjects.isEmpty == false {
                Section("Recent") {
                    ForEach(viewModel.recentProjects) { project in
                        Button(project.name) {
                            viewModel.openRecent(project)
                        }
                    }
                }
            }
        }
        .navigationTitle("Raagtex iPad")
    }

    @ViewBuilder
    private var detail: some View {
        if viewModel.projectRoot == nil {
            ContentUnavailableView {
                Label("Open a LaTeX Folder", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Choose a local folder, edit .tex files, and compile right from iPad.")
            } actions: {
                Button("Open Folder") {
                    showsFolderImporter = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 10) {
                if let banner = viewModel.bannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .onTapGesture { viewModel.clearBanner() }
                }

                HStack {
                    Text(viewModel.selectedEditorTex.isEmpty ? "Editor" : viewModel.selectedEditorTex)
                        .font(.headline)
                    Spacer()
                    Button("Save") {
                        viewModel.saveEditorIfNeeded()
                    }
                    .disabled(viewModel.hasUnsavedEditorChanges == false)

                    Button("Revert") {
                        viewModel.revertEditorChanges()
                    }
                    .disabled(viewModel.hasUnsavedEditorChanges == false)
                }

                TextEditor(text: $viewModel.editorText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.hasUnsavedEditorChanges {
                            Text("Unsaved")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                        }
                    }

                compilePanel
            }
            .padding(12)
        }
    }

    private var compilePanel: some View {
        GroupBox("Preview + Diagnostics") {
            VStack(alignment: .leading, spacing: 10) {
                statusRow

                if let pdfURL = viewModel.documentState.pdfURL {
                    IOSPDFView(url: pdfURL)
                        .frame(minHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ContentUnavailableView("No PDF yet", systemImage: "doc.richtext")
                        .frame(minHeight: 140)
                }

                if viewModel.documentState.diagnostics.isEmpty == false {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(viewModel.documentState.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(diagnostic.message)
                                        .font(.footnote)
                                    Text("\(diagnostic.severity.rawValue.uppercased()) • \(diagnostic.sourceFile ?? "Unknown file"):\(diagnostic.line ?? 0)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
    }

    private var statusRow: some View {
        HStack {
            Label(statusTitle, systemImage: statusIcon)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let lastCompile = viewModel.documentState.lastCompileAt {
                Text(lastCompile.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusTitle: String {
        switch viewModel.documentState.compileStatus {
        case .idle: "Idle"
        case .running: "Compiling"
        case .succeeded: "Compile succeeded"
        case .failed: "Compile failed"
        case .cancelled: "Compile cancelled"
        }
    }

    private var statusIcon: String {
        switch viewModel.documentState.compileStatus {
        case .idle: "circle"
        case .running: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        }
    }
}

private struct IOSPDFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

#Preview {
    IOSRootView()
}
