import AppKit
import Shared
import SwiftUI

enum ViewerWindow {
    static let sceneID = "viewer-window"
}

struct ViewerWindowView: View {
    @EnvironmentObject private var viewModel: MacRootViewModel
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(panelBackground)
                .ignoresSafeArea()

            Group {
                if let pdfURL = viewModel.documentState.pdfURL {
                    PDFPreviewView(
                        pdfURL: pdfURL,
                        refreshToken: viewModel.documentState.lastCompileAt,
                        interfaceTheme: effectiveInterfaceTheme,
                        onInverseSearch: { target in
                            viewModel.handlePDFInverseSearch(target)
                        },
                        onDocumentDisplayed: { displayedAt in
                            viewModel.notePDFDisplayed(at: displayedAt)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "No PDF Yet",
                        systemImage: "doc.richtext",
                        description: Text("Compile once to open the PDF in this detached window.")
                    )
                }
            }
            .background(previewBackground)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(10)
        }
        .navigationTitle("Viewer")
    }

    private var panelBackground: AnyShapeStyle {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return AnyShapeStyle(Color.clear)
        case .light:
            return AnyShapeStyle(.regularMaterial.opacity(viewModel.interfaceTransparency))
        case .dark:
            return AnyShapeStyle(.ultraThinMaterial.opacity(viewModel.interfaceTransparency))
        }
    }

    private var cardBackground: AnyShapeStyle {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return AnyShapeStyle(Color.clear)
        case .light:
            return AnyShapeStyle(.regularMaterial.opacity(max(0.30, viewModel.interfaceTransparency * 0.82)))
        case .dark:
            return AnyShapeStyle(.thinMaterial.opacity(max(0.34, viewModel.interfaceTransparency * 0.9)))
        }
    }

    private var previewBackground: Color {
        switch viewModel.interfaceTheme {
        case .clear, .clearLight, .clearDark:
            return Color.clear
        case .light, .dark:
            return Color(nsColor: .windowBackgroundColor).opacity(0.66)
        }
    }

    private var strokeOpacity: Double {
        viewModel.interfaceTheme.isClearVariant ? 0.18 : 0.10
    }

    private var effectiveInterfaceTheme: InterfaceTheme {
        if viewModel.interfaceTheme == .clear {
            return systemColorScheme == .dark ? .clearDark : .clearLight
        }
        return viewModel.interfaceTheme
    }
}
