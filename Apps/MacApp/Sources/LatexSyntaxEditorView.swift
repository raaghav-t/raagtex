import AppKit
import Shared
import SwiftUI

struct LatexSyntaxEditorView: NSViewRepresentable {
    @Binding var text: String
    var autocorrectionEnabled: Bool
    var syntaxColoringEnabled: Bool
    var interfaceTheme: InterfaceTheme
    var syntaxColors: EditorSyntaxColors
    var showLineNumbers: Bool
    var shortcutCommands: [EditorShortcutCommand]
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
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
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
            shortcutCommands: shortcutCommands,
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
            shortcutCommands: shortcutCommands,
            onSaveRequested: onSaveRequested,
            forceTextUpdate: false
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var lineNumberRulerView: LineNumberRulerView?

        private var isProgrammaticChange = false
        private var cachedSyntaxColoringEnabled = true
        private var cachedTheme: InterfaceTheme = .dark
        private var cachedSyntaxColors = EditorSyntaxColors.defaults(for: .dark)
        private var cachedIgnoredWords: Set<String> = []

        init(text: Binding<String>) {
            self.text = text
        }

        func applyConfiguration(
            text newText: String,
            autocorrectionEnabled: Bool,
            syntaxColoringEnabled: Bool,
            interfaceTheme: InterfaceTheme,
            syntaxColors: EditorSyntaxColors,
            showLineNumbers: Bool,
            shortcutCommands: [EditorShortcutCommand],
            onSaveRequested: (() -> Void)?,
            forceTextUpdate: Bool
        ) {
            guard let textView, let scrollView else { return }

            textView.isEditable = true
            textView.isSelectable = true
            textView.isAutomaticSpellingCorrectionEnabled = autocorrectionEnabled
            textView.isContinuousSpellCheckingEnabled = autocorrectionEnabled
            (textView as? LatexTextView)?.shortcutCommands = shortcutCommands
            (textView as? LatexTextView)?.onSaveRequested = onSaveRequested
            scrollView.rulersVisible = showLineNumbers
            scrollView.hasVerticalRuler = showLineNumbers
            lineNumberRulerView?.isHidden = showLineNumbers == false

            let needsTextSync = forceTextUpdate || textView.string != newText
            let needsStyleRefresh =
                cachedSyntaxColoringEnabled != syntaxColoringEnabled ||
                cachedTheme != interfaceTheme ||
                cachedSyntaxColors != syntaxColors

            cachedSyntaxColoringEnabled = syntaxColoringEnabled
            cachedTheme = interfaceTheme
            cachedSyntaxColors = syntaxColors

            if needsTextSync {
                isProgrammaticChange = true
                let selectedRange = textView.selectedRange()
                textView.string = newText
                applyHighlighting(
                    to: textView,
                    syntaxColoringEnabled: syntaxColoringEnabled,
                    theme: interfaceTheme,
                    syntaxColors: syntaxColors
                )
                let maxLength = (newText as NSString).length
                let clampedLocation = min(selectedRange.location, maxLength)
                let clampedLength = min(selectedRange.length, max(0, maxLength - clampedLocation))
                textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
                isProgrammaticChange = false
                lineNumberRulerView?.invalidateLineNumbers()
            } else if needsStyleRefresh {
                applyHighlighting(
                    to: textView,
                    syntaxColoringEnabled: syntaxColoringEnabled,
                    theme: interfaceTheme,
                    syntaxColors: syntaxColors
                )
            }

            if autocorrectionEnabled {
                updateIgnoredWords(in: textView, source: textView.string)
            } else if cachedIgnoredWords.isEmpty == false {
                NSSpellChecker.shared.setIgnoredWords([], inSpellDocumentWithTag: textView.spellCheckerDocumentTag)
                cachedIgnoredWords.removeAll()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            guard isProgrammaticChange == false else { return }

            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            applyHighlighting(
                to: textView,
                syntaxColoringEnabled: cachedSyntaxColoringEnabled,
                theme: cachedTheme,
                syntaxColors: cachedSyntaxColors
            )
            lineNumberRulerView?.invalidateLineNumbers()
            updateIgnoredWords(in: textView, source: textView.string)
        }

        private func applyHighlighting(
            to textView: NSTextView,
            syntaxColoringEnabled: Bool,
            theme: InterfaceTheme,
            syntaxColors: EditorSyntaxColors
        ) {
            let source = textView.string
            let attributed = NSMutableAttributedString(string: source)
            let fullRange = NSRange(location: 0, length: (source as NSString).length)

            let palette = SyntaxPalette(theme: theme, colors: syntaxColors)
            attributed.addAttributes(
                [
                    .foregroundColor: palette.base,
                    .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
                ],
                range: fullRange
            )

            if syntaxColoringEnabled {
                applyRegex(#"\\[A-Za-z@]+\*?"#, color: palette.command, on: attributed, source: source, options: [.anchorsMatchLines])
                applyRegex(#"\\(begin|end)\s*\{[^}\n]+\}"#, color: palette.environment, on: attributed, source: source, options: [.anchorsMatchLines])
                applyRegex(#"\$[^$\n]*\$"#, color: palette.math, on: attributed, source: source, options: [.anchorsMatchLines])
                applyRegex(#"\\\[[\s\S]*?\\\]"#, color: palette.math, on: attributed, source: source, options: [.dotMatchesLineSeparators])
                applyRegex(#"\\\([\s\S]*?\\\)"#, color: palette.math, on: attributed, source: source, options: [.dotMatchesLineSeparators])
                applyRegex(#"%.*$"#, color: palette.comment, on: attributed, source: source, options: [.anchorsMatchLines])
            }

            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributed)
            textView.typingAttributes = [
                .foregroundColor: palette.base,
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            ]

            let maxLength = (textView.string as NSString).length
            let clampedLocation = min(selectedRange.location, maxLength)
            let clampedLength = min(selectedRange.length, max(0, maxLength - clampedLocation))
            textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
            textView.insertionPointColor = palette.caret
        }

        private func applyRegex(
            _ pattern: String,
            color: NSColor,
            on attributed: NSMutableAttributedString,
            source: String,
            options: NSRegularExpression.Options
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let range = NSRange(location: 0, length: (source as NSString).length)
            regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
                attributed.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
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
            let fullRange = NSRange(location: 0, length: nsSource.length)

            if let commandRegex = try? NSRegularExpression(pattern: #"\\[A-Za-z@]+\*?"#, options: [.anchorsMatchLines]) {
                commandRegex.enumerateMatches(in: source, options: [], range: fullRange) { match, _, _ in
                    guard let match, match.range.location != NSNotFound else { return }
                    let rawCommand = nsSource.substring(with: match.range)
                    words.insert(rawCommand)
                    if rawCommand.first == "\\" {
                        words.insert(String(rawCommand.dropFirst()))
                    }
                }
            }

            if let environmentRegex = try? NSRegularExpression(pattern: #"\\(begin|end)\s*\{([^}\n]+)\}"#, options: [.anchorsMatchLines]) {
                environmentRegex.enumerateMatches(in: source, options: [], range: fullRange) { match, _, _ in
                    guard
                        let match,
                        match.numberOfRanges > 2,
                        match.range(at: 2).location != NSNotFound
                    else { return }
                    words.insert(nsSource.substring(with: match.range(at: 2)))
                }
            }

            return words
        }
    }
}

final class LineNumberRulerView: NSRulerView {
    weak var trackedTextView: NSTextView?
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

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
                    in: bounds
                )
            }

            lineNumber += 1
            lineStart = NSMaxRange(lineRange)
        }
    }

    private func drawLineNumber(_ value: String, atY y: CGFloat, in bounds: NSRect) {
        let label = value as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let labelSize = label.size(withAttributes: attributes)
        let x = bounds.width - labelSize.width - 8
        label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
    }
}

private final class LatexTextView: NSTextView {
    var shortcutCommands: [EditorShortcutCommand] = []
    var onSaveRequested: (() -> Void)?

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
        case ("s", false), ("r", false), ("o", false), ("w", false), ("w", true), ("e", true):
            return true
        default:
            return false
        }
    }

    private func applyShortcut(_ template: String) -> Bool {
        let marker = "$SELECTION$"
        let selected = selectedRange()
        guard let storage = textStorage else { return false }

        let source = storage.string as NSString
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

        setSelectedRange(selectionAfterInsert)
        return true
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
        case .light, .clear:
            base = NSColor(white: 0.14, alpha: 1)
            command = NSColor(colors.command)
            environment = NSColor(colors.environment)
            math = NSColor(colors.math)
            comment = NSColor(colors.comment)
            caret = NSColor(white: 0.18, alpha: 1)
        case .dark:
            base = NSColor(white: 0.90, alpha: 1)
            command = NSColor(colors.command)
            environment = NSColor(colors.environment)
            math = NSColor(colors.math)
            comment = NSColor(colors.comment)
            caret = NSColor(white: 0.94, alpha: 1)
        }
    }
}

struct EditorSyntaxColors: Equatable {
    var command: Color
    var environment: Color
    var math: Color
    var comment: Color

    static func defaults(for theme: InterfaceTheme) -> Self {
        switch theme {
        case .light, .clear:
            return .init(
                command: Color(nsColor: NSColor(red: 0.49, green: 0.12, blue: 0.64, alpha: 1)),
                environment: Color(nsColor: NSColor(red: 0.62, green: 0.19, blue: 0.56, alpha: 1)),
                math: Color(nsColor: NSColor(red: 0.16, green: 0.34, blue: 0.86, alpha: 1)),
                comment: Color(nsColor: NSColor(red: 0.20, green: 0.53, blue: 0.30, alpha: 1))
            )
        case .dark:
            return .init(
                command: Color(nsColor: NSColor(red: 0.82, green: 0.62, blue: 0.99, alpha: 1)),
                environment: Color(nsColor: NSColor(red: 0.92, green: 0.70, blue: 0.90, alpha: 1)),
                math: Color(nsColor: NSColor(red: 0.51, green: 0.71, blue: 0.99, alpha: 1)),
                comment: Color(nsColor: NSColor(red: 0.53, green: 0.82, blue: 0.61, alpha: 1))
            )
        }
    }
}
