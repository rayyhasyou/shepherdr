Native macOS dashboard and interactive terminals for agents across your Herdr machines.

### New in 0.3.0

- Prioritize agent sessions with a persistent order across all machines. A new **Priority** column makes the order visible.
- Raise/lower sessions using toolbar arrows or **⌥⌘↑ / ⌥⌘↓**, or use **Move to Top/Bottom** in the context menu.
- Priorities survive app restarts, refreshes, lifecycle changes and temporarily missing machines. New sessions append to the end.
- Reorder within a filtered list without moving hidden sessions. Column sorting remains available; **Show My Order** restores your priorities without losing them.
- Preferences stay on this Mac and store only machine/terminal identifiers. No Herdr session changes are made by reordering.

### Included from 0.2.0

- Double-click an agent to open its live native terminal, or open any existing pane from the machine's workspace menu.
- Observe first, then use **Enable Input** for keyboard/paste interaction. Switch back to **Observe Only**, disconnect or close the window without ending the pane.
- Local and SSH terminal transports use Herdr's structured frame/input protocol. No forced takeover, embedded webview or separate server component.
- SwiftTerm's AppKit renderer and MIT notices are included. Keyboard/paste and native selection/copy are supported; mouse reporting and Herdr history browsing are not yet implemented.
- Terminal integration tested against an isolated Herdr 0.9.3 server, including input and preserving the shell across detach/reconnect. Real remote terminal authentication has not yet been verified; SSH command quoting and failures are covered by automated tests.

### Download and install

- **Apple Silicon (M1 or later), macOS 14 Sonoma or later.** Xcode is not required.
- Download **Shepherdr-…-macos-arm64.dmg**, open it, and drag **Shepherdr.app** to **Applications**. A ZIP of the same app is also available.
- Install and start [Herdr](https://herdr.dev/docs/) separately. Remote monitoring uses Herdr's saved machine profiles and requires a CLI with `--machine` support, such as 0.9.3.
- Terminals require `terminal session observe/control` on the target machine (verified with CLI/server 0.9.3). Remote terminals use an already-trusted SSH host and noninteractive authentication on Unix-like hosts.
- This release has an **ad hoc signature and is not notarized by Apple**. If macOS blocks the first launch and you trust this download, use **System Settings → Privacy & Security → Open Anyway** for Shepherdr. See [Apple's instructions](https://support.apple.com/en-us/102445). Managed Macs may require administrator approval.
- `SHA256SUMS` contains checksums for both downloads. In their download directory, run `shasum -a 256 -c SHA256SUMS` after downloading both packages.

Shepherdr is an independent client for Herdr. It does not create or stop sessions; terminal input is sent only after you enable it.
