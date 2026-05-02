{ nixpkgs.overlays = [ (final: prev: { codex = final.callPackage ./codex.nix { }; }) ]; }
