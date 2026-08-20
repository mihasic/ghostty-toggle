# Updated automatically by .github/workflows/release.yml on each tagged release.
cask "term-toggle" do
  version "0.0.1"
  sha256 "dbf4b8668845256a326fb35d0ab9817e92dc7271c78a4b97a7d04dfae8c54caa"

  url "https://github.com/mihasic/term-toggle/releases/download/v#{version}/TermToggle-#{version}.dmg",
      verified: "github.com/mihasic/term-toggle/"
  name "TermToggle"
  desc "Global hotkey to show, hide, or launch a terminal"
  homepage "https://github.com/mihasic/term-toggle"

  depends_on macos: :ventura

  app "TermToggle.app"

  postflight do
    # Ad-hoc signed, not notarized: strip the download quarantine or Gatekeeper
    # refuses to launch it. Then start it, so the hotkey works without a reboot.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/TermToggle.app"]
    system_command "/usr/bin/open", args: ["#{appdir}/TermToggle.app"]
  end

  uninstall quit:   "com.mihasic.term-toggle",
            script: {
              executable: "#{appdir}/TermToggle.app/Contents/MacOS/TermToggle",
              args:       ["--unregister"],
            }
end
