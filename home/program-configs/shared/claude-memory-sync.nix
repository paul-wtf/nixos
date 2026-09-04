{ config, lib, pkgs, ... }:

let
  # ── Canonical store ──────────────────────────────────────────────────────
  # One git checkout shared by all devices. The file-based memories are
  # tiny Markdown files; the store keeps one folder per project.
  repoUrl = "git@github.com:paul-wtf/claude-memory.git";
  store   = "${config.home.homeDirectory}/claude-memory";

  # ── Projects ─────────────────────────────────────────────────────────────
  # Logical projects == store folder names.
  projectNames = [ "fluxcd" "nixos" "bernice-portfolio" ];

  # Candidate parent directories. The repos live in different places depending
  # on the machine (macOS: ~/fleet, NixOS: ~/git). Claude Code derives the
  # project key from the project working directory (every "/" becomes "-") —
  # so it diverges per machine. Instead of hard-coding the key, the activation
  # script looks for the FIRST existing path per project and computes the key
  # from it. This way the module adapts itself to every machine, and symlinks
  # are only created for projects that are actually checked out.
  projectBases = [
    "${config.home.homeDirectory}/fleet"
    "${config.home.homeDirectory}/git"
  ];

  basesSh = lib.concatStringsSep " " (map lib.escapeShellArg projectBases);

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

  # Per project: walk all base directories; if one exists, derive the key from
  # the real path (/home/paul/git/nixos -> -home-paul-git-nixos) and replace
  # the memory folder with a symlink to the store. A real pre-existing folder
  # is backed up beforehand so that nothing gets lost.
  linkLines = lib.concatStringsSep "\n" (map (name: ''
    for base in ${basesSh}; do
      proj="$base/${name}"
      [ -d "$proj" ] || continue
      key="$(echo "$proj" | ${pkgs.gnused}/bin/sed 's:/:-:g')"
      mem="${config.home.homeDirectory}/.claude/projects/$key/memory"
      run mkdir -p "${config.home.homeDirectory}/.claude/projects/$key"
      if [ -e "$mem" ] && [ ! -L "$mem" ]; then
        run mv "$mem" "$mem.pre-sync-backup-$(${pkgs.coreutils}/bin/date +%s)"
      fi
      run ln -sfn "${store}/${name}" "$mem"
    done
  '') projectNames);

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
          echo "claude-memory: clone failed (SSH key present?) — setting symlinks anyway"
      else
        run git -C "${store}" pull --rebase --autostash --quiet || true
      fi
      ${linkLines}
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
        command = "${pkgs.git}/bin/git -C ${store} pull --rebase --autostash --quiet || true";
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
