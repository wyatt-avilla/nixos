{ inputs, ... }:
{
  imports = [ inputs.wyattwtf.nixosModules.wyattwtf ];

  services.wyattwtf = {
    enable = true;
  };
}
