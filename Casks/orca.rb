cask "orca" do
  arch arm: "arm64", intel: "x64"

  version "1.4.278"
  sha256 arm:   "7066b5642428179153a0ab2a861c153fff53c45f61bf0a26efa65762c00eaa1e",
         intel: "0913ffd9f0ac18d8294f4b8f990a898db782fe9cda2854d688b966cba472210b"

  url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-macos-#{arch}.dmg"
  name "Orca"
  desc "IDE for orchestrating AI coding agents across terminals and worktrees"
  homepage "https://orca.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Let the in-app updater own updates between brew upgrades.
  auto_updates true
  conflicts_with cask: "orca@rc"
  depends_on macos: :ventura

  app "Orca.app"

  # Expose the symlink-resolving bundled CLI on PATH so headless hosts can use orca serve without the in-app installer.
  binary "#{appdir}/Orca.app/Contents/Resources/bin/orca"

  # depends_on can't say 13.4, and Homebrew upgrades auto_updates casks past the in-app updater's macOS gate.
  preflight_steps do
    run "/bin/sh", args: [
      "-c",
      'case "$(/usr/bin/sw_vers -productVersion)" in 13|13.[0-3]|13.[0-3].*) ' \
      'echo "Orca needs macOS 13.4 or later. Update macOS to upgrade Orca." >&2; exit 1;; esac',
    ]
  end

  # Zap app-created ~/.orca and Electron userData for a clean uninstall.
  zap trash: [
    "~/.orca",
    "~/Library/Application Support/Orca",
    "~/Library/Caches/com.stablyai.orca",
    "~/Library/Caches/com.stablyai.orca.ShipIt",
    "~/Library/HTTPStorages/com.stablyai.orca",
    "~/Library/Preferences/com.stablyai.orca.plist",
    "~/Library/Saved Application State/com.stablyai.orca.savedState",
  ]
end
