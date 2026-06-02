import Darwin
import Foundation

final class DirectoryWatcher {
    private let url: URL
    private let queue: DispatchQueue
    private let onChange: @Sendable () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []

    init(url: URL, queue: DispatchQueue = DispatchQueue(label: "latex-cockpit.filewatch"), onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.queue = queue
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        for directoryURL in watchedDirectoryURLs(root: url) {
            startWatching(directoryURL)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func startWatching(_ directoryURL: URL) {
        let fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source.setEventHandler { [onChange] in
            onChange()
        }

        source.setCancelHandler { [fileDescriptor] in
            close(fileDescriptor)
        }

        sources.append(source)
        source.resume()
    }

    private func watchedDirectoryURLs(root: URL) -> [URL] {
        let fileManager = FileManager.default
        var directories = [root.standardizedFileURL]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return directories
        }

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }

            if shouldSkipDirectory(fileURL) {
                enumerator.skipDescendants()
                continue
            }

            directories.append(fileURL.standardizedFileURL)
        }

        return directories
    }

    private func shouldSkipDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name == ".git" ||
            name == ".build" ||
            name == ".swiftpm" ||
            name == "DerivedData" ||
            name.hasPrefix("_minted-")
    }
}
