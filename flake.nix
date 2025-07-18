{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";

    nix-secrets = {
      url = "git+ssh://git@github.com/wyatt-avilla/nix-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-secrets,
      ...
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
        };
      };

    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit (self) inputs;
          };

          modules = [ ./hosts/desktop/configuration.nix ];
        };

        laptop = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit (self) inputs;
          };

          modules = [ ./hosts/laptop/configuration.nix ];
        };

        homelab = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit (self) inputs;
          };

          modules = [
            ./hosts/homelab/configuration.nix
            inputs.nix-secrets.nixosModules.homelab
          ];
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          pre-commit
          nixfmt-rfc-style
          statix
        ];
        shellHook = ''
          pre-commit install
        '';
      };
    };
}
