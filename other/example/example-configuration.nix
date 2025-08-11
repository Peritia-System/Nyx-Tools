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
  # Please use this backup File Extension to ensure that the bug won't cause any problems
  # nyx-rebuild deletes the backups on each rebuild before rebuilding
  # HM Bug: https://discourse.nixos.org/t/nixos-rebuild-fails-on-backup-up-config-file-by-home-manager/45992
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
