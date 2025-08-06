# ⚙️ Nyx: NixOS System Management Toolkit

**Nyx** is a modular toolkit that simplifies and automates various NixOS system management tasks, from enhanced rebuilds to cleanup and shell customization.

---

## ✨ Features

* 🔁 **Enhanced NixOS Rebuilds** — via `nyx-rebuild.nix`
* 🧹 **Automated System Cleanup** — via `nyx-cleanup.nix`
* 🛠️ **Shell Customization & Tooling** — banners and helpers via `nyx-tool.nix`
* 🧩 **All-in-One Integration** — enable everything with a single import: `nyx.nix`

---

## 📦 Dependencies

| Tool / Service       | Required | Notes                                                    |
| -------------------- | -------- | -------------------------------------------------------- |
| NixOS / Nix          | ✅        | Nyx is designed for NixOS or compatible Nix environments |
| `sudo` access        | ✅        | Needed for system-level operations                       |
| Home Manager         | ✅        | Integrates via `home.nix`                                |
| Git                  | ✅        | Required for `autoPush*` features (must be a Git repo)   |
| `nix-output-monitor` | ✅        | Automatically provided by Nyx                            |

---

## 📁 Project Structure

```
Nyx-Tools
├── default.nix          # Top-level module
├── nyx-tool.nix         # Shell enhancements and banners
├── nyx-rebuild.nix      # Enhanced nixos-rebuild logic
├── nyx-cleanup.nix      # System cleanup automation
└── other/               # Legacy scripts (to be removed soon)
```

---

## ⚙️ How It Works

* **`nyx-tool.nix`**
  Sets up shell visuals (e.g. banners) and Zsh helpers.

* **`nyx-rebuild.nix`**
  Enhances `nixos-rebuild` with:

  * Git auto-push support
  * Optional code formatting before builds
  * Rebuild logging

* **`nyx-cleanup.nix`**
  Automates system cleanup and tracks logs (optionally pushes to GitHub).

---

## 🚀 Quick Start

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
  imports = [
    inputs.nyx.homeManagerModules.default
  ];
}
```

### 3. Enable Desired Modules

```nix
{
  nyx.nyx-rebuild = {
    enable = true;
    inherit username nixDirectory;
  };
  
  nyx.nyx-cleanup = {
    enable = true;
    inherit username nixDirectory;
  };
  
  nyx.nyx-tool = {
    enable = true;
    inherit nixDirectory;
  };
}
```

> ⚠️ **Note**: `nixDirectory` must be a **full path** to your flake repo (e.g., `/home/${username}/NixOS/Nyx-Tools`).

See `./other/example/home.nix` for a working example.

---

## 🔧 Module Options

### `modules.nyx-rebuild`

| Option             | Description                            | Default                   |
| ------------------ | -------------------------------------- | ------------------------- |
| `enable`           | Enable the module                      | `false`                   |
| `startEditor`      | Launch editor before rebuilding        | `false`                   |
| `editor`           | Editor to use (`vim`, `nvim`, etc.)    | —                         |
| `enableFormatting` | Auto-format Nix files before rebuild   | `false`                   |
| `formatter`        | Formatter to use (e.g., `alejandra`)   | —                         |
| `enableAlias`      | Add CLI alias for rebuild              | `false`                   |
| `autoPushLog`      | Push rebuild logs to GitHub            | `false`                   |
| `autoPushNixDir`   | Push flake dir to GitHub after rebuild | `false`                   |
| `username`         | Username the module applies to         | Required                  |
| `nixDirectory`     | Full path to the Nix flake directory   | Required                  |
| `logDir`           | Where to store logs                    | `~/.nyx/nyx-rebuild/logs` |

---

### `modules.nyx-cleanup`

| Option            | Description                   | Default                   |
| ----------------- | ----------------------------- | ------------------------- |
| `enable`          | Enable the module             | `false`                   |
| `autoPush`        | Push logs to GitHub           | `false`                   |
| `keepGenerations` | Number of generations to keep | `5`                       |
| `enableAlias`     | Add CLI alias for cleanup     | `false`                   |
| `username`        | User this applies to          | Required                  |
| `nixDirectory`    | Full path to flake dir        | Required                  |
| `logDir`          | Path to store logs            | `~/.nyx/nyx-cleanup/logs` |

---

### `modules.nyx-tool`

| Option   | Description                     | Default |
| -------- | ------------------------------- | ------- |
| `enable` | Enables banners and shell tools | `false` |

> 💡 `nyx-tool` must be enabled for other modules to function properly.

---

## 🤝 Contributing

You're welcome to contribute:

* New features & modules
* Tooling improvements
* Bug fixes or typos

Open an issue or pull request at:

👉 [https://github.com/Peritia-System/Nyx-Tools](https://github.com/Peritia-System/Nyx-Tools)

---

## 📄 License

Licensed under the [MIT License](./LICENSE)

