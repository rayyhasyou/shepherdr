import Foundation

public struct Machine: Identifiable, Hashable, Sendable {
    public let profileID: String?
    public let name: String
    public let target: String?
    public let session: String
    public let isEnabled: Bool

    public var id: String { profileID.map { "remote:\($0)" } ?? "local" }
    public var isLocal: Bool { profileID == nil }
    public static let local = Machine(profileID: nil, name: "Local", target: nil,
                                      session: "default", isEnabled: true)

    public init(profileID: String?, name: String, target: String?, session: String, isEnabled: Bool) {
        self.profileID = profileID
        self.name = name
        self.target = target
        self.session = session
        self.isEnabled = isEnabled
    }
}

public enum AgentState: String, CaseIterable, Sendable {
    case working, blocked, idle, done, unknown

    public init(reportedValue: String) { self = Self(rawValue: reportedValue) ?? .unknown }
    public var title: String { rawValue.capitalized }
    public var priority: Int {
        switch self {
        case .blocked: 0
        case .working: 1
        case .done: 2
        case .idle: 3
        case .unknown: 4
        }
    }
    public var symbol: String {
        switch self {
        case .blocked: "exclamationmark.circle.fill"
        case .working: "arrow.triangle.2.circlepath"
        case .done: "checkmark.circle"
        case .idle: "pause.circle"
        case .unknown: "questionmark.circle"
        }
    }
}

public struct Agent: Identifiable, Equatable, Sendable {
    public struct ID: Hashable, Sendable {
        public let machineID: String
        public let terminalID: String
    }
    public let id: ID
    public let name: String
    public let kind: String
    public let state: AgentState
    public let reportedState: String
    public let workspaceID: String
    public let workspaceName: String
    public let tabID: String
    public let tabName: String
    public let paneID: String
    public let directory: String?
    public let project: String?
    public let summary: String?
    public let isLaunchPending: Bool
}

public struct Workspace: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let directory: String?
    public let tabCount: Int
    public let paneCount: Int
    public let state: AgentState
}

public struct MachineSnapshot: Equatable, Sendable {
    public let version: String
    public let protocolVersion: Int
    public let workspaces: [Workspace]
    public let agents: [Agent]
}

public enum ConnectionState: String, Sendable {
    case loading, online, unreachable, notInstalled, notRunning, incompatible, disabled

    public var title: String {
        switch self {
        case .loading: "Connecting"
        case .online: "Online"
        case .unreachable: "Unreachable"
        case .notInstalled: "Herdr not installed"
        case .notRunning: "Herdr not running"
        case .incompatible: "Incompatible Herdr"
        case .disabled: "Disabled in Herdr"
        }
    }
}

public struct HerdrFailure: Error, Equatable, LocalizedError, Sendable {
    public let state: ConnectionState
    public let message: String
    public let detail: String?

    public init(_ state: ConnectionState, _ message: String, detail: String? = nil) {
        self.state = state
        self.message = message
        self.detail = detail
    }
    public var errorDescription: String? { message }
}

public struct MachineState: Identifiable, Sendable {
    public var machine: Machine
    public var connection: ConnectionState = .loading
    public var snapshot: MachineSnapshot?
    public var failure: HerdrFailure?
    public var lastSuccess: Date?
    public var isRefreshing = false
    public var id: String { machine.id }
    public var isStale: Bool { snapshot != nil && connection != .online }
    public var agents: [Agent] { snapshot?.agents ?? [] }

    public init(machine: Machine) {
        self.machine = machine
        if !machine.isEnabled { connection = .disabled }
    }
}

/// Presentation-ready aggregation without any SwiftUI or transport dependency.
public struct AgentRow: Identifiable, Equatable, Sendable {
    public let agent: Agent
    public let machineName: String
    public let isStale: Bool
    public let lastSuccess: Date?
    public var id: Agent.ID { agent.id }
    public var name: String { agent.name }
    public var workspace: String { agent.workspaceName }
    public var project: String { agent.directory ?? agent.project ?? "—" }
    public var priority: Int { agent.state.priority }
    public var stateTitle: String { agent.state.title }

    public func matches(_ query: String) -> Bool {
        query.isEmpty || [name, agent.kind, workspace, project, machineName, agent.paneID,
                          agent.summary ?? "", stateTitle].contains {
            $0.localizedStandardContains(query)
        }
    }
}
