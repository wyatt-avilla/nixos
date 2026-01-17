{ inputs, config, ... }:
let
  inherit (config.variables) domain;
  proxyPass = "http://${config.variables.authAddress}";
in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = false;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    appendHttpConfig = ''
      proxy_buffer_size 128k;
      proxy_buffers 4 256k;
      proxy_busy_buffers_size 256k;
      large_client_header_buffers 4 16k;
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts = {
      "auth.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          inherit proxyPass;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Scheme $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
            proxy_set_header Connection "upgrade";
            proxy_set_header Upgrade $http_upgrade;
          '';
        };
      };

      "files.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations =
          let
            filebrowserProxy = "http://${config.variables.homelab.wireguard.ip}:${toString config.variables.filebrowser.port}";

            publicExtraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          in
          {
            "@error401" = {
              return = "302 /oauth2/start?rd=$scheme://$host$request_uri";
            };

            "/share" = {
              proxyPass = filebrowserProxy;
              extraConfig = publicExtraConfig;
            };

            "/static" = {
              proxyPass = filebrowserProxy;
              extraConfig = publicExtraConfig;
            };

            "/api/public/share" = {
              proxyPass = filebrowserProxy;
              extraConfig = publicExtraConfig;
            };

            "/api/public/dl" = {
              proxyPass = filebrowserProxy;
              extraConfig = publicExtraConfig;
            };

            "/" = {
              proxyPass = filebrowserProxy;
              extraConfig = ''
                auth_request /oauth2/auth;
                error_page 401 = @error401;

                auth_request_set $user $upstream_http_x_auth_request_user;
                auth_request_set $email $upstream_http_x_auth_request_email;
                proxy_set_header X-User $user;
                proxy_set_header X-Email $email;

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;

                client_max_body_size 50G;
              '';
            };

            "= /oauth2/auth" = {
              inherit proxyPass;
              extraConfig = ''
                internal;
                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_set_header X-Original-URI $request_uri;
              '';
            };

            "/oauth2/" = {
              inherit proxyPass;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
      };

      "bin.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations =
          let
            microbinProxy = "http://${config.variables.homelab.wireguard.ip}:${toString config.variables.microbin.port}";

            publicExtraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          in
          {
            "@error401" = {
              return = "302 /oauth2/start?rd=$scheme://$host$request_uri";
            };

            "/upload" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/p" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/raw" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/qr" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/file" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/static" = {
              proxyPass = microbinProxy;
              extraConfig = publicExtraConfig;
            };

            "/" = {
              proxyPass = microbinProxy;
              extraConfig = ''
                auth_request /oauth2/auth;
                error_page 401 = @error401;

                auth_request_set $user $upstream_http_x_auth_request_user;
                auth_request_set $email $upstream_http_x_auth_request_email;
                proxy_set_header X-User $user;
                proxy_set_header X-Email $email;

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };

            "= /oauth2/auth" = {
              inherit proxyPass;
              extraConfig = ''
                internal;
                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_set_header X-Original-URI $request_uri;
              '';
            };

            "/oauth2/" = {
              inherit proxyPass;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
      };

      "photos.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://${config.variables.homelab.wireguard.ip}:${toString config.variables.immich.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            client_max_body_size 50G;
          '';
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = inputs.nix-secrets.nixosModules.plainSecrets.personalEmail;
  };
}
