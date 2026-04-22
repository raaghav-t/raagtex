import AppKit
import Core
import Shared
import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var viewModel: MacRootViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var systemColorScheme
    let windowID: UUID
    @State private var syntaxColors = EditorSyntaxColors.defaults(for: .dark)
    @State private var syntaxColorsCustomized = false
    @State private var isSyntaxGlyphHovered = false
    @State private var isCommandGlyphHovered = false
    @State private var isEditorPathGlyphHovered = false
    @State private var isExperienceCollapsed = false
    @State private var expandedDirectoryPaths: Set<String> = []

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 700)
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("")
        .toolbar { windowToolbar }
        .tint(activeTint)
        .preferredColorScheme(preferredColorScheme)
        .background {
            Rectangle().fill(panelBackground).ignoresSafeArea()
        }
        .background {
            if viewModel.interfaceTheme.isClearVariant {
                WindowBackgroundEffectView(configuration: clearModeBackgroundEffectConfiguration)
                    .ignoresSafeArea()
            }
        }
        .background(
            WindowTransparencyConfigurator()
        )
        .sheet(isPresented: $viewModel.showsSyntaxColorEditor) {
            SyntaxColorEditorPopover(
                command: syntaxCommandBinding,
                environment: syntaxEnvironmentBinding,
                math: syntaxMathBinding,
                comment: syntaxCommentBinding,
                onReset: {
                    syntaxColors = EditorSyntaxColors.defaults(for: effectiveInterfaceTheme)
                    syntaxColorsCustomized = false
                }
            )
            .padding(8)
            .frame(minWidth: 360)
        }
        .sheet(isPresented: $viewModel.showsShortcutCommandEditor) {
            ShortcutCommandEditorPanel(commands: $viewModel.editorShortcutCommands)
        }
        .sheet(isPresented: $viewModel.showsTemplateManager) {
            TemplateManagerPanel()
        }
        .sheet(isPresented: $viewModel.showsNewFileSheet) {
            NewTemplateFilePanel()
        }
        .sheet(isPresented: $viewModel.showsAddStyleSheet) {
            AddStyleToProjectPanel()
        }
        .onAppear {
            syntaxColors = EditorSyntaxColors.defaults(for: effectiveInterfaceTheme)
        }
        .onChange(of: viewModel.interfaceTheme) { _, theme in
            if syntaxColorsCustomized == false {
                let effectiveTheme = theme == .clear ? effectiveInterfaceTheme : theme
                syntaxColors = EditorSyntaxColors.defaults(for: effectiveTheme)
            }
        }
        .onChange(of: systemColorScheme) { _, _ in
            if syntaxColorsCustomized == false, viewModel.interfaceTheme == .clear {
                syntaxColors = EditorSyntaxColors.defaults(for: effectiveInterfaceTheme)
            }
        }
    }

    private var sidebar: some View {
        List {
            Section {
                SidebarActionRow(
                    title: "Open Project",
                    systemImage: "folder",
                    disabled: false
                ) {
                    viewModel.promptForProject()
                }
                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                .listRowBackground(Color.clear)

                SidebarActionRow(
                    title: "Open Viewer",
                    systemImage: "macwindow",
                    disabled: viewModel.documentState.pdfURL == nil
                ) {
                    openWindow(id: ViewerWindow.sceneID, value: windowID)
                }
                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                .listRowBackground(Color.clear)
            } header: {
                Text("Workspace")
                    .textCase(nil)
                    .padding(.top, 10)
            }

            Section {
                if isExperienceCollapsed == false {
                    experienceSettingsPanel
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                experienceSectionHeader
            }

            if viewModel.projectRoot != nil {
                Section {
                    ForEach(viewModel.projectFileTree) { node in
                        fileTreeBranch(node)
                    }
                } header: {
                    HStack(spacing: 0) {
                        Text("Files")
                        Text("  ")
                        Text(viewModel.projectRoot?.path ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textCase(nil)
                }
            }

            if viewModel.recentProjects.isEmpty == false {
                Section("Recent") {
                    ForEach(viewModel.recentProjects) { project in
                    SidebarActionRow(
                        title: project.name,
                        systemImage: "folder",
                        disabled: false
                    ) {
                        viewModel.openRecent(project)
                    }
                    .help(project.rootPath)
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowBackground(Color.clear)
                }
            }
        }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detailPane: some View {
        if viewModel.projectRoot == nil {
            ContentUnavailableView {
                Label("Open a LaTeX Project", systemImage: "doc.text.magnifyingglass")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            contentSplit
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 16)
                .overlay(alignment: .top) {
                    if let banner = viewModel.bannerMessage {
                        Text(banner)
                            .font(.footnote)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.opacity)
                            .onTapGesture {
                                viewModel.clearBanner()
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.bannerMessage)
        }
    }

    private var contentSplit: some View {
        HSplitView {
            editorAndPreview
                .frame(minHeight: 500)

            if viewModel.interfaceMode == .debug {
                debugPane
                    .frame(minWidth: 240, idealWidth: 320)
                    .padding(10)
            }
        }
    }

    private var experienceSectionHeader: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.20)) {
                    isExperienceCollapsed.toggle()
                }
            } label: {
                Image(systemName: isExperienceCollapsed ? "chevron.right.circle" : "chevron.down.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("Experience")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
    }

    private var experienceSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExperienceSettingCard(title: "Appearance", subtitle: "") {
                HStack(spacing: 10) {
                    ThemeModeButtons(selection: $viewModel.interfaceTheme)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ExperienceRowLabel(icon: "cube.transparent", text: appearanceSliderLabel)
                        Spacer(minLength: 0)
                        Text("\(Int(viewModel.interfaceTransparency * 100))%")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button {
                            viewModel.interfaceTransparency = max(
                                appearanceSliderRange.lowerBound,
                                viewModel.interfaceTransparency - 0.05
                            )
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .buttonBorderShape(.roundedRectangle(radius: 6))
                        .help("Decrease by 5%")

                        Slider(value: $viewModel.interfaceTransparency, in: appearanceSliderRange)
                            .controlSize(.regular)
                            .frame(minHeight: 24)

                        Button {
                            viewModel.interfaceTransparency = min(
                                appearanceSliderRange.upperBound,
                                viewModel.interfaceTransparency + 0.05
                            )
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .buttonBorderShape(.roundedRectangle(radius: 6))
                        .help("Increase by 5%")
                    }
                }
                .help(appearanceSliderHelp)
            }

            ExperienceSettingCard(title: "Writing", subtitle: "Comfort and focus") {
                ExperienceSettingRow(icon: "leaf", label: "Zen") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.interfaceMode == .zen },
                            set: { viewModel.interfaceMode = $0 ? .zen : .debug }
                        )
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                ExperienceSettingRow(icon: "bubble.and.pencil", label: "Spellcheck") {
                    Toggle("", isOn: $viewModel.editorAutoCorrectEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    Button {
                        viewModel.presentSyntaxColorEditor()
                    } label: {
                        Image(systemName: "highlighter")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 16, height: 16)
                            .foregroundStyle((isSyntaxGlyphHovered || viewModel.showsSyntaxColorEditor) ? activeTint : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit syntax colors")
                    .onHover { hovering in
                        guard hovering != isSyntaxGlyphHovered else { return }
                        DispatchQueue.main.async {
                            isSyntaxGlyphHovered = hovering
                        }
                    }
                    Text("Syntax")
                        .font(.callout)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Toggle("", isOn: $viewModel.editorSyntaxColoringEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .frame(minHeight: 26)
                .help("Syntax coloring")

                Divider()
                    .overlay(Color.white.opacity(0.08))

                ExperienceSettingRow(icon: "list.number", label: "Line Numbers") {
                    Toggle("", isOn: $viewModel.editorLineNumbersEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack {
                    Button {
                        viewModel.presentShortcutCommandEditor()
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 16, height: 16)
                            .foregroundStyle((isCommandGlyphHovered || viewModel.showsShortcutCommandEditor) ? activeTint : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit commands")
                    .onHover { hovering in
                        guard hovering != isCommandGlyphHovered else { return }
                        DispatchQueue.main.async {
                            isCommandGlyphHovered = hovering
                        }
                    }
                    Text("Edit Commands")
                        .font(.callout)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: 26)
            }

            ExperienceSettingCard(title: "Workspace", subtitle: "Editor and preview arrangement") {
                LayoutArrangementButtons(selection: $viewModel.editorPreviewLayout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .help("Choose editor/preview arrangement")
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var editorAndPreview: some View {
        switch viewModel.editorPreviewLayout {
        case .leftRight:
            HSplitView {
                editorPane
                    .frame(minWidth: 180)
                previewPane
                    .frame(minWidth: 180)
            }
        case .rightLeft:
            HSplitView {
                previewPane
                    .frame(minWidth: 180)
                editorPane
                    .frame(minWidth: 180)
            }
        case .topBottom:
            VSplitView {
                editorPane
                previewPane
            }
        case .bottomTop:
            VSplitView {
                previewPane
                editorPane
            }
        case .editorOnly:
            editorPane
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Button {
                        viewModel.copySelectedEditorFilePath()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isEditorPathGlyphHovered ? activeTint : .secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedEditorFileURL == nil)
                    .help("Copy path")
                    .onHover { hovering in
                        let nextValue = hovering && viewModel.selectedEditorFileURL != nil
                        guard nextValue != isEditorPathGlyphHovered else { return }
                        DispatchQueue.main.async {
                            isEditorPathGlyphHovered = nextValue
                        }
                    }

                    if isEditorPathGlyphHovered {
                        Text("Copy Path")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    Text("Editor")
                        .font(.subheadline.weight(.semibold))
                }
                .animation(.easeInOut(duration: 0.12), value: isEditorPathGlyphHovered)

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
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            LatexSyntaxEditorView(
                text: $viewModel.editorText,
                autocorrectionEnabled: viewModel.editorAutoCorrectEnabled,
                syntaxColoringEnabled: viewModel.editorSyntaxColoringEnabled,
                interfaceTheme: effectiveInterfaceTheme,
                syntaxColors: syntaxColors,
                showLineNumbers: viewModel.editorLineNumbersEnabled,
                editorFontSize: CGFloat(viewModel.editorFontSize),
                shortcutCommands: viewModel.editorShortcutCommands,
                lineJumpRequest: viewModel.editorLineJumpRequest,
                onLineJumpHandled: { id in
                    viewModel.clearEditorLineJumpRequest(id)
                },
                onSaveRequested: {
                    viewModel.performSaveShortcut()
                }
            )
                .padding(12)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(editorPaneBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(10)
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Preview", systemImage: "doc.richtext")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            PDFPreviewView(
                pdfURL: viewModel.documentState.pdfURL,
                refreshToken: viewModel.documentState.lastCompileAt,
                interfaceTheme: effectiveInterfaceTheme,
                onInverseSearch: { target in
                    viewModel.handlePDFInverseSearch(target)
                },
                onDocumentDisplayed: { displayedAt in
                    viewModel.notePDFDisplayed(at: displayedAt)
                }
            )
                .background(previewBackground)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(10)
    }

    private var debugPane: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Output", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    viewModel.interfaceMode = .zen
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("Hide output pane")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            debugTimelineView
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            Picker("Output", selection: $viewModel.selectedLogTab) {
                ForEach(MacRootViewModel.LogTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            switch viewModel.selectedLogTab {
            case .diagnostics:
                diagnosticsList
            case .raw:
                rawLogView
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var debugTimelineView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pipeline Debug")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            debugTimelineRow("Save", viewModel.debugLastSaveAt)
            debugTimelineRow("Compile Request", viewModel.debugLastCompileRequestedAt)
            debugTimelineRow("Compile Start", viewModel.debugLastCompileStartedAt)
            debugTimelineRow("Compile Finish", viewModel.debugLastCompileFinishedAt)
            debugTimelineRow("PDF Display", viewModel.debugLastPDFDisplayedAt)
        }
    }

    private func debugTimelineRow(_ title: String, _ date: Date?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(formattedDebugDate(date))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private func formattedDebugDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return debugDateFormatter.string(from: date)
    }

    private var debugDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
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
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
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
        .background(rawLogBackground)
    }

    private var preferredColorScheme: ColorScheme? {
        switch viewModel.interfaceTheme {
        case .light, .clearLight:
            return .light
        case .dark, .clearDark:
            return .dark
        case .clear:
            return nil
        }
    }

    private var effectiveInterfaceTheme: InterfaceTheme {
        if viewModel.interfaceTheme == .clear {
            return systemColorScheme == .dark ? .clearDark : .clearLight
        }
        return viewModel.interfaceTheme
    }

    private var activeTint: Color {
        Color(nsColor: .controlAccentColor)
    }

    private var panelBackground: AnyShapeStyle {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return AnyShapeStyle(Color.clear)
        case .light:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.35, viewModel.interfaceTransparency * 0.7)))
        case .dark:
            return AnyShapeStyle(.thinMaterial.opacity(max(0.30, viewModel.interfaceTransparency * 0.65)))
        }
    }

    private var cardBackground: AnyShapeStyle {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return AnyShapeStyle(Color.clear)
        case .light:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.28, viewModel.interfaceTransparency * 0.58)))
        case .dark:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.26, viewModel.interfaceTransparency * 0.52)))
        }
    }

    private var editorPaneBackground: AnyShapeStyle {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return AnyShapeStyle(Color.clear)
        case .light:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.28, viewModel.interfaceTransparency * 0.56)))
        case .dark:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.26, viewModel.interfaceTransparency * 0.5)))
        }
    }

    private var previewBackground: Color {
        Color.clear
    }

    private var rawLogBackground: Color {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return Color.clear
        case .light, .dark:
            return Color(nsColor: .textBackgroundColor).opacity(0.62)
        }
    }

    private var strokeOpacity: Double {
        viewModel.interfaceTheme.isClearVariant ? 0.14 : 0.07
    }

    private var appearanceSliderLabel: String {
        viewModel.interfaceTheme.isClearVariant ? "Blur" : "Transparency"
    }

    private var appearanceSliderHelp: String {
        viewModel.interfaceTheme.isClearVariant ? "Background blur strength" : "Window transparency"
    }

    private var appearanceSliderRange: ClosedRange<Double> {
        viewModel.interfaceTheme.isClearVariant ? 0.0 ... 1.0 : 0.25 ... 1.0
    }

    private var clearModeBackgroundEffectConfiguration: WindowBackgroundEffectConfiguration {
        WindowBackgroundEffectConfiguration(
            enableBackgroundBlur: true,
            blurStrength: viewModel.interfaceTransparency,
            blurMaterial: .underWindowBackground,
            blurBlendMode: .behindWindow,
            tintColor: .clear,
            tintOpacity: 0.0,
            fallbackBlurRadius: 0.0,
            rendererPreference: .nativeMaterialBlur
        )
    }

    @ToolbarContentBuilder
    private var windowToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 10) {
                Text("raagtex")
                    .font(.headline.weight(.semibold))
                if viewModel.projectRoot != nil {
                    Text(viewModel.projectDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }

        if viewModel.projectRoot != nil {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if viewModel.texFiles.isEmpty {
                        Text("No .tex files")
                    } else {
                        ForEach(viewModel.texFiles, id: \.self) { path in
                            Button(path) {
                                viewModel.userChangedMainFile(path)
                            }
                        }
                    }
                } label: {
                    ToolbarMenuCapsule(
                        title: viewModel.texFiles.isEmpty ? "No .tex files" : (viewModel.selectedMainTex.isEmpty ? "No .tex files" : viewModel.selectedMainTex),
                        minWidth: 220
                    )
                }
                .menuStyle(.button)

                Menu {
                    ForEach(CompileEngine.allCases, id: \.self) { engine in
                        Button(engine.rawValue) {
                            viewModel.selectedEngine = engine
                        }
                    }
                } label: {
                    ToolbarMenuCapsule(title: viewModel.selectedEngine.rawValue, minWidth: 120)
                }
                .menuStyle(.button)

                Toggle("Auto", isOn: $viewModel.autoCompileEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
            }

            ToolbarItem(placement: .primaryAction) {
                Text(viewModel.statusLine)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 130, alignment: .trailing)
                    .padding(.trailing, 14)
                    .animation(.none, value: viewModel.statusLine)
            }

            ToolbarItemGroup(placement: .primaryAction) {
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
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isCompiling || viewModel.compilePreflightError != nil)
                .help(viewModel.compilePreflightError ?? "Compile current main file")
            }
        }
    }

    private func fileTreeRow(_ node: ProjectFileNode) -> some View {
        let targetDirectory = node.isDirectory ? node.relativePath : parentDirectoryPath(for: node.relativePath)
        return FileTreeRowItem(
            node: node,
            isSelected: viewModel.selectedEditorTex == node.relativePath,
            activeTint: activeTint
        ) {
            viewModel.userSelectedEditorFile(node.relativePath)
        }
        .help(node.relativePath)
        .contextMenu {
            Button("Open") {
                viewModel.openFileNode(node)
            }

            Button("Open Parent") {
                viewModel.openParentProject(of: node)
            }
            .disabled(viewModel.canOpenParentProject(of: node) == false)

            Button("Reveal in Finder") {
                viewModel.revealFileNodeInFinder(node)
            }

            Divider()

            Button("New Folder") {
                viewModel.promptCreateFolder(in: targetDirectory)
            }

            Button("New File") {
                viewModel.promptCreateFile(in: targetDirectory)
            }

            Divider()

            Button("Rename…") {
                viewModel.promptRenameFileNode(node)
            }

            Button("Duplicate") {
                viewModel.duplicateFileNode(node)
            }

            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteFileNode(node)
            }

            Divider()

            Button("Cut") {
                viewModel.cutFileNode(node)
            }

            Button("Copy") {
                viewModel.copyFileNode(node)
            }

            Button("Paste") {
                viewModel.pasteIntoDirectory(targetDirectory)
            }
            .disabled(viewModel.canPasteIntoDirectory(targetDirectory) == false)

            Divider()

            Button("Copy Path") {
                viewModel.copyFileNodePath(node)
            }
        }
    }

    private func parentDirectoryPath(for relativePath: String) -> String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }

    private func fileTreeBranch(_ node: ProjectFileNode) -> AnyView {
        if node.isDirectory {
            return AnyView(DisclosureGroup(isExpanded: expansionBinding(for: node.relativePath)) {
                ForEach(node.children ?? []) { child in
                    fileTreeBranch(child)
                }
            } label: {
                fileTreeRow(node)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleDirectoryExpansion(node.relativePath)
                    }
            })
        } else {
            return AnyView(fileTreeRow(node))
        }
    }

    private func expansionBinding(for path: String) -> Binding<Bool> {
        Binding(
            get: { expandedDirectoryPaths.contains(path) },
            set: { isExpanded in
                if isExpanded {
                    expandedDirectoryPaths.insert(path)
                } else {
                    expandedDirectoryPaths.remove(path)
                }
            }
        )
    }

    private func toggleDirectoryExpansion(_ path: String) {
        if expandedDirectoryPaths.contains(path) {
            expandedDirectoryPaths.remove(path)
        } else {
            expandedDirectoryPaths.insert(path)
        }
    }

    private func nodeRowForeground(_ node: ProjectFileNode) -> Color {
        if node.isDirectory {
            return .primary
        }
        if node.isTexFile {
            return .primary
        }
        return .secondary
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

    private var syntaxCommandBinding: Binding<Color> {
        Binding(
            get: { syntaxColors.command },
            set: {
                syntaxColors.command = $0
                syntaxColorsCustomized = true
            }
        )
    }

    private var syntaxEnvironmentBinding: Binding<Color> {
        Binding(
            get: { syntaxColors.environment },
            set: {
                syntaxColors.environment = $0
                syntaxColorsCustomized = true
            }
        )
    }

    private var syntaxMathBinding: Binding<Color> {
        Binding(
            get: { syntaxColors.math },
            set: {
                syntaxColors.math = $0
                syntaxColorsCustomized = true
            }
        )
    }

    private var syntaxCommentBinding: Binding<Color> {
        Binding(
            get: { syntaxColors.comment },
            set: {
                syntaxColors.comment = $0
                syntaxColorsCustomized = true
            }
        )
    }
}

