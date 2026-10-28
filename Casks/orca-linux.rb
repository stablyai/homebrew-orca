cask "orca-linux" do
  # Why: the x86_64 asset carries no arch suffix (`orca-linux.AppImage`) while
  # arm64 does, so the suffix — not a bare arch name — is what varies; on
  # x86_64 `arch` is nil and interpolates away.
  arch arm: "-arm64"

  version "1.4.200"
  sha256 arm64_linux:  "3eb0ff9b111b8384eb9b8fe98d809aef3546f6954817759c882877b471604144",
         x86_64_linux: "c82d9ddf532431e0da51ec5d1899a0e315aabb8e77fce45ecce7fad4733fc96a"

  url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-linux#{arch}.AppImage"
  name "Orca"
  desc "IDE for orchestrating AI coding agents across terminals and worktrees"
  homepage "https://onorca.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Why the squashfs formula: extraction reads the image's embedded filesystem
  # with unsquashfs, so the tool has to be there on any host this installs on,
  # not only on the distributions that ship squashfs-tools themselves.
  depends_on formula: "squashfs"
  # Why a separate token: `orca` is this tap's macOS cask, so the Linux build
  # ships under its own name. The AppImage is a Linux ELF, so refuse to install
  # anywhere else rather than staging a broken payload.
  depends_on linux: :any

  # Why: `orca` is the CLI, matching the macOS cask and Orca's own Linux
  # CliInstaller, which symlinks ~/.local/bin/orca. The shim walks symlinks to
  # find its app dir, so Homebrew's bin symlink resolves correctly.
  binary "squashfs-root/resources/bin/orca-ide", target: "orca"
  # Why: the GUI must launch through AppRun, not the raw Electron binary. AppRun
  # probes `unshare -Ur` and appends --no-sandbox when user namespaces are
  # unavailable, and points LD_LIBRARY_PATH at the bundled libXss/libXtst/
  # libnotify/libappindicator. Launching orca-ide directly skips both. The name
  # matches Orca's Linux executable and the deb/rpm binary.
  binary "squashfs-root/AppRun", target: "orca-ide"
  artifact "squashfs-root/orca-ide.desktop",
           target: "#{Dir.home}/.local/share/applications/orca-ide.desktop"
  # Why: install all eight bundled sizes, not just 512x512. GNOME picks an icon
  # per context (16px in lists, 48px in the dash, 256px in the switcher) and
  # downscaling one large PNG gives visibly soft launcher icons.
  artifact "squashfs-root/usr/share/icons/hicolor/16x16/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/16x16/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/24x24/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/24x24/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/32x32/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/32x32/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/48x48/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/48x48/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/64x64/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/64x64/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/128x128/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/128x128/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/256x256/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/orca-ide.png"
  artifact "squashfs-root/usr/share/icons/hicolor/512x512/apps/orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/orca-ide.png"

  preflight_steps do
    # Why unsquashfs and not the image's own `--appimage-extract`: a type-2
    # AppImage unpacks itself by reopening its own file, and that reopen fails
    # inside a `run` step ("fopen error: Is a directory"). Unpacking with a
    # separate tool is the same split the Proton casks use, and it needs no
    # FUSE either.
    #
    # The offset comes out of the ELF header, so nothing has to execute: a
    # type-2 AppImage is an ELF followed by a squashfs filesystem, and the
    # boundary is the end of the section-header table — e_shoff (8 bytes at
    # 0x28) plus e_shnum (2 bytes at 0x3c) times e_shentsize (2 bytes at 0x3a).
    # `od` reads those three fields and is coreutils, so it costs no dependency
    # where readelf would pull in binutils. It is computed from the staged file
    # on every install because it moves with the bundled AppImage runtime.
    #
    # `-no-exit-code` is load-bearing: the step runs as the installing user, so
    # unsquashfs cannot restore the image's root ownership and grades that a
    # non-fatal error, which is exit 2 and would abort the install. It still
    # exits 1 on a fatal error, and `-ignore-errors` is deliberately absent, so
    # a file it cannot write is fatal rather than leaving a half-filled
    # squashfs-root for the artifacts. `-f` lets it descend into the
    # destination and `-n` drops the progress bar.
    run "/bin/sh",
        args:  ["-c", <<~'EXTRACT'],
          set -e
          image=./orca-linux{{arch}}.AppImage
          shoff=$(od -An -tu8 -j40 -N8 --endian=little "$image" | tr -d ' ')
          shentsize=$(od -An -tu2 -j58 -N2 --endian=little "$image" | tr -d ' ')
          shnum=$(od -An -tu2 -j60 -N2 --endian=little "$image" | tr -d ' ')
          {{HOMEBREW_PREFIX}}/bin/unsquashfs -no-exit-code -n -f \
            -o "$((shoff + shnum * shentsize))" -d squashfs-root "$image"
        EXTRACT
        chdir: "{{staged_path}}"

    # Why: the extracted tree is the install; keeping the 193 MB image too would
    # double the Caskroom footprint for no benefit.
    remove "orca-linux{{arch}}.AppImage"

    # Why: Orca ships an electron-updater manifest and marks
    # resources/package-type as "AppImage", so the app treats itself as
    # self-updating. It cannot actually damage this install: AppRun assigns
    # APPIMAGE without exporting it, so AppImageUpdater finds no image to
    # overwrite and its install step fails instead of replacing AppRun. Dropping
    # the manifest removes the remaining reason for the app to fetch a release it
    # cannot install, and keeps brew unambiguously in charge of the version.
    # The app configures its feed programmatically, so treat this as belt rather
    # than braces — `brew upgrade` is the update path either way.
    remove "squashfs-root/resources/app-update.yml"

    # Why: `Exec=AppRun %U` only resolves inside a mounted AppImage. Point it at
    # the Homebrew bin symlink so the entry survives version bumps, and keep %U
    # so the x-scheme-handler/orca and text/markdown handlers still get their arg.
    # No `audit_result: false` here, unlike the two below: a .desktop with no
    # Exec line is a broken payload and should fail the install loudly.
    inreplace "squashfs-root/orca-ide.desktop",
              /^Exec=.*$/,
              "Exec={{HOMEBREW_PREFIX}}/bin/orca-ide %U"
    # Why: an IDE under Utility lands in GNOME's "Utilities" folder. Both keys
    # are optional in a .desktop file, so `audit_result: false` keeps a build
    # that omits one installable — `inreplace` raises on an absent pattern.
    inreplace "squashfs-root/orca-ide.desktop",
              /^Categories=.*$/,
              "Categories=Development;IDE;",
              audit_result: false
    # Why: brew owns the version here, so an AppImage-provenance stamp would go
    # stale on the first upgrade and misreport what's installed.
    inreplace "squashfs-root/orca-ide.desktop",
              /^X-AppImage-Version=.*\n/,
              "",
              audit_result: false
    # StartupWMClass=orca is left untouched: it's what lets the shell group
    # Orca's windows under this launcher icon.
  end

  # Why: without a database refresh the entry and its URL handler only appear
  # after the next login. `must_succeed: false` keeps the step a no-op on
  # desktops that don't ship the tool.
  #
  # The path is spelled out with `{{user}}` rather than `~`, and that is
  # load-bearing. These steps run inside Homebrew's cask sandbox, which has its
  # own empty $HOME, so `~` expands to a directory that does not exist — both
  # refreshes then silently no-op and `must_succeed: false` hides it. There is
  # no `{{home}}` token (the runner's token list is prefix/staged_path/appdir
  # and friends, plus `{{user}}`), `chdir` resolves only against the step's
  # default base, and interpolating #{Dir.home} is rejected by the style cop,
  # which allows only step DSL calls and literal arguments inside a steps
  # block. Hardcoding /home is safe here because the cask is Linux-only.
  #
  # `writable_paths` is load-bearing for the same reason: the sandbox grants a
  # step write access to the Caskroom, the appdir and the linked prefix
  # directories only, so without it update-desktop-database reports "The
  # databases in [.] could not be updated" and gtk-update-icon-cache reports
  # "Permission denied" on .icon-theme.cache — both swallowed by
  # `must_succeed: false`. `writable_base: :home` resolves against the real
  # home the runner is handed, not the sandbox's empty $HOME.
  postflight_steps do
    run "update-desktop-database",
        args:           ["."],
        chdir:          "/home/{{user}}/.local/share/applications",
        writable_paths: [".local/share/applications"],
        writable_base:  :home,
        must_succeed:   false
    run "gtk-update-icon-cache",
        args:           ["-f", "-t", "."],
        chdir:          "/home/{{user}}/.local/share/icons/hicolor",
        writable_paths: [".local/share/icons/hicolor"],
        writable_base:  :home,
        must_succeed:   false
  end

  uninstall_postflight_steps do
    run "update-desktop-database",
        args:           ["."],
        chdir:          "/home/{{user}}/.local/share/applications",
        writable_paths: [".local/share/applications"],
        writable_base:  :home,
        must_succeed:   false
    run "gtk-update-icon-cache",
        args:           ["-f", "-t", "."],
        chdir:          "/home/{{user}}/.local/share/icons/hicolor",
        writable_paths: [".local/share/icons/hicolor"],
        writable_base:  :home,
        must_succeed:   false
  end

  # Why: Orca keeps worktrees and agent state in ~/.orca, as it does on macOS,
  # plus Electron's userData directory. That directory is lowercase `orca`: the
  # packaged app.asar declares `name: "orca"` with no productName and never calls
  # setPath, and a real Linux install was observed creating ~/.config/orca. The
  # capitalised macOS spelling would silently miss it on a case-sensitive volume.
  zap trash: [
    "~/.cache/orca",
    "~/.config/orca",
    "~/.orca",
  ]

  caveats <<~EOS
    Homebrew owns this install's version. Orca's own updater cannot replace it,
    because an extracted AppImage leaves it nothing to write back to, but it can
    still report a release it is unable to install. Upgrade with:
      brew upgrade --cask orca-linux

    Both `orca` and `orca-ide` are Electron, so they link against a desktop
    runtime (GTK 3, NSS, cups, ALSA) that Homebrew cannot supply. A desktop
    install already has it. On a headless host, install your distribution's
    Electron or Chromium dependencies before running `orca serve`, or the
    binaries will fail at load time rather than on launch.
  EOS
end
