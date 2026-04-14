import PDFKit
import Shared
import SwiftUI

struct PDFPreviewView: NSViewRepresentable {
    var pdfURL: URL?
    var refreshToken: Date?
    var interfaceTheme: InterfaceTheme = .dark
    var onInverseSearch: ((PDFInverseSearchTarget) -> Void)? = nil
    var onDocumentDisplayed: ((Date) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = InverseSearchPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysAsBook = false
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        let canvasColor = canvasBackgroundColor(for: interfaceTheme)
        view.backgroundColor = canvasColor
        context.coordinator.configureInteraction(for: view, onInverseSearch: onInverseSearch)
        context.coordinator.onDocumentDisplayed = onDocumentDisplayed
        context.coordinator.applyInternalBackgroundStyling(to: view, canvasColor: canvasColor)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        let canvasColor = canvasBackgroundColor(for: interfaceTheme)
        nsView.backgroundColor = canvasColor
        context.coordinator.configureInteraction(for: nsView, onInverseSearch: onInverseSearch)
        context.coordinator.onDocumentDisplayed = onDocumentDisplayed
        guard let pdfURL else {
            nsView.document = nil
            context.coordinator.lastLoadedURL = nil
            context.coordinator.lastRefreshToken = nil
            context.coordinator.lastKnownViewState = nil
            context.coordinator.cancelPendingRetry()
            return
        }

        let needsReload =
            context.coordinator.lastLoadedURL != pdfURL ||
            context.coordinator.lastRefreshToken != refreshToken ||
            nsView.document == nil

        if needsReload {
            context.coordinator.lastKnownViewState = context.coordinator.captureViewState(from: nsView)
            if let document = context.coordinator.loadDocument(from: pdfURL) {
                context.coordinator.applyLoadedDocument(
                    document,
                    to: nsView,
                    loadedURL: pdfURL,
                    refreshToken: refreshToken,
                    canvasColor: canvasColor
                )
            } else {
                context.coordinator.scheduleLoadRetry(
                    on: nsView,
                    pdfURL: pdfURL,
                    refreshToken: refreshToken,
                    canvasColor: canvasColor,
                    attempt: 1
                )
            }
        }
    }

    private func canvasBackgroundColor(for theme: InterfaceTheme) -> NSColor {
        switch theme {
        case .light:
            return NSColor(white: 0.93, alpha: 1.0)
        case .dark, .clear:
            return NSColor(white: 0.16, alpha: 1.0)
        }
    }

    final class Coordinator {
        var lastLoadedURL: URL?
        var lastRefreshToken: Date?
        var lastKnownViewState: PDFViewState?
        var onInverseSearch: ((PDFInverseSearchTarget) -> Void)?
        var onDocumentDisplayed: ((Date) -> Void)?
        private var retryLoadWorkItem: DispatchWorkItem?

        struct PDFViewState {
            let pageIndex: Int
            let point: CGPoint
        }

        func configureInteraction(for view: PDFView, onInverseSearch: ((PDFInverseSearchTarget) -> Void)?) {
            self.onInverseSearch = onInverseSearch
            if let view = view as? InverseSearchPDFView {
                view.onPrimaryClick = { [weak self, weak view] pointInView in
                    guard let self, let view else { return }
                    self.handlePDFClick(at: pointInView, in: view)
                }
            }
        }

        func loadDocument(from url: URL) -> PDFDocument? {
            if let data = try? Data(contentsOf: url), let document = PDFDocument(data: data) {
                return document
            }
            return PDFDocument(url: url)
        }

        func applyLoadedDocument(
            _ document: PDFDocument,
            to view: PDFView,
            loadedURL: URL,
            refreshToken: Date?,
            canvasColor: NSColor
        ) {
            retryLoadWorkItem?.cancel()
            retryLoadWorkItem = nil

            view.document = document
            lastLoadedURL = loadedURL
            lastRefreshToken = refreshToken
            applyInternalBackgroundStyling(to: view, canvasColor: canvasColor)
            restoreViewState(on: view)
            onDocumentDisplayed?(Date())
        }

        func scheduleLoadRetry(
            on view: PDFView,
            pdfURL: URL,
            refreshToken: Date?,
            canvasColor: NSColor,
            attempt: Int
        ) {
            guard attempt <= 20 else { return }

            retryLoadWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self, weak view] in
                guard let self, let view else { return }
                self.retryLoadWorkItem = nil
                if let document = self.loadDocument(from: pdfURL) {
                    self.applyLoadedDocument(
                        document,
                        to: view,
                        loadedURL: pdfURL,
                        refreshToken: refreshToken,
                        canvasColor: canvasColor
                    )
                } else {
                    self.scheduleLoadRetry(
                        on: view,
                        pdfURL: pdfURL,
                        refreshToken: refreshToken,
                        canvasColor: canvasColor,
                        attempt: attempt + 1
                    )
                }
            }

            retryLoadWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: work)
        }

        func cancelPendingRetry() {
            retryLoadWorkItem?.cancel()
            retryLoadWorkItem = nil
        }

        func applyInternalBackgroundStyling(to view: PDFView, canvasColor: NSColor) {
            styleContainerBackgrounds(view: view, canvasColor: canvasColor)
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.styleContainerBackgrounds(view: view, canvasColor: canvasColor)
            }
        }

        private func handlePDFClick(at pointInView: CGPoint, in view: PDFView) {
            guard
                let document = view.document
            else { return }

            guard let page = view.page(for: pointInView, nearest: true) else { return }
            let pagePoint = view.convert(pointInView, to: page)
            let pageIndex = document.index(for: page)
            guard pageIndex >= 0 else { return }

            onInverseSearch?(
                PDFInverseSearchTarget(
                    pageIndex: pageIndex,
                    pagePoint: pagePoint,
                    pageBounds: page.bounds(for: view.displayBox)
                )
            )
        }

        private func styleContainerBackgrounds(view: PDFView, canvasColor: NSColor) {
            view.backgroundColor = canvasColor
            for child in view.subviews {
                if let scrollView = child as? NSScrollView {
                    scrollView.drawsBackground = true
                    scrollView.backgroundColor = canvasColor
                    let clipView = scrollView.contentView
                    clipView.drawsBackground = true
                    clipView.backgroundColor = canvasColor
                } else if let clipView = child as? NSClipView {
                    clipView.drawsBackground = true
                    clipView.backgroundColor = canvasColor
                }
            }
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

struct PDFInverseSearchTarget: Equatable {
    let pageIndex: Int
    let pagePoint: CGPoint
    let pageBounds: CGRect
}

private final class InverseSearchPDFView: PDFView {
    var onPrimaryClick: ((CGPoint) -> Void)?

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard event.type == .leftMouseUp, event.clickCount == 1 else { return }
        let point = convert(event.locationInWindow, from: nil)
        onPrimaryClick?(point)
    }
}
