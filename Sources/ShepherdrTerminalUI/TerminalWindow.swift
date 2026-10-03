import AppKit
import SwiftUI
import SwiftTerm
import ShepherdrCore

private typealias TerminalViewState<Value> = SwiftUI.State<Value>

@MainActor
public struct TerminalWindow: View {
    @TerminalViewState<TerminalStore> private var store: TerminalStore

    public init(target: TerminalTarget) { _store = SwiftUI.State(initialValue: TerminalStore(target: target)) }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                Text(store.target.machine.name).fontWeight(.medium)
                Text("· \(store.target.machine.session) · \(store.target.workspace)").foregroundStyle(.secondary)
                Spacer()
                if store.status == .connecting { ProgressView().controlSize(.small) }
                Text(statusLabel).foregroundStyle(store.status == .interactive ? Color.green : .secondary)
            }
            .font(.callout).padding(12).background(.bar)
            Divider()
            if let message = store.message {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message).font(.callout).textSelection(.enabled)
                    if let detail = store.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            .lineLimit(5).help(detail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                Divider()
            }
            TerminalSurface(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text(store.status == .interactive ? "Keyboard and paste go to this existing terminal." : "Observe the live terminal. Enable Input to interact.")
                Spacer()
                Text("Closing this window detaches only.")
            }
            .font(.caption).foregroundStyle(.secondary).padding(8).background(.bar)
        }
        .frame(minWidth: 640, minHeight: 420)
        .navigationTitle("\(store.target.title) — \(store.target.machine.name)")
        .toolbar {
            ToolbarItem {
                Button(store.status == .interactive ? "Observe Only" : "Enable Input",
                       systemImage: store.status == .interactive ? "eye" : "keyboard") {
                    store.open(mode: store.status == .interactive ? .observe : .control)
                }
                .disabled(store.status == .connecting)
                .help("Connect without taking control away from another terminal client")
            }
            ToolbarItem {
                Button("Reconnect", systemImage: "arrow.clockwise") { store.open(mode: store.mode) }
                    .disabled(store.status == .connecting)
            }
            ToolbarItem {
                Button("Disconnect", systemImage: "eject") { store.disconnect() }
                    .disabled(store.status == .disconnected || store.status == .ended)
            }
        }
        .onDisappear { store.disconnect() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in store.disconnect() }
    }

    private var statusLabel: String {
        switch store.status {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .observing: "Observing"
        case .interactive: "Input enabled"
        case .ended: "Detached"
        case .failed: "Connection failed"
        }
    }
}

@MainActor
private struct TerminalSurface: NSViewRepresentable {
    let store: TerminalStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 520),
                                          font: .monospacedSystemFont(ofSize: 13, weight: .regular))
        view.nativeBackgroundColor = .textBackgroundColor
        view.nativeForegroundColor = .textColor
        view.allowMouseReporting = false // Selection and copy remain native; input uses the keyboard.
        view.terminalDelegate = context.coordinator
        let coordinator = context.coordinator
        store.display = { [weak view, weak coordinator] frame in
            guard let view else { return }
            coordinator?.applyingFrame = true
            if view.getTerminal().cols != frame.columns || view.getTerminal().rows != frame.rows {
                view.resize(cols: frame.columns, rows: frame.rows)
            }
            view.feed(byteArray: Array(frame.bytes)[...])
            coordinator?.applyingFrame = false
        }
        store.resetDisplay = { [weak view] in view?.feed(text: "\u{1b}c") }
        store.resize(columns: view.getTerminal().cols, rows: view.getTerminal().rows)
        store.open()
        return view
    }

    func updateNSView(_ view: SwiftTerm.TerminalView, context: Context) {
        view.nativeBackgroundColor = .textBackgroundColor
        view.nativeForegroundColor = .textColor
        if store.status == .interactive, !context.coordinator.wasInteractive {
            view.window?.makeFirstResponder(view)
        }
        context.coordinator.wasInteractive = store.status == .interactive
    }

    static func dismantleNSView(_ view: SwiftTerm.TerminalView, coordinator: Coordinator) {
        coordinator.store.disconnect()
        coordinator.store.display = nil
        coordinator.store.resetDisplay = nil
        view.terminalDelegate = nil
    }

    @MainActor final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate {
        let store: TerminalStore
        var applyingFrame = false
        var wasInteractive = false
        init(store: TerminalStore) { self.store = store }
        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            if !applyingFrame { store.resize(columns: newCols, rows: newRows) }
        }
        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) { store.send(.bytes(Data(data))) }
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased()) else { return }
            NSWorkspace.shared.open(url)
        }
        func bell(source: SwiftTerm.TerminalView) {}
        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}
