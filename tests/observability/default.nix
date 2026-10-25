{ pkgs, self }:
let
  rules = builtins.head self.nixosConfigurations.vps.config.services.prometheus.ruleFiles;
  tests = pkgs.writeText "rule-tests.json" (
    builtins.toJSON {
      rule_files = [ rules ];
      evaluation_interval = "30s";
      tests = [
        {
          interval = "30s";
          input_series = [
            {
              series = ''node_memory_MemAvailable_bytes{instance="test",host="test"}'';
              values = "5+0x22 50+0x4";
            }
            {
              series = ''node_memory_MemTotal_bytes{instance="test",host="test"}'';
              values = "100+0x27";
            }
          ];
          promql_expr_test = [
            {
              expr = ''ALERTS{alertname="HostMemoryLow",alertstate="firing"}'';
              eval_time = "9m30s";
              exp_samples = [ ];
            }
            {
              expr = ''ALERTS{alertname="HostMemoryLow",alertstate="firing"}'';
              eval_time = "10m";
              exp_samples = [
                {
                  labels = ''ALERTS{alertname="HostMemoryLow",alertstate="firing",host="test",instance="test",severity="warning"}'';
                  value = 1;
                }
              ];
            }
            {
              expr = ''ALERTS{alertname="HostMemoryLow",alertstate="firing"}'';
              eval_time = "12m";
              exp_samples = [ ];
            }
          ];
        }
        {
          interval = "30s";
          input_series = [
            {
              series = ''probe_success{instance="app",service="test",probe_location="backend"}'';
              values = "0+0x5 1+0x3";
            }
          ];
          promql_expr_test = [
            {
              expr = ''ALERTS{alertname="ApplicationUnavailable",alertstate="firing"}'';
              eval_time = "1m30s";
              exp_samples = [ ];
            }
            {
              expr = ''ALERTS{alertname="ApplicationUnavailable",alertstate="firing"}'';
              eval_time = "2m";
              exp_samples = [
                {
                  labels = ''ALERTS{alertname="ApplicationUnavailable",alertstate="firing",instance="app",service="test",probe_location="backend",severity="warning"}'';
                  value = 1;
                }
              ];
            }
            {
              expr = ''ALERTS{alertname="ApplicationUnavailable",alertstate="firing"}'';
              eval_time = "3m";
              exp_samples = [ ];
            }
          ];
        }
      ];
    }
  );
in
{
  observability-rules =
    pkgs.runCommand "observability-rules" { nativeBuildInputs = [ pkgs.prometheus.cli ]; }
      ''
        promtool check rules ${rules}
        promtool test rules ${tests}
        touch $out
      '';
  observability-vm = import ./vm.nix {
    inherit pkgs;
    inherit (self) inputs;
  };
}
