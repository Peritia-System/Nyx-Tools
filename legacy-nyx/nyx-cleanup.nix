{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx or {};
  cfg    = nyxCfg."nyx-cleanup" or {};

  # Read the cleanup script template and replace tokens
  cleanupScript =
    let
      src = builtins.readFile ./bash/nyx-cleanup.sh; # Script with @TOKENS@
    in
    builtins.replaceStrings
      [
        "@LOG_DIR@" "@KEEP_GENERATIONS@" "@AUTO_PUSH@" "@GIT_BIN@" "@VERSION@"
      ]
      [
        (toString nyxCfg.logDir)
        (toString (cfg.keepGenerations or 5))
        (if (nyxCfg.autoPush or false) then "true" else "false")
        "${pkgs.git}/bin/git"
        "1.2.0"
      ]
      src;
in
{
  options.nyx."nyx-cleanup" = {
    enable = lib.mkEnableOption "Enable nyx-cleanup script";

    keepGenerations = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Number of NixOS *system* generations to keep.";
    };

    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add alias 'nc' for 'nyx-cleanup'.";
    };
  };

  config = lib.mkIf ((nyxCfg.enable or false) && (cfg.enable or false)) {
    home.packages = [
      (pkgs.writeShellScriptBin "nyx-cleanup" cleanupScript)
    ];

    home.shellAliases = lib.mkIf (cfg.enableAlias or true) {
      nc = "nyx-cleanup";
    };
  };
}
