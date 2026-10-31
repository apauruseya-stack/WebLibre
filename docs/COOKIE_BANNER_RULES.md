# Contributing cookie banner rules

Rules are data, not code. A contribution is a JSON object appended to
`packages/flutter_mozilla_components/android/src/main/assets/extensions/cookie_banner/rules.json`.

## Schema

```json
{
  "id": "my-cmp",
  "domains": ["*"],
  "detectors": [
    { "type": "css", "selector": "#my-banner" }
  ],
  "reject": [
    { "type": "click", "selector": "#my-reject-button" },
    { "type": "text" }
  ],
  "hide": ["#my-banner"],
  "allowHideRoot": true,
  "confidence": 0.9
}
```

## Hard rules

- The reject phrase list in `textPhrases` contains only reject-like phrases.
  `OK`, `Continue`, `Got it`, `Agree`, `Accept` are never clicked.
- Prefer the CMP's own API (`tcfapi`, `gpp`) over DOM clicks when possible.
- Never add a selector that could match an accept button.
- `allowHideRoot` must be `true` only when hiding the detected root is safe
  (no scroll lock that cannot be restored).
- Test on at least 5 sites before submitting.

## Validation

Run the fuzz test: `flutter test test/features/cookie_banners/`. The parser
must accept the new rule and the text matcher must never click an accept-like
phrase.
