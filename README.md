# ⚙️ Nyx: NixOS System Management Toolkit

**Nyx** is a modular toolkit for managing NixOS systems. It streamlines NixOS rebuilds, system cleanups, and developer workflow enhancements through a unified and extensible interface. Simply import one file to enable all features.

---

## ✨ Features

* 🔁 **Enhanced NixOS Rebuilds** — via `nyx-rebuild.nix`
* 🧹 **Automated System Cleanup** — via `nyx-cleanup.nix`
* 🛠️ **Custom Shell Tools & Visuals** — like banners via `nyx-tool.nix`
* 🧩 **One-File Integration** — import just `nyx.nix` to activate everything

---

## 📦 Dependencies

* ✅ NixOS or compatible Nix environment  
* ✅ `sudo` access (for system operations)  
* ✅ [Home Manager](https://github.com/nix-community/home-manager)  
* ✅ Git — required if you use `autoPush` features (must be a Git repo)  
* ✅ Zsh (included via Nyx modules)  
* ✅ [`nix-output-monitor`](https://github.com/maralorn/nix-output-monitor) (included via Nyx)

> ℹ️ No need to preinstall Zsh or `nix-output-monitor`; Nyx provides them internally.

---

## 📁 Project Structure

```bash
Nyx-Tools
├── nyx.nix              # Master module
├── nyx-tool.nix         # Shell customizations (e.g., banners)
├── nyx-rebuild.nix      # Enhanced nixos-rebuild logic
├── nyx-cleanup.nix      # System cleanup logic
└── zsh/
    ├── nyx-cleanup.zsh
    ├── nyx-rebuild.zsh
    └── nyx-tool.zsh
````

---

## ⚙️ How It Works

* `nyx.nix`: Central module that imports all others.
* `nyx-tool.nix`: Adds startup banners and sources Zsh helpers.
* `nyx-rebuild.nix`: Extends `nixos-rebuild` with logs, Git push, and optional formatting.
* `nyx-cleanup.nix`: Automates system cleanup and logs output.
* `zsh/*.zsh`: Shell scripts sourced into Zsh to handle CLI tooling.

---

## 🚀 Quick Start

### 1. Import into `home.nix`

```nix
imports = [
  ./path/to/Nyx-Tools/nyx.nix
];
```

### 2. Enable desired modules

```nix
modules.nyx-rebuild = {
  enable = true;
  inherit username nixDirectory;
};

modules.nyx-cleanup = {
  enable = true;
  inherit username nixDirectory;
};

modules.nix-tool = {
  enable = true;
  inherit nixDirectory;
};
```

> ⚠️ **Note:** You must define `nixDirectory` in your configuration or import it.
> It must be a **full path** to your flake directory (e.g., `/home/${username}/NixOS/Nyx-Tools`).

👉 See the [example config](./EXAMPLE_home.nix) for a working setup.

---

## 🛠️ Module Options

### `nyx-rebuild`

| Option             | Description                         | Default |
| ------------------ | ----------------------------------- | ------- |
| `enable`           | Enable this module                  | `false` |
| `startEditor`      | Launch an editor before rebuild     | `false` |
| `editor`           | Which editor to use (`nvim`, `vim`) | —       |
| `enableFormatting` | Format Nix files before rebuild     | `false` |
| `formatter`        | Formatter to use (`alejandra`)      | —       |
| `enableAlias`      | Add shell alias for rebuild         | `false` |
| `autoPush`         | Push rebuild logs or dir to GitHub  | `false` |

---

### `nyx-cleanup`

| Option            | Description                          | Default |
| ----------------- | ------------------------------------ | ------- |
| `enable`          | Enable this module                   | `false` |
| `autoPush`        | Push logs to GitHub after cleanup    | `false` |
| `keepGenerations` | Number of system generations to keep | `5`     |
| `enableAlias`     | Add shell alias for cleanup          | `false` |

---

### `nix-tool`

| Option   | Description        | Default |
| -------- | ------------------ | ------- |
| `enable` | Enable this module | `false` |

---

## 🎨 Customization

Nyx is fully modular and extensible. You can:

* Modify existing `.nix` or `.zsh` files
* Add new modules and source them in `nyx.nix`

### Example: Adding a Custom Tool

```nix
# Add to nyx.nix or your home.nix
imports = [
  ./nyx-rebuild.nix
  ./my-custom-tool.nix
];
```

Create `my-custom-tool.nix` and optionally pair it with a `.zsh` helper script in the `zsh/` folder.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request to:

* Add new functionality
* Improve existing tools
* Fix bugs or typos

---

## 📄 License

Licensed under the [MIT License](./LICENSE).