private struct SidebarActionRow: View {
    let title: String
    let systemImage: String
    let disabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered && disabled == false ? Color.primary.opacity(0.08) : Color.clear)
            )
            .foregroundStyle(disabled ? .secondary.opacity(0.5) : Color.primary)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .disabled(disabled)
        .contentShape(Rectangle())
        .onHover { hover in
            let nextValue = hover && disabled == false
            guard nextValue != isHovered else { return }
            DispatchQueue.main.async {
                isHovered = nextValue
            }
        }
    }
}

private struct FileTreeRowItem: View {
    let node: ProjectFileNode
    let isSelected: Bool
    let activeTint: Color
    let onSelect: () -> Void
    @State private var isHovered = false

    private var isClickable: Bool {
        node.isTexFile
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: node.symbolName)
                .foregroundStyle(iconColor)
                .frame(width: 14)

            Text(node.displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(node.isDirectory ? .subheadline : .callout)
                .foregroundStyle(foregroundColor)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard isClickable else { return }
            onSelect()
        }
        .onHover { hover in
            let nextValue = hover && isClickable
            guard nextValue != isHovered else { return }
            DispatchQueue.main.async {
                isHovered = nextValue
            }
        }
    }

    private var iconColor: Color {
        if node.isDirectory { return .secondary }
        if isSelected { return activeTint }
        return .secondary
    }

    private var foregroundColor: Color {
        if isSelected { return activeTint }
        if isHovered { return .primary }
        if node.isDirectory { return .primary }
        return .secondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return activeTint.opacity(0.16)
        }
        if isHovered {
            return activeTint.opacity(0.10)
        }
        return .clear
    }
}

