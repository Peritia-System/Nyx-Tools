{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx;
  cfg = config.nyx.nyx-tool;
  infoScript =
    let
      src = builtins.readFile ./bash/nyx-info.sh;
    in
    builtins.replaceStrings
      [ "@LOG_DIR@" ]
      [ (toString nyxCfg.logDir) ]
      src;
in
{
  options.nyx.nyx-tool = {
    enable = lib.mkEnableOption "Enable nyx-tool banner script and the current info";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.figlet
      (pkgs.writeShellScriptBin "nyx-tool"
        (builtins.readFile ./bash/nyx-tool.sh)
      )
      (pkgs.writeShellScriptBin "nyx-info"
        infoScript
      )
    ];
  };
}
