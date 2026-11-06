<div align="center">

# Cibula

**A free, private browser for iPhone. Every request goes through Tor.**

*Layer by layer, no traces.*

**Cibula is a fork of [Onion Browser](https://github.com/OnionBrowser/OnionBrowser)** with a new design and without the clutter.

[![Fork of Onion Browser](https://img.shields.io/badge/fork%20of-Onion%20Browser-7D4CDB?style=for-the-badge)](https://github.com/OnionBrowser/OnionBrowser)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#requirements)
[![Tor](https://img.shields.io/badge/network-Tor-7D4CDB?style=for-the-badge&logo=torproject&logoColor=white)](https://www.torproject.org/)
[![Telegram](https://img.shields.io/badge/Telegram-Download-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](#download)

**English** · [Русский](README.ru.md) · [Українська](README.uk.md)

</div>

---

> **Cibula is a fork of Onion Browser.** It is an independent project and is not affiliated with or endorsed by Onion Browser, Tigas Ventures LLC or The Tor Project.

<a id="download"></a>

## Download

The latest ready-made version of Cibula is available in our Telegram channel.

[![Download in Telegram](https://img.shields.io/badge/Telegram-Download%20the%20latest%20version-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](TELEGRAM_LINK)

Cibula is not on the App Store. The builds are `.ipa` files. iOS does not install unsigned apps, so unless the channel post says a build is already signed, sign it with your own Apple developer certificate first (see [Install](#install)).

## Features

- **Tor only.** The built-in Tor is the single option.
- **New look.** Deep purple theme, a new welcome screen and a new "entering the Tor network" screen.
- **Liquid Glass bars.** The address bar and the toolbar float over the page as rounded glass capsules (real Liquid Glass on iOS 26, frosted glass on older versions).
- **Merge the bars.** An optional switch puts the address bar and the buttons into one capsule at the bottom, like Safari (Settings, Miscellaneous, needs an app restart).
- **Safari-style tabs.** Tall cards in two columns, hold and drag to reorder, swipe up to close.
- **Less clutter.** A shorter settings screen with only what you need.
- **Free.** No ads, no subscriptions, no hidden payments.

<a id="requirements"></a>

## Requirements

An iPhone with iOS 17 or newer (the built-in Tor needs it).

<a id="install"></a>

## Install

1. Download `Cibula.ipa` from the [Telegram channel](#download).
2. Sign it with your own certificate and provisioning profile (the bundle ID must match your profile) and install it on your device.

## Build it yourself

Without a Mac, the easiest way is the included `codemagic.yaml`: connect this repository to [Codemagic](https://codemagic.io/), choose the `cibula-ipa` workflow and start a build. When it finishes, download `Cibula-ipa.zip` from the artifacts and rename it to `Cibula.ipa`.

On a Mac you can build with Xcode, see [BUILD.md](BUILD.md).

## Security

Please read [SECURITY.md](SECURITY.md), especially the part about known limitations. Tor does not make you anonymous by itself.

## Credits

- [Onion Browser](https://github.com/OnionBrowser/OnionBrowser) by Mike Tigas, its contributors and translators. Cibula is a fork and is built on their work.
- [Endless](https://github.com/jcs/endless) by joshua stein, on which Onion Browser is based.
- [The Tor Project](https://www.torproject.org/) and the open source libraries that bring Tor to iOS.

## License

See [LICENSE](LICENSE). It contains the Onion Browser License and the Endless License, which apply to this project.
