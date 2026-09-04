{ config, lib, pkgs, ... }:

let
  # ── Canonical store ──────────────────────────────────────────────────────
  # One git checkout shared by all devices. The file-based memories are
  # tiny Markdown files; the store keeps one folder per project.
  repoUrl = "git@github.com:paul-wtf/claude-memory.git";
  store   = "${config.home.homeDirectory}/claude-memory";

  # sync.sh in the store links every project memory on this machine, deriving
  # the store folder from the project path -- so no list here goes stale.
  syncScript = "${store}/sync.sh";

  # ── Global CLAUDE.md ─────────────────────────────────────────────────────
  # The instructions read in every session on every device, so they belong in
  # the same store as the memories.
  claudeMd       = "${store}/CLAUDE.md";
  claudeMdTarget = "${config.home.homeDirectory}/.claude/CLAUDE.md";

  # A real file on this machine is moved into the store rather than backed up
  # when the store has none — otherwise the first switch on the machine that
  # wrote the file would strand its content in a backup nobody reads again.
  claudeMdLines = ''
    run mkdir -p "${config.home.homeDirectory}/.claude"
    if [ -e "${claudeMdTarget}" ] && [ ! -L "${claudeMdTarget}" ]; then
      if [ -e "${claudeMd}" ]; then
        run mv "${claudeMdTarget}" "${claudeMdTarget}.pre-sync-backup-$(${pkgs.coreutils}/bin/date +%s)"
      else
        run mv "${claudeMdTarget}" "${claudeMd}"
      fi
    fi
    [ -e "${claudeMd}" ] || run touch "${claudeMd}"
    run ln -sfn "${claudeMd}" "${claudeMdTarget}"
  '';

in
{
  # git is needed at activation and hook runtime.
  home.packages = [ pkgs.git ];

  # ── Activation ───────────────────────────────────────────────────────────
  # Runs on every `home-manager switch`. Clones the store the first time,
  # afterwards pulls, then lets sync.sh place the links. Idempotent.
  home.activation.claudeMemorySync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH"
      if [ ! -d "${store}/.git" ]; then
        run git clone ${repoUrl} "${store}" || \
          echo "claude-memory: clone failed (SSH key present?)"
      else
        run git -C "${store}" pull --rebase --autostash --quiet || true
      fi
      if [ -e "${syncScript}" ]; then
        run ${pkgs.bash}/bin/bash "${syncScript}" || true
      fi
      ${claudeMdLines}
    '';

  # ── Sync hooks ───────────────────────────────────────────────────────────
  # Merged into ~/.claude/settings.json (home-manager combines
  # programs.claude-code.settings across modules).
  programs.claude-code.settings.hooks = {
    # On session start, fetch the latest state from the other devices.
    SessionStart = [{
      hooks = [{
        type = "command";
        command = "(${pkgs.git}/bin/git -C ${store} pull --rebase --autostash --quiet; PATH=${pkgs.git}/bin:$PATH ${pkgs.bash}/bin/bash ${syncScript}) >/dev/null 2>&1 || true";
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
