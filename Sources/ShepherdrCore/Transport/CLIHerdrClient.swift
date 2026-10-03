import Foundation

public struct CLIHerdrClient: HerdrClient, HerdrTerminalClient {
    private let runner: any CommandRunning
    private let executable: URL?
    private let timeout: TimeInterval

    public init(executable: URL? = nil, timeout: TimeInterval = 12) {
        self.init(runner: ProcessRunner(), executable: executable, timeout: timeout)
    }

    init(runner: any CommandRunning, executable: URL? = nil, timeout: TimeInterval = 12) {
        self.runner = runner
        self.executable = executable
        self.timeout = timeout
    }

    public func machines() async throws -> [Machine] {
        let output = try await execute(["machine", "list", "--json"])
        try validate(output, machine: .local)
        do { return try HerdrJSON.machines(output.stdout) }
        catch { throw decodingFailure(error) }
    }

    public func connect(to target: TerminalTarget, mode: TerminalMode, size: TerminalSize) async throws -> any HerdrTerminalConnection {
        let command = try TerminalCommand.make(target: target, mode: mode, size: size, executable: executable)
        return try await CLITerminalConnection.start(command: command, mode: mode)
    }

    public func snapshot(for machine: Machine) async throws -> MachineSnapshot {
        let prefix = machine.profileID.map { ["--machine", $0] } ?? []
        let output = try await execute(prefix + ["api", "snapshot"])
        do { try validate(output, machine: machine) }
        catch let failure as HerdrFailure {
            // Some older CLIs emit an OS error for a missing socket. Prefer the supported
            // JSON status query over inferring server state from that human diagnostic.
            if machine.isLocal, failure.state == .unreachable,
               let statusOutput = try? await execute(["status", "server", "--json"]),
               statusOutput.exitCode == 0,
               let status = try? HerdrJSON.decoder().decode(ServerStatusDTO.self, from: statusOutput.stdout) {
                if !status.running {
                    throw HerdrFailure(.notRunning, "Start Herdr on this machine, then refresh.")
                }
                if status.compatible == false {
                    throw HerdrFailure(.incompatible, "The Herdr CLI and running server use different protocols.",
                                       detail: "Check `herdr status --json` and resolve the mismatch in Herdr.")
                }
            }
            throw failure
        }
        do { return try HerdrJSON.snapshot(output.stdout, machine: machine) }
        catch { throw decodingFailure(error) }
    }

    private func execute(_ arguments: [String]) async throws -> CommandOutput {
        let url = try executable ?? ExecutableLocator().locate()
        do { return try await runner.run(executable: url, arguments: arguments, timeout: timeout) }
        catch is CancellationError { throw CancellationError() }
        catch CommandError.timedOut {
            throw HerdrFailure(.unreachable, "Herdr did not respond within \(Int(timeout)) seconds.",
                               detail: "Check the machine and SSH connection. Shepherdr will retry automatically.")
        } catch CommandError.outputTooLarge {
            throw HerdrFailure(.incompatible, "Herdr’s response exceeded the 8 MB limit.")
        } catch {
            throw HerdrFailure(.unreachable, "Could not run Herdr.", detail: error.localizedDescription)
        }
    }

    private func validate(_ output: CommandOutput, machine: Machine) throws {
        // API errors may be written to stderr with a nonzero exit code, including protocol errors.
        for data in [output.stdout, output.stderr] {
            if let error = try? HerdrJSON.decoder().decode(APIErrorDTO.self, from: data) {
                throw apiFailure(error.error)
            }
            for line in data.split(separator: 0x0A) {
                if let error = try? HerdrJSON.decoder().decode(APIErrorDTO.self, from: Data(line)) {
                    throw apiFailure(error.error)
                }
            }
        }
        guard output.exitCode == 0 else {
            let detail = String(decoding: output.stderr.prefix(4_096), as: UTF8.self).nonempty
                ?? "Herdr exited with status \(output.exitCode)."
            // Usage errors have no JSON envelope. Exit 2 is Herdr's unsupported CLI contract.
            if output.exitCode == 2 {
                throw HerdrFailure(.incompatible,
                    machine.isLocal ? "This Herdr installation does not support the required JSON commands."
                    : "Update local Herdr to a build that supports --machine forwarding.", detail: detail)
            }
            throw HerdrFailure(.unreachable,
                machine.isLocal ? "Could not connect to the local Herdr server."
                : "Could not query this saved machine. Check SSH and remote Herdr setup.", detail: detail)
        }
    }

    private func apiFailure(_ error: APIErrorDTO.Body) -> HerdrFailure {
        let state: ConnectionState
        switch error.code {
        case "server_not_running": state = .notRunning
        case "not_installed", "herdr_not_installed": state = .notInstalled
        case "protocol_mismatch", "method_not_found", "unknown_method", "unsupported_method", "invalid_request":
            state = .incompatible
        default: state = .unreachable
        }
        return HerdrFailure(state, error.message, detail: "Herdr error: \(error.code)")
    }

    private func decodingFailure(_ error: Error) -> HerdrFailure {
        if let failure = error as? HerdrFailure { return failure }
        return HerdrFailure(.incompatible, "Herdr returned JSON that Shepherdr could not read.",
                           detail: "Expected the supported machine list or session.snapshot contract. \(error)")
    }
}
