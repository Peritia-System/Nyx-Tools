# Nyx: NixOS System Management Toolkit

**Nyx** is a modular toolkit that simplifies and automates various NixOS system management tasks, from enhanced rebuilds to cleanup and shell customization.

---

## Features

* **Enhanced NixOS Rebuilds** — via `nyx-rebuild.nix`
* **Automated System Cleanup** — via `nyx-cleanup.nix`
* **Shell Customization & Tooling** — banners and helpers via `nyx-tool.nix`
* **All-in-One Integration** — enable everything with a single import: `nyx.nix`

---

## Dependencies

| Tool / Service       | Required | Notes                                                    |
| -------------------- | -------- | -------------------------------------------------------- |
| NixOS / Nix          | ✅        | Nyx is designed for NixOS or compatible Nix environments |
| `sudo` access        | ✅        | Needed for system-level operations                       |
| Home Manager         | ✅        | Integrates via `home.nix`                                |
| Git                  | ✅        | Required for `autoPush*` features (must be a Git repo)   |
| `nix-output-monitor` | ✅        | Automatically provided by Nyx                            |

---

## Project Structure

```
Nyx-Tools
├── nyx
│   ├── bash
│   │   ├── nyx-cleanup.sh
│   │   ├── nyx-rebuild.sh
│   │   ├── nyx-tool.sh
│   │   └── nyx-tui.sh
│   ├── default.nix
│   ├── nyx-cleanup.nix
│   ├── nyx-rebuild.nix
│   ├── nyx-tool.nix
│   └── nyx-tui.nix
└── other/
```

---

## How It Works

* **`default.nix`**  
  Importing the other Modules.

* **`nyx-tool.nix`**  
  Sets up shell visuals (e.g. banners) and Zsh helpers.

* **`nyx-rebuild.nix`**  
  Enhances `nixos-rebuild` with:

  * Git auto-push support
  * Optional code formatting before builds
  * Rebuild logging

* **`nyx-cleanup.nix`**  
  Automates system cleanup and tracks logs (optionally pushes to GitHub).

* **`nyx-tui.nix`**  
  Making a TUI for the other tools.


---

## Quick Start

### 1. Add Nyx to your Flake

```nix
# flake.nix
{
  inputs.nyx.url = "github:Peritia-System/Nyx-Tools";

  outputs = inputs @ { nixpkgs, nyx, ... }:
  {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
```

### 2. Import Nyx into Home Manager

```nix
# home.nix
{
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.nyx.homeManagerModules.default
  ];
}
```

### 3. Enable Desired Modules

```nix
{
  nyx = {
    
    enable = true;
    inherit username nixDirectory;
    logDir = "/home/${username}/.nyx/logs";
    autoPush = false;

    nyx-rebuild = {
      enable = true;
      editor = "nvim";
      formatter = "alejandra";
      enableAlias = false;
      startEditor = false;
    };
    
    nyx-cleanup = {
      enable = true;
      keepGenerations = 5;
      enableAlias = false;
    };
    
    nyx-tool = {
      enable = true;
    };

    nyx-tui = {
      enable          = true;
      enableAlias     = false;
    };

  };
}
```

> ⚠️ **Note**: `nixDirectory` must be a **full path** to your flake repo (e.g., `/home/${username}/NixOS/Nyx-Tools`).

See `other/example/example-home.nix` for a working example.

---

### 4. Rebuild and you can use it:

```bash
# to just do a simple rebuild you can:
nyx-rebuild

# to see the available options: 
$ nyx-rebuild -h
nyx-rebuild [--repair] [--update]

  --repair   Stage & commit the nix_dir with "rebuild - repair <timestamp>"
             and remove any unfinished logs (Current-Error*.txt and rebuild-*.log
             that are not final nixos-gen_* logs).

  --update   Before rebuilding, update the flake in nix_dir using:
               nix flake update

# to cleanup old configurations:
nyx-cleanup

# And to see the other options:
nyx-cleanup -h
nyx-cleanup [--dry-run] [--keep N]

Prunes old *system* generations, runs GC (and store optimise), and tidies logs.

Options:
  --dry-run       Show actions without doing them.
  --keep N        Override configured generations to keep (default: 5).
  -h, --help      Show this help.


# For nyx-tui run simply 
nyx-tui

# or for a small startup animation
nyx-tui --pretty


```

##### Showcase
<details>
<summary>nyx-tui</summary>
[Video](other/Ressources/showcase.mp4)

</details>

---

## Module Options

### `nyx.nyx-rebuild`

| Option             | Description                            | Default                   |
| ------------------ | -------------------------------------- | ------------------------- |
| `enable`           | Enable the module                      | `false`                   |
| `startEditor`      | Launch editor before rebuilding        | `false`                   |
| `editor`           | Editor to use (`vim`, `nvim`, etc.)    | —                         |
| `enableFormatting` | Auto-format Nix files before rebuild   | `false`                   |
| `formatter`        | Formatter to use (e.g., `alejandra`)   | —                         |
| `enableAlias`      | Add CLI alias for rebuild              | `false`                   |

---

### `nyx.nyx-cleanup`

| Option            | Description                   | Default                   |
| ----------------- | ----------------------------- | ------------------------- |
| `enable`          | Enable the module             | `false`                   |
| `keepGenerations` | Number of generations to keep | `5`                       |
| `enableAlias`     | Add CLI alias for cleanup     | `false`                   |

---

### `nyx.nyx-tui`

| Option            | Description                   | Default                   |
| ----------------- | ----------------------------- | ------------------------- |
| `enable`          | Enable the module             | `false`                   |
| `enableAlias`     | Add CLI alias for the tui     | `false`                   |

---

### `nyx.nyx-tool`

| Option   | Description                     | Default |
| -------- | ------------------------------- | ------- |
| `enable` | Enables banners and shell tools | `false` |

> 💡 `nyx-tool` must be enabled for other modules to function properly.

---

## Contributing

You're welcome to contribute:

* New features & modules
* Tooling improvements
* Bug fixes or typos

Open an issue or pull request at:

👉 [https://github.com/Peritia-System/Nyx-Tools](https://github.com/Peritia-System/Nyx-Tools)

---

## License

Licensed under the [MIT License](./LICENSE)

