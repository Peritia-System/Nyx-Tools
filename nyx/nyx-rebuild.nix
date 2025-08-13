{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx;
  cfg    = nyxCfg."nyx-rebuild";

  # Read template and inject values
  rebuiltScript =
    let
      src = builtins.readFile ./bash/nyx-rebuild.sh;  # uses @TOKENS@, not ${...}
    in
    builtins.replaceStrings
      [
        "@NIX_DIR@" "@LOG_DIR@" "@START_EDITOR@" "@ENABLE_FORMATTING@"
        "@EDITOR@" "@FORMATTER@" "@GIT_BIN@" "@NOM_BIN@" "@AUTO_PUSH@" "@AUTO_COMMIT@" "@VERSION@" 
      ]
      [
        (toString nyxCfg.nixDirectory)
        (toString nyxCfg.logDir)
        (if cfg.startEditor then "true" else "false")
        (if cfg.enableFormatting then "true" else "false")
        cfg.editor
        cfg.formatter
        "${pkgs.git}/bin/git"
        "${pkgs.nix-output-monitor}/bin/nom"
        (if nyxCfg.autoPush then "true" else "false")
        (if nyxCfg.autoCommit then "true" else "false")
        "1.2.0"
      ]
      src;
in
{
  options.nyx."nyx-rebuild" = {
    enable = lib.mkEnableOption "Enable nyx-rebuild script";

    editor            = lib.mkOption { type = lib.types.str;  default = "nvim"; };
    formatter         = lib.mkOption { type = lib.types.str;  default = "alejandra"; };
    startEditor       = lib.mkOption { type = lib.types.bool; default = false; };
    enableFormatting  = lib.mkOption { type = lib.types.bool; default = false; };
    enableAlias       = lib.mkOption { type = lib.types.bool; default = true;  };
  };

  config = lib.mkIf (nyxCfg.enable && cfg.enable) {
    environment.systemPackages =
      lib.optionals (cfg.enableFormatting && cfg.formatter == "alejandra") [ pkgs.alejandra ]
      ++ [
        # Ensure nyx-tool exists if you call it in the script
        (pkgs.writeShellScriptBin "nyx-rebuild" rebuiltScript)
      ];

    environment.shellAliases = lib.mkIf cfg.enableAlias {
      nr = "nyx-rebuild";
    };
  };
}
