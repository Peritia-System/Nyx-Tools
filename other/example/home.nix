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

  nyx.nyx-rebuild = {
    enable = true;
    inherit username nixDirectory;
    editor = "nvim";
    formatter = "alejandra";
    enableAlias = false;
    autoPushLog = false;
    autoPushNixDir = false;
    startEditor = false;
    logDir = "/home/${username}/.nyx/nyx-rebuild/logs";
  };
  
  nyx.nyx-cleanup = {
    enable = true;
    inherit username nixDirectory;
    autoPush = false;
    keepGenerations = 5;
    enableAlias = false;
    logDir = "/home/${username}/.nyx/nyx-rebuild/logs";
  };
  
  nyx.nyx-tool = {
    enable = true;
    inherit nixDirectory;
  };


  ################################################################
  # Basic Home Manager Setup
  ################################################################

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
}
