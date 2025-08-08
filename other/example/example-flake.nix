{
  description = "EXAMPLE-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nyx.url = "github:Peritia-System/Nyx-Tools";
  };
  outputs = inputs @ {
    nixpkgs,
    home-manager,
    nyx,
    ...
  }: {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          host = "default";
        };
        modules = [
          ./Configurations/Hosts/Default/configuration.nix
          # No need to include nyx here
        ];
      };
    };
  };
}
