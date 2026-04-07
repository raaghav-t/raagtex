import SwiftUI

enum ViewerWindow {
    static let sceneID = "viewer-window"
}

struct ViewerWindowView: View {
    @EnvironmentObject private var viewModel: MacRootViewModel

    var body: some View {
        Group {
            if let pdfURL = viewModel.documentState.pdfURL {
                PDFPreviewView(pdfURL: pdfURL)
            } else {
                ContentUnavailableView(
                    "No PDF Yet",
                    systemImage: "doc.richtext",
                    description: Text("Compile once to open the PDF in this detached window.")
                )
            }
        }
        .padding(8)
        .navigationTitle("raagtex Viewer")
    }
}
