{ config, lib, pkgs,... }:

let
  cfg = config.modules.nix-tool;
  scriptTargetPath = "${cfg.nixDirectory}/Misc/Nyx-Tools/zsh/nyx-tool.zsh";
in
{
  options.modules.nix-tool = {
    enable = lib.mkEnableOption "Enable nix-tool Zsh function for Banner display.";

    nixDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Path to the main Nix directory used for scripts.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.figlet
    ];

    programs.zsh.enable = lib.mkDefault true;

    programs.zsh.initContent = ''
    source "${scriptTargetPath}"
    '';
  };
}
