# Audiyo

Audiyo is a macOS menu-bar app for enforcing audio device priority.

Open **Device priorities** from the menu bar and choose **Sound output** or
**Microphone**. Add devices to your numbered list and drag your favorites to the
top. Audiyo uses device 1 if connected, otherwise device 2, then device 3. It
switches back when a higher choice reconnects. If none are connected, Audiyo
leaves the current device alone unless you've made a temporary selection.

New devices wait under **Other devices**, which is collapsed by default.
Expand it and choose **Add to list** to include a device in your order.
**Remove from list** moves a device back there without forgetting it. Your
existing switching order is preserved when upgrading. You can still choose any
connected device from the menu bar for now; choose **Use my list again** to end
that temporary selection. Quitting Audiyo also clears temporary selections.

Automatically discovered devices are forgotten after seven days without being
seen by Audiyo. Devices you add to or remove from your list, reorder, or choose for
alerts are kept until you explicitly forget them. Cleanup runs on device refreshes, including
an hourly refresh while Audiyo is running, even with automatic switching paused.
Forgotten devices that return appear under **Other devices**.

AirPlay entries from older configs are eligible for the same seven-day cleanup.
Other existing devices are kept because those configs did not record which
priorities were set manually. Recorded priority choices and the selected alert
device remain protected.

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

Audiyo defaults to a background menu-bar utility: no Dock icon and no main
window. In Settings, you can hide the menu-bar icon or show a Dock/app-switcher
icon; Audiyo keeps at least one control surface visible.

```sh
make install
open /Applications/Audiyo.app
```

Launch at Login is only available when Audiyo is running from
`/Applications/Audiyo.app`. After installing and launching that copy, open
Settings from the menu-bar icon or Dock/app menu and enable Launch at Login.

For local development without installing:

```sh
make run
```
