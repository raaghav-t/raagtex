import Foundation

enum TemplateKind: String, CaseIterable, Identifiable {
    case document
    case style

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .document:
            return "Documents"
        case .style:
            return "Styles"
        }
    }

    var folderName: String {
        switch self {
        case .document:
            return "Documents"
        case .style:
            return "Styles"
        }
    }

    var defaultFileName: String {
        switch self {
        case .document:
            return "main.tex"
        case .style:
            return "note_style.tex"
        }
    }
}

enum TemplatePreviewMode: String, CaseIterable, Identifiable {
    case text
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .pdf:
            return "PDF"
        }
    }
}

struct TemplateEntry: Identifiable, Hashable {
    let kind: TemplateKind
    let fileURL: URL
    let lastModifiedAt: Date?
    let customDisplayName: String?

    var id: String {
        fileURL.standardizedFileURL.path
    }

    var fileName: String {
        fileURL.lastPathComponent
    }

    var displayName: String {
        if let customDisplayName {
            let trimmed = customDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return fileURL.deletingPathExtension().lastPathComponent
    }
}
