{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    nix-secrets = {
      url = "git+ssh://git@github.com/wyatt-avilla/nix-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ci = {
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
      nix-ci,
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

      ci = nix-ci.lib.mkProject {
        inherit pkgs;
        src = self;
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
          missingVpsImageInputs =
            nixpkgs.lib.optionals (ageKey == "") [ "SOPS_AGE_KEY" ]
            ++ nixpkgs.lib.optionals (hashedPassword == "") [ "HASHED_PASSWORD" ];
          skippedVpsImageMessage = "skipping VPS image build because ${nixpkgs.lib.concatStringsSep " and " missingVpsImageInputs} ${
            if builtins.length missingVpsImageInputs == 1 then "is" else "are"
          } not set. Use `nix run .#build-vps-image` to provide the impure inputs.";
          skippedVpsImage = nixpkgs.lib.warn skippedVpsImageMessage (
            pkgs.runCommand "vps-image-skipped" { } ''
              echo ${nixpkgs.lib.escapeShellArg "warning: ${skippedVpsImageMessage}"} >&2
              mkdir -p "$out"
              printf '%s\n' ${nixpkgs.lib.escapeShellArg skippedVpsImageMessage} > "$out/README"
            ''
          );
        in
        {
          vpsImage =
            if missingVpsImageInputs == [ ] then
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

                    users.users.wyatt.hashedPassword = hashedPassword;
                  }
                ];
              }).config.system.build.images.digital-ocean
            else
              skippedVpsImage;
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

      formatter.${system} = ci.formatter;

      devShells.${system}.default = ci.devShell;

      checks.${system} = ci.checks;
    };
}
