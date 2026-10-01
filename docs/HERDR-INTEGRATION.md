# Herdr integration notes

Inspected on 2026-09-29 before implementation:

- [Herdr repository](https://github.com/herdrdev/herdr): CLI dispatch, machine catalog serialization, machine target routing, snapshot collection, schema types and protocol guards.
- [Documentation overview](https://herdr.dev/docs/).
- [Socket API](https://herdr.dev/docs/socket-api/).
- [Connecting machines](https://herdr.dev/docs/connecting-machines/).
- [CLI reference](https://herdr.dev/docs/cli-reference/).
- [Agents](https://herdr.dev/docs/agents/).
- Installed Herdr 0.9.0: `api schema --json`, `api snapshot`, `status server --json`, `machine list --json`, and a read-only probe of `--machine` support.

Rechecked on 2026-10-01 with installed CLI 0.9.3: `--machine` is supported, and the unchanged Shepherdr probe successfully reads the existing local 0.9.0 server. Herdr reports that server as compatible with no restart required.

## Commands and envelopes

| Purpose | Invocation | Consumed shape |
| --- | --- | --- |
| Saved profiles | `herdr machine list --json` | Array of `id`, `label`, `target`, `session`, `enabled`; `selected` is irrelevant to routing |
| Local session | `herdr api snapshot` | `result.type == session_snapshot`, `result.snapshot` |
| Remote session | `herdr --machine <opaque-profile-id> api snapshot` | Same snapshot envelope, remote session chosen by Herdr |
| Diagnose older local socket failures | `herdr status server --json` | `running`, `compatible` |

Every invocation uses an executable URL and an argument array. There is no shell interpolation, SSH implementation, TUI scraping or parsing of human listings. Herdr owns forwarding, saved session selection and protocol negotiation. The originally inspected 0.9.0 CLI rejects `--machine`; installed CLI 0.9.3 supports it. There is no fallback from a failed remote request to Local.

API failures can be JSON on stderr with a nonzero exit status. Decode those envelopes first. Older CLI usage errors have exit status 2 without an envelope; these are reported as incompatible commands. Unstructured transport diagnostics are shown as details, not parsed into agent data. Remote authentication, install and bridge failures without a structured error remain actionable **Unreachable** states. No hidden interactive input is possible: stdin is closed and SSH askpass is disabled.

## Snapshot mapping

The snapshot contains `version`, private `protocol`, `workspaces`, `tabs`, `panes`, `layouts`, and `agents`. Layout geometry and focus do not affect the overview and are ignored. Core consumed collections are required; omitted/malformed collections cannot erase last-known data. Additional fields are ignored.

Only the `agents` array creates agent rows. Join its `workspace_id`, `tab_id` and `pane_id` to the corresponding records. Identity is `(machine ID, terminal_id)`, retaining all routing IDs for future actions. Names are optional: use `name`, then `display_agent`/`agent`. Preserve reported semantic `agent_status`; display-only labels, titles and metadata must not override it. Unknown future state strings map to **Unknown** and remain visible in the inspector. Workspace labels are distinct from filesystem paths. Prefer an agent's foreground directory, pane foreground directory, reported cwd, then worktree checkout information.

Herdr owns agent detection and lifecycle authority. Shepherdr does not infer agent progress from screen contents, timing, process names or shell output. In particular, idle does not imply completion, and a custom summary does not imply blocked. The snapshot's explicit done state is shown as Done. New completion sequence fields are not used to invent local unread-completion state.

JSON compatibility is based on the response contract, not a hard-coded private binary protocol number. Herdr's CLI may itself enforce CLI/server compatibility and emit `protocol_mismatch`; Shepherdr surfaces that error. A newer server with additional fields or states can remain usable.

## Refresh and events

The inspected CLI exposes snapshot/schema commands but no general event-stream wrapper. `events.subscribe` requires a persistent raw socket connection; `agent.wait` is targeted coordination, not a cluster subscription. v0 therefore uses bounded periodic CLI snapshots and manual refresh, without a helper daemon or plugin.

A future socket transport must subscribe and receive acknowledgement **before** taking the bootstrap snapshot, buffer events during bootstrap, then reconcile them in order. It must resnapshot on reconnect and apply workspace/tab/pane/agent lifecycle updates. Do not assume that subscriptions replay earlier events. Expose changes to the store through the client boundary; SwiftUI should remain transport-independent.

Queries run concurrently, each with a 12-second process deadline and an 8 MB output bound. Both output pipes drain off the main actor. Cancellation kills the child-owned process group when available, and terminates the child otherwise. The store publishes each response as it arrives. Catalog failure retains known profiles, successful discovery removes deleted profiles, disabled profiles are not queried, and failed snapshots retain their last data and timestamp. Refreshes do not overlap. The refresh interval starts after the prior refresh completes, so unavailable remotes can lengthen a whole cluster cycle by up to the command deadline; manual refresh is disabled during that cycle.

## Deliberate limits

- Local is the default session. Remote profiles each identify one session.
- No live socket subscriptions in this CLI-only milestone.
- No persistence of cached session data across launches.
- No changes to Herdr state or machine configuration.
- Actual multi-host SSH validation needs configured machines; automated tests exercise multiple synthetic machines and failures through the same store/client boundary.
