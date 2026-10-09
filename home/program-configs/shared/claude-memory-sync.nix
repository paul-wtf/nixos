{ config, lib, pkgs, ... }:

let
  # ── Canonical store ──────────────────────────────────────────────────────
  # One git checkout shared by all devices. The file-based memories are
  # tiny Markdown files; the store keeps one folder per project.
  repoUrl = "git@github.com:paul-wtf/claude-memory.git";
  store   = "${config.home.homeDirectory}/claude-memory";

  # The store's own sync.sh links every project memory on this machine into
  # it, nested repos (~/git/cyperia/core -> cyperia-core) included, so there
  # is no project list here.
  syncScript = pkgs.writeShellScript "claude-memory-sync" ''
    export PATH=${lib.makeBinPath (with pkgs; [ bash coreutils diffutils gnugrep gnused git openssh ])}:$PATH
    git -C ${store} pull --rebase --autostash --quiet || true
    [ -f ${store}/sync.sh ] && bash ${store}/sync.sh || true
  '';

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

  # ── Activation: clone store + create symlinks ────────────────────────────
  # Runs on every `home-manager switch`. Idempotent: clones the store the
  # first time, afterwards only pulls; creates/refreshes the symlinks.
  home.activation.claudeMemorySync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH"
      if [ ! -d "${store}/.git" ]; then
        run git clone ${repoUrl} "${store}" || \
          echo "claude-memory: clone failed (SSH key present?) — memories stay local"
      fi
      run ${syncScript}
      ${claudeMdLines}
    '';

  # ── Sync hooks ───────────────────────────────────────────────────────────
  # Merged into ~/.claude/settings.json (home-manager combines
  # programs.claude-code.settings across modules).
  programs.claude-code.settings.hooks = {
    # On session start, fetch the latest state from the other devices and link
    # projects that are new on this machine.
    SessionStart = [{
      hooks = [{
        type = "command";
        command = "${syncScript}";
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
