# GhosttyToggle

One global hotkey — **⌥`** (Option + backtick) — to show, hide, or launch
[Ghostty](https://ghostty.org), from anywhere in macOS.

| Ghostty is… | ⌥` does |
| --- | --- |
| Not running | Launches it |
| Behind another app | Brings it to the front |
| In front of you | Hides it |
| Running with no windows | Brings it up **and** opens a new window |

It runs in the background: no Dock icon, no menu bar item, no windows, and no
permission prompts. Starts automatically at login.

**Why not Ghostty's own `global:` keybind?** It handles rows 2 and 3, but it cannot
launch Ghostty when Ghostty isn't running — there's no app there to receive the key.
This fills that gap.

## Install

```sh
brew tap mihasic/ghostty-toggle https://github.com/mihasic/ghostty-toggle
brew trust mihasic/ghostty-toggle
brew install --cask ghostty-toggle
```

Homebrew 6 requires the explicit `brew trust` for any tap outside the official ones.

That's it — ⌥` works immediately, and GhosttyToggle starts at login from then on.
macOS may ask you to approve it once under **System Settings → General → Login
Items & Extensions**.

Requires macOS 13 (Ventura) or later. Apple Silicon and Intel.

### Upgrade

```sh
brew upgrade --cask ghostty-toggle
```

### Uninstall

```sh
brew uninstall --cask ghostty-toggle
```

This also removes it from your login items.

### Without Homebrew

Download the DMG from [Releases](https://github.com/mihasic/ghostty-toggle/releases),
drag **GhosttyToggle** to Applications, then clear the download quarantine and launch
it:

```sh
xattr -dr com.apple.quarantine /Applications/GhosttyToggle.app
open /Applications/GhosttyToggle.app
```

The app is ad-hoc signed rather than notarized (no paid Apple Developer account), so
without that `xattr` step Gatekeeper refuses to open it. The Homebrew cask does it for
you.

## Ghostty's quick terminal

If you also use Ghostty's built-in quick terminal, give it a **different** combo —
two apps cannot share one hotkey, and the loser fails silently rather than warning you.
In `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`:

```
keybind = global:ctrl+shift+grave_accent=toggle_quick_terminal
```

A running Ghostty holds its old binding until you restart it; reloading the config is
not enough.

## Why ⌥` and not ⌃`

⌃` is the usual quake-terminal binding, and also **toggle integrated terminal** in
VS Code, Zed and JetBrains IDEs. A global hotkey is grabbed system-wide, so binding
⌃` here would silently kill the terminal toggle in every editor. ⌥` is unclaimed and
keeps the one-modifier muscle memory; its only cost is the grave-accent dead key
(⌥` then `a` → à).

## Changing the hotkey

Edit `Config` in `Sources/main.swift`, then run `./build.sh`:

```swift
static let keyCode: UInt32 = UInt32(kVK_ANSI_Grave)   // kVK_* from Carbon/HIToolbox/Events.h
static let modifiers: UInt32 = UInt32(optionKey)       // controlKey | optionKey | cmdKey | shiftKey
```

Key codes are physical key positions, not characters. Combos worth avoiding: ⌘`
(cycle windows in an app), ⌘Space (Spotlight), ⌥Space (Raycast/Alfred), ⌃Space (input
source, IDE completion). If the app exits with *"could not register"*, something else
already owns that combination.

## Command line

```
GhosttyToggle                 run as background agent (default)
GhosttyToggle --toggle        perform one toggle and exit — scriptable, no hotkey
GhosttyToggle --state         print the detected Ghostty state
GhosttyToggle --login-status  print the login-item registration status
GhosttyToggle --unregister    remove from login items
GhosttyToggle --version
GhosttyToggle --help
```

The binary lives at `/Applications/GhosttyToggle.app/Contents/MacOS/GhosttyToggle`.

Point it at a different terminal with `GHOSTTY_TOGGLE_BUNDLE_ID`, e.g.
`GHOSTTY_TOGGLE_BUNDLE_ID=com.github.wez.wezterm`.

Watch what it's doing:

```sh
log stream --predicate 'subsystem == "com.mihasic.ghostty-toggle"' --info
```

## Build from source

```sh
./build.sh               # build, sign, install to ~/Applications, launch
./build.sh --no-install  # build only
./build.sh --dmg         # build and package build/GhosttyToggle-<version>.dmg
```

Needs the Xcode command line tools (Swift 6.x). ~250 lines of Swift, one `swiftc`
invocation per architecture — no Xcode project, no SwiftPM, no dependencies.

`build.sh` installs to `~/Applications`, so uninstall the Homebrew copy first
(`brew uninstall --cask ghostty-toggle`) — two copies fight over the hotkey and the
loser fails silently.

Releases are cut by tagging: `git tag v$(cat VERSION) && git push origin v$(cat VERSION)`.
[`.github/workflows/release.yml`](.github/workflows/release.yml) builds the universal
DMG, publishes it, and updates [`Casks/ghostty-toggle.rb`](Casks/ghostty-toggle.rb).

## Design notes

- **`RegisterEventHotKey`, not an event tap.** This needs no Accessibility / Input
  Monitoring grant. A `CGEvent` tap would prompt on first run and lose the grant on
  every rebuild, since TCC keys on the code signature.
- **Two apps cannot share a combo, and the loser fails silently.** Both registrations
  return `noErr`; only the first one to register receives the key.
- **Ghostty's quick terminal is a separate window class.** `NSApplication.hide()` does
  not hide it, so ⌥` will not put away a lone quick terminal. Out of scope by design.
- **No window counting.** `CGWindowListCopyWindowInfo` cannot answer "does Ghostty
  have windows?" — `.optionAll` reports buffers of closed windows, `.optionOnScreenOnly`
  omits other Spaces. A single LaunchServices open covers rows 1, 2 and 4 instead;
  AppKit itself decides whether a reopen needs a new window.

## License

MIT — see [LICENSE](LICENSE).
