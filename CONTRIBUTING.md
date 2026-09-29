# Contributing

Shepherdr is an independent, read-only macOS client for Herdr. Issues and pull requests are welcome.

Use Swift 6 and Xcode 16 or later. Run `swift test` and the Xcode build/test command in the README before opening a pull request. Keep SwiftUI separate from transport and DTOs, preserve unknown-field compatibility, and include regression coverage for protocol or store behavior. Test fixtures must contain synthetic data, not real project paths or SSH profiles.

No third-party dependencies are currently needed. Discuss additions first. Do not copy Herdr implementation code. Describe which supported public API your change uses and how it behaves when a machine is unavailable.

The project uses Apache-2.0. Contributions are accepted under that license.
