{ config, lib, pkgs, ... }:

let
  cfg = config.nyx.nyx-tool;
in
{
  options.nyx.nyx-tool = {
    enable = lib.mkEnableOption "Enable nyx-tool banner script";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkDefault true;
    home.packages = [
      pkgs.figlet
      (pkgs.writeShellScriptBin "nyx-tool"
        (builtins.readFile ./bash/nyx-tool.sh)
      )
    ];
  };
}
