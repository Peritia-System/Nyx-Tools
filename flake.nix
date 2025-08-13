{
  description = "Nyx: Home Manager Tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    homeManagerModules.default = import ./legacy-nyx;
    homeManagerModules.legacy = import ./legacy-nyx;

    nixosModules.default = import ./nyx;
  };
}
