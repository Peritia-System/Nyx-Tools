{ config, pkgs, host, lib, inputs, userconf, ... }:

let
  username = "YOUR_USER";
  nixDirectory = "/home/${username}/NixOS";
in {
  ################################################################
  # Module Imports
  ################################################################

  imports = [
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
  ];

  ################################################################
  # Home Manager Configuration
  ################################################################

home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "delme-HMbackup";
  users.${username} = import ./home.nix;

  extraSpecialArgs = {
    inherit inputs nixDirectory username;
  };
};
  ################################################################
  # System Version
  ################################################################

  system.stateVersion = "25.05";

  # ... Add more
}
