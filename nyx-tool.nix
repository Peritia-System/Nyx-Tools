{ config, lib, pkgs, ... }:

let
  cfg = config.modules.nix-tool;
  scriptTargetPath = "${cfg.nixDirectory}/Misc/zsh/nyx-rebuild.zsh";
in
{
  options.modules.nix-tool.enable = lib.mkEnableOption "Enable nix-tool Zsh function for tool metadata display.";

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
