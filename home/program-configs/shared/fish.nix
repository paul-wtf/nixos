{ ... }:
{
  programs.fish = {
    enable = true;
    # Generate completions from man pages (for tools without their own fish completions)
    generateCompletions = true;
    # Startup overview: hyfetch (teal-sky modules from fastfetch.nix) only in the
    # first interactive fish per terminal window — nested shells and
    # tmux splits inherit __greeting_shown and stay quiet.
    interactiveShellInit = ''
      set -g fish_greeting
      if not set -q __greeting_shown
          set -gx __greeting_shown 1
          command -q hyfetch; and hyfetch
      end
    '';
    shellAliases = {
      grep = "rg";
      ls = "eza -la --group-directories-first --icons auto";
      cat = "bat";
      claude = "tmux new claude";
    };
  };

  # Install the alias targets right next to the aliases so they exist on
  # every platform (on the Mac they used to come from Homebrew only).
  # bat/eza also get catppuccin-themed via autoEnable this way.
  programs.ripgrep.enable = true;
  programs.eza.enable = true;
  programs.bat.enable = true;

  # Completions for hundreds of CLIs (git, docker, kubectl, nix, ...) incl. descriptions
  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
  };

  # Fuzzy finder: Ctrl+R = fuzzy history, Ctrl+T = files, Alt+C = cd
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
}
