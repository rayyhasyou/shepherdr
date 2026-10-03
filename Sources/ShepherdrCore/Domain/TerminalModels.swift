import Foundation

public struct TerminalPane: Identifiable, Equatable, Sendable {
    public let terminalID: String
    public let paneID: String
    public let workspaceID: String
    public let workspaceName: String
    public let title: String
    public var id: String { terminalID }
}

/// A window always targets this exact terminal and session, never the caller's focused pane.
public struct TerminalTarget: Hashable, Codable, Sendable {
    public let machine: Machine
    public let terminalID: String
    public let title: String
    public let workspace: String

    public init(machine: Machine, terminalID: String, title: String, workspace: String) {
        self.machine = machine
        self.terminalID = terminalID
        self.title = title
        self.workspace = workspace
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.machine.id == rhs.machine.id && lhs.machine.session == rhs.machine.session && lhs.terminalID == rhs.terminalID
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(machine.id)
        hasher.combine(machine.session)
        hasher.combine(terminalID)
    }
}

public enum TerminalMode: String, Sendable { case observe, control }

public struct TerminalSize: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public init(columns: Int = 100, rows: Int = 30) {
        self.columns = min(500, max(2, columns))
        self.rows = min(250, max(2, rows))
    }
}

public struct TerminalFrame: Equatable, Sendable {
    public let bytes: Data
    public let columns: Int
    public let rows: Int
    public let isFull: Bool
}

public enum TerminalEvent: Equatable, Sendable {
    case frame(TerminalFrame)
    case closed(String)
}

public enum TerminalInput: Sendable {
    case bytes(Data)
    case resize(TerminalSize)
    case scroll(up: Bool, lines: Int)
    case release
}

public protocol HerdrTerminalConnection: Sendable {
    var events: AsyncThrowingStream<TerminalEvent, Error> { get }
    func send(_ input: TerminalInput) async throws
    /// Detaches this client only. It must never stop the server, pane or its shell.
    func close()
}

public protocol HerdrTerminalClient: Sendable {
    func connect(to target: TerminalTarget, mode: TerminalMode, size: TerminalSize) async throws -> any HerdrTerminalConnection
}
