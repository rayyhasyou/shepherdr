import SwiftUI
import ShepherdrCore

struct DashboardView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var store: ClusterStore
    @Bindable var sessionOrder: SessionOrderStore
    @ViewState<String?> private var destination = "all"
    @ViewState<Agent.ID?> private var selection: Agent.ID? = nil
    @ViewState<String?> private var workspaceID: String? = nil
    @ViewState<String> private var search = ""
    @ViewState<String> private var stateFilter = "all"
    @ViewState<Bool> private var inspectorVisible = false
    @ViewState<[KeyPathComparator<AgentRow>]> private var sortOrder = [KeyPathComparator(\AgentRow.manualPriority)]
    @AppStorage("refreshSeconds") private var refreshSeconds = 5

    private var selectedMachine: MachineState? {
        store.machines.first { $0.id == destination }
    }
    private var scopedAgents: [AgentRow] {
        store.agents.filter { destination == "all" || $0.id.machineID == destination }
    }
    private var rows: [AgentRow] {
        sessionOrder.ranked(store.agents).filter {
            (destination == "all" || $0.id.machineID == destination)
            && (stateFilter == "all" || $0.agent.state.rawValue == stateFilter)
            && (workspaceID == nil || $0.agent.workspaceID == workspaceID)
            && $0.matches(search)
        }.sorted(using: sortOrder)
    }
    private var selectedRow: AgentRow? { store.agents.first { $0.id == selection } }
    private var isManualOrder: Bool { sortOrder.first == KeyPathComparator(\AgentRow.manualPriority) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if let failure = store.discoveryFailure, failure.state != .notInstalled {
                    NoticeView(title: "Saved machines could not be refreshed", message: failure.message,
                               detail: failure.detail)
                }
                if let machine = selectedMachine {
                    MachineHeader(state: machine, workspaceID: $workspaceID) { pane in
                        openWindow(id: "terminal", value: TerminalTarget(machine: machine.machine, terminalID: pane.terminalID,
                                                                       title: pane.title, workspace: pane.workspaceName))
                    }
                } else {
                    summary
                    if store.machines.contains(where: { $0.failure != nil }) {
                        clusterFailures
                    }
                }
                agentTable
                footer
            }
            .navigationTitle(selectedMachine?.machine.name ?? "All Agents")
            .searchable(text: $search, placement: .toolbar, prompt: "Search agents, projects, machines")
            .toolbar {
                ToolbarItemGroup {
                    Menu {
                        Button("Show My Order") { sortOrder = [KeyPathComparator(\AgentRow.manualPriority)] }
                        Button("Sort by State") { sortOrder = [KeyPathComparator(\AgentRow.priority), KeyPathComparator(\AgentRow.name)] }
                    } label: {
                        Label(isManualOrder ? "My Order" : "Column Sort", systemImage: "list.number")
                    }
                    .help("Return to your saved priorities or sort by lifecycle state")
                    Button("Raise Priority", systemImage: "arrow.up") { moveSelection(.up) }
                        .disabled(!canMove(selection, .up))
                        .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                        .help(isManualOrder ? "Move above the previous visible session (⌥⌘↑)" : "Choose Show My Order to change priorities")
                    Button("Lower Priority", systemImage: "arrow.down") { moveSelection(.down) }
                        .disabled(!canMove(selection, .down))
                        .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                        .help(isManualOrder ? "Move below the next visible session (⌥⌘↓)" : "Choose Show My Order to change priorities")
                }
                ToolbarItem {
                    Button("Open Terminal", systemImage: "terminal") {
                        if let selectedRow { openTerminal(selectedRow) }
                    }
                    .disabled(selectedRow == nil || selectedRow?.isStale == true)
                    .help("Open the selected agent’s live terminal")
                }
                ToolbarItem {
                    Picker("Agent state", selection: $stateFilter) {
                        Text("All States").tag("all")
                        ForEach(AgentState.allCases, id: \.rawValue) { state in
                            Text(state == .blocked ? "Blocked · Needs Attention" : state.title).tag(state.rawValue)
                        }
                    }
                    .help("Filter by Herdr lifecycle state")
                }
                ToolbarItem {
                    Button { Task { await store.refresh() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .help("Refresh every machine (⌘R)")
                }
                ToolbarItem {
                    Menu {
                        Picker("Automatic refresh", selection: $refreshSeconds) {
                            Text("Every 5 seconds").tag(5)
                            Text("Every 15 seconds").tag(15)
                            Text("Every 30 seconds").tag(30)
                            Text("Every minute").tag(60)
                            Text("Paused").tag(0)
                        }
                    } label: {
                        Label("Refresh Options", systemImage: "clock.arrow.circlepath")
                    }
                    .help("Automatic refresh options")
                }
                ToolbarItem {
                    Button { inspectorVisible.toggle() } label: {
                        Label("Agent Details", systemImage: "sidebar.right")
                    }
                    .help("Show agent details")
                }
            }
            .inspector(isPresented: $inspectorVisible) {
                AgentInspector(row: selectedRow)
                    .inspectorColumnWidth(min: 240, ideal: 280, max: 380)
            }
        }
        .task {
            configureRefresh()
            await store.monitor()
        }
        .onChange(of: refreshSeconds) { configureRefresh() }
        .onChange(of: store.agents.map(\.id), initial: true) {
            sessionOrder.synchronize(with: store.agents.map(\.id))
        }
        .onChange(of: destination) {
            workspaceID = nil
            selection = nil
        }
        .onChange(of: rows.map(\.id)) {
            if let selection, !rows.contains(where: { $0.id == selection }) { self.selection = nil }
        }
        .onChange(of: store.machines.map(\.id)) {
            if destination != "all", !store.machines.contains(where: { $0.id == destination }) {
                destination = "all"
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            if store.automaticRefresh { Task { await store.refresh() } }
        }
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section {
                HStack {
                    Label("All Agents", systemImage: "square.stack.3d.up")
                    Spacer()
                    Text("\(store.agents.count)").monospacedDigit().foregroundStyle(.secondary)
                }
                .tag("all")
                .accessibilityLabel("All Agents, \(store.agents.count) agents")
            }
            Section("Machines") {
                ForEach(store.machines) { state in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: state.machine.isLocal ? "laptopcomputer" : "server.rack")
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.machine.name).lineLimit(1)
                            HStack(spacing: 4) {
                                ConnectionDot(state: state.connection)
                                Text(state.connection.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 2)
                        if !state.agents.isEmpty {
                            Text("\(state.agents.count)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(state.id)
                    .help(state.machine.target ?? "Local Herdr default session")
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                Text("\(store.onlineCount) of \(store.machines.filter { $0.machine.isEnabled }.count) online")
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(12)
        }
    }

    private var summary: some View {
        HStack(spacing: 20) {
            ForEach([AgentState.working, .blocked, .idle, .done], id: \.rawValue) { state in
                let count = scopedAgents.filter { $0.agent.state == state && !$0.isStale }.count
                HStack(spacing: 5) {
                    Image(systemName: state.symbol)
                        .foregroundStyle(state == .blocked && count > 0 ? Color.orange : .secondary)
                    Text("\(count)").fontWeight(.semibold).monospacedDigit()
                    Text(state == .blocked ? "need attention" : state.rawValue).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            if scopedAgents.contains(where: \.isStale) {
                Text("\(scopedAgents.filter(\.isStale).count) stale")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var clusterFailures: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(store.machines.filter { $0.failure != nil }) { state in
                Button { destination = state.id } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                        Text("\(state.machine.name): \(state.connection.title)")
                        if state.isStale { Text("· Showing last known data").foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(state.failure?.message ?? "")
            }
        }
        .font(.callout).foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.quaternary.opacity(0.35))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var agentTable: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Priority", value: \.manualPriority) { row in
                Text("\(row.manualPriority)").monospacedDigit().foregroundStyle(.secondary)
                    .help("Priority in your saved order across all machines")
            }.width(60)
            TableColumn("Agent", value: \.name) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name).fontWeight(.medium).lineLimit(1)
                    Text(row.agent.kind == row.name ? row.agent.paneID : row.agent.kind)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.vertical, 5)
                .opacity(row.isStale ? 0.6 : 1)
                .help(row.agent.summary ?? row.name)
            }.width(min: 130, ideal: 180)
            TableColumn("State", value: \.priority) { row in
                VStack(alignment: .leading, spacing: 2) {
                    StateLabel(state: row.agent.state, stale: row.isStale)
                    if row.isStale {
                        Label("Stale", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Stale: last successful snapshot \(row.lastSuccess?.formatted() ?? "unknown")")
                            .accessibilityLabel("Stale data")
                    }
                }
            }.width(min: 100, ideal: 120)
            TableColumn("Workspace", value: \.workspace) { row in
                Text(row.workspace).lineLimit(1).help("\(row.agent.workspaceID) · Tab \(row.agent.tabName)")
            }.width(min: 100, ideal: 150)
            TableColumn("Machine", value: \.machineName) { row in
                Text(row.machineName).lineLimit(1)
            }.width(min: 90, ideal: 130)
            TableColumn("Project / Directory", value: \.project) { row in
                Text(row.project).font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .help(row.project)
            }.width(min: 130, ideal: 260)
        }
        .contextMenu(forSelectionType: Agent.ID.self) { ids in
            if let id = ids.first {
                if let row = store.agents.first(where: { $0.id == id }) {
                    Button("Open Terminal") { openTerminal(row) }.disabled(row.isStale)
                }
                Button("Show Details") { selection = id; inspectorVisible = true }
                Divider()
                Button("Raise Priority") { move(id, .up) }.disabled(!canMove(id, .up))
                Button("Lower Priority") { move(id, .down) }.disabled(!canMove(id, .down))
                Button("Move to Top") { move(id, .first) }.disabled(!canMove(id, .first))
                Button("Move to Bottom") { move(id, .last) }.disabled(!canMove(id, .last))
            }
        } primaryAction: { ids in
            selection = ids.first
            if let selectedRow { openTerminal(selectedRow) }
        }
        .overlay {
            if rows.isEmpty { emptyState.padding(30).allowsHitTesting(false) }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if store.isRefreshing && store.lastRefresh == nil {
            VStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Connecting to Herdr…").foregroundStyle(.secondary)
            }
        } else if !search.isEmpty || stateFilter != "all" || workspaceID != nil {
            ContentUnavailableView("No Matching Agents", systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("Try a different search, state or workspace."))
        } else if let machine = selectedMachine, machine.connection != .online {
            ContentUnavailableView(machine.connection.title, systemImage: "network.slash",
                                   description: Text(machine.failure?.message ?? "This profile is disabled in Herdr."))
        } else if store.onlineCount == 0 {
            ContentUnavailableView("Waiting for Herdr", systemImage: "network",
                                   description: Text("Select a machine to see connection details. Refresh after starting Herdr or completing SSH setup."))
        } else {
            ContentUnavailableView("No Agents Running", systemImage: "terminal",
                                   description: Text("Connected to Herdr. Agents will appear here when Herdr detects them in a workspace."))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(rows.count) agent\(rows.count == 1 ? "" : "s")")
            Text(isManualOrder ? "· My order" : "· Column sort")
                .help("Priorities are saved on this Mac. Sorting columns does not change them.")
            if store.isRefreshing {
                ProgressView().controlSize(.mini).scaleEffect(0.8)
                Text("Refreshing…")
            } else if let lastRefresh = store.lastRefresh {
                Text("· Checked \(lastRefresh.formatted(date: .omitted, time: .standard))")
            }
            Spacer()
            Text(refreshSeconds == 0 ? "Automatic refresh paused" : "Refreshes every \(refreshSeconds)s")
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func configureRefresh() {
        store.automaticRefresh = refreshSeconds > 0
        store.refreshInterval = TimeInterval(max(5, refreshSeconds))
    }

    private func canMove(_ id: Agent.ID?, _ direction: SessionOrderStore.Move) -> Bool {
        isManualOrder && sessionOrder.canMove(id, direction, visibleIDs: rows.map(\.id))
    }

    private func moveSelection(_ direction: SessionOrderStore.Move) {
        if let selection { move(selection, direction) }
    }

    private func move(_ id: Agent.ID, _ direction: SessionOrderStore.Move) {
        guard isManualOrder else { return }
        sessionOrder.move(id, direction, visibleIDs: rows.map(\.id))
        selection = id
    }

    private func openTerminal(_ row: AgentRow) {
        guard !row.isStale, let machine = store.machines.first(where: { $0.id == row.id.machineID }),
              machine.connection == .online else { return }
        openWindow(id: "terminal", value: TerminalTarget(machine: machine.machine, terminalID: row.id.terminalID,
                                                       title: row.name, workspace: row.workspace))
    }
}
