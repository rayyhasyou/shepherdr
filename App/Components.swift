import SwiftUI
import ShepherdrCore

struct ConnectionDot: View {
    let state: ConnectionState
    private var color: Color {
        switch state {
        case .online: .green
        case .loading, .disabled: .secondary
        default: .orange
        }
    }
    var body: some View {
        Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
    }
}

struct StateLabel: View {
    let state: AgentState
    var stale = false
    private var color: Color {
        guard !stale else { return .secondary }
        return switch state {
        case .blocked: .orange
        case .working: .blue
        case .done: .green
        case .idle, .unknown: .secondary
        }
    }
    var body: some View {
        Label(state.title, systemImage: state.symbol)
            .foregroundStyle(color)
            .fontWeight(state == .blocked && !stale ? .medium : .regular)
            .help(state == .blocked ? "Herdr reports this agent needs attention" : state.title)
    }
}

struct NoticeView: View {
    let title: String
    let message: String
    let detail: String?
    @ViewState<Bool> private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "exclamationmark.circle").fontWeight(.medium)
            Text(message).foregroundStyle(.secondary).textSelection(.enabled)
            if let detail {
                DisclosureGroup("Details", isExpanded: $expanded) {
                    Text(detail).font(.caption).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.quaternary.opacity(0.3))
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct MachineHeader: View {
    let state: MachineState
    @Binding var workspaceID: String?
    @ViewState<Bool> private var showWorkspaces = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ConnectionDot(state: state.connection)
                Text(state.connection.title).fontWeight(.medium)
                Text("· \(state.machine.target ?? "This Mac") · \(state.machine.session) session")
                    .foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if let snapshot = state.snapshot {
                    Text("Herdr \(snapshot.version)").foregroundStyle(.tertiary)
                }
            }
            .font(.callout).padding(.horizontal, 20).padding(.vertical, 12)
            if let failure = state.failure {
                NoticeView(title: state.isStale ? "Showing last known data" : state.connection.title,
                           message: failure.message, detail: failure.detail)
            }
            if state.isStale, let date = state.lastSuccess {
                Text("Last received \(date.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 8)
            }
            if let workspaces = state.snapshot?.workspaces, !workspaces.isEmpty {
                DisclosureGroup(isExpanded: $showWorkspaces) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(workspaces) { workspace in
                                HStack(spacing: 8) {
                                    Image(systemName: "folder").foregroundStyle(.secondary)
                                    Text(workspace.name).fontWeight(.medium).lineLimit(1)
                                    Text(workspace.directory ?? workspace.id)
                                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 8)
                                    Text("\(state.agents.filter { $0.workspaceID == workspace.id }.count) agents")
                                        .monospacedDigit()
                                    Text("· \(workspace.tabCount) tabs · \(workspace.paneCount) panes")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.callout).padding(.vertical, 5)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    .frame(maxHeight: min(CGFloat(workspaces.count) * 29, 155))
                } label: {
                    HStack {
                        Text("Workspaces (\(workspaces.count))").font(.callout).fontWeight(.medium)
                        Spacer()
                        Picker("Workspace", selection: $workspaceID) {
                            Text("All Workspaces").tag(String?.none)
                            ForEach(workspaces) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .onChange(of: workspaces.map(\.id)) {
                    if let workspaceID, !workspaces.contains(where: { $0.id == workspaceID }) { self.workspaceID = nil }
                }
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct AgentInspector: View {
    let row: AgentRow?

    var body: some View {
        if let row {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "terminal").font(.title).foregroundStyle(.secondary)
                        Text(row.name).font(.title2).fontWeight(.semibold)
                        StateLabel(state: row.agent.state, stale: row.isStale)
                        if row.isStale {
                            Label("Last known state", systemImage: "clock.badge.exclamationmark")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    field("Agent type", row.agent.kind)
                    field("Machine", row.machineName)
                    field("Workspace", row.workspace)
                    field("Tab", "\(row.agent.tabName) · \(row.agent.tabID)")
                    field("Pane", row.agent.paneID)
                    field("Directory", row.agent.directory ?? "Not reported")
                    if let summary = row.agent.summary { field("Summary", summary) }
                    if row.agent.isLaunchPending { field("Launch", "Pending in Herdr") }
                    if row.agent.state == .unknown { field("Reported state", row.agent.reportedState) }
                    Divider()
                    field("Terminal ID", row.id.terminalID)
                    if let date = row.lastSuccess {
                        field("Last received", date.formatted(date: .abbreviated, time: .standard))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .textSelection(.enabled)
            }
        } else {
            ContentUnavailableView("Agent Details", systemImage: "info.circle",
                                   description: Text("Select an agent to inspect its Herdr metadata."))
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
