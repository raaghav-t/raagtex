import SwiftUI

@main
struct RaagtexMacApp: App {
    @StateObject private var viewModel = MacRootViewModel()

    var body: some Scene {
        WindowGroup("raagtex") {
            MacRootView()
                .environmentObject(viewModel)
        }

        WindowGroup("Viewer", id: ViewerWindow.sceneID) {
            ViewerWindowView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 900, height: 700)
    }
}
