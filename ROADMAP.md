# Cat Browser Roadmap - Protection, Migration, Accessibility, Transparency, On-Device AI

> Living document for the `apauruseya-stack/cat-browser` fork.
>
> - **Last updated:** 2026-10-30
> - **Scope:** `apps/weblibre` (Flutter/Dart) and `packages/flutter_mozilla_components` (Kotlin / GeckoView bridge)
> - **Engine baseline:** Mozilla Android Components `158.0.2`, GeckoView `158.0.20261024061337`
> - **Status:** planning. Nothing in this document is implemented unless its checklist says so.

This document is the implementation reference for five initiatives:

| ID | Initiative | User problem it solves | Effort (person-weeks) | Risk | Depends on | Target |
|----|------------|------------------------|-----------------------|------|------------|--------|
| A | [Cookie and banner handling](#a-cookie-and-banner-handling) | Consent walls and "reject all" hunts on every site | 6-8 | Medium | D (stats hooks), extension host | 2027 Q1 |
| B | [Import from Chromium and Firefox profiles](#b-import-from-chromium-and-firefox-profiles) | Switching browsers loses bookmarks, history, passwords, tabs | 10-14 | High (passwords) | Login storage (new), Places bulk API (new) | 2027 Q2-Q3 |
| C | [Accessibility suite](#c-accessibility-suite) | TalkBack, large text, contrast, motion, switch access are second-class | 6-9 | Low-Medium | None | 2027 Q1-Q2 |
| D | [Telemetry-free protection stats](#d-telemetry-free-protection-stats) | Users cannot see what protection actually did | 5-7 | Low | A (banner events) | 2026 Q4-2027 Q1 |
| E | [Local AI enhancements](#e-local-ai-enhancements-strict-opt-in) | On-device AI only names containers today | 12-18 | High (perf, battery, trust) | C (a11y for output UI), content extraction | 2027 Q3-Q4 |

Total: roughly 40-55 person-weeks. The order above is the recommended order, not the requested order; see [Sequencing](#sequencing-and-release-plan).

---

## Table of contents

1. [How to use this document](#how-to-use-this-document)
2. [Fork constraints and ground rules](#fork-constraints-and-ground-rules)
3. [Shared foundations](#shared-foundations)
4. [A. Cookie and banner handling](#a-cookie-and-banner-handling)
5. [B. Import from Chromium and Firefox profiles](#b-import-from-chromium-and-firefox-profiles)
6. [C. Accessibility suite](#c-accessibility-suite)
7. [D. Telemetry-free protection stats](#d-telemetry-free-protection-stats)
8. [E. Local AI enhancements (strict opt-in)](#e-local-ai-enhancements-strict-opt-in)
9. [Sequencing and release plan](#sequencing-and-release-plan)
10. [Definition of done](#definition-of-done)
11. [Decision log](#decision-log)
12. [Open questions](#open-questions)
13. [Appendix: file map and references](#appendix-file-map-and-references)

---

## How to use this document

### Status legend

| Marker | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress (add owner + branch in the line) |
| `[x]` | Done (link the PR/commit) |
| `[-]` | Dropped or deferred (record why in the decision log) |

### Working rules

1. **One initiative per branch**, prefixed `feat/a-cookie-`, `feat/b-import-`, etc. Never mix two initiatives in one PR.
2. **New code lives in new files and new feature directories.** Edits to upstream-owned files are kept to the minimum listed in each "Integration points" table, so `scripts/sync-upstream.ps1` keeps merging cleanly.
3. **Every setting is additive and defaulted safely.** A new feature must be usable when its flag is off, and off must mean "behave exactly like today".
4. **Every user-facing string goes through ARB files.** One `<feature>_en.arb` per feature, then translations. No hard-coded English in widgets.
5. **Every milestone ends with a build.** Debug build must pass, and the release build (`flutter build apk --release --flavor stable`) must be produced before the milestone is marked done.
6. **Update this file in the same PR** that changes a milestone state. That is the whole point of keeping it in the repo.

### Estimates

Estimates assume one experienced Flutter/Android developer familiar with the codebase. They include tests and localization but not translation review or store review. Add 30% for a first-time contributor.

---

## Fork constraints and ground rules

These constraints are specific to this fork and shape every plan below.

| Constraint | Consequence for planning |
|------------|--------------------------|
| Rust toolchain, `gomobile` AAR and the combined native lib are **not** available in the build environment. `lib/core/rust_lib.dart` is a no-op. | No new Rust dependencies. No feature may require the Rust runtime. |
| Proxy/Tor transport was removed. `main.dart` no longer starts it; the Proxy settings category is hidden. | Do not build features that assume Tor/proxy exists. Keep nullable `network_mode` dimensions so an upstream sync can fill them later. |
| Release APK is ~317 MB and a release build takes ~4 minutes. | No large model or rule pack is bundled in the APK. Everything heavy is downloaded on demand, after explicit consent. |
| Upstream is `FaFre/WebLibre`; the fork merges `upstream/main` regularly. | Prefer additive modules. Record every upstream file touched. |
| GeckoView 158 build ships **no** `cookiebanners` service assets, and `ContentBlocking.Settings.Builder` has no cookie-banner method (verified by inspecting the AAR). | Cookie banner handling must be a WebExtension + native-messaging feature, not an engine setting. |
| No login/password storage layer exists in the bridge today (no `Autocomplete.StorageDelegate` implementation, no `logins` API). | Password import is blocked until a login store is built. It is phased last. |
| There is no telemetry, no crash reporting and no analytics in the app. | Stats must be computed locally from local sources and must never open a socket. This is testable. |

### Known debt to clean up along the way

- `apps/weblibre/lib/features/user/data/database/definitions.drift` still imports `package:flutter_singbox_proxy` and declares `proxy_profile`, even though the transport is gone.
- `features/proxy/` and `features/tor/` still contain code that is hidden but compiled.
- `PersistedBoolKey.supporterBannerDismissed` is now unused after the home banner removal.

These are small, safe cleanups. They are not part of any initiative, but each initiative should not make them worse.

---

## Shared foundations

Build these once, in this order, before or alongside initiative D and A.

### F1. Feature flags and settings

Add a single, typed place for new switches instead of scattering fields:

- Prefer new fields on `GeneralSettings` (`apps/weblibre/lib/features/user/data/models/general_settings.dart`) when the value is user-facing and exportable.
- Use `PersistedBoolKey` (`lib/core/providers/persisted_bool.dart`) for pure UI state that should not be exported (expanded panels, dismissed hints).
- Add a `FeatureFlags` provider only for build-time experiments; do not duplicate user settings there.

Rules:

- New settings get a `@JsonKey(name: ...)` and a default in the constructor's `??` chain, so old exported settings still deserialize.
- Settings are exported/imported through `features/settings/domain/entities/settings_export_document.dart`. New fields must round-trip; add a test.
- Every setting gets a `SettingsEntryDefinition` with `keywords`, so settings search finds it.

### F2. Local data layer

Per-feature Drift databases already exist (`features/*/data/database/definitions.drift`). New initiatives follow that pattern:

```
features/<name>/data/database/definitions.drift   # schema
features/<name>/data/database/database.dart       # @DriftDatabase
features/<name>/data/database/daos/*.dart         # queries
features/<name>/data/providers.dart               # Riverpod wiring
```

Conventions:

- `STRICT` tables, UTC timestamps stored as `DATETIME`.
- Add `schemaVersion` + a `database.steps.dart` migration; never edit a shipped table in place without a migration step.
- Keep row counts bounded: raw events have a retention window, aggregates are rolled up.
- No URLs in stats tables unless the feature explicitly needs them; prefer hostnames and hashes (see [D](#d-telemetry-free-protection-stats)).

### F3. Built-in extension host

Two built-in extensions already demonstrate the pattern and should be reused rather than reinvented:

| Extension | Location | Native port | Notes |
|-----------|----------|-------------|-------|
| `cookie-manager@weblibre.eu` | `packages/flutter_mozilla_components/android/src/main/assets/extensions/cookie-manager/` | `cookieManager` | `browser.cookies` get/getAll/set/remove via `CookieManagerFeature` |
| `browser_extension@weblibre.eu` | `.../assets/extensions/browser_extension/` | `mozacBrowserExtension` | has `webRequest`, `webRequestBlocking`, `<all_urls>`, plus `readability.min.js`, `turndown.js` |
| `ml-engine@weblibre.eu` | `.../assets/extensions/ml_engine/` | `mlEngine` | `browser.experiments.ml` (embeddings, topic generation) |

For a new built-in extension:

1. Add the folder under `android/src/main/assets/extensions/<name>/`.
2. Add a `object <Name>Feature` in `.../feature/` modelled on `CookieManagerFeature` (request ids, mutex, `BuiltInWebExtensionController`, `ResultConsumer`).
3. Install it in `EngineProvider.kt` next to the other `*.install(...)` calls.
4. Expose it to Dart through a new Pigeon API (`packages/flutter_mozilla_components/pigeons/gecko.dart` -> regenerate `gecko.g.dart` / `Gecko.g.kt`) and a thin Dart service in `lib/src/domain/services/`.
5. Add a Riverpod repository in the app that wraps the service, like `TrackingProtectionRepository`.

Do **not** add page-level logic to `cookie-manager`; it only talks to `browser.cookies`. Create a separate extension so failures are isolated.

### F4. Local event ledger

Initiatives A, D and E all need "something happened" events that survive restarts and can be aggregated. Define one small ledger and reuse it:

```sql
CREATE TABLE local_event (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  occurred_at DATETIME NOT NULL,
  kind        TEXT NOT NULL,        -- 'tracker_blocked', 'banner_rejected', ...
  subject     TEXT,                 -- hostname or site key, nullable
  value       INTEGER NOT NULL DEFAULT 1,
  meta_json   TEXT                  -- small, optional, never page content
) STRICT;

CREATE INDEX idx_local_event_time ON local_event(occurred_at);
CREATE INDEX idx_local_event_kind ON local_event(kind, occurred_at);
```

Rules:

- `meta_json` may contain rule ids, categories, counts. It must never contain page text, form values, or full URLs.
- A retention job deletes raw rows older than the configured window (default 7 days) and writes daily rollups.
- Every writer goes through one repository, so the "no network" and "bounded size" guarantees are enforced in one place.

### F5. Content extraction (shared by B and E)

Two existing paths, use the cheaper one that fits:

| Path | Where | Output | Use for |
|------|-------|--------|---------|
| Readability content script | `assets/extensions/readability_extract/content.js` + `ReadabilityExtractFeature.kt` | article text/HTML | Summaries, semantic indexing of the current page |
| Turndown | `browser_extension/turndown.js` exposed as `GeckoBrowserExtensionService.turndownHtml` | markdown + plain text, 1s timeout | Feed articles and already-fetched HTML |
| Reader view | `feature-readerview` (Mozilla Components) | readable rendering | User-facing reading mode |

Rules: extraction runs off the UI thread, is capped (e.g. 200k characters), and never runs on `about:` pages, input fields, or private containers unless the user explicitly asks.

### F6. Localization and accessibility primitives

- Add `<feature>_en.arb` next to the feature and run `flutter gen-l10n` (config in `apps/weblibre/l10n.yaml`).
- Every new interactive widget must pass the accessibility guidelines listed in [C](#c-accessibility-suite). Retrofitting is more expensive than doing it once.

### F7. Testing and CI

Minimum per PR:

- `flutter analyze` clean for touched packages.
- Unit tests for parsers, rules, aggregation and prompt builders (pure Dart, no engine).
- Widget tests for new screens, including an accessibility guidelines test (see C).
- One integration test per user-visible flow on the emulator.
- A "no network" test for modules that must stay offline: a test that imports the module and asserts no `HttpClient`, `dio`, or `http` usage, or a lint/grep gate in CI.

### F8. Upstream sync discipline

Add a short table to each PR description:

| Upstream file touched | Why | Conflict risk |
|-----------------------|-----|---------------|
| `EngineProvider.kt` | install new feature | low (one line) |
| `gecko.dart` (Pigeon) | new API | medium (regenerate) |

If a change needs more than ~30 lines in an upstream file, stop and look for an additive seam first.

---

## A. Cookie and banner handling

### Why

Consent banners are the most common interruption on the web. uBlock Origin already hides many of them with cosmetic filters, but hiding is not rejecting: the consent state stays unset, sites re-show the wall, and some refuse to render content until a choice is made. Firefox desktop solves this with a cookie-banner service and remote rules; this GeckoView build does not ship that service, so Cat Browser needs its own.

### Goals

1. Automatically choose **"reject non-essential"** where a reject control exists.
2. Never click "accept all" or an ambiguous button.
3. Work without uBlock Origin installed, and cooperate with it when it is.
4. Keep all rules and decisions on device.
5. Never break a page: every automatic action is reversible and observable.

### Non-goals

- Legal compliance advice or a GDPR consent manager.
- Bypassing paywalls or consent walls that have no reject option.
- Server-side or cloud rule evaluation.
- Handling non-cookie interstitials (newsletter modals, app-install prompts) beyond a cosmetic hide list.

### Current state (verified)

- **No cookie/consent code exists in the app.** A repo-wide search for `consent`, `cookieBanner`, `autoconsent` returns nothing in `apps/weblibre/lib`.
- **uBlock hardening already includes** `fanboy-cookiemonster` and `ublock-annoyances` in `kUBlockHardeningStockTokens` (`lib/features/user/data/models/ublock_filter_list_settings.dart`). That is the cosmetic-hide fallback, not a rejecter.
- **`cookie-manager@weblibre.eu`** exists and exposes `browser.cookies` through the `cookieManager` native port (`CookieManagerFeature.kt`). It has no content script.
- **`browser_extension@weblibre.eu`** has `webRequest` + `webRequestBlocking` + `<all_urls>` and a native port, so page-level observation and injection are already possible.
- **GeckoView 158 has no cookie-banner API.** `ContentBlocking.Settings.Builder` exposes `cookieBehavior`, `cookieBehaviorPrivateMode`, `cookiePurging` only, and the AAR's `omni.ja` contains no `cookiebanners` module.

### Architecture

```
content script (all frames, document_start)
  |  detect banner (selector / text / CMP global / shadow DOM)
  |  decide: reject / hide / leave
  v
background script  <--- rules JSON (bundled, cached in browser.storage.local)
  |  native port "cookieBanner"
  v
CookieBannerFeature.kt  --->  Dart repository  --->  local_event ledger (D)
                                   |
                                   +--> per-site decisions (Drift)
                                   +--> settings + banner badge UI
```

Why a content script and not a filter list only: a filter list can hide an element but cannot click a specific "Reject all" control, cannot call `__tcfapi('postGdprConsent', ...)`, and cannot record "handled" for stats.

### Rule format

Rules are data, versioned, and bundled as JSON. No code in rules.

```json
{
  "version": 1,
  "updated": "2026-10-30",
  "rules": [
    {
      "id": "cookiebot",
      "domains": ["*"],
      "detectors": [
        { "type": "css", "selector": "#CybotCookiebotDialog" },
        { "type": "global", "name": "Cookiebot" }
      ],
      "reject": [
        { "type": "click", "selector": "#CybotCookiebotDialogBodyButtonDecline" },
        { "type": "click", "text": ["reject all", "decline", "only necessary", "essential only"] }
      ],
      "hide": ["#CybotCookiebotDialog", "#CybotCookiebotDialogBodyUnderlay"],
      "confidence": 0.95
    }
  ]
}
```

Detector types:

| Type | Meaning | Notes |
|------|---------|-------|
| `css` | Element exists | Fast, most reliable |
| `global` | Known CMP JS object exists (`Cookiebot`, `OneTrust`, `__tcfapi`, `__gpp`) | Use the CMP's own API when possible |
| `text` | A button/link whose accessible text matches a phrase | Multilingual phrase lists; case- and whitespace-insensitive |
| `shadow` | Same as `css`, but pierces open shadow roots | Closed shadow roots are out of scope |
| `frame` | Known CMP iframe URL pattern | Same-origin scripting only; otherwise ask the parent |

Reject actions, in preference order:

1. `tcfapi` / `gpp` API call (most reliable, no DOM dependency).
2. Click a rule selector.
3. Click by text phrase from a **reject-only** phrase list.
4. Hide the overlay (cosmetic fallback) and mark the site as "hidden, not rejected".

Hard safety rules:

- The phrase list contains only reject-like phrases. `OK`, `Continue`, `Got it`, `Agree`, `Accept` are never clicked.
- At most 3 click attempts per page load, within 10 seconds.
- Never act inside a cross-origin iframe unless the CMP exposes an API.
- Stop immediately if the page navigates, the element disappears, or a login/payment form is focused.
- A "page looks broken? undo" action restores the banner and adds a site exception.

### Data model

```sql
CREATE TABLE cookie_site_decision (
  site_key     TEXT PRIMARY KEY NOT NULL,   -- eTLD+1
  mode         TEXT NOT NULL,               -- 'auto', 'ask', 'off'
  last_action  TEXT,                        -- 'rejected', 'hidden', 'failed'
  rule_id      TEXT,
  updated_at   DATETIME NOT NULL
) STRICT;

CREATE TABLE cookie_rule_override (
  rule_id      TEXT PRIMARY KEY NOT NULL,
  disabled     BOOLEAN NOT NULL DEFAULT FALSE,
  reject_json  TEXT,                        -- user-supplied selectors
  updated_at   DATETIME NOT NULL
) STRICT;

CREATE TABLE cookie_banner_event (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  occurred_at  DATETIME NOT NULL,
  site_key     TEXT NOT NULL,
  action       TEXT NOT NULL,               -- 'rejected','hidden','failed','none'
  rule_id      TEXT,
  confidence   REAL
) STRICT;
```

`cookie_banner_event` is the source for initiative D; it is written through the shared ledger where possible.

### Integration points

| File | Change | Size |
|------|--------|------|
| `assets/extensions/cookie_banner/manifest.json` | new MV2 extension: `content_scripts` (all frames, document_start), `storage`, `nativeMessaging` | new |
| `assets/extensions/cookie_banner/content.js` | detectors, reject logic, shadow DOM, overlay hide | new, ~600 lines |
| `assets/extensions/cookie_banner/background.js` | rule fetch/cache, native port, per-site decisions | new, ~200 lines |
| `assets/extensions/cookie_banner/rules.json` | bundled rule pack | new |
| `.../feature/CookieBannerFeature.kt` | native port + request routing | new |
| `EngineProvider.kt` | one `CookieBannerFeature.install(it)` line | 1 line |
| `pigeons/gecko.dart` + generated | `GeckoCookieBannerApi`: `getStatus`, `setSiteMode`, `reportEvent` | new |
| `lib/src/domain/services/gecko_cookie_banner.dart` | Dart service | new |
| `lib/features/cookie_banners/` | repository, settings, badge, per-site sheet | new feature |
| `settings/presentation/screens/privacy_security_settings.dart` | one settings entry + section | ~20 lines |
| `browser/presentation/widgets/sheets/tracking_protection_section.dart` | banner status row (optional) | ~30 lines |

### Milestones

#### A0 - Cosmetic fallback (1-2 days)

- [x] Ensure `fanboy-cookiemonster` and `ublock-annoyances` are in the default hardening set for new installs (already in the constant; verify the onboarding default path uses it).
- [x] Add a settings toggle: **Privacy & security -> Cookie banners** (enum `off`/`detect`/`reject`/`rejectOrHide`). Default `rejectOrHide`.
- [ ] Document that this hides but does not reject.

**Acceptance:** with the toggle on, banners are visually gone on the test corpus; no reject is claimed anywhere in the UI.

#### A1 - Detection only (1-2 weeks)

- [x] New extension skeleton, rule schema v1, top 25 CMP rules.
- [x] Detection in all frames, including open shadow roots.
- [x] Report `banner_seen` events to the ledger (no clicks).
- [ ] Show a small, dismissible badge on the page: "Cookie banner detected - reject?".

**Acceptance:** on 50 test sites, >= 90% of banners are detected; zero DOM clicks; extension disabled -> zero change in page behaviour.

#### A2 - Auto-reject (2-3 weeks)

- [x] Reject actions: `tcfapi`, selector click, reject-only text click.
- [ ] Per-site modes (`auto`, `ask`, `off`) with a UI to change them from the badge.
- [ ] "Undo" restores the overlay and sets the site to `ask`.
- [x] Safety guards (attempt cap, timeout, navigation abort, form-focus abort).
- [x] Stats events: `banner_rejected`, `banner_failed`.

**Acceptance:**

- >= 75% of detected banners handled without user interaction on the corpus.
- Zero clicks on accept-like text (assert in tests and review the rule pack).
- Page-breakage rate < 2% on the corpus; every breakage has an undo path.
- Toggle off -> no content script actions, no measurable page slowdown.

#### A3 - Rule repository (2-3 weeks)

- [x] Bundled pack versioned with a hash; cached in `browser.storage.local`.
- [x] Optional rule updates: manual "Check for rule updates" plus an opt-in weekly check. No identifiers, no query parameters, no cookies on the request; download a static JSON and verify its hash against a pinned value shipped in the app.
- [x] Local overrides: disable a rule, add selectors for a site, export/import overrides as JSON.
- [x] Rule editor UI in the settings screen (advanced).

**Acceptance:** offline works with the bundled pack; a failed update never leaves an empty rule set; overrides survive updates.

#### A4 - Coverage and hardening (2 weeks)

- [x] CMP iframe handling where same-origin or API-based.
- [x] Confidence tuning from local stats (failed actions per rule).
- [x] Rule contribution workflow documented in the repo (JSON only, no code).
- [x] Fuzz tests for the rule parser and the text matcher.

**Acceptance:** >= 85% handled on the corpus; no crash in 1,000 randomized pages; rule pack loads in < 50 ms.

### Settings additions

| Setting | Type | Default | Notes |
|---------|------|---------|-------|
| `cookieBannerHandling` | enum `off`, `detect`, `reject`, `rejectOrHide` | `rejectOrHide` | `detect` is the safe preview mode |
| `cookieBannerRuleUpdates` | bool | `false` | Explicit opt-in for network rule fetch |
| `cookieBannerShowBadge` | bool | `true` | Badge on detected banners |
| `cookieBannerStoreDecisions` | bool | `true` | Needed for per-site memory; turning off keeps only counters |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Clicking the wrong control | Medium | High (consent granted) | Reject-only phrase list, explicit selectors, accept-phrase denylist, tests |
| Page breakage (overlay hidden but scroll locked) | Medium | Medium | Detect `overflow:hidden` on `body`/`html` and restore it; undo action |
| CMP changes its DOM | High | Low | Prefer CMP APIs; rules are data and update independently |
| Closed shadow DOM | Medium | Low | Out of scope; fall back to cosmetic hide |
| Users expect "no banners at all" | High | Low | Set expectations in settings copy: rejects where possible, hides otherwise |
| Rule update request leaks usage | Low | High | Static file, no query, no cookies, hash pinned, opt-in, documented |

### Test plan

- Unit: rule parser, phrase matcher (multilingual, punctuation, case), selector escaping, confidence thresholds.
- Integration: 50-site corpus, recorded pass/fail per site, run on every rule-pack change.
- Regression: page with no banner must be byte-identical in behaviour (no DOM mutation when nothing is detected).
- Privacy: assert the rule updater sends no cookies and no identifiers (intercept the request in a test).

---

## B. Import from Chromium and Firefox profiles

### Why

Switching browsers is the moment a privacy browser wins or loses a user. Cat Browser already imports bookmarks from HTML and Firefox JSON; everything else (history, passwords, open tabs, extension lists) is missing. The README explicitly targets Firefox/Fennec/IronFox users, so migration is a natural gap.

### Goals

1. One screen that accepts a profile export or a browser data file and imports what it can.
2. A **preview before writing**: counts per category, conflicts, and what will be skipped.
3. Transactional, resumable, cancellable, and undoable.
4. No network, no plaintext passwords left on disk, no silent overwrite.

### Non-goals

- Reading another app's private storage without root or a user-provided export.
- Cloud sync or account-based migration.
- Automatically installing extensions.
- Importing from iOS browsers.

### Current state (verified)

- Bookmarks: HTML (Netscape format) and Firefox JSON parsing exist.
  - `lib/features/geckoview/features/bookmarks/utils/bookmark_html_utils.dart`
  - `lib/features/geckoview/features/bookmarks/utils/bookmark_json_utils.dart`
  - `lib/features/geckoview/features/bookmarks/utils/bookmark_import_isolate.dart`
  - `lib/features/geckoview/features/bookmarks/utils/bookmark_importer.dart` (bulk `insertTree`, progress events)
- History: **read and delete only**. `GeckoHistoryService` has `getDetailedVisits`, `deleteVisitsBetween`, `recordObservation`; there is no bulk insert.
- Passwords: **no storage layer at all**. No `Autocomplete.StorageDelegate` implementation in the Kotlin bridge, no logins API in Pigeon, no passwords screen.
- Tabs: no session import. There is a `recently_closed_tabs` feature, unrelated to foreign sessions.
- Extensions: `BrowserAddonService.install(guid)` installs from AMO by GUID; there is no "list and map" flow.
- File picking: `file_picker` is already a dependency and used by the bookmark import UI.

### Architecture

```
pick file / zip
      |
      v
detect format (magic bytes + extension + JSON shape)
      |
      v
parse in isolate  ->  ImportBundle (canonical model)
      |
      v
validate + dedupe + preview (counts, conflicts, unsupported)
      |
      v
user selects categories  ->  apply (per-category, transactional)
      |
      v
report + undo token
```

### Canonical model

```dart
enum ImportSource { chrome, brave, edge, firefox, fennec, htmlBookmarks, chromeCsv, firefoxCsv }

class ImportBundle {
  final ImportSource source;
  final List<ImportBookmarkNode> bookmarks;
  final List<ImportHistoryEntry> history;
  final List<ImportLogin> logins;      // empty until login storage exists
  final List<ImportTab> tabs;
  final List<ImportAddon> addons;
  final List<ImportIssue> issues;      // skipped rows, reasons
}

class ImportHistoryEntry {
  final Uri url;
  final String? title;
  final DateTime visitedAt;
  final int visitCount;
}

class ImportLogin {
  final Uri origin;
  final String username;
  final String password;   // in memory only; never logged, never persisted in plaintext
  final String? formActionOrigin;
}
```

### Source support matrix

| Source | File | What | Feasibility | Phase |
|--------|------|------|-------------|-------|
| Chrome / Brave / Edge | `Bookmarks` (JSON) | bookmarks + folders | High | B1 |
| Chrome / Brave / Edge | `History` (SQLite) | history | High | B1 |
| Chrome / Brave / Edge | `Preferences` / `Secure Preferences` (JSON) | installed extension list | High (mapping only) | B3 |
| Chrome / Brave / Edge | `Login Data` (SQLite, encrypted) | passwords | Low (OS crypto) | B4 (skip by default) |
| Chrome | password CSV export | passwords | High, but plaintext | B4 |
| Firefox / Fennec / IronFox | `places.sqlite` | bookmarks + history | High | B1 |
| Firefox | `bookmarks.html` | bookmarks | Already done | B0 |
| Firefox | `bookmarks-*.json` | bookmarks | Already done | B0 |
| Firefox | `sessionstore.jsonlz4` | open tabs | Medium (mozLz4 decode) | B2 |
| Firefox | `extensions.json` | add-on list | High (mapping only) | B3 |
| Firefox | `logins.json` + `key4.db` | passwords | Low (NSS PBE/AES/HMAC) | B4 (defer) |
| Firefox | password CSV export | passwords | High, but plaintext | B4 |
| Any | HTML bookmarks | bookmarks | Already done | B0 |
| Any | `.zip` of a profile directory | all of the above | Medium (zip-slip checks) | B2 |

Important: on modern Android, Chrome's and Firefox's data directories are app-private. The realistic user path is **desktop export -> copy to phone -> import**, or a profile `.zip` the user creates. The UI must say so plainly instead of offering a "find installed browsers" button that cannot work.

### Format notes (implementation detail)

- SQLite files start with `SQLite format 3\0`. Use the existing `sqlite3` Dart dependency in read-only mode (`open(mode: OpenMode.readOnly)`), never write to the source.
- Chrome history: `urls.url`, `urls.title`, `visits.visit_time` in **microseconds since 1601-01-01 UTC**. Convert with `DateTime.utc(1601) + Duration(microseconds: t)`.
- Firefox history: `moz_places.url`, `moz_places.title`, `moz_historyvisits.visit_date` in **microseconds since 1970 UTC**.
- Chrome bookmarks: `roots.bookmark_bar`, `roots.other`, `roots.synced`; each node has `type` (`url`/`folder`), `name`, `url`, `children`.
- Firefox `sessionstore.jsonlz4`: file starts with `mozLz40\0`, then a little-endian uint32 uncompressed length, then an LZ4 block. Decode to JSON, read `windows[].tabs[].entries[]` (use the last entry) and `_closedTabs` if present.
- Chrome `Sessions/` (SNSS) is a binary format with no stable public spec. **Do not attempt it** in the first release; mark it unsupported with a clear message.
- Firefox `logins.json` is encrypted with a key derived from `key4.db` (NSS PBE, PBKDF2 + AES-CBC + HMAC). Implementing NSS key4 parsing in Dart is possible but large and security-sensitive. Prefer the CSV export path; revisit only if there is demand.

### Data model

```sql
CREATE TABLE import_job (
  id            TEXT PRIMARY KEY NOT NULL,
  source        TEXT NOT NULL,
  started_at    DATETIME NOT NULL,
  finished_at   DATETIME,
  status        TEXT NOT NULL,          -- 'preview','running','done','failed','cancelled'
  categories    TEXT NOT NULL,          -- JSON list
  counts_json   TEXT NOT NULL,          -- per-category imported/skipped
  undo_json     TEXT,                   -- enough to reverse: folder guids, visit timestamps
  error         TEXT
) STRICT;

CREATE TABLE import_conflict (
  job_id        TEXT NOT NULL REFERENCES import_job(id) ON DELETE CASCADE,
  category      TEXT NOT NULL,
  key           TEXT NOT NULL,          -- url, origin+username, ...
  resolution    TEXT NOT NULL,          -- 'kept-both','skipped','replaced'
  PRIMARY KEY (job_id, category, key)
) STRICT;
```

### New engine APIs needed

| API | Purpose | Implementation sketch |
|-----|---------|-----------------------|
| `GeckoHistoryApi.importVisits(List<VisitImport>)` | bulk history insert | Places `Visits`/`HistoryStorage` write in one transaction, batched (500/batch), progress events |
| `GeckoHistoryApi.deleteImportedVisits(List<VisitKey>)` | undo | delete by `(url, visitTime)` in batches |
| `GeckoLoginsApi.*` | password storage (prerequisite) | `Autocomplete.StorageDelegate` + encrypted store; see B4 |

Do not fake history import by opening each URL in a hidden tab. It pollutes sessions, triggers network, and is slow.

### Login storage prerequisite (B4 blocker)

Before any password import:

1. Implement `GeckoSession` autocomplete delegates (`onLoginSave`, `onLoginFetch`, `onLoginUsed`, `onLoginUpdate`, `onLoginDelete`) in `BaseBrowserFragment` or a dedicated feature.
2. Store credentials in a dedicated SQLite DB with per-record AES-256-GCM encryption; key in Android Keystore (StrongBox when available), never in SharedPreferences.
3. Add a Passwords settings screen: list, search, reveal (re-auth), edit, delete, "never save for this site".
4. Add save/update prompts in the browser UI.
5. Only then add CSV/logins.json import.

This is a full initiative on its own (~4-6 weeks). If passwords are not funded, ship B1-B3 and mark passwords "not supported yet" in the import screen.

### Integration points

| File | Change | Size |
|------|--------|------|
| `lib/features/profile_import/` | new feature: models, parsers, isolate, repository, screens | new |
| `lib/features/geckoview/features/bookmarks/presentation/screens/bookmark_list.dart` | "Import from browser..." entry that opens the new flow | ~15 lines |
| `lib/features/settings/presentation/screens/settings.dart` | new "Import & migrate" category entry | ~15 lines |
| `packages/flutter_mozilla_components/pigeons/gecko.dart` | history bulk import + logins API | new |
| `.../api/GeckoHistoryApiImpl.kt` | implement bulk insert | ~150 lines |
| `.../feature/LoginStorageFeature.kt` | autocomplete delegate + storage | new (B4) |

### Milestones

#### B0 - Unify what exists (3-5 days)

- [x] Move the two bookmark import entry points into one "Import" screen.
- [x] Add source detection for HTML vs Firefox JSON.
- [x] Add a preview step (counts + top-level folders) before writing.
- [x] Add `import_job` records and a report screen.

**Acceptance:** importing the same file twice does not duplicate bookmarks; cancel during preview writes nothing.

#### B1 - Bookmarks + history from Chrome-family and Firefox (3-4 weeks)

- [x] Chrome `Bookmarks` JSON parser (folders, order, roots).
- [x] Chrome `History` SQLite parser (read-only, chunked).
- [x] Firefox `places.sqlite` parser for bookmarks and history.
- [x] Canonical model + dedupe rules.
- [x] Bulk history insert API + progress + cancellation.
- [x] Merge vs replace per category.
- [x] Imported bookmarks land in a top-level folder `Imported from <source> (<date>)` so undo is one delete.
- [x] Undo the last import: exact history rows by (url, timestamp) plus the imported bookmark folder, persisted across restarts.

**Acceptance:**

- 50k-history import completes in < 60 s on a mid-range device, with UI progress.
- Cancel leaves no partial history rows (transaction per batch + job-level cleanup).
- Duplicate detection: same URL + same visit timestamp is imported once.
- Undo removes exactly the imported rows and the imported folder, nothing else.

#### B2 - Tabs and profile archives (2-3 weeks)

- [ ] `.zip` profile import with zip-slip and size protections (cap 1 GB, 100k entries).
- [ ] Firefox `sessionstore.jsonlz4` decode + tab extraction.
- [ ] "Open imported tabs" flow: choose container (regular/private/new "Imported"), choose active vs background.
- [ ] Skip `about:` and `file:` URLs.

**Acceptance:** a 200-tab session imports in < 10 s and opens without blocking the UI; malformed archives fail with a clear message and no partial writes.

#### B3 - Extension lists (1-2 weeks)

- [ ] Parse Chrome `Preferences` and Firefox `extensions.json` into a list of names/IDs.
- [ ] Match against a curated AMO mapping table (bundled JSON).
- [ ] Show three states: "available", "no equivalent", "already installed".
- [ ] Install only after an explicit per-item confirmation, through `BrowserAddonService.install(guid)`.

**Acceptance:** no extension is installed without a tap; unmapped items are listed, not silently dropped; the mapping table is data, not code.

#### B4 - Passwords (4-6 weeks, gated)

- [ ] Login storage prerequisite (see above).
- [ ] Chrome/Firefox CSV import with a plaintext warning and a "delete the CSV afterwards" reminder.
- [ ] Optional `logins.json` decryption behind an "advanced" flag (only if B4 is funded).
- [ ] Never log credentials; redact in error reports; zero buffers best-effort.

**Acceptance:** passwords are encrypted at rest; the import screen refuses to proceed without an explicit warning; no credential appears in logs (test with a logging spy).

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Source DB is locked/corrupt | Medium | Low | Open read-only, copy to temp first, surface a clear error |
| Huge files exhaust memory | Medium | Medium | Stream/chunk, isolate with memory cap, hard size limits |
| Wrong timestamp epoch | High | Medium | Unit tests with known fixtures for both epochs |
| Password plaintext leaks | Medium | Critical | Encrypted store, no logs, redacted errors, explicit consent |
| Chrome encrypted `Login Data` cannot be decrypted | High | Medium | Do not promise it; offer CSV |
| Zip-slip / path traversal | Low | Critical | Canonicalize paths, reject `..`, cap entry count/size |
| Import duplicates on re-run | Medium | Medium | Deterministic keys + `import_job` dedupe |

### Test plan

- Fixture files (small, anonymized) checked into `test/fixtures/import/`: Chrome bookmarks JSON, Chrome history SQLite, Firefox places SQLite, sessionstore jsonlz4, extensions.json, CSVs.
- Golden tests for the canonical model produced from each fixture.
- Property test: importing the same bundle twice yields the same database state.
- Cancellation test at every phase.
- Security tests: zip-slip archive, oversized entry, malformed SQLite, truncated jsonlz4.

---

## C. Accessibility suite

### Why

Accessibility is currently a collection of good intentions: a UI scale slider, an animation toggle, and scattered `Semantics`. Users who rely on TalkBack, large text, high contrast, or switch access hit unlabeled controls, clipped layouts at large font sizes, and motion they cannot disable. First-class accessibility also improves the experience for everyone (bright sunlight, one-handed use, temporary injury).

### Goals

1. Every interactive control has an accessible name, role and state.
2. Text can grow to 200% without clipping or losing controls.
3. A high-contrast theme that meets WCAG 2.2 AA contrast for UI chrome.
4. Motion can be reduced or removed independently of the system setting.
5. Keyboard, D-pad and switch access can reach and operate every primary action.
6. Web content respects the user's font size, zoom and reader preferences.

### Non-goals

- Certifying third-party websites.
- Full screen-reader support for the Gecko-rendered page content (that is GeckoView's accessibility tree; we can only ensure we do not break it).
- A custom screen reader.

### Current state (verified)

- `GeneralSettings` already has `uiScaleFactor` (0.5-1.5, step 0.05), `disableAnimations`, and `themeMode` (default dark).
- `applyAppMediaQueryOverrides` in `lib/presentation/main_app.dart` wraps the app in a `_AppTextScaler` that multiplies the system scale by `uiScaleFactor`, and sets `disableAnimations` when requested.
- Web content font size exists: `engineSettings.fontSizeFactor` (0.5-3.0, step 0.1), `webFontsEnabled`, `automaticFontSizeAdjustment`, `fontInflationEnabled`, `inputAutoZoomEnabled`; UI in `settings/presentation/screens/web_content_settings.dart` and `browser/presentation/widgets/font_size_bottom_sheet.dart`.
- Some widgets use `Semantics` (tab reorder, drag handles, a few buttons), but there is no systematic audit, no accessibility test, and no high-contrast theme.
- `MediaQuery.highContrast` and `ColorScheme.fromSeed(contrastLevel:)` are available in the current Flutter SDK but unused.
- No switch-access or focus-ring support beyond Flutter defaults.

### Architecture

```
AccessibilitySettings (new, in GeneralSettings or its own model)
        |
        +--> _AppMediaQueryOverrides (text scale, bold text, reduce motion, high contrast)
        +--> AppTheme (high-contrast ColorScheme, focus colors, target sizes)
        +--> Widgets (Semantics, focus order, minimum targets)
        +--> EngineSettings (web font size, inflation, zoom)
        +--> Settings UI (new "Accessibility" category)
```

### Settings model

Add an `AccessibilitySettings` section (or fields, if export simplicity wins):

| Setting | Type | Default | Notes |
|---------|------|---------|-------|
| `textScaleMode` | `system`, `app`, `capped` | `system` | `capped` limits system scale to `maxSystemScale` |
| `textScaleFactor` | double 0.5-2.0 | 1.0 | App multiplier; 2.0 is the new ceiling |
| `maxSystemScale` | double 1.0-2.0 | 1.5 | Only for `capped` |
| `boldText` | bool | false | Also honors `MediaQuery.boldText` |
| `highContrast` | `system`, `on`, `off` | `system` | Drives `highContrastTheme` |
| `contrastLevel` | double 0.0-1.0 | 0.0 | Material 3 tonal contrast |
| `reduceMotion` | `system`, `on`, `off` | `system` | Merged with `disableAnimations` |
| `largeTouchTargets` | bool | false | Min 56 dp instead of 48 dp |
| `showFocusRing` | bool | true | Visible 2 px, 3:1 focus indicator |
| `verboseHints` | bool | false | Adds "double tap to activate" style hints |
| `colorBlindPalette` | `none`, `deuteranopia`, `protanopia`, `tritanopia` | `none` | Container colors and charts |

### Workstreams

#### C1. Audit and quick wins (1 week)

- [x] Inventory every `IconButton`, `InkWell`, `GestureDetector`, custom paint and drag handle in `lib/`.
- [x] Add `tooltip` + `Semantics(label:)` where an icon has no text.
- [ ] Mark decorative images `ExcludeSemantics`.
- [ ] Merge compound rows with `MergeSemantics` so TalkBack reads one sentence, not five.
- [ ] Fix known offenders first: toolbar buttons, quick tab switcher chips, FABs, tab grid items, container chips, sheet drag handles.

**Acceptance:** zero unlabeled interactive nodes in a widget-tree audit test on the main screens.

#### C2. Text scaling (1-2 weeks)

- [x] Raise the app ceiling from 1.5 to 2.0.
- [x] Add `capped` mode so system 200% does not multiply into 300%+.
- [x] Replace fixed-height rows and `SizedBox`-clamped text with intrinsic layouts where they clip.
- [ ] Add golden tests at 1.0, 1.5, 2.0 and with `boldText` on.
- [ ] Ensure dialogs, sheets, toolbars and the address bar remain usable at 2.0.

**Acceptance:** no overflow errors and no unreachable controls at 200% on a 360 dp wide screen; golden tests cover the five main screens.

#### C3. High contrast and color (1-2 weeks)

- [ ] Build `highContrastLight` / `highContrastDark` themes with >= 7:1 body text and >= 4.5:1 secondary text.
- [ ] Respect `MediaQuery.highContrast` in `system` mode.
- [ ] Ensure the focus ring and selection colors meet 3:1 against adjacent colors.
- [ ] Do not rely on color alone for state (tracker categories, container identity, errors): add icon or text.
- [ ] Color-blind-safe palettes for container colors and the stats charts.

**Acceptance:** `textContrastGuideline` and a custom 3:1 non-text contrast test pass in both themes; container identity is distinguishable without color.

#### C4. Motion (3-5 days)

- [ ] Consolidate `disableAnimations` + new `reduceMotion` into one resolved value.
- [ ] Honor the system accessibility feature even when the app setting says `system`.
- [ ] Replace essential animations with instant transitions or cross-fades when reduced.
- [ ] Keep the "reduce motion" toggle discoverable in Accessibility settings, not buried in General.

**Acceptance:** with reduce motion on, no route transition exceeds 100 ms; no animation loops run; tab switching and sheets still feel responsive.

#### C5. Focus, keyboard and switch access (2-3 weeks)

- [ ] `FocusTraversalGroup` per region (toolbar, content, sheets) with a sane order.
- [ ] Visible focus indicator everywhere, not just Material defaults.
- [ ] D-pad/TV remote navigation for the main flows; `Shortcuts`/`Actions` for select/back/menu.
- [ ] Switch access: every primary action reachable in <= 5 switch presses from the home screen; no gesture-only actions without an alternative.
- [ ] Add an "Accessibility" settings category with a "Test with TalkBack" help page.

**Acceptance:** complete the primary task set (open URL, switch tab, open menu, dismiss dialog, add bookmark) using only D-pad and only switch access.

#### C6. Web content and reader (1 week)

- [ ] Expose web font size, inflation and auto-zoom in the Accessibility category (they exist in Web content; link, do not duplicate).
- [ ] Reader mode: font family, size, line height, justification, theme (light/sepia/dark/high contrast).
- [ ] Ensure `force user scalable` / zoom is on by default for accessibility (verify the Gecko pref and expose it).
- [ ] Do not override the user's system font scale inside Gecko.

**Acceptance:** a page with `user-scalable=no` can still be zoomed; reader mode text scales to 200% without horizontal scrolling.

#### C7. Semantics quality (1 week)

- [ ] Announce route changes and major state changes with `SemanticsService.announce`.
- [ ] Use `liveRegion` for snackbars, loading, and progress.
- [ ] Add `sortKey` so toolbar order matches visual order for screen readers.
- [ ] Provide meaningful labels for counts ("3 trackers blocked", not "3").
- [ ] Localize every label and hint.

**Acceptance:** a scripted TalkBack walkthrough of the five main screens produces no "unlabeled button" and no duplicate announcements.

### Integration points

| File | Change | Size |
|------|--------|------|
| `lib/features/user/data/models/general_settings.dart` | new accessibility fields | ~60 lines |
| `lib/presentation/main_app.dart` | resolve scale/contrast/motion; wrap themes | ~80 lines |
| `lib/core/design/` | `app_theme.dart` with high-contrast variants, focus colors, palettes | new |
| `lib/features/settings/presentation/screens/accessibility_settings.dart` | new category | new |
| `lib/features/settings/presentation/screens/settings.dart` | register category | ~15 lines |
| widgets with icon-only actions | semantics labels | many small edits |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Large-text layout regressions across a big UI | High | Medium | Golden tests + a "200% smoke test" in CI |
| High-contrast theme fights dynamic color | Medium | Medium | Disable dynamic color when high contrast is on |
| Semantics changes alter TalkBack order unexpectedly | Medium | Medium | Test with TalkBack, not just widget tests |
| Scope creep into redesign | High | Medium | Only fix a11y defects; visual redesign is a separate project |

### Test plan

- `flutter test` with `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `labeledTapTargetGuideline` on every new screen.
- Golden tests at 100%/150%/200% text and in high contrast.
- Manual TalkBack matrix: Android 10, 13, 15; TalkBack current; gesture and 3-button navigation.
- D-pad and switch-access scripted walkthroughs.
- Reduce-motion test asserting animation durations.

---

## D. Telemetry-free protection stats

### Why

A privacy browser asks users to trust invisible work. A local, honest report ("this week: 1,284 trackers blocked, 312 banners rejected, 48 cookies deleted") makes protection tangible without sending anything anywhere. It also gives the team a local signal for tuning rules (initiative A) and AI ranking (E), without telemetry.

### Goals

1. Show what protection did, locally, with no network.
2. Be explicit about what is measured vs estimated.
3. Let users export and delete the data.
4. Bound storage growth.

### Non-goals

- Cross-device or cloud dashboards.
- Any analytics, crash reporting, or "anonymous usage" ping.
- Per-request interception logging of full URLs by default.
- Marketing-style "you saved 4.2 GB" claims without a documented estimate.

### Current state (verified)

- Gecko already records tracker statistics: `GeckoTrackingProtectionApi.fetchTrackingStatistics()` returns `TrackingStatistics` with per-day, per-category counts.
- `summarizeTrackingStatistics` (`lib/features/geckoview/features/browser/domain/entities/blocked_trackers.dart`) turns that into a total and a 7-day per-category map.
- `trackerStatisticsProvider` (`.../browser/domain/providers/blocked_trackers.dart`) feeds `_TrackerStatisticsSummary` inside `settings/presentation/screens/privacy_security_settings.dart`.
- Per-page trackers are shown in `tracking_protection_section.dart`.
- There is no saved-data estimate, no cookie-deletion count, no banner count, no per-site breakdown, no export, and no retention control.
- Proxy/Tor usage does not exist in this fork.

### Architecture

```
sources                          ledger (F4)                views
-------                          -----------                -----
ETP statistics  --poll/diff-->   local_event  --rollup-->   daily_rollup
uBO (limited)   --n/a-------->                              dashboard
banner ext.     --events----->                              per-site detail
cookie ops      --instrument->                              export/clear
```

### Measurement honesty

| Metric | Source | Accuracy | Label in UI |
|--------|--------|----------|-------------|
| Trackers blocked | Gecko ETP statistics | Exact (engine count) | "blocked" |
| Trackers by category | Gecko ETP statistics | Exact | "blocked" |
| Banners rejected / hidden | Cookie banner extension (A) | Exact for actions taken | "handled" |
| Cookies deleted | App cookie/delete-data calls | Exact | "deleted" |
| Requests blocked by uBlock | Not exposed by uBO | Unavailable | omit, or "not counted" |
| Data saved | count x category average | **Estimate** | "estimated" + info sheet |
| Time saved | documented formula | **Estimate** | "estimated", off by default |
| Tor/proxy usage | absent in this fork | N/A | omit; keep nullable column |

Decision: **do not** guess uBlock's numbers. Counting only ETP is honest and matches the browser's own UI. If uBlock counts are wanted later, add a tiny `webRequest` counter extension that counts *all* requests and blocked-by-ETP ones; never claim it measures uBO.

### Data model

```sql
CREATE TABLE daily_rollup (
  day        DATE NOT NULL,
  metric     TEXT NOT NULL,     -- 'tracker_blocked','banner_rejected','cookie_deleted',...
  category   TEXT,              -- optional, e.g. tracker category
  value      INTEGER NOT NULL,
  PRIMARY KEY (day, metric, category)
) STRICT;

CREATE TABLE site_rollup (
  day        DATE NOT NULL,
  site_key   TEXT NOT NULL,     -- eTLD+1
  metric     TEXT NOT NULL,
  value      INTEGER NOT NULL,
  PRIMARY KEY (day, site_key, metric)
) STRICT;
```

Plus the shared `local_event` table. Raw events: 7 days. `daily_rollup`: 365 days. `site_rollup`: 30 days. A vacuum job runs weekly and trims to a 20 MB cap.

### Ingestion rules

- **ETP diffing:** poll `fetchTrackingStatistics()` on resume, after a page finishes loading (debounced 5 s), and at most once per 30 s. Keep the last seen `(category, day, count)` map; append the delta only. Handle counter resets (engine data cleared) by resetting the baseline, never by writing a negative value.
- **Banner events:** written by the extension through the native port (A).
- **Cookie deletions:** instrument `GeckoCookieService.removeCookie` and the delete-browsing-data paths in one wrapper so counts cannot be double-reported.
- **Day boundary:** UTC days, matching Gecko. The UI may group by local day but must say so if it differs.

### Dashboard

New screen: **Settings -> Privacy & security -> Protection report** (and a home-module card, optional).

Layout:

1. Hero: total blocked since `<date>`, 7-day sparkline.
2. Category breakdown, reusing `BlockedTrackerCategory` icons and colors (color-blind safe).
3. Banners handled, cookies deleted.
4. Top sites (local, eTLD+1 only) with counts.
5. "Estimated data saved" with an info sheet documenting the constants.
6. Actions: export JSON/CSV, clear all stats, retention selector.
7. A permanent footer: "Computed on this device. Nothing is sent anywhere." linking to the privacy policy section.

### Integration points

| File | Change | Size |
|------|--------|------|
| `lib/features/protection_stats/` | new feature: ledger, ingest, rollups, screens | new |
| `.../browser/domain/repositories/tracking_protection.dart` | expose a stream/callback for stats changes | ~30 lines |
| `.../browser/domain/providers/blocked_trackers.dart` | keep existing provider, add dashboard providers | ~40 lines |
| `privacy_security_settings.dart` | link to the new report; keep the inline summary | ~10 lines |
| `lib/core/secure_storage` or cookie service | deletion instrumentation | ~20 lines |
| `main.dart` | start the ingest/rollup service | 1 line |

### Milestones

#### D0 - Schema and ETP ingest (1 week)

- [x] Ledger + rollup tables, retention job.
- [x] ETP diffing with reset handling.
- [ ] Unit tests with synthetic `TrackingStatistics`.

**Acceptance:** totals match the existing inline summary within 1 count after a full sync; no duplicate rows after 100 resume cycles.

#### D1 - Dashboard v1 (1-2 weeks)

- [x] Report screen with hero, sparkline, categories, top sites.
- [x] Empty, loading and error states.
- [x] Settings entry + search keywords.

**Acceptance:** loads in < 300 ms with 1 year of rollups; renders correctly in high contrast and at 200% text.

#### D2 - Banner and cookie metrics (1 week, after A2)

- [ ] Ingest banner events.
- [ ] Instrument cookie deletions.
- [ ] Add those cards.

**Acceptance:** counts equal the extension's own event count for a test session; no double counting when a site is deleted via two paths.

#### D3 - Estimates, export, clear (1-2 weeks)

- [ ] Data-saved estimate with a documented constants table and an info sheet.
- [ ] Optional time-saved estimate, off by default.
- [ ] Export JSON and CSV (share sheet, no network).
- [ ] Clear all with confirmation; per-metric clear.
- [ ] Retention selector (30/90/365 days; raw 1/7/30 days).

**Acceptance:** exported JSON round-trips through the importer used in tests; clearing leaves the DB at its baseline size; the estimate is always labeled "estimated".

#### D4 - Per-site detail and insights (1 week, optional)

- [ ] Per-site drill-down (local only).
- [ ] "Most improved" / "noisiest site this week" cards, phrased neutrally.
- [ ] Weekly local summary notification (opt-in, generated on device).

**Acceptance:** notifications contain only aggregate numbers, never URLs; opt-in is off by default.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Numbers do not match Gecko's UI | Medium | High (trust) | Diff-based ingest + a reconciliation test |
| Stats DB grows unbounded | Medium | Medium | Retention + rollups + size cap + vacuum |
| Stats themselves become sensitive | Medium | Medium | eTLD+1 only, 30-day site retention, easy clear |
| Double counting across paths | Medium | Medium | Single writer, idempotency keys |
| Estimate presented as fact | Medium | High | "estimated" label, info sheet, no headline claims |

### Test plan

- Synthetic `TrackingStatistics` fixtures covering: first run, steady state, day rollover, engine reset, category renames.
- Idempotency: replay the same poll 100 times -> one row set.
- Retention: insert 400 days -> only 365 remain.
- No-network gate: a test that scans the module's imports for HTTP clients and fails on any.
- Performance: dashboard build time with 1 year of data.

---

## E. Local AI enhancements (strict opt-in)

### Why

Cat Browser already runs on-device ML for container naming: topic prediction and document embeddings, via Gecko's `EngineProcess` and `browser.experiments.ml`. Extending that to summarization, tab comparison, semantic local search and feed triage is a natural, differentiated feature - if it stays local, optional, and honest about its limits.

### Goals

1. Page summarization with citations to the source page.
2. Compare 2-5 open tabs on demand.
3. Semantic search over local history, bookmarks, feeds and open tabs.
4. Feed triage ranked by interest, explainable and reversible.
5. Strict opt-in per capability, explicit model downloads, fully offline after download.

### Non-goals

- A chat assistant.
- Cloud inference or any request containing page content.
- Automatic actions (auto-close tabs, auto-hide articles, auto-fill forms).
- Bundling models in the APK.
- Training or fine-tuning on device.

### Current state (verified)

- `enableLocalAiFeatures` gates AI in `GeckoInferenceRepository` and in the container suggestion chip (`container_chips.dart`).
- Onboarding has an explicit warning page: `features/onboarding/presentation/pages/ai_configuration.dart`.
- `GeckoMlService` (`packages/flutter_mozilla_components/lib/src/domain/services/gecko_ml.dart`) exposes:
  - `predictDocumentTopic(Set<String> titles)`
  - `generateDocumentEmbeddings(List<String> documents)`
  - `clearMlCache()`
- The engine lives in `assets/extensions/ml_engine/api/ml.js`, using `createEngine`, `EngineProcess`, `FEATURES`, `ModelHub`, `OPFS`, with two tasks: `feature-extraction` (`smart-tab-embedding`) and `text2text-generation` (`smart-tab-topic`). Backend is `onnx` (WASM) because the Android build has no native InferenceSession.
- Native side: `MLEngineFeature.kt` serializes requests with a mutex and a 130 s timeout; progress events flow to Dart as `MlProgressData`.
- Dart side: `GeckoInferenceRepository` has an engine lock, a 120 s timeout, an LRU topic cache (50) and an embedding cache (1000).
- Content extraction for summaries is available through `readability_extract` and `turndownHtml`.
- Feed data lives in `features/web_feed/` with `FeedArticle` columns `summaryHtml`, `summaryMarkdown`, `contentHtml`, `contentMarkdown`, `contentPlain`.

### Architecture

```
UI entry points
  summarize page | compare tabs | semantic search | feed "for you"
        |
        v
AiTaskQueue (priority, cancel, concurrency=1, battery/thermal gate)
        |
        v
AiRepository (cache, chunking, prompts, output sanitation)
        |
        +--> GeckoMlService (existing) --> ml_engine extension --> EngineProcess
        |         new actions: summarize, compare, embedQuery, classify
        |
        +--> ContentExtractor (readability / turndown / reader view)
        |
        +--> AiStore (Drift): cache + vector index + model registry mirror
```

### Model management

A dedicated **Settings -> AI -> Models** screen:

| Field | Example |
|-------|---------|
| Task | Summarization / Embeddings / Topic |
| Model | name + revision |
| Size | e.g. 180 MB |
| License | shown verbatim |
| Source | Mozilla model hub |
| Status | not downloaded / downloading (progress) / ready / update available |
| Actions | Download, Delete, Verify |

Rules:

- Nothing downloads until the user taps Download and accepts the size.
- Default: download only on unmetered networks; a "download now on mobile data" confirmation otherwise.
- After download, inference must work in airplane mode. This is an acceptance test, not a promise.
- Show total disk used by AI and offer "delete all models".
- Model downloads are the only network activity in this feature; the URL is static and contains no user data.

### Capability design

#### E1. Page summarization

- **Entry points:** page menu "Summarize", reader-mode toolbar button, long-press a tab -> "Summarize".
- **Input:** readability plain text, capped at 12k characters. If longer, chunk into ~2k-character windows with 10% overlap.
- **Strategy:** map-reduce. Per chunk, ask for 3 bullets; then a final pass merges bullets into 5 bullets + "key facts" + reading time.
- **Output:** bottom sheet with title, bullets, "AI-generated, may be wrong", "Open page", "Copy", "Share", "Regenerate".
- **Caching:** key = SHA-256 of (normalized text + model id + prompt version). Stored in `ai_summary`.
- **Sanitization:** strip HTML, cap output length, no links, no markdown images.

#### E2. Tab comparison

- Select 2-5 tabs (multi-select in the tab tray) -> "Compare".
- Extract readable text per tab (cap 4k chars each).
- Compute embeddings to cluster sections; then a single prompt returns a table: rows = criteria (topic, stance, key facts, freshness), columns = tabs.
- UI: horizontally scrollable table, tab titles as headers, tap a header to switch tabs.
- Guard: fewer than 2 tabs -> disabled; private/isolated containers excluded unless explicitly selected.

#### E3. Semantic local search

- Index sources (each opt-in): history, bookmarks, feeds, open tabs.
- Document = title + snippet (first 500 chars of extracted text when available; otherwise title + URL path).
- Embedding dimension depends on the model (the smart-tab embedding model is small). Store as quantized int8 with a per-vector scale to keep ~400 bytes/doc.
- Query: embed the query, cosine top-k (brute force in an isolate, using `ml_utils` nearest-neighbor helpers), then merge with keyword results using reciprocal rank fusion.
- UI: a "Related" section under the existing suggestions; never replaces exact matches.
- Maintenance: incremental on visit/bookmark/feed insert; nightly backfill with progress; delete vectors when the source row is deleted or history is cleared.
- Cap: 50k documents per source, 200k total; show index size and a "rebuild index" action.

#### E4. Feed triage

- Interest vector = mean of embeddings of articles the user saved, read to completion (if measurable), or explicitly thumbs-upped; minus thumbs-down.
- Score = 0.6 * cosine(interest, article) + 0.2 * recency + 0.2 * source affinity.
- Present as an optional "For you" sort; always keep chronological as default.
- Every ranked item has "Why this?" -> "Because you read: <title>".
- Thumbs up/down adjust the interest vector immediately; "reset interests" available.
- Never auto-mark read, never auto-hide.

### Data model

```sql
CREATE TABLE ai_model (
  task         TEXT NOT NULL,
  model_id     TEXT NOT NULL,
  revision     TEXT,
  size_bytes   INTEGER NOT NULL,
  license      TEXT,
  status       TEXT NOT NULL,     -- 'absent','downloading','ready','error'
  downloaded_at DATETIME,
  PRIMARY KEY (task, model_id)
) STRICT;

CREATE TABLE ai_summary (
  content_hash TEXT PRIMARY KEY NOT NULL,
  model_id     TEXT NOT NULL,
  prompt_ver   INTEGER NOT NULL,
  summary_json TEXT NOT NULL,
  created_at   DATETIME NOT NULL
) STRICT;

CREATE TABLE ai_vector (
  doc_kind     TEXT NOT NULL,     -- 'history','bookmark','feed','tab'
  doc_id       TEXT NOT NULL,
  model_id     TEXT NOT NULL,
  dim          INTEGER NOT NULL,
  scale        REAL NOT NULL,
  vector       BLOB NOT NULL,     -- int8 quantized
  updated_at   DATETIME NOT NULL,
  PRIMARY KEY (doc_kind, doc_id, model_id)
) STRICT;

CREATE TABLE ai_interest (
  kind         TEXT PRIMARY KEY NOT NULL,  -- 'feed','search'
  model_id     TEXT NOT NULL,
  dim          INTEGER NOT NULL,
  vector       BLOB NOT NULL,
  updated_at   DATETIME NOT NULL
) STRICT;
```

### Integration points

| File | Change | Size |
|------|------|------|
| `assets/extensions/ml_engine/api/ml.js` | new actions: `summarize`, `compareDocuments`, `embedQuery`, `classify` | ~250 lines |
| `assets/extensions/ml_engine/background.js` | route the new actions | ~40 lines |
| `pigeons/gecko.dart` | extend `GeckoMlApi` | ~20 lines |
| `.../api/GeckoMlApiImpl.kt` | implement new calls | ~120 lines |
| `lib/src/domain/services/gecko_ml.dart` | Dart methods | ~60 lines |
| `lib/features/ai/` | queue, repository, store, models screen, UI | new feature |
| `.../tabs/domain/repositories/gecko_inference.dart` | refactor to use the shared AI repository; keep behavior | ~100 lines |
| `.../tabs/presentation/widgets/container_chips.dart` | unchanged behavior, new gate | ~10 lines |
| `.../browser/features/menu/.../page_actions_section.dart` | "Summarize page" action | ~20 lines |
| `.../web_feed/presentation/` | "For you" sort + why-this sheet | ~200 lines |
| `.../search/presentation/` | "Related" semantic section | ~150 lines |
| `settings/presentation/screens/settings.dart` | AI category with per-capability toggles | ~20 lines |

### Milestones

#### E0 - Foundations and model manager (3-4 weeks)

- [ ] Generalize `GeckoInferenceRepository` into `AiRepository` without changing container-naming behavior (regression tests).
- [ ] Model registry + Models screen + download/delete/verify + disk usage.
- [x] Per-capability flags: `aiSummarize`, `aiTabCompare`, `aiSemanticSearch`, `aiFeedTriage`, all default off.
- [ ] `AiTaskQueue`: single concurrency, priority, cancellation, timeouts, retry with backoff.
- [ ] Model registry + Models screen + download/delete/verify + disk usage.
- [ ] Per-capability flags: `aiSummarize`, `aiTabCompare`, `aiSemanticSearch`, `aiFeedTriage`, all default off.
- [ ] Battery/thermal gate: skip when battery < 15% and not charging; cancel on background.

**Acceptance:** container naming still works exactly as before; models download only after explicit consent; airplane-mode inference works after download; deleting a model frees the reported bytes.

#### E1 - Summarization (2-3 weeks)

- [ ] Extraction pipeline with readability fallback to turndown.
- [ ] Chunking + map-reduce prompts + output sanitation.
- [ ] Cache + regenerate.
- [ ] UI: sheet, copy, share, disclaimer.
- [ ] Progress reporting from the ML engine to a determinate bar.

**Acceptance:** a 3,000-word article summarizes in < 15 s on a mid-range device; output has 5 bullets, no HTML, no invented URLs; repeated open uses cache (< 100 ms); cancel leaves no partial cache entry.

#### E2 - Semantic search (3-4 weeks)

- [ ] Indexer for history/bookmarks/feeds/tabs with per-source opt-in.
- [ ] int8 quantization + cosine search in an isolate.
- [ ] RRF merge with keyword suggestions.
- [ ] Index size UI + rebuild + clear.
- [ ] Backfill with progress and cancellation.

**Acceptance:** 20k documents index in < 5 minutes on a mid-range device; a query returns in < 300 ms; deleting history removes its vectors within one maintenance run; exact-match results are never displaced.

#### E3 - Tab comparison (2 weeks)

- [ ] Multi-select in the tab tray.
- [ ] Extraction cap + comparison prompt + table UI.
- [ ] Container privacy rules.
- [ ] Cite tab titles, link back.

**Acceptance:** 2-5 tabs produce a table in < 25 s; selecting a private tab requires explicit confirmation; cancel works mid-run.

#### E4 - Feed triage (3-4 weeks)

- [ ] Interest vector updates from explicit signals.
- [ ] Ranking + "For you" sort + "Why this?".
- [ ] Reset interests; explainability copy.
- [ ] Ensure chronological remains default.

**Acceptance:** ranking is stable across restarts; thumbs-down visibly changes the next ranking; no article is hidden or auto-read; the "why" always names a real source article.

#### E5 - Hardening and evaluation (2 weeks)

- [ ] Prompt-injection defenses (content delimiters, no tools, output caps).
- [ ] Evaluation set: 20 pages, human-rated faithfulness/coverage; recorded results in the repo.
- [ ] Memory ceiling and engine unload after idle.
- [ ] Localization of all AI copy and disclaimers.
- [ ] A test that asserts no network calls outside the model downloader.

**Acceptance:** no prompt from page content can trigger a network call or a UI action; peak memory < 300 MB during summarization; evaluation notes committed.

### Privacy and safety requirements

- Page content never leaves the device. The only network call is the model download, to a static URL with no user data.
- Private/isolated containers are excluded from indexing and summarization by default; each has an explicit opt-in.
- The AI history (summaries, vectors) is listed in "Clear browsing data" as its own category, and by "delete all models".
- Every AI output is labeled as AI-generated, with a "may be wrong" note and a link to the source.
- Prompts treat page text as untrusted data. System instructions explicitly ignore instructions found in content. Outputs are sanitized (no HTML, no links, length cap).
- No auto-actions: the AI can suggest, never act.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WASM inference too slow on low-end devices | High | High | Short outputs, chunk caps, model choice per RAM class, progress + cancel |
| Memory pressure / OOM | Medium | High | One engine, unload on idle, cap input, test on 3 GB device |
| Battery/thermal complaints | Medium | Medium | Battery gate, background cancel, opt-in only |
| Model license confusion | Medium | Medium | Show license verbatim before download |
| Hallucinated summaries | High | Medium | Citations, "may be wrong", no auto-actions, evaluation set |
| Prompt injection | Medium | High | Untrusted-content framing, no tools, output sanitation |
| Index size grows unbounded | Medium | Medium | int8 quantization, caps, per-source delete, size UI |
| Users think AI is cloud-based | Medium | High | Onboarding copy, airplane-mode test, "on this device" badge |

### Test plan

- Regression: existing container-naming tests must pass unchanged after the repository refactor.
- Unit: chunker, cache keys, quantize/dequantize, cosine, RRF, interest updates.
- Integration: summarize -> cache hit; index -> search -> delete source -> vector gone.
- Offline: run every capability in airplane mode after models are downloaded.
- Network gate: intercept all sockets during AI flows; fail the test on any request.
- Performance: time and memory budgets on a low-end emulator profile.

---

## Sequencing and release plan

### Dependency graph

```
F1 settings ---+--> C (a11y)
F2 data layer --+--> D (stats) ---> A (banner stats)
F3 extensions --+--> A (banner handling)
F4 ledger ------+--> D, A, E
F5 extraction --+--> B (tabs?) , E (summaries)
Login storage --+--> B4 (passwords)
```

### Proposed timeline

| Window | Initiative work | Release |
|--------|-----------------|---------|
| 2026 Q4 | F1-F4, D0-D1, C1-C2, A0 | `0.41` - protection report v1, text scaling, cosmetic banner hiding |
| 2027 Q1 | A1-A3, D2-D3, C3-C4 | `0.42` - banner rejection, high contrast, reduced motion |
| 2027 Q2 | B0-B2, C5-C6 | `0.43` - browser import (bookmarks/history/tabs), keyboard/switch access |
| 2027 Q3 | B3, E0-E1, C7 | `0.44` - extension list mapping, page summaries, TalkBack polish |
| 2027 Q4 | E2-E4, B4 (if funded) | `0.45` - semantic search, tab comparison, feed triage, passwords |
| 2028 Q1 | E5, A4, hardening | `1.0` readiness |

Dates are targets, not commitments. Every release must still pass the fork's release checklist: debug build, release build, install on a clean device, verify new defaults, publish APK, update the tag.

### Release gates per initiative

| Gate | Requirement |
|------|-------------|
| G1 | Feature flag defaults are safe; off = today's behavior |
| G2 | No new network calls, except the documented model/rule downloaders |
| G3 | Accessibility guidelines pass on new screens |
| G4 | Localization complete for English; other locales fall back cleanly |
| G5 | Data migration tested from the previous release's database |
| G6 | Upstream merge dry-run succeeds (`git merge upstream/main`) |

---

## Definition of done

A milestone is done only when all of these are true:

- [ ] Feature flag and default documented in this file.
- [ ] Settings entry exists, is searchable, and is exported/imported.
- [ ] Strings in ARB; `flutter gen-l10n` clean.
- [ ] Unit + widget + integration tests written and passing.
- [ ] Accessibility guidelines pass; tested at 200% text and in high contrast.
- [ ] No-network requirement verified where applicable.
- [ ] Performance budget met and recorded.
- [ ] Data migration from the previous schema tested.
- [ ] `git merge upstream/main` dry-run reviewed; touchpoints table updated.
- [ ] Release build produced and installed on a clean device.
- [ ] Changelog entry written; this roadmap updated.
- [ ] Privacy policy / in-app explanation updated if data is stored.

---

## Decision log

| ID | Date | Decision | Rationale | Revisit when |
|----|------|----------|-----------|--------------|
| D1 | 2026-10-30 | Cookie banner handling is an extension, not an engine setting | GeckoView 158 exposes no cookie-banner API and ships no `cookiebanners` service | GeckoView adds a supported API |
| D2 | 2026-10-30 | Never click accept-like text; reject-only phrase list | Wrong click grants consent, which is worse than doing nothing | Never |
| D3 | 2026-10-30 | Rule updates are opt-in and hash-pinned | Avoid a silent network dependency and a supply-chain surface | Never |
| D4 | 2026-10-30 | Stats count ETP only; uBlock counts are omitted | uBO exposes no stable count API; guessing breaks trust | uBO adds an API |
| D5 | 2026-10-30 | Data-saved is always labeled "estimated" | Honest measurement is a product value | A per-request size API appears |
| D6 | 2026-10-30 | Password import is gated on a new encrypted login store | No login storage exists; importing into plaintext is unacceptable | Never |
| D7 | 2026-10-30 | No models in the APK; download on demand | APK is already ~317 MB and builds take ~4 min | Never |
| D8 | 2026-10-30 | AI is per-capability opt-in, off by default | Trust and battery; container naming keeps its existing flag | Never |
| D9 | 2026-10-30 | Semantic index uses int8 vectors in Drift | 384-dim float32 is ~1.5 KB/doc; int8 is ~400 B and good enough for top-k | A vector DB extension is available and proven |

---

## Open questions

1. **Cookie rules:** do we maintain our own rule pack, or vendor a permissively licensed one (for example an EasyList-style consent list) and add reject actions on top? Licensing must be checked before shipping.
2. **Rule updates:** should the update endpoint be our GitHub raw file, or a signed static file hosted on `weblibre.eu`? The latter needs infrastructure.
3. **History import:** should imported history count toward frecency and suggestions immediately, or be marked "imported" and excluded from ranking for a grace period?
4. **Passwords:** is the encrypted login store funded? If not, B1-B3 ship without passwords and the UI says so.
5. **Accessibility:** do we target WCAG 2.2 AA for the browser chrome as a public claim, or keep it as an internal goal until an external audit?
6. **Text scale:** is a 2.0 ceiling enough, or do we need a "no cap" option that accepts broken layouts?
7. **Stats:** should site-level stats be on by default, or only aggregate counts (with site detail opt-in)?
8. **AI models:** which summarization model fits the 3 GB RAM class after quantization? This needs a benchmark before E1 is scheduled.
9. **Semantic search:** index page text (better results, more storage) or titles/snippets only (cheaper, weaker)? Start with titles/snippets, measure.
10. **Feed triage:** is "read to completion" measurable without scroll tracking? If not, use explicit signals only.

---

## Appendix: file map and references

### Where things live today

| Concern | Path |
|---------|------|
| App entry / service wiring | `apps/weblibre/lib/main.dart` |
| Settings model | `apps/weblibre/lib/features/user/data/models/general_settings.dart` |
| Engine (web content) settings | `apps/weblibre/lib/features/user/data/models/engine_settings.dart` |
| DoH providers | same file, `BuiltInDohProviders` |
| Settings categories | `apps/weblibre/lib/features/settings/presentation/screens/settings.dart` |
| Privacy settings UI | `.../settings/presentation/screens/privacy_security_settings.dart` |
| Web content settings UI | `.../settings/presentation/screens/web_content_settings.dart` |
| uBlock lists | `.../user/data/models/ublock_filter_list_settings.dart` |
| Tracker stats model | `.../geckoview/features/browser/domain/entities/blocked_trackers.dart` |
| Tracker stats provider | `.../geckoview/features/browser/domain/providers/blocked_trackers.dart` |
| Tracking protection repo | `.../geckoview/features/browser/domain/repositories/tracking_protection.dart` |
| Per-page protection sheet | `.../geckoview/features/browser/presentation/widgets/sheets/tracking_protection_section.dart` |
| Bookmark import | `.../geckoview/features/bookmarks/utils/` |
| History service | `packages/flutter_mozilla_components/lib/src/domain/services/gecko_history.dart` |
| Cookie service | `packages/flutter_mozilla_components/lib/src/domain/services/gecko_cookie.dart` |
| Add-on service | `.../lib/src/domain/services/gecko_addon.dart` + `apps/weblibre/lib/features/geckoview/features/browser/domain/services/browser_addon.dart` |
| ML service | `packages/flutter_mozilla_components/lib/src/domain/services/gecko_ml.dart` |
| ML engine extension | `packages/flutter_mozilla_components/android/src/main/assets/extensions/ml_engine/` |
| ML native feature | `.../android/src/main/kotlin/eu/weblibre/flutter_mozilla_components/feature/MLEngineFeature.kt` |
| Inference repository | `apps/weblibre/lib/features/geckoview/features/tabs/domain/repositories/gecko_inference.dart` |
| AI onboarding | `apps/weblibre/lib/features/onboarding/presentation/pages/ai_configuration.dart` |
| Content extraction | `.../assets/extensions/readability_extract/`, `.../assets/extensions/browser_extension/turndown.js` |
| Built-in extension host | `.../android/src/main/kotlin/.../feature/CookieManagerFeature.kt`, `EngineProvider.kt` |
| Local KV storage | `apps/weblibre/lib/features/user/data/database/definitions.drift` (`setting`, `riverpod`) |
| Upstream sync | `scripts/sync-upstream.ps1` |
| Release builds | `flutter build apk --release --flavor stable` (see fork notes) |

### Reference material

- GeckoView `ContentBlocking` (no cookie-banner mode in 158): inspect `classes.jar` from `geckoview-omni`.
- Mozilla Android Components `158.0.2`: `feature-addons`, `feature-readerview`, `browser-engine-gecko`.
- Firefox ML engine: `chrome://global/content/ml/EngineProcess.sys.mjs`, `ModelHub.sys.mjs`, `OPFS.sys.mjs` (used by `ml.js`).
- Places history schema: `moz_places`, `moz_historyvisits`.
- Chrome profile schema: `Bookmarks`, `History`, `Preferences`, `Login Data`.
- Mozilla session store: `sessionstore.jsonlz4` (`mozLz40\0` + LZ4 block).
- WCAG 2.2: contrast 1.4.3 / 1.4.11, target size 2.5.8, motion 2.3.3.
- Flutter accessibility testing: `meetsGuideline`, `textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`.

### Fork release notes template

```
Cat Browser <version>

New
- ...

Changed
- ...

Fixed
- ...

Privacy
- No telemetry added. All new data stays on device.
- ...

Known limitations
- ...
```

---

*End of roadmap. Update the status markers and the decision log in the same PR that changes behavior.*
