# OpenGuard

OpenGuard is a tiny native macOS menu bar utility that keeps filename extensions
assigned to the applications you choose. If another application hijacks a
default handler, OpenGuard restores your rule automatically.

The first launch creates a `.md → Visual Studio Code` rule when VS Code is
installed. Add, replace, or remove rules from the OpenGuard window.

## Highlights

- Five switchable UI languages: 简体中文, English, 日本語, 한국어, and Español
- 33 built-in extension presets, plus a custom extension option
- Automatic restoration every ten seconds
- Optional login launch without administrator privileges

## Compatibility

- macOS 10.13 High Sierra or later
- Intel (`x86_64`) and Apple Silicon (`arm64`)
- No third-party runtime or administrator privileges required

OpenGuard uses the macOS Launch Services database. Rules are based on Uniform
Type Identifiers (UTIs), because that is how macOS represents filename types.

## Build

Xcode Command Line Tools are required:

```sh
make verify
```

The resulting universal app is `build/OpenGuard.app`. To create a ZIP suitable
for a GitHub release:

```sh
make package
```

The local build uses ad-hoc signing. A public binary release should be signed
with an Apple Developer ID and notarized before distribution to other Macs.

## Usage

1. Move `OpenGuard.app` to `/Applications`.
2. Open it and add an extension/application rule.
3. Enable **Start OpenGuard at login** after moving the app.
4. Leave automatic restoration enabled.

The menu bar indicator remains active even after the settings window closes.
OpenGuard checks rules every ten seconds.

## Diagnostic command

```sh
build/OpenGuard.app/Contents/MacOS/OpenGuard --diagnose md
```

## Privacy

OpenGuard has no network code. It stores rules in macOS user defaults and, when
requested, creates only this login-agent file:

`~/Library/LaunchAgents/com.gloryhuis.OpenGuard.agent.plist`

## License

Source-available under the
[PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0).
You may inspect, modify, fork, and redistribute OpenGuard for noncommercial
purposes. Commercial use is not permitted by this license.
