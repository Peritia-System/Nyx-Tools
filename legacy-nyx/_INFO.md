# This is just a Legacy keep up 

Note:

---

```txt
⚠ IMPORTANT PROJECT UPDATE ⚠

Please note that I will soon switch Nyx from a Home Manager module to a NixOS module.
You can still use the Home Manager module, but I will only continue developing it for Nyx at a specific legacy commit/revision.

Please consider pinning Nyx to that commit:
https://github.com/Peritia-System/Nyx-Tools/blob/main/Documentation/How-to-Homemanager.md

Or even better switch to the nixosmodule. Checkout the ReadMe for that:
https://github.com/Peritia-System/Nyx-Tools

If you use this, you can keep the current version indefinitely but wont receive updates.
If you dont pin to that commit, I wont take any responsibility for breakage.
(Note: I dont take any responsibility regardless — this is a hobby project.)
If you want to ensure it works, help me develop it.

Thank you for your understanding <3

This is not supposed to discourage you from using Nyx!!! I am so, so glad you use Nyx :)
But it is very early in development so things move quick and big changes will be common.
Plus as I said, it is a hobby project and at the moment I develop alone.
```

---

this only exists for: 
```nix
# flake.nix
{
homeManagerModules.default = import ./legacy-nyx;
}
```
please do not rely on this. i WILL delete it. this is only to make the transition easier. Plase switch to the nixosmodule

I don't wanna make any changes to anything in `legacy-nyx`
Feel free to Fork it but there is no reason for it to be a HM Module.