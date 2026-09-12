<p align="center">
  <img src="docs/open-guard-hero.png" alt="OpenGuard protecting default file associations" width="100%">
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

# OpenGuard

OpenGuard is a lightweight native macOS menu bar utility that keeps filename extensions assigned to the applications you choose. If another application changes a default handler, OpenGuard restores your rule automatically.

## Why OpenGuard exists

It started with one very specific annoyance: after assigning `.md` files to Visual Studio Code, Xcode or another application would take the association back. Finder's “Always Open With” can repair it once, but cannot stop the next takeover.

OpenGuard keeps the user's choice stable without a privileged helper, a heavy background service, or administrator access.

## Highlights

- 33 programmer-friendly presets grouped into text and source code, documents, images, media, and archives.
- Set one application for a whole group, then override individual extensions when needed.
- Add groups and rules, reorder them by dragging, move rules across groups, and rename groups from the context menu. Removing a group moves its rules safely to the root.
- Search applications by localized name, original name, Bundle ID, or path—including system aliases such as the localized name of Preview.
- Restore changed handlers every three seconds, plus immediate checks after wake and app activation.
- Native AppKit implementation with no third-party runtime.
- Five switchable UI languages: 简体中文, English, 日本語, 한국어, and Español.
- Universal Intel and Apple Silicon support, back to macOS 10.13.
- No administrator privileges; login launch uses a user-level LaunchAgent.
- Non-blocking update checks on launch and every hour, using GitHub Releases as the source of truth.

## Usage

1. Move `OpenGuard.app` to `/Applications`.
2. Use the top buttons to add groups or rules. Drag rows to reorder them or move rules between groups and the root.
3. Click `…` on a group to assign one application to every extension, or on an extension to create an override. Right-click a group to rename it.
4. Optionally enable **Start OpenGuard at login**, and leave automatic restoration enabled.

The menu bar utility remains active after its window closes. Removing a group preserves its rules at the root. **Initialize Groups** is kept inside the top **Settings** menu and requires confirmation.

## How it works—and its limit

OpenGuard reads and updates handlers through macOS Launch Services and Uniform Type Identifiers (UTIs). It is not a kernel-level interceptor and cannot prevent another process from writing to the system database. Instead, it detects a change and restores the selected handler quickly, keeping the design lightweight and unprivileged.

## Update checks

- One asynchronous check on every launch; startup and rule protection are never blocked.
- One check every hour while OpenGuard is running.
- A new version is shown only once per run.
- Network errors, rate limits, and repositories without a Release are skipped quietly.
- OpenGuard opens the GitHub release page only after confirmation; it never downloads or installs an update silently.

## Compatibility

- macOS 10.13 High Sierra or later
- Intel (`x86_64`) and Apple Silicon (`arm64`)
- No third-party runtime or administrator privileges required

## Build

Xcode Command Line Tools are required:

```sh
make clean verify
```

The universal app is written to `build/OpenGuard.app`. Local builds use ad-hoc signing; public binaries should be signed with an Apple Developer ID and notarized.

To create a drag-to-Applications DMG, a fallback ZIP, and SHA-256 checksums:

```sh
make clean package
```

To inspect one extension:

```sh
build/OpenGuard.app/Contents/MacOS/OpenGuard --diagnose md
```

## Privacy

OpenGuard contains no telemetry, advertising, or tracking. It never uploads rules, filenames, file lists, or the application index. Its only network request retrieves public Release metadata from the GitHub API.

Rules are kept in macOS user defaults. If login launch is enabled, OpenGuard creates only:

`~/Library/LaunchAgents/com.gloryhuis.OpenGuard.agent.plist`

## Artwork

The icon and README hero were created specifically for OpenGuard from original text-only prompts. No reference images, stock assets, third-party trademarks, or existing application logos were used. See [ARTWORK.md](ARTWORK.md).

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0). You may inspect, modify, fork, and redistribute OpenGuard for noncommercial purposes. Commercial use is not permitted. This is not an OSI-approved open-source license.
