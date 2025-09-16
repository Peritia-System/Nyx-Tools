{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx;
  cfg    = nyxCfg."nyx-rebuild";

  # Function to put a file from lib/ into the Nix store
  libFile = file:
    builtins.toFile
      (builtins.baseNameOf file)
      (builtins.readFile ./bash/lib/${file});

  # List of files you want to source
  filesToSource = [
    "git.sh"
    "logging.sh"
    "sudo.sh"
#    "nyx-rebuild-logic.sh"
  ];

  # Build sourcing lines dynamically
  sourcingLines =
    builtins.concatStringsSep "\n"
      (map (f: "source ${libFile f}") filesToSource);

  # Read template and inject values
  rebuiltScript =
    let
      src = builtins.readFile ./bash/nyx-rebuild.sh;
    in
      builtins.replaceStrings
        [
          "@FLAKE_DIRECTORY@" 
          "@LOG_DIR@" 
          "@ENABLE_FORMATTING@"
          "@FORMATTER@" 
          "@GIT_BIN@" 
          "@NOM_BIN@" 
          "@AUTO_STAGE@" 
          "@AUTO_COMMIT@" 
          "@AUTO_PUSH@" 
          "@VERSION@" 
        ]
        [
          (toString nyxCfg.nixDirectory)
          (toString nyxCfg.logDir)
          (if cfg.enableFormatting then "true" else "false")
          cfg.formatter
          "${pkgs.git}/bin/git"
          "${pkgs.nix-output-monitor}/bin/nom"
          (if nyxCfg.autoStage  then "true" else "false")
          (if nyxCfg.autoCommit then "true" else "false")
          (if nyxCfg.autoPush   then "true" else "false")
          "1.2.0"
        ]
        (
          "#!/usr/bin/env bash\n"
          + "source_all () {\n"
          + sourcingLines
          + "\n}\n"
          + src
        );

in
{
  options.nyx."nyx-rebuild" = {
    enable           = lib.mkEnableOption "Enable nyx-rebuild script";
    formatter        = lib.mkOption { type = lib.types.str;  default = "alejandra"; };
    enableFormatting = lib.mkOption { type = lib.types.bool; default = false; };
    enableAlias      = lib.mkOption { type = lib.types.bool; default = true;  };
  };

  config = lib.mkIf (nyxCfg.enable && cfg.enable) {
    environment.systemPackages =
      lib.optionals (cfg.enableFormatting && cfg.formatter == "alejandra") [
        pkgs.alejandra
      ]
      ++ [
        (pkgs.writeShellScriptBin "nyx-rebuild" rebuiltScript)
      ];

    environment.shellAliases = lib.mkIf cfg.enableAlias {
      nr = "nyx-rebuild";
    };
  };
}
