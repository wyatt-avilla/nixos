{ pkgs, ... }:
{
  nixpkgs.overlays = [ (final: _prev: { codex = final.callPackage ./codex.nix { }; }) ];

  users.users.wyatt.packages = [ pkgs.codex ];
}
