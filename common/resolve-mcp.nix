{ pkgs, ... }:
let
  resolve = pkgs.davinci-resolve-studio;
  # ResolveMCP loads fusionscript.so, which only finds its libraries inside Resolve's FHS env.
  resolve-mcp = pkgs.writeShellScriptBin "resolve-mcp" ''
    exec ${resolve}/bin/davinci-resolve-studio ${resolve.davinci}/bin/ResolveMCP "$@"
  '';
in
{
  environment.systemPackages = [ resolve-mcp ];
}
