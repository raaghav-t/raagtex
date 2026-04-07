import SwiftUI

struct IOSRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("raagtex Viewer") {
                    Label("Companion scaffold is ready", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    Text("V2 will pair with macOS to receive live PDF updates and compile-state summaries.")
                        .foregroundStyle(.secondary)
                }

                Section("Planned Companion Capabilities") {
                    Label("Live PDF refresh", systemImage: "doc.richtext")
                    Label("Compile status cards", systemImage: "exclamationmark.bubble")
                    Label("Page-change summary", systemImage: "list.bullet.rectangle")
                }
            }
            .navigationTitle("Viewer")
        }
    }
}

#Preview {
    IOSRootView()
}
