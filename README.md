Nyx — NixOS System Management Toolkit

**Nyx** is a modular toolkit that makes managing NixOS easier — faster rebuilds, automated cleanup, shell customization, and an optional TUI interface.

---

## Features

* **Enhanced Rebuilds** — Git auto-push, optional formatting, rebuild logs
* **Automated Cleanup** — prune old generations, GC, optimize store
* **Shell Tools** — banners, helpers, aliases
* **TUI Interface** — simple, pretty menu for all Nyx tools
* **One Import to Enable All** — `nyx.nix`

---

## Requirements

| Tool / Service       | Required | Notes                            |
| -------------------- | -------- | -------------------------------- |
| NixOS / Nix          | ✅        | Core platform                    |
| `sudo`               | ✅        | Needed for system changes        |
| Home Manager         | ✅        | For integration                  |
| Git                  | ✅        | Required for `autoPush` features |
| `nix-output-monitor` | ✅        | Installed automatically by Nyx   |

---

## Quick Install

### 1. Add Nyx to your flake

```nix
# flake.nix
{
  inputs.nyx.url = "github:Peritia-System/Nyx-Tools";

  outputs = inputs @ { nixpkgs, nyx, ... }: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
```

### 2. Import in Home Manager

```nix
# home.nix
{
  imports = [ inputs.nyx.homeManagerModules.default ];
}
```

### 3. Enable modules

```nix
nyx = {
  enable     = true;
  username   = "alex";
  nixDirectory = "/home/alex/NixOS"; # full path to flake repo
  logDir     = "/home/alex/.nyx/logs";
  autoPush   = false;

  nyx-tool.enable    = true;   # must be enabled for others
  nyx-rebuild.enable = true;
  nyx-cleanup.enable = true;
  nyx-tui.enable     = true;
};
```

---

## Usage

```bash
nyx-rebuild --update   # Update flake + rebuild
nyx-rebuild --repair   # Repair and clean unfinished logs

nyx-cleanup            # Remove old generations + GC
nyx-cleanup --dry-run  # Preview cleanup

nyx-tui                # Launch TUI
nyx-tui --pretty       # TUI with animation
```

---

## Showcase

<details>
<summary>nyx-tui</summary>

<video src="other/Ressources/showcase.mp4" controls autoplay loop muted width="640">
  Your browser does not support the video tag.
</video>

</details>


---

## Module Options

| Module        | Key Options                               |
| ------------- | ----------------------------------------- |
| `nyx-rebuild` | `startEditor`, `formatter`, `enableAlias` |
| `nyx-cleanup` | `keepGenerations`, `enableAlias`          |
| `nyx-tui`     | `enableAlias`                             |
| `nyx-tool`    | Shell banners & helpers (base req)        |

---

## Tips

* `nyx-tool` **must be enabled** for other modules.
* `nixDirectory` must be a full Git repo path for `autoPush` to work.
* See `other/example/example-home.nix` for a full working setup.

---

## More Info 

refer to: **[Documentaion](./Documentation/main.md)**


---


## 📜 License
[MIT](./LICENSE) — Contributions welcome!
