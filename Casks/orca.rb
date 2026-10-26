cask "orca" do
  arch arm: "arm64", intel: "x64"

  version "1.4.241"
  sha256 arm:   "be5000497b370e9727c2343de50720312b9882d59ec0ba2012c02fbddc8e305e",
         intel: "cde5cb6793b53b19faeb58bb968160571428d023d62bf4c5639b6ab79bc9c90b"

  url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-macos-#{arch}.dmg"
  name "Orca"
  desc "IDE for orchestrating AI coding agents across terminals and worktrees"
  homepage "https://onorca.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Let the in-app updater own updates; Homebrew skips auto_updates unless --greedy.
  auto_updates true
  conflicts_with cask: "orca@rc"
  depends_on macos: :big_sur

  app "Orca.app"

  # Expose the symlink-resolving bundled CLI on PATH so headless hosts can use orca serve without the in-app installer.
  binary "#{appdir}/Orca.app/Contents/Resources/bin/orca"

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
