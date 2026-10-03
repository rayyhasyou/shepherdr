import SwiftUI
import ShepherdrCore
import ShepherdrTerminalUI

// Use the public State property wrapper explicitly. This also supports SDKs that
// export a same-named macro unavailable to standalone command-line toolchains.
typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct ShepherdrApp: App {
    @ViewState<ClusterStore> private var store = ClusterStore()
    @ViewState<SessionOrderStore> private var sessionOrder = SessionOrderStore()

    var body: some Scene {
        Window("Shepherdr", id: "cluster") {
            DashboardView(store: store, sessionOrder: sessionOrder)
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

        WindowGroup("Terminal", id: "terminal", for: TerminalTarget.self) { $target in
            if let target { TerminalWindow(target: target) }
        }
        .defaultSize(width: 1_000, height: 680)
    }
}
