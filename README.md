# brave-origin-bin

GitHub mirror and updater for the AUR package `brave-origin-bin`.

The workflow checks Brave Browser stable releases for matching `brave-origin`
Debian assets, updates `PKGBUILD` and `.SRCINFO`, commits the mirror change, and
pushes the package update to AUR.

## Required Secret

Add this repository secret:

```text
AUR_SSH_PRIVATE_KEY
```

Its public key must be added to the AUR account that maintains
`brave-origin-bin`.
