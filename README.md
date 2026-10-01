# Shepherdr

A native macOS overview of the coding agents running across your [Herdr](https://herdr.dev/) machines.

Open **All Agents** to see who is working, who needs attention, and which workspace and machine each agent belongs to. Shepherdr is an independent, open-source client; it is not an official Herdr application and is not affiliated with the Herdr project.

## v0

- Native SwiftUI split view, sortable agent table, search, lifecycle filters, and metadata inspector.
- Local default session plus saved SSH machines from Herdr's machine catalog.
- Machine views with workspace, tab and pane counts, including workspaces without agents.
- Working, blocked, idle, done and unknown states; blocked agents sort first by default.
- Concurrent queries, independent connection states, and last-known data marked stale after failure.
- Automatic refresh (5, 15, 30 or 60 seconds), pause, manual refresh with **⌘R**, and refresh after wake.

Read-only: no terminal, prompts, agent/workspace creation, worktree management, machine management, notifications, or menu-bar UI.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 16 or later, with its license accepted and first-launch components installed.
- A locally installed `herdr` supporting `machine list --json` and `api snapshot`.
- For remote machines, a local Herdr build with the documented global `--machine` option, plus compatible remote installations and an already-running server. Herdr CLI 0.9.3 provides that option; 0.9.0 does not. Shepherdr shows an incompatibility message on older CLIs.

Local integration has been verified with CLI 0.9.3 querying an existing, compatible 0.9.0 server. Updating the CLI does not require replacing a compatible running server.

No package dependencies, API keys, accounts, or server-side Shepherdr service are required.

## Build and run

From this repository's root:

```sh
open Shepherdr.xcodeproj
```

Choose the shared **Shepherdr** scheme and **My Mac** destination, then press **⌘R**. No development team is needed for a local build. The application intentionally does not use App Sandbox: it must launch the user's installed Herdr executable and access Herdr's socket and SSH environment.

Or build and launch the application from Terminal:

```sh
xcodebuild -project Shepherdr.xcodeproj \
  -scheme Shepherdr -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/Shepherdr.app
```

If Xcode requests setup, open Xcode once to install its components. Review and accept Apple's license with `sudo xcodebuild -license`. If the wrong developer directory is selected, use `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.

Swift Package Manager also builds the application executable:

```sh
swift build --product shepherdr
swift run shepherdr
```

Use the Xcode-built `.app` for normal Dock/Finder use. Distribution signing and notarization are outside v0.

## Connect Herdr

Start Herdr normally on your Mac. Shepherdr queries the **local default session** and detects agents that Herdr itself reports. A shell pane is not an agent. If no coding agents are running, an empty agent table is expected; select **Local** to inspect the real workspace inventory.

Configure SSH machines in Herdr, then refresh Shepherdr:

```sh
herdr machine add workbox --label "Build machine"
# A saved profile can target a named remote session:
herdr machine add lab --label "Lab" --remote-session agents
herdr machine list --json
```

One profile represents one session, not every session on its host. Disabled profiles remain visible and are not polled. Credentials, host-key approval, installs and server startup remain Herdr's responsibility. Complete interactive SSH/Herdr setup in Terminal; Shepherdr never installs, starts, stops or restarts Herdr. Load passphrase-protected keys into your SSH agent before opening the app.

Shepherdr locates Herdr in `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.cargo/bin`, then absolute entries in `PATH`. For a custom installation, set `SHEPHERDR_HERDR_PATH` to the absolute executable path in **Scheme → Run → Arguments → Environment Variables**, or launch the built app's executable with that variable:

```sh
SHEPHERDR_HERDR_PATH=/absolute/path/to/herdr \
  build/Build/Products/Debug/Shepherdr.app/Contents/MacOS/Shepherdr
```

No shell startup files are sourced. Inherited `HERDR_SESSION`, `HERDR_SOCKET_PATH`, and pane/workspace/tab routing variables are cleared so opening Shepherdr from an agent pane cannot silently retarget Local. Herdr's own configuration environment is otherwise retained.

## Tests and diagnostics

```sh
swift test
xcodebuild -project Shepherdr.xcodeproj \
  -scheme Shepherdr -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
# Read-only live transport/store smoke test; exits 1 when no machine is online:
swift run shepherdr-probe
```

Tests use Swift Testing, synthetic JSON fixtures, a mock `HerdrClient`, an injected command runner, and bounded real subprocess tests. They cover decoding, domain joins, all states, future states, duplicate IDs, aggregation, partial failures, stale retention, recovery, catalog failures, disabled/removed profiles, incremental results, cancellation, literal arguments, and pipe draining. No running Herdr or SSH access is needed for the test suite.

Use the machine sidebar for failure details. A malformed response is **Incompatible**, never a successful empty session. Temporary failures keep cached rows visible with a stale marker and last-received timestamp. The summary counts exclude stale rows. Last-known snapshots are held in memory only; quitting clears them. The app does not collect telemetry or save session data to disk.

## Architecture

```text
App/                              SwiftUI presentation
Sources/ShepherdrCore/
  Transport/                      HerdrClient, CLI adapter, executable discovery, async Process runner
  DTO/                            JSON wire types, validation and domain mapping
  Domain/                         Machine, Workspace, Agent, lifecycle and failure models
  Store/                          MainActor observable cluster state and concurrent refresh
Sources/ShepherdrProbe/            Read-only integration diagnostic
Tests/ShepherdrCoreTests/          Protocol, transport and store regression tests
```

`HerdrClient` exposes domain snapshots and the machine catalog. Views never execute commands or decode JSON. Agent identity combines the machine profile and terminal ID, so identical pane IDs and names on different machines remain distinct. Native Unix-socket transport and event subscriptions can be added behind this boundary. Future agent actions can use the retained machine, workspace, tab, pane and terminal identifiers.

See [integration notes](docs/HERDR-INTEGRATION.md) for the inspected contract, compatibility policy, event strategy and limitations.

## License

[Apache License 2.0](LICENSE). Original Shepherdr implementation; no Herdr source is copied or bundled.
