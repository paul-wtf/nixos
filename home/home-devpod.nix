{ lib, pkgs, ... }:
let
  # gpg-agent hands pinentry the tty of whoever asked, and for a Claude session
  # that is the terminal Claude draws in. The prompt goes to a tmux window instead.
  pinentryTmux = pkgs.writeShellApplication {
    name = "pinentry-tmux";
    runtimeInputs = with pkgs; [ coreutils gnused tmux ];
    text = ''
      tmux has-session -t main 2>/dev/null || tmux new-session -d -s main
      read -r pane tty < <(tmux new-window -t main -n gpg -P -F '#{pane_id} #{pane_tty}' 'exec sleep 86400')
      dir=$(mktemp -d)
      mkfifo "$dir/in"
      pin=""
      feed=""
      cleanup() {
        [ -z "$pin" ] || kill "$pin" 2>/dev/null || true
        [ -z "$feed" ] || kill "$feed" 2>/dev/null || true
        tmux kill-pane -t "$pane" 2>/dev/null || true
        rm -rf "$dir"
      }
      trap cleanup EXIT
      # gpg-agent cancels a prompt whose caller went away by signalling this process.
      trap 'exit 130' INT TERM HUP

      ${lib.getExe' pkgs.pinentry-curses "pinentry-curses"} --ttyname "$tty" --ttytype tmux-256color < "$dir/in" &
      pin=$!
      sed -u -e "s|^OPTION ttyname=.*|OPTION ttyname=$tty|" -e 's|^OPTION ttytype=.*|OPTION ttytype=tmux-256color|' <&0 > "$dir/in" &
      feed=$!

      # Once gpg-agent closes our stdin, pinentry gets nothing more to answer.
      wait -n "$pin" "$feed" || true
      if kill -0 "$pin" 2>/dev/null && ! kill -0 "$feed" 2>/dev/null; then
        sleep 1
        kill "$pin" 2>/dev/null || true
      fi
      wait "$pin"
    '';
  };
in
{
  imports = [
    ./home-headless.nix
    ./program-configs/linux/gpg-agent.nix
  ];

  home.username = "paul";
  home.homeDirectory = "/home/paul";
  targets.genericLinux.enable = true;

  services.gpg-agent.pinentry.package = lib.mkForce pinentryTmux;

  programs.ssh.settings."*" = {
    User = "root";
    IdentityAgent = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
  };

  programs.neovim.initLua = lib.mkAfter ''
    vim.g.clipboard = "osc52"
  '';

  programs.claude-code.settings = {
    model = "opus[1m]";
    inputNeededNotifEnabled = true;
    agentPushNotifEnabled = true;
    defaultToAgentsView = false;
  };

  home.packages = with pkgs; [ kubectl fluxcd gh go jdk jq kubelogin-oidc ];
}
