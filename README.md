<p align="center">
  <img width="180" src="apps/weblibre/assets/icon/icon.png" alt="Cat Browser logo">
</p>

<h1 align="center">Cat Browser</h1>

<p align="center">
  <b>Private by default. Experimental by design.</b><br>
  An Android browser built on Mozilla's Gecko engine, forked from WebLibre and pointed in whatever direction I feel like.
</p>

<p align="center">
  <a href="https://github.com/apauruseya-stack/cat-browser/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/apauruseya-stack/cat-browser?style=for-the-badge&label=release&color=8b5cf6"></a>
  <a href="https://github.com/apauruseya-stack/cat-browser/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/apauruseya-stack/cat-browser/total?style=for-the-badge&color=f59e0b"></a>
  <a href="COPYING"><img alt="License" src="https://img.shields.io/badge/license-AGPL--3.0-22c55e?style=for-the-badge"></a>
  <a href="https://developer.android.com"><img alt="Android 8.0+" src="https://img.shields.io/badge/android-8.0%2B-3ddc84?style=for-the-badge&logo=android&logoColor=white"></a>
  <a href="https://mozilla.github.io/geckoview/"><img alt="GeckoView 158" src="https://img.shields.io/badge/engine-GeckoView%20158-ff7139?style=for-the-badge&logo=firefoxbrowser&logoColor=white"></a>
  <a href="https://flutter.dev"><img alt="Built with Flutter" src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"></a>
</p>

---

## Download

