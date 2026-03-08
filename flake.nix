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
          hashedPassword = builtins.getEnv "HASHED_PASSWORD";
        in
        {
          vpsImage =
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
                    text = nixpkgs.lib.throwIfNot (
                      ageKey != ""
                    ) "SOPS_AGE_KEY must be set. Use: nix run .#build-vps-image" ageKey;
                    mode = "0400";
                  };

                  users.users.wyatt.hashedPassword = nixpkgs.lib.throwIfNot (
                    hashedPassword != ""
                  ) "HASHED_PASSWORD must be set. Use: nix run .#build-vps-image" hashedPassword;
                }
              ];
            }).config.system.build.images.digital-ocean;
        };

      apps.${system}.build-vps-image =
        let
          script = pkgs.writeShellApplication {
            name = "build-vps-image";
            runtimeInputs = with pkgs; [
              mkpasswd
              nix
            ];
            text = ''
              if [ -z "''${SOPS_AGE_KEY:-}" ]; then
                echo "Enter SOPS age private key:"
                read -r SOPS_AGE_KEY
                export SOPS_AGE_KEY
              fi

              echo "Enter user password:"
              HASHED_PASSWORD=$(mkpasswd --method=yescrypt)
              export HASHED_PASSWORD

              SOPS_AGE_KEY="$SOPS_AGE_KEY" \
              HASHED_PASSWORD="$HASHED_PASSWORD" \
              nix build .#vpsImage --impure "$@"
            '';
          };
        in
        {
          type = "app";
          program = "${script}/bin/build-vps-image";
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
