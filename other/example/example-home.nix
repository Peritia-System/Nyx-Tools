{ config, nixDirectory, username, pkgs, inputs, ... }:

{

  ################################################################
  # Module Imports
  ################################################################

  imports = [
    # Other Home Manager Modules 
    # ......
    inputs.nyx.homeManagerModules.default
  ];

  ################################################################
  # Nyx Tools Configuration
  ################################################################

nyx = {
  
  enable = true;
  inherit username nixDirectory;
  logDir = "/home/${username}/.nyx/logs";
  autoPush = false;

  nyx-rebuild = {
    enable = true;
    editor = "nvim";
    formatter = "alejandra";
    enableAlias = false;
    startEditor = false;
  };
  
  nyx-cleanup = {
    enable = true;
    keepGenerations = 5;
    enableAlias = false;
  };
  
  nyx-tool = {
    enable = true;
  };

  nyx-tui = {
    enable          = true;
    enableAlias     = false;
  };
}
  ################################################################
  # Basic Home Manager Setup
  ################################################################

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
}
