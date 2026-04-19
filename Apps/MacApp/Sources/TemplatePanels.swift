import SwiftUI

struct TemplateManagerPanel: View {
    @EnvironmentObject private var viewModel: MacRootViewModel

    @State private var selectedKind: TemplateKind = .document
    @State private var selectedTemplateID = ""
    @State private var previewMode: TemplatePreviewMode = .text
    @State private var templateNameDraft = ""

    private var templates: [TemplateEntry] {
        viewModel.templates(for: selectedKind)
    }

    private var selectedTemplate: TemplateEntry? {
        templates.first(where: { $0.id == selectedTemplateID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Template & Style Manager")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                Button("Done") {
                    viewModel.dismissTemplateManager()
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Template folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.templateFolderURL?.path ?? "Unavailable")
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Button("Choose Folder…") {
                        viewModel.promptSelectTemplateFolder()
                    }
                    Button("Use Default") {
                        viewModel.useDefaultTemplateFolder()
                    }
                    Button("Reveal") {
                        viewModel.revealTemplateFolderInFinder()
                    }
                    Spacer(minLength: 0)
                }
            }

            Picker("Template Type", selection: $selectedKind) {
                ForEach(TemplateKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Button("Import .tex…") {
                    viewModel.importTemplates(of: selectedKind)
                }
                Button("New Empty…") {
                    viewModel.promptCreateEmptyTemplate(of: selectedKind)
                }
                Button("Refresh") {
                    viewModel.refreshTemplateLibrary()
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Template name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Template Name", text: $templateNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .disabled(selectedTemplate == nil)
                    Button("Save") {
                        guard let selectedTemplate else { return }
                        viewModel.updateTemplateDisplayName(selectedTemplate, to: templateNameDraft)
                    }
                    .disabled(selectedTemplate == nil)
                    Button("Reset") {
                        guard let selectedTemplate else { return }
                        viewModel.resetTemplateDisplayName(selectedTemplate)
                    }
                    .disabled(selectedTemplate == nil)
                }
                if let selectedTemplate {
                    Text("File name: \(selectedTemplate.fileName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Select a template to edit its display name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HSplitView {
                List(templates, id: \.id, selection: $selectedTemplateID) { template in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Text(template.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(template.id)
                }
                .frame(minWidth: 280)

                TemplatePreviewPane(
                    previewMode: $previewMode,
                    text: viewModel.templatePreviewText(for: selectedTemplate)
                )
            }
            .frame(minHeight: 360)
        }
        .padding(16)
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            if selectedTemplateID.isEmpty {
                selectedTemplateID = templates.first?.id ?? ""
            }
            refreshTemplateNameDraft()
        }
        .onChange(of: selectedKind) { _, _ in
            selectedTemplateID = templates.first?.id ?? ""
            refreshTemplateNameDraft()
        }
        .onChange(of: selectedTemplateID) { _, _ in
            refreshTemplateNameDraft()
        }
        .onChange(of: templates) { _, newTemplates in
            if newTemplates.contains(where: { $0.id == selectedTemplateID }) == false {
                selectedTemplateID = newTemplates.first?.id ?? ""
            }
            refreshTemplateNameDraft()
        }
    }

    private func refreshTemplateNameDraft() {
        templateNameDraft = selectedTemplate?.displayName ?? ""
    }
}

struct NewTemplateFilePanel: View {
    @EnvironmentObject private var viewModel: MacRootViewModel

    @State private var fileName = "untitled.tex"
    @State private var useDocumentTemplate = true
    @State private var selectedDocumentID = "none"
    @State private var selectedStyleID = "none"
    @State private var previewMode: TemplatePreviewMode = .text

    private var documentTemplates: [TemplateEntry] {
        viewModel.documentTemplates
    }

    private var styleTemplates: [TemplateEntry] {
        viewModel.styleTemplates
    }

    private var selectedDocumentTemplate: TemplateEntry? {
        guard useDocumentTemplate else { return nil }
        return documentTemplates.first(where: { $0.id == selectedDocumentID })
    }

    private var selectedStyleTemplate: TemplateEntry? {
        guard selectedStyleID != "none" else { return nil }
        return styleTemplates.first(where: { $0.id == selectedStyleID })
    }

