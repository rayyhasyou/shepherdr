# v0 verification

Validated on 2026-09-30 on macOS 26.6.2 (Apple Silicon), using Xcode 27.0 / Swift 6.4. Deployment target is macOS 14; an actual macOS 14 runtime has not been tested.

## Automated and live checks

- `xcodebuild -project Shepherdr.xcodeproj -scheme Shepherdr -configuration Debug -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test` — **passed**, building the native application and running 27 tests in 3 suites.
- `swift test` — **passed**, the same 27 tests.
- `shepherdr-probe` against the real local installation — **passed**: executable discovered, Herdr 0.9.0 / protocol 22 decoded, one real workspace, no detected agents at verification time.
- Repeated the live probe on 2026-10-01 after updating the CLI to 0.9.3 — **passed** against the existing 0.9.0 server. Structured server status reported `compatible: true` and `restart_needed: false`; no server restart or session changes were performed.
- Xcode scheme XML, project plist and synthetic JSON fixtures — valid.
- Multiple machines, same IDs across machines, partial failures, recovery and stale retention — covered by the mock-client tests. No saved remote machine was available for real SSH verification.

## UI verification

The built native application was opened and inspected interactively:

- **Real installation:** All Agents showed Local as online and the expected empty agent state. Selecting Local displayed its actual workspace, directory, tab and pane counts, Herdr version and default session.
- **Synthetic cluster:** a separate disposable app copy used `SHEPHERDR_HERDR_PATH` to query an isolated fixture executable. Local and a remote profile supplied agents; another profile reported Herdr not running; a disabled profile stayed visible. No real Herdr configuration was changed.
- **Navigation and inspection:** checked All Agents, machine selection, workspace filtering, search by machine, the Blocked filter, and the metadata inspector. Machine/workspace ownership and routing identifiers matched the fixtures. Blocked agents appeared first with restrained orange emphasis.
- **Partial failure:** after a remote became unreachable, its four cached agents remained visible and marked stale while Local continued updating. The machine view exposed the error and last-received timestamp; summary counts excluded stale data.
- **Refresh and recovery:** pausing automatic refresh preserved the displayed snapshot. Manual refresh then recovered the remote and replaced cached rows, clearing stale markers.
- **Scale and layout:** checked 60 aggregate agents across two reachable machines, including unknown and future lifecycle values displayed as Unknown. Inspected a roughly 900 × 550 window with the inspector open: native horizontal table scrolling and vertical inspector scrolling kept content accessible.

The synthetic cluster validates application behavior, not a real SSH connection. No saved remote machine or real running coding agent was available during the initial verification. The updated CLI 0.9.3 supports `--machine`; real multi-host forwarding still needs successful SSH authentication and a saved profile targeting an existing remote session.
