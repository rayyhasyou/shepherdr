import Foundation

/// Domain-facing boundary. A socket client can implement this without changing the store or views.
/// Future event support should subscribe before bootstrapping, and resnapshot after reconnects.
public protocol HerdrClient: Sendable {
    func machines() async throws -> [Machine]
    func snapshot(for machine: Machine) async throws -> MachineSnapshot
}

public struct ExecutableLocator: Sendable {
    public init() {}

    public func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                       home: String = NSHomeDirectory()) throws -> URL {
        if let explicit = environment["SHEPHERDR_HERDR_PATH"], !explicit.isEmpty {
            guard explicit.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: explicit) else {
                throw HerdrFailure(.notInstalled, "The configured Herdr executable is unavailable.", detail: explicit)
            }
            return URL(fileURLWithPath: explicit)
        }
        // Finder-launched applications have a minimal PATH. Do not source shell startup files.
        let directories = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.cargo/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for directory in directories where directory.hasPrefix("/") {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("herdr")
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        throw HerdrFailure(.notInstalled, "Install Herdr, then refresh.",
                           detail: "Shepherdr checks Homebrew, ~/.local/bin, ~/.cargo/bin and PATH. A custom location can be set with SHEPHERDR_HERDR_PATH.")
    }
}