APKs are published on the [releases page](https://github.com/apauruseya-stack/cat-browser/releases). Grab the file that matches your device:

| File | Use it for | Size |
|------|-----------|------|
| `app-stable-arm64-v8a-release.apk` | Nearly every phone from 2017 onward | ~148 MB |
| `app-stable-armeabi-v7a-release.apk` | Older 32-bit phones and tablets | ~145 MB |
| `app-stable-x86_64-release.apk` | Emulators, Chromebooks, x86 tablets | ~156 MB |
| `app-stable-release.aab` | App store uploads | ~504 MB |

The `app-stableImpeller-*` files are the same app with Impeller turned on. Impeller is a newer GPU renderer: smoother in places, still finding its feet in others. Try it if the normal build feels choppy.

**Pre-releases** are built from tags containing `alpha` or `pre`. They publish APK-only, skip the app bundle, and are marked as pre-release on the releases page. They are the fastest way to see what landed this week, and the fastest way to find a regression.

**A note on signing:** these builds are signed with a local debug key, not a Play Store key. Android will refuse to install one over a Play-installed copy, so uninstall the old one first. Your data goes with it.

---

## Why this fork exists

WebLibre is a solid, general-purpose browser and it deserves the credit for almost everything under the hood. Cat Browser is my sandbox on top of it: a place to ship ideas that are too opinionated, too unfinished, or too weird for upstream.

Some of those ideas work. Some of them will be reverted next month. Both are fine.

## What Cat Browser adds

| Feature | What it does | Status |
|---------|--------------|--------|
| **Home page redesign** | A clock instead of the brand mark, wallpaper behind it, and an hourly rotation across Bing, Wikimedia Picture of the Day and NASA APOD. Pure black is the default for AMOLED screens, and tapping the clock flips the logo between black and white. | Shipped |
| **Privacy X-Ray** | A shield badge with the live blocked count, in the toolbar and in the site info sheet, broken down by tracker category. Assigned to a toolbar button you can customize or remove. | Shipped |
| **Cookie banner handling** | Detects consent banners in every frame, including open shadow roots. Rejects through the CMP's own API first, then a reject-only click list. Never clicks "accept". Per-site modes, undo, a rule editor, and optional rule updates pinned to a hash. | Shipped, experimental |
| **Import from other browsers** | Chrome, Brave, Edge and Firefox bookmarks plus history, with a preview before anything is written, duplicate detection, cancellation and undo. | Shipped, passwords not yet |
| **Accessibility pass** | App text scale up to 200%, a capped mode so system scaling cannot multiply past the ceiling, bold text, and a reduce motion switch. | Partial |
| **Protection report** | A local dashboard showing what the browser actually blocked, computed from engine counters. No network, no telemetry. | v1 |
| **Saner defaults** | DNS over HTTPS on (Cloudflare and NextDNS), tab stacking off, Privacy Badger as an opt-in, supporter banner removed. | Shipped |
| **Fullscreen** | Immersive sticky mode, re-applied when the window metrics change, plus an optional hidden status bar. | Shipped |
| **Branding** | Cat logo, launcher icon, bundled font, and rebranded English strings. | Shipped |
| **Real CI** | A GitHub Actions pipeline that builds per-ABI APKs and an app bundle, checks the localization template, and publishes the release. | Shipped |

## In progress

- [ ] Profile archives and open tabs: `.zip` profile import with zip-slip and size limits, and Firefox `sessionstore.jsonlz4` decoding
- [ ] Extension list migration: read a Chrome or Firefox add-on list, map it against a curated AMO table, install only after a tap
- [ ] Password import, blocked until there is an encrypted login store to import into
- [ ] High contrast themes, visible focus rings, D-pad and switch access, reader typography controls
- [ ] Protection stats: per-site breakdown, export, retention caps
- [ ] On-device AI helpers: settings scaffolding only, no model ships with the app

The full plan, with acceptance criteria and the reasoning behind each decision, lives in [ROADMAP.md](ROADMAP.md).

## Everything else comes from WebLibre

Containers with per-container cookie isolation, isolated tabs that keep their session across restarts, tree-style tabs with pinning and stacking, Firefox-compatible extensions (uBlock Origin is offered during onboarding), local search across tabs and bookmarks and history and feeds, reader mode, translation, RSS, Firefox Sync, adaptive layout, keyboard shortcuts, gestures, and the download manager.

Two things are inherited but **not available in this build**: Tor and the proxy client. The settings category is hidden and the transport is not wired up. Do not install this expecting a VPN.

## Privacy

There is no telemetry, no crash reporting, and no analytics in the app. Nothing about your browsing leaves the device unless you ask it to, for example by enabling online wallpapers, turning on Firefox Sync, or letting the cookie banner rules check for updates.

## Build it yourself

You need Flutter 3.47.8, JDK 17, the Android SDK with the NDK version pinned in `apps/weblibre/android/gradle.properties`, Go 1.25 for the native runtime, Python 3 for the asset and localization scripts, and Node 20 for the JS components.

```bash
git clone https://github.com/apauruseya-stack/cat-browser.git
cd cat-browser
dart pub global activate melos 7.8.1
melos bootstrap
melos run build              # merges l10n fragments, then runs build_runner
melos run update-assets
melos run build-components
```

The proxy plugins need a native AAR before Gradle will configure:

```bash
melos run build-go-runtime
```

That script expects Linux or macOS, and CI runs it on Ubuntu. On Windows, build inside WSL or let GitHub Actions do it.

Then build the app:

```bash
cd apps/weblibre
flutter build apk --release --flavor stable --split-per-abi --no-tree-shake-icons
```

Flavors are `stable`, `stableImpeller`, `alpha` and `alphaImpeller`. A debug build is just `flutter run` from `apps/weblibre`.

## Project layout

| Path | What lives there |
|------|------------------|
| `apps/weblibre/` | The Flutter app |
| `packages/` | Shared Flutter packages, including the GeckoView bridge |
| `native/` | Go and native helpers for the proxy runtime |
| `scripts/` | Asset, localization and upstream sync scripts |
| `ROADMAP.md` | The plan, with status per milestone |

## Credits and license

Cat Browser is a fork of [WebLibre](https://github.com/FaFre/WebLibre), which is itself built on Mozilla's GeckoView and Android Components. None of that work is mine, and the fork would not exist without it.

The code is [AGPL-3.0](COPYING), same as upstream. If you redistribute it, keep the attribution and publish your changes.

Cat Browser is not affiliated with the WebLibre project or with Mozilla.
