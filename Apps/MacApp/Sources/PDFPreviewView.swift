import PDFKit
import SwiftUI

struct PDFPreviewView: NSViewRepresentable {
    var pdfURL: URL?
    var refreshToken: Date?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysAsBook = false
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard let pdfURL else {
            nsView.document = nil
            context.coordinator.lastLoadedURL = nil
            context.coordinator.lastKnownModificationDate = nil
            context.coordinator.lastKnownFileSize = nil
            context.coordinator.lastRefreshToken = nil
            context.coordinator.lastKnownViewState = nil
            return
        }

        let resourceValues = try? pdfURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modificationDate = resourceValues?.contentModificationDate
        let fileSize = resourceValues?.fileSize
        let needsReload =
            context.coordinator.lastLoadedURL != pdfURL ||
            context.coordinator.lastKnownModificationDate != modificationDate ||
            context.coordinator.lastKnownFileSize != fileSize ||
            context.coordinator.lastRefreshToken != refreshToken ||
            nsView.document?.documentURL != pdfURL

        if needsReload {
            context.coordinator.lastKnownViewState = context.coordinator.captureViewState(from: nsView)
            if let data = try? Data(contentsOf: pdfURL), let document = PDFDocument(data: data) {
                nsView.document = document
            } else {
                nsView.document = PDFDocument(url: pdfURL)
            }
            context.coordinator.lastLoadedURL = pdfURL
            context.coordinator.lastKnownModificationDate = modificationDate
            context.coordinator.lastKnownFileSize = fileSize
            context.coordinator.lastRefreshToken = refreshToken
            context.coordinator.restoreViewState(on: nsView)
        }
    }

    final class Coordinator {
        var lastLoadedURL: URL?
        var lastKnownModificationDate: Date?
        var lastKnownFileSize: Int?
        var lastRefreshToken: Date?
        var lastKnownViewState: PDFViewState?

        struct PDFViewState {
            let pageIndex: Int
            let point: CGPoint
        }

        func captureViewState(from view: PDFView) -> PDFViewState? {
            if let destination = view.currentDestination,
               let destinationPage = destination.page,
               let document = view.document {
                let pageIndex = document.index(for: destinationPage)
                guard pageIndex >= 0 else { return nil }
                return PDFViewState(pageIndex: pageIndex, point: destination.point)
            }

            if let page = view.currentPage, let document = view.document {
                let pageIndex = document.index(for: page)
                guard pageIndex >= 0 else { return nil }
                return PDFViewState(pageIndex: pageIndex, point: .zero)
            }

            return nil
        }

        func restoreViewState(on view: PDFView) {
            guard
                let state = lastKnownViewState,
                let document = view.document,
                state.pageIndex < document.pageCount,
                let page = document.page(at: state.pageIndex)
            else { return }

            view.go(to: PDFDestination(page: page, at: state.point))
        }
    }
}
