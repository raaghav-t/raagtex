import Foundation

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
}
