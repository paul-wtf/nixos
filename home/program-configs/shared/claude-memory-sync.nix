{ config, lib, pkgs, ... }:

let
  # ── Canonical store ──────────────────────────────────────────────────────
  # One git checkout shared by all devices. The file-based memories are
  # tiny Markdown files; the store keeps one folder per project.
  repoUrl = "git@github.com:paul-wtf/claude-memory.git";
  store   = "${config.home.homeDirectory}/claude-memory";

  # ── Which projects ───────────────────────────────────────────────────────
  # All of them. There is no list: the store's own sync.sh derives a project's
  # folder from its Claude Code key minus the base directory the repo sits
  # under (~/git on NixOS, ~/fleet on macOS), so ~/git/spawnery and
  # ~/fleet/spawnery both meet spawnery/. It folds every real memory directory
  # on this machine into the store and replaces it with a symlink, then links
  # every store folder into its key here, so a project checked out for the
  # first time reads the shared memories from its very first session. The
  # rule lives in the store rather than here so that a machine without
  # home-manager runs exactly the same thing.
  sync = "${pkgs.bash}/bin/bash ${store}/sync.sh";

in
{
  # git is needed at activation and hook runtime.
  home.packages = [ pkgs.git ];

  # ── Activation: clone store + link everything ────────────────────────────
  # Runs on every `home-manager switch`. Idempotent: clones the store the
  # first time, afterwards only pulls; then lets sync.sh do the linking.
  home.activation.claudeMemorySync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.diffutils}/bin:${pkgs.gnugrep}/bin:${pkgs.hostname}/bin:$PATH"
      if [ ! -d "${store}/.git" ]; then
        run git clone ${repoUrl} "${store}" || \
          echo "claude-memory: clone failed (SSH key present?) — nothing linked"
      else
        run git -C "${store}" pull --rebase --autostash --quiet || true
      fi
      if [ -x "${store}/sync.sh" ]; then
        run ${sync}
      fi
    '';

  # ── Sync hooks ───────────────────────────────────────────────────────────
  # Merged into ~/.claude/settings.json (home-manager combines
  # programs.claude-code.settings across modules).
  programs.claude-code.settings.hooks = {
    # On session start, fetch the latest state from the other devices and
    # link any project that appeared since the last switch.
    SessionStart = [{
      hooks = [{
        type = "command";
        command = "(${pkgs.git}/bin/git -C ${store} pull --rebase --autostash --quiet; ${sync}) >/dev/null 2>&1 || true";
      }];
    }];

    # On session end, push back local changes (only when something changed,
    # race-safe via pull --rebase before push, || true so the session is not blocked).
    Stop = [{
      hooks = [{
        type = "command";
        command = "${pkgs.git}/bin/git -C ${store} add -A && ${pkgs.git}/bin/git -C ${store} diff --cached --quiet || (${pkgs.git}/bin/git -C ${store} commit -qm 'sync: memory update' && ${pkgs.git}/bin/git -C ${store} pull --rebase --autostash && ${pkgs.git}/bin/git -C ${store} push) || true";
      }];
    }];
  };
}
