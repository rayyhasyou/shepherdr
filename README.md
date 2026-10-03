# Shepherdr

A native macOS dashboard and terminal client for coding agents across your [Herdr](https://herdr.dev/) machines.

Open **All Agents** to see who is working, who needs attention, and which workspace and machine each agent belongs to. Shepherdr is an independent, open-source client; it is not an official Herdr application and is not affiliated with the Herdr project.

## Features

- Native SwiftUI split view, sortable agent table, search, lifecycle filters, and metadata inspector.
- Persistent session priorities shared across the cluster, with move controls and keyboard shortcuts.
- Local default session plus saved SSH machines from Herdr's machine catalog.
- Machine views with workspace, tab and pane counts, including workspaces without agents.
- Working, blocked, idle, done and unknown states; **Sort by State** brings blocked agents to the top.
- Concurrent queries, independent connection states, and last-known data marked stale after failure.
- Automatic refresh (5, 15, 30 or 60 seconds), pause, manual refresh with **⌘R**, and refresh after wake.
- Native terminal windows for existing agents and shell panes, locally or over SSH.
- Live observation, explicit keyboard/paste input, reconnect and detach without ending the underlying session.

No agent/workspace creation, worktree management, machine management, notifications, or menu-bar UI. Monitoring remains read-only; terminal input goes to the existing session when you enable it.

## Download and install

Download the `.dmg` from [the latest GitHub release](https://github.com/rayyhasyou/shepherdr/releases/latest), open it, and drag **Shepherdr.app** to **Applications**. A `.zip` of the same app and SHA-256 checksums are also available. Requires **Apple Silicon (M1 or later) and macOS 14 Sonoma or later**; no Xcode is needed to run the download.

Current downloads have an **ad hoc signature and are not notarized by Apple**. If macOS blocks the first launch because the developer cannot be verified and you trust this download, use **System Settings → Privacy & Security → Open Anyway** for Shepherdr. Follow [Apple's instructions](https://support.apple.com/en-us/102445); managed Macs may require administrator approval.

Install and start Herdr separately, then open Shepherdr. The app reads your existing sessions and saved machines.

## Requirements

- macOS 14 Sonoma or later.
- To build from source: Xcode 16 or later, with its license accepted and first-launch components installed.
- A locally installed `herdr` supporting `machine list --json` and `api snapshot`.
- For remote machines, a local Herdr build with the documented global `--machine` option, plus compatible remote installations and an already-running server. Herdr CLI 0.9.3 provides that option; 0.9.0 does not. Shepherdr shows an incompatibility message on older CLIs.
- For interactive terminals, the Herdr installation on the target machine must support `terminal session observe` and `terminal session control`. Verified with CLI/server 0.9.3. Remote terminals require a Unix-like host, OpenSSH access and an existing saved profile.

Local integration has been verified with CLI 0.9.3 querying an existing, compatible 0.9.0 server. Updating the CLI does not require replacing a compatible running server.

The native terminal renderer uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), pinned to 1.10.1 (MIT). This AppKit version builds without an additional Metal compiler component or binary framework. SwiftPM also resolves SwiftTerm's command-line tooling dependency, ArgumentParser; it is not linked into Shepherdr. No API keys, accounts, or server-side Shepherdr service are required.

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

Use the Xcode-built `.app` for normal Dock/Finder use. See [releasing](docs/RELEASING.md) for the automated Apple Silicon packages and their signing status.

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

Local executable discovery does not source shell startup files. Inherited `HERDR_SESSION`, `HERDR_SOCKET_PATH`, and pane/workspace/tab routing variables are cleared so opening Shepherdr from an agent pane cannot silently retarget Local. Herdr's own configuration environment is otherwise retained.

## Prioritize sessions

The **Priority** column shows your saved order across all machines. Select an agent session and use the toolbar arrows to raise or lower its priority, or press **⌥⌘↑ / ⌥⌘↓**. The context menu also offers **Move to Top** and **Move to Bottom**.

Ordering is saved on this Mac and restored when you reopen Shepherdr. Newly discovered sessions join the end. Refreshes, lifecycle changes, temporary disconnections and an incomplete machine catalog do not erase existing positions. Priorities follow the machine profile and terminal ID, so sessions with identical names on different machines stay independent. A newly created terminal has a new identity and joins the end.

You can reorder while searching or filtering by state, workspace or machine: movement is relative to the visible sessions, and hidden sessions retain their saved slots. Priority numbers refer to the current cluster as a whole, so a filtered list can have gaps. Clicking a column header temporarily sorts by that column without changing saved priorities. Choose **Show My Order** from the numbered-list toolbar menu (or sort Priority ascending) to resume manual ordering. Reordering controls are disabled during other column sorts.

Only stable identifiers and their order are stored in the app's local preferences. Priorities are independent of Herdr state and are not synchronized between Macs.

## Interact with an existing session

1. Double-click an agent, or select it and choose **Open Terminal** in the toolbar or context menu.
2. To open a shell pane without an agent, select its machine and use the terminal menu beside its workspace.
3. The terminal opens in **Observing** mode. Click **Enable Input** to type or paste, including prompts and normal terminal keyboard shortcuts. Use **Observe Only** to release input control.
4. **Disconnect**, closing the window, or quitting Shepherdr detaches its client. Herdr keeps the underlying pane and shell running. **Reconnect** attaches to the same terminal ID.

Each window identifies the machine, session and workspace. Shepherdr never forces takeover from another controller. If Herdr reports a control conflict, release the other client or continue observing. Terminal resizing uses Herdr's supported viewport/resize messages. Mouse reporting and browsing Herdr's historical scrollback are not implemented in this version; native text selection, copying and keyboard/paste input are supported.

For remote terminals, Shepherdr invokes the remote installed Herdr CLI through `/usr/bin/ssh` using the saved profile's target and session. Host keys must already be trusted and authentication must work without a prompt. It uses the host's `herdr` on PATH, then checks `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` and `~/.cargo/bin`. Connection or compatibility failures appear in the terminal window and leave the cluster dashboard usable.

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

Tests use Swift Testing, synthetic JSON fixtures, mock cluster/terminal clients, isolated preferences, an injected command runner, and bounded real subprocess tests. They cover decoding, domain joins, all states, future states, duplicate IDs, aggregation, partial failures, stale retention, recovery, catalog failures, disabled/removed profiles, incremental results, cancellation, literal arguments, pipe draining, terminal JSON streams, observation/input boundaries, detach/reconnect, priority persistence and filtered reordering. No running Herdr or SSH access is needed for the test suite.

Use the machine sidebar for failure details. A malformed response is **Incompatible**, never a successful empty session. Temporary failures keep cached rows visible with a stale marker and last-received timestamp. The summary counts exclude stale rows. Last-known snapshots are held in memory only; quitting clears them. The app does not collect telemetry or write snapshot/terminal contents to disk; saved priorities contain only session identifiers.

## Architecture

```text
App/                              SwiftUI presentation
Sources/ShepherdrCore/
  Transport/                      CLI adapters, executable discovery, bounded process/stream transports
  DTO/                            JSON wire types, validation and domain mapping
  Domain/                         Machine, Workspace, Agent, lifecycle and failure models
  Store/                          MainActor cluster state, local session priorities and terminal connections
Sources/ShepherdrTerminalUI/       SwiftTerm AppKit renderer and SwiftUI terminal window
Sources/ShepherdrProbe/            Read-only integration diagnostic
Tests/ShepherdrCoreTests/          Protocol, transport and store regression tests
```

`HerdrClient` exposes domain snapshots and the machine catalog. `HerdrTerminalClient` exposes live terminal connections, frames and input. `CLIHerdrClient` implements both; views never execute commands or decode JSON. Agent identity combines the machine profile and terminal ID, so identical pane IDs and names on different machines remain distinct. Native Unix-socket transport and event subscriptions can replace the CLI behind these boundaries.

See [integration notes](docs/HERDR-INTEGRATION.md) for the inspected contract, compatibility policy, event strategy and limitations.

## License

[Apache License 2.0](LICENSE). Original Shepherdr implementation; no Herdr or herdrm source is copied or bundled. [SwiftTerm's MIT notices](Sources/ShepherdrTerminalUI/Resources/SwiftTerm-LICENSE) are included in the app. The session-oriented design was informed by studying [herdrm](https://github.com/missuo/herdrm).