private struct ExperienceSettingCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.regularMaterial.opacity(0.48))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct ExperienceSettingRow<Control: View>: View {
    let icon: String?
    let label: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 10) {
            ExperienceRowLabel(icon: icon, text: label)
            Spacer(minLength: 0)
            control
        }
        .frame(minHeight: 26)
    }
}

private struct ExperienceRowLabel: View {
    let icon: String?
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.callout.weight(.regular))
                .lineLimit(1)
        }
    }
}

private struct ThemeModeButtons: View {
    @Binding var selection: InterfaceTheme
    @State private var hoveredTheme: InterfaceTheme?

    private let activeTint = Color(nsColor: .controlAccentColor)

    var body: some View {
        HStack(spacing: 6) {
            themeButton(.light, label: "Light")
            themeButton(.dark, label: "Dark")
            themeButton(.clear, label: "Clear")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func themeButton(_ theme: InterfaceTheme, label: String) -> some View {
        Button(label) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                selection = theme
            }
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(backgroundColor(for: theme), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(borderColor(for: theme), lineWidth: 1)
        }
        .foregroundStyle(isSelected(theme) ? Color.primary : Color.secondary)
        .onHover { hovering in
            let nextValue: InterfaceTheme? = hovering ? theme : (hoveredTheme == theme ? nil : hoveredTheme)
            guard nextValue != hoveredTheme else { return }
            DispatchQueue.main.async {
                hoveredTheme = nextValue
            }
        }
    }

    private func backgroundColor(for theme: InterfaceTheme) -> Color {
        if isSelected(theme) {
            return activeTint.opacity(0.16)
        }
        if hoveredTheme == theme {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }

    private func borderColor(for theme: InterfaceTheme) -> Color {
        if isSelected(theme) {
            return activeTint.opacity(0.24)
        }
        if hoveredTheme == theme {
            return Color.primary.opacity(0.14)
        }
        return .clear
    }

    private func isSelected(_ theme: InterfaceTheme) -> Bool {
        if theme == .clear {
            return selection.isClearVariant
        }
        return selection == theme
    }
}

private struct SyntaxColorEditorPopover: View {
    @Binding var command: Color
    @Binding var environment: Color
    @Binding var math: Color
    @Binding var comment: Color
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Syntax Colors")
                .font(.subheadline.weight(.semibold))

            SyntaxColorRow(label: "Commands", color: $command)
            SyntaxColorRow(label: "Environments", color: $environment)
            SyntaxColorRow(label: "Math", color: $math)
            SyntaxColorRow(label: "Comments", color: $comment)

            Divider()

            Button("Reset to Defaults", role: .destructive) {
                onReset()
            }
        }
        .padding(12)
        .frame(width: 250)
    }
}

