{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx or {};
  cfg    = nyxCfg."nyx-tui" or {};

  # Read the tui script template and replace tokens
  tuiScript =
    let
      src = builtins.readFile ./bash/nyx-tui.sh; # Script with @TOKENS@
    in
    builtins.replaceStrings
      [
        "@LOG_DIR@" "@NIX_DIR@" "@VERSION@" "@DIALOG_BIN@"
      ]
      [
        (toString nyxCfg.logDir)
        (toString nyxCfg.nixDirectory)
        "1.1.1"
        "${pkgs.dialog}/bin/dialog"
      ]
      src;
in
{
  options.nyx."nyx-tui" = {
    enable = lib.mkEnableOption "Enable nyx-tui script";
    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add alias 'nyx' for 'nyx-tui'.";
    };
  };

  config = lib.mkIf ((nyxCfg.enable or false) && (cfg.enable or false)) {
    home.packages = [
      (pkgs.writeShellScriptBin "nyx-tui" tuiScript)
    ];

    home.shellAliases = lib.mkIf (cfg.enableAlias or true) {
      nyx = "nyx-tui";
    };
  };
}


