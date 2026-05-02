{ pkgs, ... }:
{
  nixpkgs.overlays = [ (final: prev: { codex = final.callPackage ./codex.nix { }; }) ];

  users.users.wyatt.packages = [ pkgs.codex ];
}
