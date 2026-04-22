import Core
import PDFKit
import Shared
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct IOSRootView: View {
    @StateObject private var viewModel = IOSRootViewModel()
    @State private var showsFolderImporter = false
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { topToolbar }
        .fileImporter(
            isPresented: $showsFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.openProject(url: url)
            case .failure(let error):
                viewModel.bannerMessage = "Folder import failed: \(error.localizedDescription)"
            }
        }
    }

    private var sidebar: some View {
        List {
            if viewModel.projectRoot != nil {
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
    }

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: topBarLeadingPlacement) {
            HStack(spacing: 8) {
                Text("raagtex")
                    .font(.headline.weight(.semibold))
                if let projectRoot = viewModel.projectRoot {
                    Text(projectRoot.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }

        ToolbarItemGroup(placement: topBarTrailingPlacement) {
            Button {
                showsFolderImporter = true
            } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }

            if viewModel.recentProjects.isEmpty == false {
                Menu {
                    ForEach(viewModel.recentProjects) { project in
                        Button(project.name) {
                            viewModel.openRecent(project)
                        }
                    }
                } label: {
                    Label("Recent", systemImage: "clock.arrow.circlepath")
                }
            }

            if viewModel.projectRoot != nil {
                Button {
                    toggleSidebarVisibility()
                } label: {
                    Label("Sidebar", systemImage: splitViewVisibility == .detailOnly ? "sidebar.left" : "sidebar.left.hide")
                }

                Button {
                    viewModel.refreshProjectFiles()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Menu {
                    if viewModel.texFiles.isEmpty {
                        Text("No .tex files")
                    } else {
                        ForEach(viewModel.texFiles, id: \.self) { file in
                            Button {
                                viewModel.selectedEditorTex = file
                            } label: {
                                if viewModel.selectedEditorTex == file {
                                    Label(file, systemImage: "checkmark")
                                } else {
                                    Text(file)
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        viewModel.selectedEditorTex.isEmpty ? "Edit" : viewModel.selectedEditorTex,
                        systemImage: "text.cursor"
                    )
                }

                Menu {
                    if viewModel.texFiles.isEmpty {
                        Text("No .tex files")
                    } else {
                        ForEach(viewModel.texFiles, id: \.self) { file in
                            Button {
                                viewModel.selectedMainTex = file
                            } label: {
                                if viewModel.selectedMainTex == file {
                                    Label(file, systemImage: "checkmark")
                                } else {
                                    Text(file)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Main", systemImage: "doc.text")
                }

                Menu {
                    ForEach(EditorPreviewLayout.allCases, id: \.self) { layout in
                        Button {
                            viewModel.editorPreviewLayout = layout
                        } label: {
                            if viewModel.editorPreviewLayout == layout {
                                Label(layout.iosLabel, systemImage: "checkmark")
                            } else {
                                Text(layout.iosLabel)
                            }
                        }
                    }
                } label: {
                    Label("Layout", systemImage: viewModel.editorPreviewLayout.iosIconName)
                }

                Menu {
                    ForEach(CompileEngine.allCases, id: \.self) { engine in
                        Button {
                            viewModel.selectedEngine = engine
                        } label: {
                            if viewModel.selectedEngine == engine {
                                Label(engine.rawValue, systemImage: "checkmark")
                            } else {
                                Text(engine.rawValue)
                            }
                        }
                    }
                } label: {
                    Label(viewModel.selectedEngine.rawValue, systemImage: "gearshape.2")
                }

                if viewModel.isCompiling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        viewModel.compileNow()
                    } label: {
                        Label("Compile", systemImage: "play.fill")
                    }
                    .disabled(viewModel.selectedMainTex.isEmpty)
                }
            }
        }
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
                detailControlStrip

                if let banner = viewModel.bannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .onTapGesture { viewModel.clearBanner() }
                }

                editorAndPreviewContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(12)
        }
    }

    private var detailControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    showsFolderImporter = true
                } label: {
                    Label("Open", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                if viewModel.recentProjects.isEmpty == false {
                    Menu {
                        ForEach(viewModel.recentProjects) { project in
                            Button(project.name) {
                                viewModel.openRecent(project)
                            }
                        }
                    } label: {
                        Label("Recent", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    toggleSidebarVisibility()
                } label: {
                    Label("Sidebar", systemImage: splitViewVisibility == .detailOnly ? "sidebar.left" : "sidebar.left.hide")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.refreshProjectFiles()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Menu {
                    if viewModel.texFiles.isEmpty {
                        Text("No .tex files")
                    } else {
                        ForEach(viewModel.texFiles, id: \.self) { file in
                            Button {
                                viewModel.selectedEditorTex = file
                            } label: {
                                if viewModel.selectedEditorTex == file {
                                    Label(file, systemImage: "checkmark")
                                } else {
                                    Text(file)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Edit", systemImage: "text.cursor")
                }
                .buttonStyle(.bordered)

                Menu {
                    if viewModel.texFiles.isEmpty {
                        Text("No .tex files")
                    } else {
                        ForEach(viewModel.texFiles, id: \.self) { file in
                            Button {
                                viewModel.selectedMainTex = file
                            } label: {
                                if viewModel.selectedMainTex == file {
                                    Label(file, systemImage: "checkmark")
                                } else {
                                    Text(file)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Main", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(EditorPreviewLayout.allCases, id: \.self) { layout in
                        Button {
                            viewModel.editorPreviewLayout = layout
                        } label: {
                            if viewModel.editorPreviewLayout == layout {
                                Label(layout.iosLabel, systemImage: "checkmark")
                            } else {
                                Text(layout.iosLabel)
                            }
                        }
                    }
                } label: {
                    Label("Layout", systemImage: viewModel.editorPreviewLayout.iosIconName)
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(CompileEngine.allCases, id: \.self) { engine in
                        Button {
                            viewModel.selectedEngine = engine
                        } label: {
                            if viewModel.selectedEngine == engine {
                                Label(engine.rawValue, systemImage: "checkmark")
                            } else {
                                Text(engine.rawValue)
                            }
                        }
                    }
                } label: {
                    Label(viewModel.selectedEngine.rawValue, systemImage: "gearshape.2")
                }
                .buttonStyle(.bordered)

                if viewModel.isCompiling {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Button {
                        viewModel.compileNow()
                    } label: {
                        Label("Compile", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedMainTex.isEmpty)
                }
            }
            .padding(8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var editorAndPreviewContent: some View {
        switch viewModel.editorPreviewLayout {
        case .leftRight:
            HStack(spacing: 10) {
                editorPane
                compilePanel
            }
        case .rightLeft:
            HStack(spacing: 10) {
                compilePanel
                editorPane
            }
        case .topBottom:
            VStack(spacing: 10) {
                editorPane
                compilePanel
            }
        case .bottomTop:
            VStack(spacing: 10) {
                compilePanel
                editorPane
            }
        case .editorOnly:
            editorPane
        }
    }

    private var editorPane: some View {
        VStack(spacing: 10) {
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

    private var topBarLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    private var topBarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    private func toggleSidebarVisibility() {
        withAnimation(.easeInOut(duration: 0.15)) {
            splitViewVisibility = splitViewVisibility == .detailOnly ? .all : .detailOnly
        }
    }
}

private extension EditorPreviewLayout {
    var iosLabel: String {
        switch self {
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

    var iosIconName: String {
        switch self {
        case .leftRight:
            return "rectangle.lefthalf.inset.filled"
        case .rightLeft:
            return "rectangle.righthalf.inset.filled"
        case .topBottom:
            return "rectangle.tophalf.inset.filled"
        case .bottomTop:
            return "rectangle.bottomhalf.inset.filled"
        case .editorOnly:
            return "rectangle.inset.filled"
        }
    }
}

private struct IOSPDFView: IOSPlatformViewRepresentable {
    let url: URL

    #if canImport(UIKit)
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
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .windowBackgroundColor
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
    #endif
}

#if canImport(UIKit)
private typealias IOSPlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
private typealias IOSPlatformViewRepresentable = NSViewRepresentable
#endif

#Preview {
    IOSRootView()
}
