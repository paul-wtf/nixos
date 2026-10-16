{ pkgs, ... }:
{
  environment.systemPackages = [ (import ./frameaverage-package.nix { inherit pkgs; }) ];
}
