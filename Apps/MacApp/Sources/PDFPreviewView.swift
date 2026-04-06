import PDFKit
import SwiftUI

struct PDFPreviewView: NSViewRepresentable {
    var pdfURL: URL?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysAsBook = false
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard let pdfURL else {
            nsView.document = nil
            return
        }

        if nsView.document?.documentURL != pdfURL {
            nsView.document = PDFDocument(url: pdfURL)
        }
    }
}
