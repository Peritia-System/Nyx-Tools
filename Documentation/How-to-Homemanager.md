# How-to: Home Manager → Legacy Nyx

**Why:** Nyx is moving to a NixOS module. If you’re on Home Manager today and want stability, pin Nyx to the “legacy” state (by `rev`) or a local checkout.

---

If you forgot how to setup the home.nix see the [Example](./Legacy/example-home.nix)

--- 

## How to still use the Homemanager Import:

### Option A — Pin Nyx to a specific revision


```nix
{
  description = "EXAMPLE-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Old:
    # nyx.url = "github:Peritia-System/Nyx-Tools";

    # Legacy pin (replace rev with the legacy commit you want):
    nyx.url = "github:Peritia-System/Nyx-Tools?rev=7f73899c918a09bae789306fe3fa73dbc2d83997";
  };

  outputs = inputs @ { nixpkgs, home-manager, nyx, ... }: {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs self; host = "default"; };
        modules = [
          ./Configurations/Hosts/Default/configuration.nix
        ];
      };
    };
  };
}
```


### Option B — Pin to a local checkout 

This will **never** change unless you `git pull` inside the repo.

1. Clone:

```bash
git clone https://github.com/Peritia-System/Nyx-Tools /path/to/repo
cd  /path/to/repo
git reset --hard 7f73899c918a09bae789306fe3fa73dbc2d83997 # or any other commit you want 
   
```

2. Point your flake at the local path:

```nix
{
  description = "EXAMPLE-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Local path (no updates unless you update the repo)
    nyx.url = "/path/to/repo/";
  };

  outputs = inputs @ { nixpkgs, home-manager, nyx, ... }: {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs self; host = "default"; };
        modules = [
          ./Configurations/Hosts/Default/configuration.nix
        ];
      };
    };
  };
}
```


