# v0 verification

Validated on macOS 26.6.2 (Apple Silicon), using Xcode 27.0 / Swift 6.4. Deployment target is macOS 14; an actual macOS 14 runtime has not been tested.

## Automated and live checks

- `xcodebuild -project Shepherdr.xcodeproj -scheme Shepherdr -configuration Debug -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test` — **passed**, building the native application and running 27 tests in 3 suites.
- `swift test` — **passed**, the same 27 tests.
- `shepherdr-probe` against the real local installation — **passed**: executable discovered, Herdr 0.9.0 / protocol 22 decoded, one real workspace, no detected agents at verification time.
- Xcode scheme XML, project plist and synthetic JSON fixtures — valid.
- Multiple machines, same IDs across machines, partial failures, recovery and stale retention — covered by the mock-client tests. No saved remote machine was available for real SSH verification.

## UI verification

Pending interactive verification: the computer was locked when the built app was first opened for inspection. The completed build and unit tests do not substitute for that check.

The remaining check is to inspect the real Local workspace and exercise a synthetic cluster through an injected CLI: table layout, search, state/workspace filters, sorting, inspector, refresh, stale retention and recovery.
