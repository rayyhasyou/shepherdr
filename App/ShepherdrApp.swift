import SwiftUI
import ShepherdrCore

// Use the public State property wrapper explicitly. This also supports SDKs that
// export a same-named macro unavailable to standalone command-line toolchains.
typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct ShepherdrApp: App {
    @ViewState<ClusterStore> private var store = ClusterStore()

    var body: some Scene {
        Window("Shepherdr", id: "cluster") {
            DashboardView(store: store)
                .frame(minWidth: 880, minHeight: 500)
        }
        .defaultSize(width: 1_180, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Cluster") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.isRefreshing)
            }
            CommandGroup(replacing: .help) {
                Link("Herdr Documentation", destination: URL(string: "https://herdr.dev/docs/")!)
            }
        }
    }
}
