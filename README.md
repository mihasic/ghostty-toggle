# GhosttyToggle

A ~200-line macOS background agent that binds one global hotkey — **Ctrl+`** — to show, hide, or launch [Ghostty](https://ghostty.org).

| Ghostty state | Ctrl+` does |
| --- | --- |
| Not running | Launches it |
| Running, not frontmost | Activates and focuses it |
| Running, frontmost | Hides it |
| Running with zero windows | Activates it **and** opens a new window |

No Dock icon, no menu bar item, no windows, no permission prompts.

## Why not just use Ghostty's own keybind?

`keybind = global:ctrl+backquote=toggle_visibility` gets you rows 2–3, but it cannot
launch Ghostty when Ghostty isn't running — nothing is there to receive the key.
That gap is the entire reason this exists.

## No permission prompts

The hotkey is registered with Carbon's **`RegisterEventHotKey`**, which needs no
Accessibility / Input Monitoring (TCC) grant. That matters practically: an
`NSEvent.addGlobalMonitorForEvents` or `CGEvent`-tap implementation would prompt on
first run *and* lose its grant every time the binary is rebuilt or re-signed, since
TCC keys on the code signature. Don't swap it out.

## Build & install

```sh
./build.sh              # compile, sign, install to ~/Applications, launch, register login item
./build.sh --no-install  # build only, leaves build/GhosttyToggle.app
```

Requirements: Xcode command line tools (Swift 6.x). No Xcode project, no SwiftPM, no
third-party dependencies — one `swiftc` invocation per architecture, then `lipo`.

The app is ad-hoc signed (`codesign -s -`), so it runs locally without a Developer ID
but is not distributable to other machines.

### Login item

`build.sh` launches the app, which calls `SMAppService.mainApp.register()` — a no-op
if it is already registered. macOS may show it under **System Settings → General →
Login Items & Extensions** as needing approval the first time.

## Uninstall

```sh
~/Applications/GhosttyToggle.app/Contents/MacOS/GhosttyToggle --unregister
pkill -x GhosttyToggle
rm -rf ~/Applications/GhosttyToggle.app
```

## Changing the hotkey

Edit `Config` in `Sources/main.swift` and rebuild:

```swift
static let keyCode: UInt32 = UInt32(kVK_ANSI_Grave)   // the key
static let modifiers: UInt32 = UInt32(controlKey)      // the modifiers
```

- **Key codes** are the `kVK_*` constants from `Carbon/HIToolbox/Events.h`
  (`kVK_ANSI_Grave` = 0x32, `kVK_Space` = 0x31, `kVK_ANSI_T` = 0x11, …). They are
  physical positions, not characters.
- **Modifiers** are Carbon masks, OR them together:
  `controlKey`, `optionKey`, `cmdKey`, `shiftKey`.
  e.g. Cmd+Option+T → `UInt32(cmdKey | optionKey)` with `kVK_ANSI_T`.

If the app exits immediately with *"could not register Ctrl+`"*, another process
already owns that combination.

## Other flags

```
GhosttyToggle                 run as background agent (default)
GhosttyToggle --toggle        perform one toggle and exit — scriptable, no hotkey
GhosttyToggle --state         print the detected Ghostty state
GhosttyToggle --unregister    remove from login items
GhosttyToggle --no-login-item run without touching login items
GhosttyToggle --help
```

`GHOSTTY_TOGGLE_BUNDLE_ID` overrides the target app, if you want to point this at a
different terminal:

```sh
GHOSTTY_TOGGLE_BUNDLE_ID=com.github.wez.wezterm ~/Applications/GhosttyToggle.app/Contents/MacOS/GhosttyToggle
```

## Logs

```sh
log stream --predicate 'subsystem == "com.mihasic.ghostty-toggle"' --info
```

Each hotkey press logs which of the four states it saw and what it did.

## Notes / known limits

- **Ghostty's quick terminal is a separate window class.** `NSApplication.hide()`
  does not hide it, so if the quick terminal is the only thing on screen, Ctrl+`
  will not put it away. Out of scope by design.
- **Two apps cannot share one combo — and the loser fails silently.** Ghostty's
  `global:` keybinds use the same `RegisterEventHotKey` mechanism. If Ghostty already
  binds Ctrl+`, *both* registrations return `noErr`, but only the first registrant
  ever receives the key: GhosttyToggle looks installed and does nothing. Verified
  experimentally — with Ghostty holding the key, presses went to Ghostty's quick
  terminal and GhosttyToggle's handler never ran; on a combo nothing else owned, the
  same binary toggled correctly on every press.

  So GhosttyToggle owns Ctrl+`, and the quick-terminal binding in
  `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` has moved to
  **Ctrl+Shift+`**. A running Ghostty keeps its old registration until it is
  restarted; a config reload is not enough to release it.
- **Window counting is deliberately absent.** Deciding "does Ghostty have any
  windows?" from `CGWindowListCopyWindowInfo` does not work: `.optionAll` reports
  retained buffers of already-closed windows, and `.optionOnScreenOnly` omits windows
  sitting on another Space. Instead a single LaunchServices open covers rows 1, 2 and
  4 of the table — AppKit itself decides whether a reopen needs a new window, and it
  is the only thing that actually knows.

## License

MIT — see [LICENSE](LICENSE).
