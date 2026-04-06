import Darwin
import Foundation

final class DirectoryWatcher {
    private let url: URL
    private let queue: DispatchQueue
    private let onChange: @Sendable () -> Void
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?

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

        fileDescriptor = open(url.path, O_EVTONLY)
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

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
