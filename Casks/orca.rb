cask "orca" do
  arch arm: "arm64", intel: "x64"

  version "1.4.22"
  sha256 arm:   "3cbfe53a9d6b78253a894692c48fa8feb11b89c7f8313bd19a7ab83ff36552be",
         intel: "e719be3c248fd3b27f71cc1798f762cf8bc375037617df362113679a9d07808f"

  url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-macos-#{arch}.dmg",
      verified: "github.com/stablyai/orca/"
  name "Orca"
  desc "IDE for orchestrating AI coding agents across terminals and worktrees"
  homepage "https://onorca.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Why: electron-updater (src/main/updater.ts) handles in-place updates by
  # writing a new Orca.app into /Applications. Marking the cask auto_updates
  # tells Homebrew not to compete with the in-app updater — `brew upgrade`
  # becomes a no-op unless the user passes --greedy, and brew's version
  # metadata stays aligned with whatever the app has swapped itself to.
  auto_updates true
  depends_on macos: ">= :big_sur"

  app "Orca.app"

  # Why: Orca writes user data under ~/.orca (worktrees, agent state) and
  # Electron's standard userData directories. Zap removes everything the app
  # creates during normal use so `brew uninstall --zap` is a clean slate.
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
