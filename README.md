# Polytoken Nix flake

This flake packages the official Polytoken `linux-amd64` binary for
`x86_64-linux`. It pins Polytoken 0.5.6 and verifies the download with the
SHA-256 published in Polytoken's `SHA256SUMS.linux`.

Run it directly:

```console
nix run . -- --version
nix run .
```

Build it or install it into your user profile:

```console
nix build
nix profile install .
polytoken --version
```

The upstream binary is statically linked, so it does not need an ELF
interpreter patch or extra runtime libraries on NixOS.

## Updating

The Polytoken executable lives in the read-only Nix store, so do not use
`polytoken update`. Update this flake instead:

```console
nix run .#update
nix flake check
```

The updater reads Polytoken's `latest` channel, downloads the official
checksum manifest and candidate binary, and only changes `release.json` when
the downloaded bytes match the published SHA-256.

The `Update Polytoken` GitHub Actions workflow runs this process daily. When a
new release passes `nix flake check`, it opens or refreshes a pull request on
the `automation/polytoken-update` branch. The workflow can also be run manually
from the Actions tab.

Before the first run, enable **Allow GitHub Actions to create and approve pull
requests** under **Settings → Actions → General → Workflow permissions**. An
optional `POLYTOKEN_UPDATE_TOKEN` repository secret can supply a fine-grained
token instead of `GITHUB_TOKEN`; it needs repository contents and pull-request
write access.

Polytoken's own automatic update check can be disabled in the user
configuration:

```yaml
updates:
  automatic_check: false
```
