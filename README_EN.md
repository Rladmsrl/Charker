<div align="center">
  <img src="Resources/Screenshots/app-icon-rounded.png" width="128" alt="Charker icon" />
  <h1>Charker</h1>
  <p><strong>Monitor and control the Anker Prime 160W, 250W, and an experimental wireless charging pad from your Mac.</strong></p>
  <p><a href="README.md">简体中文</a> · English</p>
  <p>
    <a href="https://github.com/qzz0518/Charker/stargazers"><img src="https://img.shields.io/github/stars/qzz0518/Charker?style=flat-square" alt="GitHub Stars" /></a>
    <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License" /></a>
    <a href="https://x.com/zerah_eth"><img src="https://img.shields.io/badge/follow-%40zerah__eth-111111?style=flat-square&logo=x&logoColor=white" alt="Follow @zerah_eth on X" /></a>
  </p>
</div>

<p align="center">
  <img src="Resources/Screenshots/overview.png" width="1100" alt="Charker overview with live power, the 3D device, port status, and power timeline" />
</p>

Charker is an unofficial macOS app for the **Anker Prime 160W (A2687)**, **Anker Prime Charger 250W (A2345)**,
and **Anker Prime wireless charging pad (A25X7, experimental)**.
The 160W and the wireless pad connect directly over Bluetooth; the 250W connects through your Anker account over Wi-Fi.

> [!IMPORTANT]
> Charker is an independent project, not affiliated with or endorsed by Anker. Readings are verified on a
> 160W (Bluetooth firmware `v0.0.5.2`) and a 250W (firmware `2.1.1.6`). Of the controls, the 160W's display
> settings and the 250W's port on/off are verified on hardware; the rest are not yet.
>
> A25X7 support is an experimental Bluetooth connection and live power for three pads. The decoder and the
> subscribe command `A1 01 21` were checked against public SolixBLE captures. **This Charker port has not
> been accepted on hardware.** Screen brightness, charge mode, and switches are omitted because the evidence
> is not sufficient. Pads are labeled 1/2/3: public notes disagree about which slot is a phone, a watch, or earbuds.

## Features

- **Live overview**: voltage, current, and power for each port, a 3D model of the charger, and a power chart. A25X7 shows power for three pads and the total, without unconfirmed voltage or current.
- **Menu bar**: total or per-port power without the main window, in a layout you choose.
- **Energy and cost**: energy use and cost by day, week, or month, with CSV / JSON export.
- **Device controls**
  - 160W: port on/off and countdowns; display language, brightness, auto-lock, and orientation; fixed allocation; custom charging mode.
  - 250W: port on/off, countdowns, and schedules; charging modes and priority ports; custom charging modes; display, clock screensaver, and themes; Labs switches.
- **Apple Home**: add each port to the Home app to see its power (iOS 27) and switch it.
- **Simulated charger**: try the interface without a charger; simulated data stays out of your real history.
- **Chinese and English**, with in-app updates.

## Install

Requires macOS 14 or later.

```bash
brew install --cask qzz0518/tap/charker
```

Or download the DMG from [Releases](https://github.com/qzz0518/Charker/releases) and drag Charker into Applications.

## Connect

**160W (Bluetooth)**: fully quit the Anker app on your phone first (the 160W takes one connection at a time
and may not show up while another device is connected), then choose the charger under
**Devices & Connection** and enter your Anker account ID if prompted.

**250W (Wi-Fi)**: bind the charger and set up Wi-Fi in the Anker app first, then sign in with the same
Anker account under **Devices & Connection**. Choose JP for a Japanese account; mainland China accounts
sign in with an SMS code.

**Wireless pad A25X7 (Bluetooth, experimental)**: quit the official app, choose this model during setup, then
connect under **Devices & Connection**. Enter the Anker account ID that owns it if asked. The screen shows
power for Pad 1/2/3 only. Apple Home, screen brightness, and charge mode are not available for this model.

On the 160W or 250W, turn on **Allow Port Switching** in **Advanced** before controlling ports.

**Apple Home**: turn on **Connect to Apple Home** in **Apple Home**, then scan the code with the Home app on
iPhone. When it says the accessory isn't certified, choose **Add Anyway**. The whole charger (with total
power) and each port have their own code; with both added, Home's whole-home power counts the charger
twice. Home shows “No Response” while the Mac is asleep or Charker is not running. Only the charger
currently selected in Charker updates in Home.

## Privacy

- 160W and A25X7 data travel over local Bluetooth; 250W data and controls travel encrypted through the Anker cloud. A25X7 power stays on the live chart for that connection and is not written into the 160W energy archive.
- **Connect to Apple Home** is off by default. When on, port states and power go encrypted over your local
  network to your Home.
- Energy history and settings stay on this Mac. There is no Charker server and no usage data collection.
- Passwords and SMS codes are never saved. The 250W login token lives in Keychain and is deleted when you
  sign out; the charger stays bound in the official app.
- The 250W's custom charging modes, Labs switches, and uploaded clock pictures are saved to your Anker
  account, as the official app does.

## Build from Source

Requires Xcode Command Line Tools, Swift 6.0+, rustup, mise, and ripgrep:

```bash
git clone https://github.com/qzz0518/Charker.git
cd Charker
mise run verify        # build, test, and bundle dist/Charker.app
open dist/Charker.app
```

Test real Bluetooth with the bundled `.app`; `mise run run` is only for UI and simulator work.

## Contributing

[Issues](https://github.com/qzz0518/Charker/issues) and pull requests are welcome. For device behavior, include
the model, firmware version, and steps to reproduce. Do not upload account IDs, serial numbers, Bluetooth
addresses, or raw captures.

## Credits and License

The protocol work draws on [SolixBLE](https://github.com/flip-dots/SolixBLE),
[Anker_Prime_160W_WebBLE](https://github.com/Hyper-Beast/Anker_Prime_160W_WebBLE),
[Anker_Prime_BLE_hacking](https://github.com/atc1441/Anker_Prime_BLE_hacking), and
[anker-solix-api](https://github.com/thomluther/anker-solix-api); Charker's implementation is written independently.

Code is released under the [MIT License](LICENSE). Anker trademarks, product images, 3D models, and other
third-party assets are not covered by it; see [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
