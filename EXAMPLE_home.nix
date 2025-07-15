```nix

{ config, nixDirectory, pkgs, ... }:

let
  nixDirectory = "/home/${username}/NixOS";

in
{

  ################################################################
  # Module Imports
  ################################################################

  imports = [
    # Nyx Tools
    /home/${username}/NixOS/Nyx-Tools
  
  ];


  ################################################################
  # Nyx Tools Configuration
  ################################################################

  modules.nyx-rebuild = {
    enable = true;
    inherit username nixDirectory;
    editor = "nvim";
    formatter = "alejandra";
    enableAlias = false;
    autoPush = false;
    enableFormatting = false;
    startEditor = false;
  };

  modules.nyx-cleanup = {
    enable = true;
    inherit username nixDirectory;
    autoPush = false;
    keepGenerations = 5;
    enableAlias = false;
  };

    
  modules.nix-tool = {
    enable = true;
    inherit nixDirectory;
  };

}


```