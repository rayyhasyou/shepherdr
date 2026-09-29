import Testing
import Foundation
@testable import ShepherdrCore

@Suite @MainActor struct TransportTests {
    private let executable = URL(fileURLWithPath: "/test/herdr")

    @Test func testCLIUsesStructuredCatalogAndOpaqueRemoteSelector() async throws {
        let runner = RecordingRunner([
            CommandOutput(stdout: try Fixture.data("machines"), stderr: Data(), exitCode: 0),
            CommandOutput(stdout: try Fixture.data(), stderr: Data(), exitCode: 0)
        ])
        let client = CLIHerdrClient(runner: runner, executable: executable)
        let catalog = try await client.machines()
        _ = try await client.snapshot(for: catalog[0])
        let args = await runner.recordedArguments()
        #expect(args == [["machine", "list", "--json"], ["--machine", "opaque-remote-a", "api", "snapshot"]])
    }

    @Test func testLocalSnapshotCommand() async throws {
        let runner = RecordingRunner([CommandOutput(stdout: try Fixture.data(), stderr: Data(), exitCode: 0)])
        let client = CLIHerdrClient(runner: runner, executable: executable)
        _ = try await client.snapshot(for: .local)
        let args = await runner.recordedArguments()
        #expect(args == [["api", "snapshot"]])
    }

    @Test func testAPIErrorOnStderrIsReadBeforeExitStatus() async {
        for (code, state) in [("server_not_running", ConnectionState.notRunning),
                              ("protocol_mismatch", .incompatible), ("method_not_found", .incompatible),
                              ("herdr_not_installed", .notInstalled)] {
            let runner = RecordingRunner([output("", stderr: "{\"error\":{\"code\":\"\(code)\",\"message\":\"Action required\"}}", code: 1)])
            do {
                _ = try await CLIHerdrClient(runner: runner, executable: executable).snapshot(for: .local)
                Issue.record("Expected \(state)")
            } catch {
                #expect((error as? HerdrFailure)?.state == state)
            }
        }
    }

    @Test func testUnsupportedMachineForwardingIsActionableAndNeverFallsBackToLocal() async {
        let runner = RecordingRunner([output("", stderr: "unknown option: --machine", code: 2)])
        do {
            _ = try await CLIHerdrClient(runner: runner, executable: executable).snapshot(for: Fixture.remote)
            Issue.record("Expected incompatibility")
        } catch {
            #expect((error as? HerdrFailure)?.state == .incompatible)
            #expect((error as? HerdrFailure)?.message.contains("--machine") == true)
        }
        let args = await runner.recordedArguments()
        #expect(args.count == 1)
    }

    @Test func testLegacyConnectionFailureUsesStructuredServerStatus() async {
        let runner = RecordingRunner([output("", stderr: "OS connection error", code: 1), output(#"{"running":false,"compatible":null}"#)])
        do {
            _ = try await CLIHerdrClient(runner: runner, executable: executable).snapshot(for: .local)
            Issue.record("Expected stopped state")
        } catch { #expect((error as? HerdrFailure)?.state == .notRunning) }
        let args = await runner.recordedArguments()
        #expect(args.last == ["status", "server", "--json"])
    }

    @Test func testMalformedJSONAndMissingRequiredFieldsAreIncompatible() async {
        for response in ["invalid", "{}", #"{"result":{"type":"session_snapshot","snapshot":{}}}"#] {
            let runner = RecordingRunner([output(response)])
            do {
                _ = try await CLIHerdrClient(runner: runner, executable: executable).snapshot(for: .local)
                Issue.record("Expected incompatible response")
            } catch { #expect((error as? HerdrFailure)?.state == .incompatible) }
        }
    }

    @Test func testExecutableOverrideAndMissingInstallation() throws {
        #expect(try ExecutableLocator().locate(environment: ["SHEPHERDR_HERDR_PATH": "/bin/echo"]).path == "/bin/echo")
        #expect(throws: HerdrFailure.self) {
            try ExecutableLocator().locate(environment: ["SHEPHERDR_HERDR_PATH": "/missing/shepherdr-herdr"])
        }
    }

    @Test func testRealProcessPassesArgumentsLiterally() async throws {
        let literal = "$(touch /tmp/do-not-create) ; ' quoted value"
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: [literal], timeout: 3)
        #expect(String(decoding: result.stdout, as: UTF8.self) == literal + "\n")
        #expect(result.exitCode == 0)
    }

    @Test func testRealProcessDrainsBothPipesBeyondPipeCapacity() async throws {
        let script = "i=0; while [ $i -lt 2000 ]; do echo 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789'; echo 'stderr-abcdefghijklmnopqrstuvwxyz0123456789' >&2; i=$((i+1)); done"
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], timeout: 5)
        #expect(result.stdout.count > 100_000)
        #expect(result.stderr.count > 65_536)
        #expect(result.exitCode == 0)
    }

    @Test func testRealProcessTimeoutIsBounded() async {
        let start = Date()
        do {
            _ = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 0.1)
            Issue.record("Expected timeout")
        } catch CommandError.timedOut { }
        catch { Issue.record("Unexpected \(error)") }
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func testRealProcessCancellationIsBounded() async throws {
        let task = Task {
            try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 15)
        }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError { }
    }
}
