# Audiyo

Audiyo is a macOS menu-bar app for enforcing audio device priority.

## Build and Test

```sh
make bootstrap
make build
make test
```

## Local Release

Audiyo currently ships as a local tester build. It is signed to run locally, but
it is not Developer ID signed or notarized.

```sh
make release
make package
make verify-package
```

The DMG is written to `dist/Audiyo-0.1.0.dmg` and contains `Audiyo.app` plus an
Applications symlink for drag install.

## Install and Run in the Background

Audiyo is a background menu-bar utility. It does not show a Dock icon or main
window; the menu-bar icon is the control surface.

```sh
make install
open /Applications/Audiyo.app
```

Launch at Login is only available when Audiyo is running from
`/Applications/Audiyo.app`. After installing and launching that copy, open
Settings from the menu-bar icon and enable Launch at Login.

For local development without installing:

```sh
make run
```
