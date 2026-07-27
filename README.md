# Polytoken Nix flake

This flake packages the official Polytoken `linux-amd64` binary for
`x86_64-linux`. It pins Polytoken 0.5.6 and verifies the download with the
SHA-256 published in Polytoken's `SHA256SUMS.linux`.

Run it directly:

```console
nix run path:. -- --version
nix run path:.
```

Build it or install it into your user profile:

```console
nix build path:.
nix profile install path:.
polytoken --version
```

`path:.` also works from a normal Git checkout; there, plain `.` is
equivalent.

The upstream binary is statically linked, so it does not need an ELF
interpreter patch or extra runtime libraries on NixOS.

## Updating

The Polytoken executable lives in the read-only Nix store. Do not use
`polytoken update`; update `version`, `url`, and `hash` in `flake.nix`, then
rebuild instead. Polytoken's automatic update check can be disabled in the
user configuration:

```yaml
updates:
  automatic_check: false
```