private struct SyntaxColorRow: View {
    let label: String
    @Binding var color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct LayoutArrangementButtons: View {
    @Binding var selection: EditorPreviewLayout
    @State private var hoveredLayout: EditorPreviewLayout?

    private let orderedLayouts: [EditorPreviewLayout] = [.leftRight, .rightLeft, .topBottom, .bottomTop, .editorOnly]
    private let activeTint = Color(nsColor: .controlAccentColor)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedLayouts, id: \.self) { layout in
                layoutButton(layout)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func layoutButton(_ layout: EditorPreviewLayout) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                selection = layout
            }
        } label: {
            Image(systemName: layout.arrangementIconName)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .foregroundStyle(selection == layout ? .primary : .secondary)
                .background(backgroundColor(for: layout), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                    .stroke(borderColor(for: layout), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(layout.arrangementLabel)
        .onHover { hovering in
            let nextValue: EditorPreviewLayout? = hovering ? layout : (hoveredLayout == layout ? nil : hoveredLayout)
            guard nextValue != hoveredLayout else { return }
            DispatchQueue.main.async {
                hoveredLayout = nextValue
            }
        }
    }

    private func backgroundColor(for layout: EditorPreviewLayout) -> Color {
        if selection == layout {
            return activeTint.opacity(0.16)
        }
        if hoveredLayout == layout {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }

    private func borderColor(for layout: EditorPreviewLayout) -> Color {
        if selection == layout {
            return activeTint.opacity(0.24)
        }
        if hoveredLayout == layout {
            return Color.primary.opacity(0.14)
        }
        return .clear
    }
}

private struct ShortcutCommandEditorPanel: View {
    @Binding var commands: [EditorShortcutCommand]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcut Commands")
                .font(.subheadline.weight(.semibold))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($commands) { $command in
                        ShortcutCommandRow(command: $command) {
                            commands.removeAll { $0.id == command.id }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxHeight: 300)

            HStack {
                Button {
                    commands.append(
                        EditorShortcutCommand(
                            key: "k",
                            usesShift: false,
                            template: "\\text{$SELECTION$}"
                        )
                    )
                } label: {
                    Label("Add Command", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Reset Defaults") {
                    commands = EditorShortcutCommand.defaultCommands
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(width: 440)
    }
}

private struct ShortcutCommandRow: View {
    @Binding var command: EditorShortcutCommand
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $command.usesShift) {
                Text("Cmd").tag(false)
                Text("Cmd+Shift").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .help("Choose shortcut modifier")

            TextField("Key", text: $command.key)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .onChange(of: command.key) { _, value in
                    command.key = String(value.prefix(1)).lowercased()
                }

            TextField("Template", text: $command.template)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .help("Use $SELECTION$ as insertion point")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help("Delete command")
        }
    }
}

private struct ToolbarMenuCapsule: View {
    let title: String
    let minWidth: CGFloat
    @State private var isHovered = false

    private var backgroundColor: Color {
        if isHovered {
            return Color(nsColor: .controlBackgroundColor).opacity(0.90)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.78)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 6)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.primary)
        .frame(minWidth: minWidth, alignment: .leading)
        .padding(.leading, 9)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .onHover { hover in
            guard hover != isHovered else { return }
            DispatchQueue.main.async {
                isHovered = hover
            }
        }
    }
}

private struct HoverHighlightTextButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    private var rowTint: Color {
        Color(red: 0.31, green: 0.55, blue: 0.94)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? rowTint.opacity(0.16) : Color.clear)
                )
                .foregroundStyle(isHovered ? rowTint : Color.primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            guard hovering != isHovered else { return }
            DispatchQueue.main.async {
                isHovered = hovering
            }
        }
    }
}

private extension EditorPreviewLayout {
    var label: String {
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

    var splitIconName: String {
        switch self {
        case .leftRight, .rightLeft:
            return "rectangle.split.2x1"
        case .topBottom, .bottomTop:
            return "rectangle.split.1x2"
        case .editorOnly:
            return "rectangle.leftthird.inset.filled"
        }
    }

    var iconScaleX: CGFloat {
        switch self {
        case .rightLeft:
            return -1
        default:
            return 1
        }
    }

    var iconScaleY: CGFloat {
        switch self {
        case .bottomTop:
            return -1
        default:
            return 1
        }
    }

    var arrangementLabel: String {
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

    var arrangementIconName: String {
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

private extension ProjectFileNode {
    var symbolName: String {
        if isDirectory {
            return "folder"
        }
        if isTexFile {
            return "doc.text"
        }
        if relativePath.lowercased().hasSuffix(".pdf") {
            return "doc.richtext"
        }
        return "doc"
    }
}

private struct WindowTransparencyConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.title = ""
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.toolbar?.showsBaselineSeparator = false
    }
}

#Preview {
    MacRootView(windowID: UUID())
        .environmentObject(MacRootViewModel())
}
