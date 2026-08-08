# Updated automatically by .github/workflows/release.yml on each tagged release.
cask "ghostty-toggle" do
  version "0.0.1"
  sha256 :no_check

  url "https://github.com/mihasic/ghostty-toggle/releases/download/v#{version}/GhosttyToggle-#{version}.dmg",
      verified: "github.com/mihasic/ghostty-toggle/"
  name "GhosttyToggle"
  desc "Global hotkey to show, hide, or launch Ghostty"
  homepage "https://github.com/mihasic/ghostty-toggle"

  depends_on macos: :ventura

  app "GhosttyToggle.app"

  postflight do
    # Ad-hoc signed, not notarized: strip the download quarantine or Gatekeeper
    # refuses to launch it. Then start it, so the hotkey works without a reboot.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/GhosttyToggle.app"]
    system_command "/usr/bin/open", args: ["#{appdir}/GhosttyToggle.app"]
  end

  uninstall quit:   "com.mihasic.ghostty-toggle",
            script: {
              executable: "#{appdir}/GhosttyToggle.app/Contents/MacOS/GhosttyToggle",
              args:       ["--unregister"],
            }
end