    private var previewText: String {
        if let document = selectedDocumentTemplate {
            return viewModel.templatePreviewText(for: document)
        }
        if let style = selectedStyleTemplate {
            return viewModel.templatePreviewText(for: style)
        }
        return "Create a blank file or pick a template for preview."
    }

    private var targetDirectoryLabel: String {
        viewModel.pendingNewFileDirectory.isEmpty ? "Project root" : viewModel.pendingNewFileDirectory
    }

    private var canCreate: Bool {
        fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New File")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                Button("Cancel") {
                    viewModel.dismissNewFileSheet()
                }
            }

            Text("Destination: \(targetDirectoryLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("File name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("untitled.tex", text: $fileName)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Start from document template", isOn: $useDocumentTemplate)
                .toggleStyle(.switch)

            if useDocumentTemplate {
                Picker("Document", selection: $selectedDocumentID) {
                    Text("None").tag("none")
                    ForEach(documentTemplates, id: \.id) { template in
                        Text(template.displayName).tag(template.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("Style", selection: $selectedStyleID) {
                Text("None").tag("none")
                ForEach(styleTemplates, id: \.id) { template in
                    Text(template.displayName).tag(template.id)
                }
            }
            .pickerStyle(.menu)

            TemplatePreviewPane(previewMode: $previewMode, text: previewText)
                .frame(minHeight: 250)

            HStack {
                Spacer(minLength: 0)
                Button("Create") {
                    viewModel.createFileFromSheet(
                        named: fileName,
                        in: viewModel.pendingNewFileDirectory,
                        documentTemplate: selectedDocumentTemplate,
                        styleTemplate: selectedStyleTemplate
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(canCreate == false)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if documentTemplates.isEmpty {
                useDocumentTemplate = false
                selectedDocumentID = "none"
            } else {
                selectedDocumentID = documentTemplates.first?.id ?? "none"
            }
            selectedStyleID = "none"
        }
    }
}

struct AddStyleToProjectPanel: View {
    @EnvironmentObject private var viewModel: MacRootViewModel

    @State private var selectedStyleID = ""
    @State private var previewMode: TemplatePreviewMode = .text

    private var styles: [TemplateEntry] {
        viewModel.styleTemplates
    }

    private var selectedStyle: TemplateEntry? {
        styles.first(where: { $0.id == selectedStyleID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Style to Project")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                Button("Cancel") {
                    viewModel.dismissAddStyleSheet()
                }
            }

            if styles.isEmpty {
                ContentUnavailableView(
                    "No Style Templates",
                    systemImage: "paintbrush.pointed",
                    description: Text("Import or create style templates in Edit Templates first.")
                )
                HStack {
                    Spacer(minLength: 0)
                    Button("Open Template Manager") {
                        viewModel.dismissAddStyleSheet()
                        viewModel.presentTemplateManager()
                    }
                }
            } else {
                HSplitView {
                    List(styles, id: \.id, selection: $selectedStyleID) { style in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .lineLimit(1)
                            Text(style.fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(style.id)
                    }
                    .frame(minWidth: 240)

                    TemplatePreviewPane(
                        previewMode: $previewMode,
                        text: viewModel.templatePreviewText(for: selectedStyle)
                    )
                }
                .frame(minHeight: 280)

                HStack {
                    Spacer(minLength: 0)
                    Button("Add Style") {
                        guard let selectedStyle else { return }
                        viewModel.addStyleTemplateToCurrentProject(selectedStyle)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedStyle == nil)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 480)
        .onAppear {
            if selectedStyleID.isEmpty {
                selectedStyleID = styles.first?.id ?? ""
            }
        }
        .onChange(of: styles) { _, newStyles in
            if newStyles.contains(where: { $0.id == selectedStyleID }) == false {
                selectedStyleID = newStyles.first?.id ?? ""
            }
        }
    }
}

private struct TemplatePreviewPane: View {
    @Binding var previewMode: TemplatePreviewMode
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Preview", selection: $previewMode) {
                    ForEach(TemplatePreviewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button("Wire PDF Preview") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .help("Placeholder: wire this into PDF first-page preview next.")

                Spacer(minLength: 0)
            }

            Group {
                if previewMode == .text {
                    ScrollView {
                        Text(text)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                } else {
                    ContentUnavailableView(
                        "PDF Preview Not Wired Yet",
                        systemImage: "doc.richtext",
                        description: Text("Use the button above as the integration point for first-page PDF preview.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.45))
            )
        }
    }
}
