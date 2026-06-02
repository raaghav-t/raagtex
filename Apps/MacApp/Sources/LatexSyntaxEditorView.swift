import AppKit
import Core
import Shared
import SwiftUI

struct LatexSyntaxEditorView: NSViewRepresentable {
    @Binding var text: String
    var autocorrectionEnabled: Bool
    var syntaxColoringEnabled: Bool
    var interfaceTheme: InterfaceTheme
    var syntaxColors: EditorSyntaxColors
    var showLineNumbers: Bool
    var editorFontSize: CGFloat
    var shortcutCommands: [EditorShortcutCommand]
    var diagnostics: [CompileDiagnostic]
    var lineJumpRequest: EditorLineJumpRequest?
    var onLineJumpHandled: ((UUID) -> Void)? = nil
    var onSaveRequested: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = LatexTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: Self.clampedFontSize(editorFontSize), weight: .regular)
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 3)
        textView.textContainer?.lineFragmentPadding = 0

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        let snappingClipView = LineSnappingClipView()
        snappingClipView.trackedTextView = textView
        snappingClipView.drawsBackground = false
        snappingClipView.backgroundColor = .clear
        scrollView.contentView = snappingClipView
        scrollView.documentView = textView

        let lineNumberRuler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineNumberRuler
        scrollView.hasVerticalRuler = true

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.lineNumberRulerView = lineNumberRuler
        context.coordinator.applyConfiguration(
            text: text,
            autocorrectionEnabled: autocorrectionEnabled,
            syntaxColoringEnabled: syntaxColoringEnabled,
            interfaceTheme: interfaceTheme,
            syntaxColors: syntaxColors,
            showLineNumbers: showLineNumbers,
            editorFontSize: editorFontSize,
            shortcutCommands: shortcutCommands,
            diagnostics: diagnostics,
            lineJumpRequest: lineJumpRequest,
            onLineJumpHandled: onLineJumpHandled,
            onSaveRequested: onSaveRequested,
            forceTextUpdate: true
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.applyConfiguration(
            text: text,
            autocorrectionEnabled: autocorrectionEnabled,
            syntaxColoringEnabled: syntaxColoringEnabled,
            interfaceTheme: interfaceTheme,
            syntaxColors: syntaxColors,
            showLineNumbers: showLineNumbers,
            editorFontSize: editorFontSize,
            shortcutCommands: shortcutCommands,
            diagnostics: diagnostics,
            lineJumpRequest: lineJumpRequest,
            onLineJumpHandled: onLineJumpHandled,
            onSaveRequested: onSaveRequested,
            forceTextUpdate: false
        )
    }

    private static func clampedFontSize(_ size: CGFloat) -> CGFloat {
        min(max(size, 10), 28)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        fileprivate weak var lineNumberRulerView: LineNumberRulerView?

        private var isProgrammaticChange = false
        private var cachedSyntaxColoringEnabled = true
        private var cachedAutoCorrectionEnabled = true
        private var cachedTheme: InterfaceTheme = .dark
        private var cachedSyntaxColors = EditorSyntaxColors.defaults(for: .dark)
        private var cachedEditorFontSize: CGFloat = 15
        private var cachedLineDiagnostics: [EditorLineDiagnostic] = []
        private var cachedIgnoredWords: Set<String> = []
        private var lastHandledLineJumpRequestID: UUID?
        private var highlightWorkItem: DispatchWorkItem?
        private var ignoredWordsWorkItem: DispatchWorkItem?
        private static let commandRegex = try! NSRegularExpression(pattern: #"\\[A-Za-z@]+\*?"#, options: [.anchorsMatchLines])
        private static let environmentRegex = try! NSRegularExpression(pattern: #"\\(begin|end)\s*\{[^}\n]+\}"#, options: [.anchorsMatchLines])
        private static let inlineMathRegex = try! NSRegularExpression(pattern: #"\$[^$\n]*\$"#, options: [.anchorsMatchLines])
        private static let displayMathBracketRegex = try! NSRegularExpression(pattern: #"\\\[[\s\S]*?\\\]"#, options: [.dotMatchesLineSeparators])
        private static let displayMathParenRegex = try! NSRegularExpression(pattern: #"\\\([\s\S]*?\\\)"#, options: [.dotMatchesLineSeparators])
        private static let commentRegex = try! NSRegularExpression(pattern: #"%.*$"#, options: [.anchorsMatchLines])
        private static let ignoredWordEnvironmentRegex = try! NSRegularExpression(pattern: #"\\(begin|end)\s*\{([^}\n]+)\}"#, options: [.anchorsMatchLines])
        private static let ignoredWordsMaxScanLength = 180_000
        private static let fullMathHighlightThreshold = 180_000

        init(text: Binding<String>) {
            self.text = text
        }

        deinit {
            highlightWorkItem?.cancel()
            ignoredWordsWorkItem?.cancel()
        }

        func applyConfiguration(
            text newText: String,
            autocorrectionEnabled: Bool,
            syntaxColoringEnabled: Bool,
            interfaceTheme: InterfaceTheme,
            syntaxColors: EditorSyntaxColors,
            showLineNumbers: Bool,
            editorFontSize: CGFloat,
            shortcutCommands: [EditorShortcutCommand],
            diagnostics: [CompileDiagnostic],
            lineJumpRequest: EditorLineJumpRequest?,
            onLineJumpHandled: ((UUID) -> Void)?,
            onSaveRequested: (() -> Void)?,
            forceTextUpdate: Bool
        ) {
            guard let textView, let scrollView else { return }
            let effectiveFontSize = LatexSyntaxEditorView.clampedFontSize(editorFontSize)
            let lineDiagnostics = EditorLineDiagnostic.collapsed(from: diagnostics)

            textView.isEditable = true
            textView.isSelectable = true
            textView.isAutomaticSpellingCorrectionEnabled = autocorrectionEnabled
            textView.isContinuousSpellCheckingEnabled = autocorrectionEnabled
            (textView as? LatexTextView)?.shortcutCommands = shortcutCommands
            (textView as? LatexTextView)?.onSaveRequested = onSaveRequested
            (textView as? LatexTextView)?.diagnostics = lineDiagnostics
            scrollView.rulersVisible = showLineNumbers
            scrollView.hasVerticalRuler = showLineNumbers
            lineNumberRulerView?.isHidden = showLineNumbers == false
            lineNumberRulerView?.diagnostics = lineDiagnostics

            let needsTextSync = forceTextUpdate || textView.string != newText
            let needsStyleRefresh =
                cachedSyntaxColoringEnabled != syntaxColoringEnabled ||
                cachedTheme != interfaceTheme ||
                cachedSyntaxColors != syntaxColors ||
                cachedEditorFontSize != effectiveFontSize ||
                cachedLineDiagnostics != lineDiagnostics

            cachedSyntaxColoringEnabled = syntaxColoringEnabled
            cachedAutoCorrectionEnabled = autocorrectionEnabled
            cachedTheme = interfaceTheme
            cachedSyntaxColors = syntaxColors
            cachedEditorFontSize = effectiveFontSize
            cachedLineDiagnostics = lineDiagnostics

            if needsTextSync {
                isProgrammaticChange = true
                let selectedRange = clampedSelectedRange(in: textView)
                textView.string = newText
                applyHighlighting(
                    to: textView,
                    syntaxColoringEnabled: syntaxColoringEnabled,
                    theme: interfaceTheme,
                    syntaxColors: syntaxColors,
                    fontSize: effectiveFontSize
                )
                setSelectedRangeIfNeeded(selectedRange, in: textView)
                isProgrammaticChange = false
                lineNumberRulerView?.invalidateLineNumbers()
            } else if needsStyleRefresh {
                applyHighlighting(
                    to: textView,
                    syntaxColoringEnabled: syntaxColoringEnabled,
                    theme: interfaceTheme,
                    syntaxColors: syntaxColors,
                    fontSize: effectiveFontSize
                )
                lineNumberRulerView?.invalidateLineNumbers()
            }

            if autocorrectionEnabled {
                updateIgnoredWords(in: textView, source: textView.string)
            } else if cachedIgnoredWords.isEmpty == false {
                NSSpellChecker.shared.setIgnoredWords([], inSpellDocumentWithTag: textView.spellCheckerDocumentTag)
                cachedIgnoredWords.removeAll()
            }

            if let lineJumpRequest, lineJumpRequest.id != lastHandledLineJumpRequestID {
                jumpToLine(lineJumpRequest.line, in: textView)
                lastHandledLineJumpRequestID = lineJumpRequest.id
                DispatchQueue.main.async {
                    onLineJumpHandled?(lineJumpRequest.id)
                }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            guard isProgrammaticChange == false else { return }

            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            lineNumberRulerView?.invalidateLineNumbers()
            scheduleHighlightRefresh(for: textView)
            scheduleIgnoredWordsRefresh(for: textView)
        }

        private func scheduleHighlightRefresh(for textView: NSTextView) {
            guard cachedSyntaxColoringEnabled else { return }
            highlightWorkItem?.cancel()
            let delay = highlightDebounceDelay(for: (textView.string as NSString).length)
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.applyHighlighting(
                    to: textView,
                    syntaxColoringEnabled: self.cachedSyntaxColoringEnabled,
                    theme: self.cachedTheme,
                    syntaxColors: self.cachedSyntaxColors,
                    fontSize: self.cachedEditorFontSize
                )
            }
            highlightWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private func scheduleIgnoredWordsRefresh(for textView: NSTextView) {
            if cachedAutoCorrectionEnabled == false {
                if cachedIgnoredWords.isEmpty == false {
                    NSSpellChecker.shared.setIgnoredWords([], inSpellDocumentWithTag: textView.spellCheckerDocumentTag)
                    cachedIgnoredWords.removeAll()
                }
                return
            }

            ignoredWordsWorkItem?.cancel()
            let delay = ignoredWordsDebounceDelay(for: (textView.string as NSString).length)
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.updateIgnoredWords(in: textView, source: textView.string)
            }
            ignoredWordsWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private func applyHighlighting(
            to textView: NSTextView,
            syntaxColoringEnabled: Bool,
            theme: InterfaceTheme,
            syntaxColors: EditorSyntaxColors,
            fontSize: CGFloat
        ) {
            let source = textView.string
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: (source as NSString).length)

            let palette = SyntaxPalette(theme: theme, colors: syntaxColors)
            let selectedRange = clampedSelectedRange(in: textView)
            textStorage.beginEditing()
            textStorage.setAttributes(
                [
                    .foregroundColor: palette.base,
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                ],
                range: fullRange
            )

            if syntaxColoringEnabled {
                applyRegex(Self.commandRegex, color: palette.command, on: textStorage, source: source)
                applyRegex(Self.environmentRegex, color: palette.environment, on: textStorage, source: source)
                applyRegex(Self.commentRegex, color: palette.comment, on: textStorage, source: source)

                if (source as NSString).length <= Self.fullMathHighlightThreshold {
                    applyRegex(Self.inlineMathRegex, color: palette.math, on: textStorage, source: source)
                    applyRegex(Self.displayMathBracketRegex, color: palette.math, on: textStorage, source: source)
                    applyRegex(Self.displayMathParenRegex, color: palette.math, on: textStorage, source: source)
                }
            }
            textStorage.endEditing()
            textView.typingAttributes = [
                .foregroundColor: palette.base,
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            ]

            setSelectedRangeIfNeeded(selectedRange, in: textView)
            textView.insertionPointColor = palette.caret
        }

        private func applyRegex(
            _ regex: NSRegularExpression,
            color: NSColor,
            on textStorage: NSTextStorage,
            source: String
        ) {
            let range = NSRange(location: 0, length: (source as NSString).length)
            regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
                textStorage.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }

        private func clampedSelectedRange(in textView: NSTextView) -> NSRange {
            clampedRange(textView.selectedRange(), maxLength: (textView.string as NSString).length)
        }

        private func clampedRange(_ range: NSRange, maxLength: Int) -> NSRange {
            guard range.location != NSNotFound else {
                return NSRange(location: maxLength, length: 0)
            }

            let location = min(max(0, range.location), maxLength)
            let length = min(max(0, range.length), max(0, maxLength - location))
            return NSRange(location: location, length: length)
        }

        private func setSelectedRangeIfNeeded(_ range: NSRange, in textView: NSTextView) {
            let clamped = clampedRange(range, maxLength: (textView.string as NSString).length)
            guard NSEqualRanges(textView.selectedRange(), clamped) == false else { return }
            textView.setSelectedRange(clamped)
        }

        private func updateIgnoredWords(in textView: NSTextView, source: String) {
            let ignoredWords = latexIgnoredWords(in: source)
            guard ignoredWords != cachedIgnoredWords else { return }
            NSSpellChecker.shared.setIgnoredWords(Array(ignoredWords), inSpellDocumentWithTag: textView.spellCheckerDocumentTag)
            cachedIgnoredWords = ignoredWords
        }

        private func latexIgnoredWords(in source: String) -> Set<String> {
            var words = Set<String>()
            let nsSource = source as NSString
            let scanLength = min(nsSource.length, Self.ignoredWordsMaxScanLength)
            let scanSource = nsSource.substring(with: NSRange(location: 0, length: scanLength))
            let nsScanSource = scanSource as NSString
            let fullRange = NSRange(location: 0, length: nsScanSource.length)

            Self.commandRegex.enumerateMatches(in: scanSource, options: [], range: fullRange) { match, _, _ in
                guard let match, match.range.location != NSNotFound else { return }
                let rawCommand = nsScanSource.substring(with: match.range)
                words.insert(rawCommand)
                if rawCommand.first == "\\" {
                    words.insert(String(rawCommand.dropFirst()))
                }
            }

            Self.ignoredWordEnvironmentRegex.enumerateMatches(in: scanSource, options: [], range: fullRange) { match, _, _ in
                guard
                    let match,
                    match.numberOfRanges > 2,
                    match.range(at: 2).location != NSNotFound
                else { return }
                words.insert(nsScanSource.substring(with: match.range(at: 2)))
            }

            return words
        }

        private func highlightDebounceDelay(for length: Int) -> TimeInterval {
            switch length {
            case 0..<45_000:
                return 0.07
            case 45_000..<120_000:
                return 0.12
            default:
                return 0.20
            }
        }

        private func ignoredWordsDebounceDelay(for length: Int) -> TimeInterval {
            switch length {
            case 0..<45_000:
                return 0.30
            case 45_000..<120_000:
                return 0.45
            default:
                return 0.75
            }
        }

        private func jumpToLine(_ line: Int, in textView: NSTextView) {
            let targetLine = max(1, line)
            let nsText = textView.string as NSString
            let textLength = nsText.length

            guard textLength > 0 else {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                return
            }

            var currentLine = 1
            var currentLocation = 0
            while currentLine < targetLine && currentLocation < textLength {
                let lineRange = nsText.lineRange(for: NSRange(location: currentLocation, length: 0))
                let nextLocation = NSMaxRange(lineRange)
                if nextLocation <= currentLocation {
                    break
                }
                currentLocation = nextLocation
                currentLine += 1
            }

            let caretLocation = min(max(0, currentLocation), textLength)
            let caretRange = NSRange(location: caretLocation, length: 0)
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(caretRange)
            textView.scrollRangeToVisible(caretRange)
        }
    }
}

fileprivate struct EditorLineDiagnostic: Equatable {
    let line: Int
    let severity: CompileDiagnostic.Severity
    let message: String

    static func collapsed(from diagnostics: [CompileDiagnostic]) -> [EditorLineDiagnostic] {
        let lineGroups = Dictionary(grouping: diagnostics.compactMap { diagnostic -> EditorLineDiagnostic? in
            guard let line = diagnostic.line, line > 0 else { return nil }
            return EditorLineDiagnostic(
                line: line,
                severity: diagnostic.severity,
                message: diagnostic.message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }, by: \.line)

        return lineGroups.map { line, diagnostics in
            let severity = diagnostics.contains { $0.severity == .error } ? CompileDiagnostic.Severity.error :
                (diagnostics.contains { $0.severity == .warning } ? .warning : .info)
            let message = diagnostics
                .map(\.message)
                .filter { $0.isEmpty == false }
                .joined(separator: "\n")
            return EditorLineDiagnostic(line: line, severity: severity, message: message)
        }
        .sorted { $0.line < $1.line }
    }
}

fileprivate enum EditorDiagnosticColors {
    static let error = NSColor(calibratedRed: 1.0, green: 0.29, blue: 0.28, alpha: 1.0)
    static let errorFill = NSColor(calibratedRed: 1.0, green: 0.29, blue: 0.28, alpha: 0.12)
}

fileprivate final class LineNumberRulerView: NSRulerView {
    weak var trackedTextView: NSTextView?
    var diagnostics: [EditorLineDiagnostic] = [] {
        didSet {
            diagnosticLookup = Dictionary(uniqueKeysWithValues: diagnostics.map { ($0.line, $0) })
            needsDisplay = true
        }
    }
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var diagnosticLookup: [Int: EditorLineDiagnostic] = [:]
    private var trackingArea: NSTrackingArea?

    init(textView: NSTextView) {
        self.trackedTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateLineNumbers),
            name: NSText.didChangeNotification,
            object: textView
        )

        if let contentView = textView.enclosingScrollView?.contentView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(invalidateLineNumbers),
                name: NSView.boundsDidChangeNotification,
                object: contentView
            )
            contentView.postsBoundsChangedNotifications = true
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        toolTip = diagnosticMessage(at: point)
        super.mouseMoved(with: event)
    }

    @objc
    func invalidateLineNumbers() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView = trackedTextView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? .zero
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let text = textView.string as NSString
        if text.length == 0 {
            drawLineNumber(
                "1",
                atY: textView.textContainerInset.height,
                in: bounds
            )
            return
        }

        let firstVisibleChar = min(charRange.location, max(0, text.length - 1))
        let firstVisibleLine = text.lineRange(for: NSRange(location: firstVisibleChar, length: 0))

        var lineNumber = 1
        var searchLocation = 0
        while searchLocation < firstVisibleLine.location && searchLocation < text.length {
            let lineRange = text.lineRange(for: NSRange(location: searchLocation, length: 0))
            searchLocation = NSMaxRange(lineRange)
            lineNumber += 1
        }

        var lineStart = firstVisibleLine.location
        while lineStart < text.length {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerOrigin.y

            let y = lineRect.minY - visibleRect.minY
            if y > visibleRect.height + 24 {
                break
            }
            if y > -24 {
                drawLineNumber(
                    "\(lineNumber)",
                    atY: y + max(0, (lineRect.height - numberFont.pointSize) / 2.0),
                    in: bounds,
                    diagnostic: diagnosticLookup[lineNumber]
                )
            }

            lineNumber += 1
            lineStart = NSMaxRange(lineRange)
        }
    }

    private func drawLineNumber(_ value: String, atY y: CGFloat, in bounds: NSRect, diagnostic: EditorLineDiagnostic? = nil) {
        let label = value as NSString
        if diagnostic?.severity == .error {
            EditorDiagnosticColors.error.setFill()
            NSBezierPath(roundedRect: NSRect(x: 4, y: y - 1, width: 3, height: numberFont.pointSize + 3), xRadius: 1.5, yRadius: 1.5).fill()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: diagnostic?.severity == .error ? NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold) : numberFont,
            .foregroundColor: diagnostic?.severity == .error ? EditorDiagnosticColors.error : NSColor.secondaryLabelColor
        ]
        let labelSize = label.size(withAttributes: attributes)
        let x = bounds.width - labelSize.width - 8
        label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
    }

    private func diagnosticMessage(at point: NSPoint) -> String? {
        guard
            let textView = trackedTextView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return nil
        }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? .zero
        let yInTextView = point.y + visibleRect.minY
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let text = textView.string as NSString
        guard text.length > 0 else { return nil }

        let firstVisibleChar = min(charRange.location, max(0, text.length - 1))
        let firstVisibleLine = text.lineRange(for: NSRange(location: firstVisibleChar, length: 0))
        var lineNumber = 1
        var searchLocation = 0
        while searchLocation < firstVisibleLine.location && searchLocation < text.length {
            let lineRange = text.lineRange(for: NSRange(location: searchLocation, length: 0))
            searchLocation = NSMaxRange(lineRange)
            lineNumber += 1
        }

        var lineStart = firstVisibleLine.location
        while lineStart < text.length {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerOrigin.y
            if lineRect.minY <= yInTextView, yInTextView <= lineRect.maxY {
                return diagnosticLookup[lineNumber]?.message
            }
            if lineRect.minY > yInTextView {
                return nil
            }
            lineNumber += 1
            lineStart = NSMaxRange(lineRange)
        }

        return nil
    }
}

private final class LatexTextView: NSTextView {
    var shortcutCommands: [EditorShortcutCommand] = []
    var onSaveRequested: (() -> Void)?
    var diagnostics: [EditorLineDiagnostic] = [] {
        didSet {
            diagnosticLookup = Dictionary(uniqueKeysWithValues: diagnostics.map { ($0.line, $0) })
            needsDisplay = true
        }
    }
    private var diagnosticLookup: [Int: EditorLineDiagnostic] = [:]
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        toolTip = diagnosticMessage(at: point)
        super.mouseMoved(with: event)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawDiagnosticHighlights(in: rect)
    }

    private func drawDiagnosticHighlights(in rect: NSRect) {
        guard
            diagnosticLookup.isEmpty == false,
            let layoutManager
        else {
            return
        }

        for diagnostic in diagnostics where diagnostic.severity == .error {
            guard let lineRange = rangeForLine(diagnostic.line) else { continue }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { continue }

            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            lineRect.origin.x = 0
            lineRect.origin.y += textContainerOrigin.y
            lineRect.size.width = bounds.width
            lineRect = lineRect.insetBy(dx: 0, dy: -1)
            guard lineRect.intersects(rect) else { continue }

            EditorDiagnosticColors.error.setFill()
            NSRect(x: 0, y: lineRect.minY + 1, width: 3, height: max(2, lineRect.height - 2)).fill()
        }
    }

    private func diagnosticMessage(at point: NSPoint) -> String? {
        guard
            let layoutManager,
            let textContainer,
            diagnosticLookup.isEmpty == false
        else {
            return nil
        }

        var containerPoint = point
        containerPoint.x -= textContainerOrigin.x
        containerPoint.y -= textContainerOrigin.y
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let line = lineNumber(forCharacterAt: characterIndex)
        return diagnosticLookup[line]?.message
    }

    private func rangeForLine(_ targetLine: Int) -> NSRange? {
        let targetLine = max(1, targetLine)
        let nsText = string as NSString
        guard nsText.length > 0 else { return targetLine == 1 ? NSRange(location: 0, length: 0) : nil }

        var line = 1
        var location = 0
        while location < nsText.length {
            let range = nsText.lineRange(for: NSRange(location: location, length: 0))
            if line == targetLine {
                return range
            }
            let nextLocation = NSMaxRange(range)
            if nextLocation <= location {
                break
            }
            location = nextLocation
            line += 1
        }

        return nil
    }

    private func lineNumber(forCharacterAt characterIndex: Int) -> Int {
        let nsText = string as NSString
        let clampedIndex = min(max(0, characterIndex), nsText.length)
        var line = 1
        var location = 0
        while location < clampedIndex, location < nsText.length {
            let range = nsText.lineRange(for: NSRange(location: location, length: 0))
            let nextLocation = NSMaxRange(range)
            guard nextLocation <= clampedIndex, nextLocation > location else { break }
            location = nextLocation
            line += 1
        }
        return line
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        let relevantModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommand = relevantModifiers.contains(.command)
        let hasShift = relevantModifiers.contains(.shift)
        let onlySupportedModifiers = relevantModifiers.isSubset(of: [.command, .shift])
        let pressedKey = event.charactersIgnoringModifiers?.lowercased()

        if hasCommand, onlySupportedModifiers, let pressedKey {
            if pressedKey == "s", hasShift == false {
                guard let onSaveRequested else {
                    return super.performKeyEquivalent(with: event)
                }
                onSaveRequested()
                return true
            }
            if pressedKey == "f", hasShift == false {
                showFindPanel()
                return true
            }
            if hasShift == false, (pressedKey == "/" || event.keyCode == 44) {
                return toggleCommentOnSelectedLines()
            }
            if isReservedAppShortcut(key: pressedKey, usesShift: hasShift) {
                return super.performKeyEquivalent(with: event)
            }
            if let command = shortcutCommands.first(where: { matches($0, key: pressedKey, usesShift: hasShift) }) {
                if applyShortcut(command.template) {
                    return true
                }
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    private func matches(_ command: EditorShortcutCommand, key: String, usesShift: Bool) -> Bool {
        let shortcutKey = command.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return shortcutKey == key && command.usesShift == usesShift
    }

    private func isReservedAppShortcut(key: String, usesShift: Bool) -> Bool {
        switch (key, usesShift) {
        case ("s", false), ("f", false), ("g", false), ("g", true), ("r", false), ("o", false), ("w", false), ("w", true), ("e", true):
            return true
        default:
            return false
        }
    }

    private func showFindPanel() {
        window?.makeFirstResponder(self)
        let menuItem = NSMenuItem()
        menuItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        performFindPanelAction(menuItem)
    }

    private func applyShortcut(_ template: String) -> Bool {
        let marker = "$SELECTION$"
        guard let storage = textStorage else { return false }

        let source = storage.string as NSString
        let selected = clampedSelectedRange(for: source)
        let selectedText = selected.length > 0 ? source.substring(with: selected) : ""
        let markerRange = (template as NSString).range(of: marker)

        let replacement: String
        let selectionAfterInsert: NSRange
        if markerRange.location != NSNotFound {
            replacement = template.replacingOccurrences(of: marker, with: selectedText)
            if selected.length > 0 {
                let replacementLocation = selected.location + markerRange.location
                selectionAfterInsert = NSRange(location: replacementLocation, length: (selectedText as NSString).length)
            } else {
                selectionAfterInsert = NSRange(location: selected.location + markerRange.location, length: 0)
            }
        } else {
            replacement = template
            selectionAfterInsert = NSRange(location: selected.location + (replacement as NSString).length, length: 0)
        }

        guard shouldChangeText(in: selected, replacementString: replacement) else { return false }
        storage.replaceCharacters(in: selected, with: replacement)
        didChangeText()

        setClampedSelectedRange(selectionAfterInsert)
        return true
    }

    private func toggleCommentOnSelectedLines() -> Bool {
        guard let storage = textStorage else { return false }
        let source = storage.string as NSString
        let selection = clampedSelectedRange(for: source)
        let length = source.length
        guard length > 0 else { return false }

        let selectionStart = min(max(selection.location, 0), length)
        let selectionEndLocation: Int
        if selection.length > 0 {
            selectionEndLocation = min(length - 1, max(selectionStart, selection.location + selection.length - 1))
        } else {
            selectionEndLocation = min(length - 1, selectionStart)
        }

        let firstLineRange = source.lineRange(for: NSRange(location: selectionStart, length: 0))
        let lastLineRange = source.lineRange(for: NSRange(location: selectionEndLocation, length: 0))
        let blockStart = firstLineRange.location
        let blockEnd = NSMaxRange(lastLineRange)
        let blockRange = NSRange(location: blockStart, length: blockEnd - blockStart)
        let blockText = source.substring(with: blockRange)

        let lines = blockText.components(separatedBy: "\n")
        let nonEmptyLines = lines.filter { $0.isEmpty == false }
        guard nonEmptyLines.isEmpty == false else { return false }

        let shouldUncomment = nonEmptyLines.allSatisfy { isCommentedLine($0) }
        let transformed = lines.map { transformLine($0, uncomment: shouldUncomment) }.joined(separator: "\n")

        guard shouldChangeText(in: blockRange, replacementString: transformed) else { return false }
        storage.replaceCharacters(in: blockRange, with: transformed)
        didChangeText()

        let transformedLength = (transformed as NSString).length
        if selection.length > 0 {
            setClampedSelectedRange(NSRange(location: blockStart, length: transformedLength))
        } else {
            let offsetInLine = max(0, selectionStart - blockStart)
            let originalLine = lines.first ?? ""
            let adjustment = caretAdjustmentForToggle(
                line: originalLine,
                caretOffsetInLine: offsetInLine,
                uncommenting: shouldUncomment
            )
            let newLocation = min(blockStart + transformedLength, max(blockStart, selectionStart + adjustment))
            setClampedSelectedRange(NSRange(location: newLocation, length: 0))
        }

        return true
    }

    private func isCommentedLine(_ line: String) -> Bool {
        guard line.isEmpty == false else { return false }
        let indentCount = line.prefix { $0 == " " || $0 == "\t" }.count
        let remainder = line.dropFirst(indentCount)
        return remainder.hasPrefix("%")
    }

    private func transformLine(_ line: String, uncomment: Bool) -> String {
        guard line.isEmpty == false else { return line }

        let indentCount = line.prefix { $0 == " " || $0 == "\t" }.count
        let indent = String(line.prefix(indentCount))
        var remainder = String(line.dropFirst(indentCount))

        if uncomment {
            guard remainder.hasPrefix("%") else { return line }
            remainder.removeFirst()
            if remainder.hasPrefix(" ") {
                remainder.removeFirst()
            }
            return indent + remainder
        } else {
            return indent + "% " + remainder
        }
    }

    private func caretAdjustmentForToggle(line: String, caretOffsetInLine: Int, uncommenting: Bool) -> Int {
        let indentCount = line.prefix { $0 == " " || $0 == "\t" }.count
        if uncommenting {
            var removed = 0
            let remainder = String(line.dropFirst(indentCount))
            if remainder.hasPrefix("%") {
                removed = 1
                if remainder.dropFirst().hasPrefix(" ") {
                    removed = 2
                }
            }
            guard caretOffsetInLine > indentCount else { return 0 }
            return -min(removed, caretOffsetInLine - indentCount)
        } else {
            return caretOffsetInLine > indentCount ? 2 : 0
        }
    }

    private func clampedSelectedRange(for source: NSString) -> NSRange {
        clampedRange(selectedRange(), maxLength: source.length)
    }

    private func clampedRange(_ range: NSRange, maxLength: Int) -> NSRange {
        guard range.location != NSNotFound else {
            return NSRange(location: maxLength, length: 0)
        }

        let location = min(max(0, range.location), maxLength)
        let length = min(max(0, range.length), max(0, maxLength - location))
        return NSRange(location: location, length: length)
    }

    private func setClampedSelectedRange(_ range: NSRange) {
        let clamped = clampedRange(range, maxLength: (string as NSString).length)
        guard NSEqualRanges(selectedRange(), clamped) == false else { return }
        setSelectedRange(clamped)
    }
}

private final class LineSnappingClipView: NSClipView {
    weak var trackedTextView: NSTextView?

    override var isOpaque: Bool { false }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrained = super.constrainBoundsRect(proposedBounds)
        guard
            let textView = trackedTextView,
            let layoutManager = textView.layoutManager,
            let font = textView.font
        else {
            return constrained
        }

        let lineHeight = layoutManager.defaultLineHeight(for: font)
        guard lineHeight > 0 else {
            return constrained
        }

        let verticalInset = textView.textContainerInset.height
        let translatedY = constrained.origin.y - verticalInset
        let currentTranslatedY = bounds.origin.y - verticalInset
        let proposedLineOffset = translatedY / lineHeight
        let currentLineOffset = currentTranslatedY / lineHeight

        let snappedLineOffset: CGFloat
        if proposedLineOffset > currentLineOffset {
            // Scrolling down: only reveal the next line once a full line delta is reached.
            snappedLineOffset = floor(proposedLineOffset)
        } else if proposedLineOffset < currentLineOffset {
            // Scrolling up: only reveal the previous line once a full line delta is reached.
            snappedLineOffset = ceil(proposedLineOffset)
        } else {
            snappedLineOffset = proposedLineOffset
        }

        let snappedY = snappedLineOffset * lineHeight + verticalInset
        let minY = documentRect.minY
        let maxY = max(minY, documentRect.maxY - constrained.height)
        constrained.origin.y = min(max(snappedY, minY), maxY)
        return constrained
    }
}

private struct SyntaxPalette {
    let base: NSColor
    let command: NSColor
    let environment: NSColor
    let math: NSColor
    let comment: NSColor
    let caret: NSColor

    init(theme: InterfaceTheme, colors: EditorSyntaxColors) {
        switch theme {
        case .light, .clearLight:
            base = NSColor(white: 0.14, alpha: 1)
            command = Self.resolvedColor(colors.command)
            environment = Self.resolvedColor(colors.environment)
            math = Self.resolvedColor(colors.math)
            comment = Self.resolvedColor(colors.comment)
            caret = NSColor(white: 0.18, alpha: 1)
        case .dark, .clearDark, .clear:
            base = NSColor(white: 0.90, alpha: 1)
            command = Self.resolvedColor(colors.command)
            environment = Self.resolvedColor(colors.environment)
            math = Self.resolvedColor(colors.math)
            comment = Self.resolvedColor(colors.comment)
            caret = NSColor(white: 0.94, alpha: 1)
        }
    }

    private static func resolvedColor(_ color: Color) -> NSColor {
        let candidate = NSColor(color)
        return candidate.usingColorSpace(.extendedSRGB) ?? candidate.usingColorSpace(.sRGB) ?? candidate
    }
}

struct EditorSyntaxColors: Equatable {
    var command: Color
    var environment: Color
    var math: Color
    var comment: Color

    static func defaults(for theme: InterfaceTheme) -> Self {
        switch theme {
        case .light, .clearLight:
            return .init(
                command: Color(nsColor: NSColor(red: 0.49, green: 0.12, blue: 0.64, alpha: 1)),
                environment: Color(nsColor: NSColor(red: 0.62, green: 0.19, blue: 0.56, alpha: 1)),
                math: Color(nsColor: NSColor(red: 0.16, green: 0.34, blue: 0.86, alpha: 1)),
                comment: Color(nsColor: NSColor(red: 0.20, green: 0.53, blue: 0.30, alpha: 1))
            )
        case .dark, .clearDark, .clear:
            return .init(
                command: Color(nsColor: NSColor(red: 0.82, green: 0.62, blue: 0.99, alpha: 1)),
                environment: Color(nsColor: NSColor(red: 0.92, green: 0.70, blue: 0.90, alpha: 1)),
                math: Color(nsColor: NSColor(red: 0.51, green: 0.71, blue: 0.99, alpha: 1)),
                comment: Color(nsColor: NSColor(red: 0.53, green: 0.82, blue: 0.61, alpha: 1))
            )
        }
    }
}
