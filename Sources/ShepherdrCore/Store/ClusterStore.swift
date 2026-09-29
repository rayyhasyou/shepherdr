import Foundation
import Observation

@MainActor @Observable
public final class ClusterStore {
    public private(set) var machines: [MachineState] = [MachineState(machine: .local)]
    public private(set) var discoveryFailure: HerdrFailure?
    public private(set) var isRefreshing = false
    public private(set) var lastRefresh: Date?
    public var automaticRefresh = true
    public var refreshInterval: TimeInterval = 5
    @ObservationIgnored private let client: any HerdrClient

    public init(client: any HerdrClient = CLIHerdrClient()) { self.client = client }

    public var agents: [AgentRow] {
        machines.flatMap { state in
            state.agents.map { AgentRow(agent: $0, machineName: state.machine.name,
                                       isStale: state.isStale, lastSuccess: state.lastSuccess) }
        }.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            if $0.machineName != $1.machineName { return $0.machineName < $1.machineName }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id.terminalID < $1.id.terminalID
        }
    }

    public var onlineCount: Int { machines.filter { $0.connection == .online }.count }

    /// Local querying and catalog discovery start together. Every machine publishes as it finishes.
    /// A slow remote never delays display of a healthy machine. Overlapping refreshes are coalesced.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            for index in machines.indices { machines[index].isRefreshing = false }
        }
        enum Update: Sendable {
            case catalog(Result<[Machine], HerdrFailure>)
            case snapshot(String, Result<MachineSnapshot, HerdrFailure>)
            case cancelled
        }
        let client = client
        await withTaskGroup(of: Update.self) { group in
            // Also refresh known remotes immediately if catalog discovery is temporarily failing.
            var scheduled = Set<String>()
            for index in machines.indices where machines[index].machine.isEnabled {
                let machine = machines[index].machine
                machines[index].isRefreshing = true
                scheduled.insert(machine.id)
                group.addTask {
                    do { return .snapshot(machine.id, .success(try await client.snapshot(for: machine))) }
                    catch is CancellationError { return .cancelled }
                    catch { return .snapshot(machine.id, .failure(Self.failure(error))) }
                }
            }
            group.addTask {
                do { return .catalog(.success(try await client.machines())) }
                catch is CancellationError { return .cancelled }
                catch { return .catalog(.failure(Self.failure(error))) }
            }
            for await update in group {
                guard !Task.isCancelled else { group.cancelAll(); continue }
                switch update {
                case .catalog(.success(let discovered)):
                    discoveryFailure = nil
                    let catalog = [Machine.local] + discovered.filter { !$0.isLocal }
                    // Defend the protocol boundary even for alternate clients.
                    var seen = Set<String>()
                    machines = catalog.filter { seen.insert($0.id).inserted }.map { machine in
                        var state = machines.first { $0.id == machine.id } ?? MachineState(machine: machine)
                        state.machine = machine
                        if !machine.isEnabled {
                            state.connection = .disabled
                            state.isRefreshing = false
                        } else if state.connection == .disabled {
                            state.connection = .loading
                        }
                        return state
                    }
                    for index in machines.indices where machines[index].machine.isEnabled {
                        let machine = machines[index].machine
                        guard scheduled.insert(machine.id).inserted else { continue }
                        machines[index].isRefreshing = true
                        group.addTask {
                            do { return .snapshot(machine.id, .success(try await client.snapshot(for: machine))) }
                            catch is CancellationError { return .cancelled }
                            catch { return .snapshot(machine.id, .failure(Self.failure(error))) }
                        }
                    }
                case .catalog(.failure(let failure)):
                    discoveryFailure = failure
                case .snapshot(let id, let result):
                    guard let index = machines.firstIndex(where: { $0.id == id }),
                          machines[index].machine.isEnabled else { continue }
                    machines[index].isRefreshing = false
                    switch result {
                    case .success(let snapshot):
                        machines[index].snapshot = snapshot
                        machines[index].connection = .online
                        machines[index].failure = nil
                        machines[index].lastSuccess = Date()
                    case .failure(let failure):
                        machines[index].connection = failure.state
                        machines[index].failure = failure
                    }
                case .cancelled: break
                }
            }
        }
        if !Task.isCancelled { lastRefresh = Date() }
    }

    /// Cancellation belongs to the window's SwiftUI task. No detached polling task survives it.
    public func monitor() async {
        await refresh()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(refreshInterval)) }
            catch { return }
            if automaticRefresh { await refresh() }
        }
    }

    nonisolated private static func failure(_ error: Error) -> HerdrFailure {
        error as? HerdrFailure ?? HerdrFailure(.unreachable, "Could not read Herdr data.", detail: error.localizedDescription)
    }
}
