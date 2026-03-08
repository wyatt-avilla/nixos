{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    nix-secrets = {
      url = "git+ssh://git@github.com/wyatt-avilla/nix-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-checks = {
      url = "git+ssh://git@github.com/wyatt-avilla/nix-ci";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-discord-bot = {
      url = "github:wyatt-avilla/claude-discord-bot";
    };

    wyattwtf = {
      url = "github:wyatt-avilla/wyatt.wtf";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-checks,
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

        vps = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
            inherit (self) inputs;
          };

          modules = [
            ./hosts/vps/configuration.nix
            inputs.nix-secrets.nixosModules.vps
          ];
        };
      };

      packages.${system} =
        let
          ageKey = builtins.getEnv "SOPS_AGE_KEY";
        in
        {
          vpsImage =
            assert
              ageKey != ""
              || throw "SOPS_AGE_KEY must be set. Usage: SOPS_AGE_KEY=\$(cat /path/to/key) nix build .#vpsImage --impure";
            (nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit system;
                inherit (self) inputs;
              };

              modules = [
                ./hosts/vps/configuration.nix
                inputs.nix-secrets.nixosModules.vps
                {
                  sops.age = {
                    keyFile = nixpkgs.lib.mkForce "/etc/sops/age-key";
                    sshKeyPaths = [ ];
                  };

                  environment.etc."sops/age-key" = {
                    text = ageKey;
                    mode = "0400";
                  };
                }
              ];
            }).config.system.build.images.digital-ocean;
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

      checks.${system} = {
        formatting = nix-checks.lib.mkFormattingCheck {
          inherit pkgs;
          src = self;
        };

        linting = nix-checks.lib.mkLintingCheck {
          inherit pkgs;
          src = self;
        };

        dead-code = nix-checks.lib.mkDeadCodeCheck {
          inherit pkgs;
          src = self;
        };
      };
    };
}
