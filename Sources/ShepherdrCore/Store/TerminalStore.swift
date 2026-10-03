import Foundation
import Observation

@MainActor @Observable
public final class TerminalStore {
    public enum Status: Equatable { case disconnected, connecting, observing, interactive, ended, failed }
    public let target: TerminalTarget
    public private(set) var status: Status = .disconnected
    public private(set) var mode: TerminalMode = .observe
    public private(set) var message: String?
    public private(set) var detail: String?
    public private(set) var size = TerminalSize()
    @ObservationIgnored public var display: ((TerminalFrame) -> Void)?
    @ObservationIgnored public var resetDisplay: (() -> Void)?
    @ObservationIgnored private let client: any HerdrTerminalClient
    @ObservationIgnored private var connection: (any HerdrTerminalConnection)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var resizeTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var inputTask: Task<Void, Never>?

    public init(target: TerminalTarget, client: any HerdrTerminalClient = CLIHerdrClient()) {
        self.target = target
        self.client = client
    }

    public func open(mode: TerminalMode = .observe) {
        disconnect()
        self.mode = mode
        status = .connecting
        message = nil
        detail = nil
        resetDisplay?()
        let attempt = generation
        task = Task { [weak self, client, target, size] in
            do {
                let stream = try await client.connect(to: target, mode: mode, size: size)
                guard let self, attempt == self.generation, !Task.isCancelled else { stream.close(); return }
                self.connection = stream
                defer { stream.close() }
                for try await event in stream.events {
                    guard attempt == self.generation, !Task.isCancelled else { return }
                    switch event {
                    case .frame(let frame):
                        self.status = mode == .control ? .interactive : .observing
                        self.display?(frame)
                    case .closed(let reason):
                        self.message = reason
                        self.status = .ended
                    }
                }
                if attempt == self.generation, self.status != .failed {
                    self.status = .ended
                    self.message = self.message ?? "Detached. The terminal continues in Herdr."
                    self.connection = nil
                }
            } catch {
                guard let self, attempt == self.generation, !Task.isCancelled else { return }
                self.status = .failed
                self.message = error.localizedDescription
                self.detail = (error as? HerdrFailure)?.detail
                self.connection = nil
            }
        }
    }

    public func disconnect() {
        generation += 1
        resizeTask?.cancel()
        resizeTask = nil
        inputTask?.cancel()
        inputTask = nil
        task?.cancel()
        task = nil
        connection?.close()
        connection = nil
        status = .disconnected
    }

    public func send(_ input: TerminalInput) {
        guard status == .interactive, let connection else { return }
        let previous = inputTask
        let attempt = generation
        // Keep keyboard/paste/resize order even though the transport API is asynchronous.
        inputTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled, self?.generation == attempt else { return }
            do { try await connection.send(input) }
            catch {
                guard let self, self.generation == attempt else { return }
                self.message = error.localizedDescription
                self.detail = (error as? HerdrFailure)?.detail
            }
        }
    }

    public func resize(columns: Int, rows: Int) {
        let next = TerminalSize(columns: columns, rows: rows)
        guard next != size else { return }
        size = next
        resizeTask?.cancel()
        resizeTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            guard let self else { return }
            if self.status == .interactive { self.send(.resize(self.size)) }
            // Observe has no stdin resize authority. Reopen just this observer at its new viewport.
            else if self.status == .observing || self.status == .connecting { self.open(mode: self.mode) }
        }
    }
}
