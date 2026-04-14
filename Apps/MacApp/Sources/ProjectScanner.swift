import Foundation

struct ProjectFileNode: Identifiable, Hashable {
    let relativePath: String
    let displayName: String
    let isDirectory: Bool
    let children: [ProjectFileNode]?

    var id: String { relativePath }

    var isTexFile: Bool {
        isDirectory == false && relativePath.lowercased().hasSuffix(".tex")
    }
}

enum ProjectScanner {
    static func findTexFiles(projectRoot: URL) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var paths: [String] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() != "tex" {
                continue
            }

            let relative = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            paths.append(relative)
        }

        return paths.sorted()
    }

    static func buildFileTree(projectRoot: URL) -> [ProjectFileNode] {
        buildNodes(in: projectRoot, projectRoot: projectRoot, depth: 0, maxDepth: 12)
    }

    private static func buildNodes(
        in directory: URL,
        projectRoot: URL,
        depth: Int,
        maxDepth: Int
    ) -> [ProjectFileNode] {
        guard depth <= maxDepth else { return [] }

        let fm = FileManager.default
        guard
            let children = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        else {
            return []
        }

        let sorted = children.sorted { lhs, rhs in
            let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if lhsIsDirectory != rhsIsDirectory {
                return lhsIsDirectory && lhsIsDirectory != rhsIsDirectory
            }

            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        return sorted.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory ?? false

            let relativePath = url.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            if isDirectory {
                let childNodes = buildNodes(in: url, projectRoot: projectRoot, depth: depth + 1, maxDepth: maxDepth)
                return ProjectFileNode(
                    relativePath: relativePath,
                    displayName: url.lastPathComponent,
                    isDirectory: true,
                    children: childNodes
                )
            }

            if isSupplementaryArtifact(relativePath: relativePath) {
                return nil
            }

            return ProjectFileNode(
                relativePath: relativePath,
                displayName: url.lastPathComponent,
                isDirectory: false,
                children: nil
            )
        }
    }

    private static func isSupplementaryArtifact(relativePath: String) -> Bool {
        let lower = relativePath.lowercased()

        let hiddenSuffixes = [
            ".aux", ".log", ".out", ".toc", ".lof", ".lot",
            ".fls", ".fdb_latexmk", ".bbl", ".blg", ".bcf",
            ".run.xml", ".synctex.gz", ".synctex(busy)", ".xdv",
            ".nav", ".snm", ".vrb", ".acn", ".acr", ".alg",
            ".glg", ".glo", ".gls", ".ist", ".loa"
        ]

        if hiddenSuffixes.contains(where: { lower.hasSuffix($0) }) {
            return true
        }

        if lower.contains("/_minted-") {
            return true
        }

        return false
    }
}
