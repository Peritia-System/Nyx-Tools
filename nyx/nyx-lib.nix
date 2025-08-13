# nyx-lib.nix — NixOS module that renders and installs nyx-lib.sh
{ config, lib, pkgs, ... }:

let
  nyxCfg = config.nyx or {};        # expect a parent `nyx` namespace
  cfg    = (config.nyx."nyx-lib") or {};

  # Source your nyx-lib.sh from the nix file tree (same dir as this module)
  libSrc = builtins.readFile ./nyx-lib.sh;

  boolToStr = b: if b then "true" else "false";

  # Replace tokens (keep exactly the @TOKENS@ used in nyx-lib.sh)
  libScript =
    builtins.replaceStrings
      [
        "@LOG_DIR@" "@NIX_DIR@" "@VERSION@"
        "@START_EDITOR@" "@ENABLE_FORMATTING@" "@EDITOR@" "@FORMATTER@"
        "@GIT_BIN@" "@NOM_BIN@" "@AUTO_PUSH@" "@AUTO_COMMIT@"
        "@KEEP_GENERATIONS@" "@DIALOG_BIN@"
      ]
      [
        (toString (nyxCfg.logDir or "/var/log/nyx"))
        (toString (nyxCfg.nixDirectory or "/etc/nixos"))
        (cfg.version or "1.2.0")
        (boolToStr (nyxCfg.startEditor or false))
        (boolToStr (nyxCfg.enableFormatting or false))
        (toString (nyxCfg.editorCmd or "${pkgs.nano}/bin/nano"))
        (toString (nyxCfg.formatterCmd or "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt"))
        "${pkgs.git}/bin/git"
        "${pkgs.nix-output-monitor}/bin/nom"
        (boolToStr (nyxCfg.autoPush or false))
        (boolToStr (cfg.autoCommit or true))
        (toString (nyxCfg.keepGenerations or 5))
        (toString (nyxCfg.dialogBin or "${pkgs.dialog}/bin/dialog"))
      ]
      libSrc;
in
{
  options.nyx."nyx-lib" = {
    enable = lib.mkEnableOption "Install shared nyx-lib.sh for Nyx tools";

    # Only lib-specific knobs here; global knobs (logDir, nixDirectory, etc.)
    # are expected under `config.nyx` to avoid duplication.
    autoCommit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow lib helpers to perform commits when called by tools.";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "1.2.0";
      description = "Version string embedded in nyx-lib.sh.";
    };
  };

  config = lib.mkIf ((nyxCfg.enable or true) && (config.nyx."nyx-lib".enable or false)) {
    # Ensure required tools are present for helpers.
    environment.systemPackages = with pkgs; [
      git nix-output-monitor dialog
      # quality-of-life defaults used by tokens above:
      (nyxCfg.enableFormatting or false) && nixpkgs-fmt
    ];

    # Install the rendered lib helpers at a stable path.
    environment.etc."nyx/nyx-lib.sh".text = libScript;

    # Provide a simple wrapper for sourcing (optional, handy for scripts):
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nyx-source-lib" ''
        #!/usr/bin/env bash
        set -euo pipefail
        # shellcheck disable=SC1091
        source /etc/nyx/nyx-lib.sh
      '')
    ];
  };
}
