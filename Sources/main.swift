//
//  GhosttyToggle
//
//  A pure-background macOS agent that binds one global hotkey (Option+`) to
//  show / hide / launch Ghostty.
//
//  Carbon's RegisterEventHotKey, not an event tap: it needs no Accessibility grant.
//

import AppKit
import Carbon.HIToolbox
import ServiceManagement
import os

// MARK: - Configuration

private enum Config {
    /// Overridable to test against a scratch app or point at another terminal.
    static let targetBundleID =
        ProcessInfo.processInfo.environment["GHOSTTY_TOGGLE_BUNDLE_ID"] ?? "com.mitchellh.ghostty"

    /// Option+` — change these two and rebuild to rebind.
    static let keyCode: UInt32 = UInt32(kVK_ANSI_Grave)
    static let modifiers: UInt32 = UInt32(optionKey)

    /// Four-char signature + id identifying our hotkey in the Carbon event.
    static let hotKeySignature: OSType = 0x4754_4747  // 'GTGG'
    static let hotKeyID: UInt32 = 1

    /// Per-session agent variables, never worth handing down to Ghostty.
    static let poisonedEnvironmentPrefixes = ["CLAUDE", "_CLAUDE", "ANTHROPIC", "_ANTHROPIC", "AI_AGENT"]
}

private let log = Logger(subsystem: "com.mihasic.ghostty-toggle", category: "toggle")

// MARK: - Ghostty state

private enum GhosttyState {
    case notRunning
    case frontmost(NSRunningApplication)
    /// Hidden, behind other apps, or windowless — all handled by `showOrLaunch()`.
    case background(NSRunningApplication)
}

private func ghosttyApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: Config.targetBundleID).first
}

private func currentState() -> GhosttyState {
    guard let app = ghosttyApp() else { return .notRunning }
    // `isHidden` matters: a hidden app can still report isActive briefly.
    return app.isActive && !app.isHidden ? .frontmost(app) : .background(app)
}

// MARK: - Actions

private func ghosttyURL() -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Config.targetBundleID) {
        return url
    }
    let fallback = "/Applications/Ghostty.app"
    return FileManager.default.fileExists(atPath: fallback) ? URL(fileURLWithPath: fallback) : nil
}

/// Bring Ghostty to the front, launching it if it isn't running and giving it a
/// window if it has none.
///
/// One LaunchServices open covers all three, and not `activate()`: the reopen
/// event lets AppKit decide whether a window is needed, which we cannot count
/// reliably ourselves. It unhides on the way too.
private func showOrLaunch() {
    guard let url = ghosttyURL() else {
        log.error("Ghostty not found (bundle id \(Config.targetBundleID, privacy: .public))")
        return
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    config.createsNewApplicationInstance = false
    // Only consulted on a cold launch; a running Ghostty keeps its own env.
    config.environment = ProcessInfo.processInfo.environment.filter { key, _ in
        !Config.poisonedEnvironmentPrefixes.contains { key.hasPrefix($0) }
    }
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
        if let error {
            log.error("openApplication failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// The whole point of the app. Called from the Carbon handler and from `--toggle`.
func toggleGhostty() {
    switch currentState() {
    case .notRunning:
        log.notice("state: not running -> launch")
        showOrLaunch()
    case .frontmost(let app):
        log.notice("state: frontmost -> hide")
        app.hide()
    case .background:
        log.notice("state: background -> activate (and open a window if it has none)")
        showOrLaunch()
    }
}

// MARK: - Global hotkey (Carbon)

/// Kept alive for the process lifetime; unregistering is the OS's job at exit.
private var hotKeyRef: EventHotKeyRef?

/// Must capture nothing: `InstallEventHandler` takes a bare C function pointer.
private let hotKeyHandler: EventHandlerUPP = { _, event, _ in
    guard let event else { return OSStatus(eventNotHandledErr) }
    var received = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &received)
    guard status == noErr, received.id == Config.hotKeyID else {
        return OSStatus(eventNotHandledErr)
    }
    toggleGhostty()
    return noErr
}

private func registerHotKey() -> Bool {
    var spec = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed))

    let handlerStatus = InstallEventHandler(
        GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil)
    guard handlerStatus == noErr else {
        log.error("InstallEventHandler failed: \(handlerStatus)")
        return false
    }

    let id = EventHotKeyID(signature: Config.hotKeySignature, id: Config.hotKeyID)
    let status = RegisterEventHotKey(
        Config.keyCode, Config.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    guard status == noErr else {
        // -9868 (eventHotKeyExistsErr) means somebody else already owns Option+`.
        log.error("RegisterEventHotKey failed: \(status)")
        return false
    }
    return true
}

// MARK: - Login item

private func registerLoginItem() {
    let service = SMAppService.mainApp
    switch service.status {
    case .enabled:
        return  // already a login item; no-op
    case .requiresApproval:
        log.notice("login item awaiting approval in System Settings > General > Login Items")
        return
    default:
        do {
            try service.register()
            log.notice("registered as login item")
        } catch {
            log.error("login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private func unregisterLoginItem() {
    do {
        try SMAppService.mainApp.unregister()
        print("GhosttyToggle: unregistered from login items.")
    } catch {
        print("GhosttyToggle: unregister failed: \(error.localizedDescription)")
        exit(1)
    }
}

// MARK: - Entry point

let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--version") {
    // Set from ./VERSION at build time; only present when run inside the bundle.
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    print("GhosttyToggle \(version ?? "unknown")")
    exit(0)
}

if arguments.contains("--unregister") {
    unregisterLoginItem()
    exit(0)
}

if arguments.contains("--login-status") {
    // Meaningful only when run from inside the installed bundle.
    switch SMAppService.mainApp.status {
    case .enabled: print("enabled")
    case .requiresApproval: print("requires-approval")
    case .notRegistered: print("not-registered")
    case .notFound: print("not-found")
    @unknown default: print("unknown")
    }
    exit(0)
}

if arguments.contains("--state") {
    switch currentState() {
    case .notRunning: print("not-running")
    case .frontmost: print("frontmost")
    case .background(let app): print("background (hidden=\(app.isHidden))")
    }
    exit(0)
}

if arguments.contains("--toggle") {
    // One-shot: run the state machine without installing a hotkey.
    toggleGhostty()
    // Give the async openApplication callback a moment to fire.
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
    exit(0)
}

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    GhosttyToggle — global Option+` to show/hide/launch Ghostty.

      (no flags)     run as a background agent and register the hotkey
      --toggle       perform one toggle and exit
      --state        print the detected Ghostty state and exit
      --login-status print the login-item registration status
      --unregister   remove from login items
      --version      print the version
      --help         this message
    """)
    exit(0)
}

let app = NSApplication.shared
// Must happen before run(): no Dock icon, no menu bar, no windows.
app.setActivationPolicy(.accessory)

guard registerHotKey() else {
    fputs("GhosttyToggle: could not register Option+` — is another app using it?\n", stderr)
    exit(1)
}

if !arguments.contains("--no-login-item") {
    registerLoginItem()
}

log.notice("GhosttyToggle running; Option+` registered")
app.run()
