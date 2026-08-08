# GhosttyToggle

Global **⌥`** to show, hide, or launch [Ghostty](https://ghostty.org). macOS background
agent, ~200 lines of Swift, no Dock icon, no menu bar item, no permission prompts.

| Ghostty state | ⌥` does |
| --- | --- |
| Not running | Launches it |
| Running, not frontmost | Activates and focuses it |
| Running, frontmost | Hides it |
| Running with zero windows | Activates it **and** opens a new window |

Ghostty's own `keybind = global:…=toggle_visibility` covers rows 2–3 only — it cannot
launch Ghostty when Ghostty isn't running. That gap is why this exists.

## Build & install

```sh
./build.sh               # compile, sign, install to ~/Applications, launch, register login item
./build.sh --no-install  # build only
```

Needs Xcode command line tools (Swift 6.x); no SwiftPM, no dependencies. Ad-hoc signed,
so it runs locally but is not distributable. The login item may need approval once under
**System Settings → General → Login Items & Extensions**.

Uninstall:

```sh
~/Applications/GhosttyToggle.app/Contents/MacOS/GhosttyToggle --unregister
pkill -x GhosttyToggle
rm -rf ~/Applications/GhosttyToggle.app
```

## Flags

```
GhosttyToggle                 run as background agent (default)
GhosttyToggle --toggle        perform one toggle and exit — scriptable, no hotkey
GhosttyToggle --state         print the detected Ghostty state
GhosttyToggle --unregister    remove from login items
GhosttyToggle --no-login-item run without touching login items
GhosttyToggle --help
```

`GHOSTTY_TOGGLE_BUNDLE_ID` points it at another terminal, e.g.
`GHOSTTY_TOGGLE_BUNDLE_ID=com.github.wez.wezterm`.

Logs: `log stream --predicate 'subsystem == "com.mihasic.ghostty-toggle"' --info`

## Changing the hotkey

Edit `Config` in `Sources/main.swift` and rebuild:

```swift
static let keyCode: UInt32 = UInt32(kVK_ANSI_Grave)   // kVK_* from Carbon/HIToolbox/Events.h
static let modifiers: UInt32 = UInt32(optionKey)       // controlKey | optionKey | cmdKey | shiftKey
```

Key codes are physical positions, not characters. If the app exits with *"could not
register"*, another process owns that combination.

**Why ⌥` and not ⌃`:** ⌃` is the usual quake-terminal binding, and also toggle-integrated-
terminal in VS Code, Zed and JetBrains. `RegisterEventHotKey` grabs a combo system-wide, so
binding it here silently kills it in every editor. Also avoid ⌘` (cycle windows in app),
⌘Space (Spotlight), ⌥Space (Raycast/Alfred), ⌃Space (input source, IDE completion). ⌥` costs
only the grave-accent dead key; use `cmdKey | optionKey` if you type accents.

## Design notes

- **`RegisterEventHotKey`, not an event tap.** Needs no Accessibility / Input Monitoring
  grant. A `CGEvent` tap would prompt on first run and lose the grant on every rebuild,
  since TCC keys on the code signature. Don't swap it out.
- **Two apps cannot share one combo, and the loser fails silently.** Both registrations
  return `noErr`; only the first registrant gets the key. Ghostty's `global:` keybinds use
  the same mechanism, so its quick terminal must sit on a different combo. A running
  Ghostty holds its registration until restarted — a config reload does not release it.
- **Ghostty's quick terminal is a separate window class.** `NSApplication.hide()` does not
  hide it. Out of scope by design.
- **No window counting.** `CGWindowListCopyWindowInfo` cannot answer "does Ghostty have
  windows?" — `.optionAll` reports buffers of closed windows, `.optionOnScreenOnly` omits
  other Spaces. One LaunchServices open covers rows 1, 2 and 4 instead; AppKit decides
  whether a reopen needs a new window.

## License

MIT — see [LICENSE](LICENSE).
