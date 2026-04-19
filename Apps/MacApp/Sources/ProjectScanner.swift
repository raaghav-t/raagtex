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
    struct Snapshot {
        let texFiles: [String]
        let fileTree: [ProjectFileNode]
    }

    private struct DirectoryEntry {
        let url: URL
        let name: String
        let isDirectory: Bool
    }

    static func scan(projectRoot: URL) -> Snapshot {
        let normalizedRoot = projectRoot.standardizedFileURL
        let rootPath = normalizedRoot.path
        let rootPathPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        var texFiles: [String] = []
        let fileTree = buildNodes(
            in: normalizedRoot,
            projectRootPathPrefix: rootPathPrefix,
            depth: 0,
            maxDepth: 12,
            texFiles: &texFiles
        )
        texFiles.sort()
        return Snapshot(texFiles: texFiles, fileTree: fileTree)
    }

    private static func buildNodes(
        in directory: URL,
        projectRootPathPrefix: String,
        depth: Int,
        maxDepth: Int,
        texFiles: inout [String]
    ) -> [ProjectFileNode] {
        guard depth <= maxDepth else { return [] }

        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        guard
            let children = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        else {
            return []
        }

        let entries = children.map { childURL -> DirectoryEntry in
            let values = try? childURL.resourceValues(forKeys: keys)
            return DirectoryEntry(
                url: childURL,
                name: values?.name ?? childURL.lastPathComponent,
                isDirectory: values?.isDirectory ?? false
            )
        }

        let sorted = entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && rhs.isDirectory == false
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var nodes: [ProjectFileNode] = []
        nodes.reserveCapacity(sorted.count)

        for entry in sorted {
            let relativePath = relativePath(for: entry.url, projectRootPathPrefix: projectRootPathPrefix)
            if entry.isDirectory {
                if shouldSkipDirectory(relativePath: relativePath) {
                    continue
                }
                let childNodes = buildNodes(
                    in: entry.url,
                    projectRootPathPrefix: projectRootPathPrefix,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    texFiles: &texFiles
                )
                nodes.append(ProjectFileNode(
                    relativePath: relativePath,
                    displayName: entry.name,
                    isDirectory: true,
                    children: childNodes
                ))
                continue
            }

            if entry.url.pathExtension.caseInsensitiveCompare("tex") == .orderedSame {
                texFiles.append(relativePath)
            }

            if isSupplementaryArtifact(relativePath: relativePath) {
                continue
            }

            nodes.append(ProjectFileNode(
                relativePath: relativePath,
                displayName: entry.name,
                isDirectory: false,
                children: nil
            ))
        }

        return nodes
    }

    private static func relativePath(for url: URL, projectRootPathPrefix: String) -> String {
        let path = url.path
        guard path.hasPrefix(projectRootPathPrefix) else {
            return url.lastPathComponent
        }
        return String(path.dropFirst(projectRootPathPrefix.count))
    }

    private static func shouldSkipDirectory(relativePath: String) -> Bool {
        let lower = relativePath.lowercased()
        return lower.hasPrefix("_minted-") || lower.contains("/_minted-")
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

        if lower.hasPrefix("_minted-") || lower.contains("/_minted-") {
            return true
        }

        return false
    }
}
