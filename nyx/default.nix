# Import all modules so only needs to Import nyx.nix
   

{ config, pkgs, lib, nixDirectory, ... }:

{
  imports = [
    # System modules
    # Rebuild
    ./nyx-rebuild.nix
    # Custom Banner
    ./nyx-tool.nix
    # Nyx cleanup
    ./nyx-cleanup.nix
  ];

}
