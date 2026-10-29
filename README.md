# Scriptorium

A quiet, minimalist note app for iPhone, dressed as a medieval manuscript.
One page, no clutter, in the spirit of Mononote, with a few touches of its own.

- **Scrolls**: each note is one page. Its first line is the title. Notes save as you type.
- **Illuminated initials**: the first letter of each note is drawn in blackletter inside a gilt frame, and the text flows around it.
- **Checklists**: tap ☐ to tick it off. Return continues the list; return on an empty item ends it.
- **Wax seals**: lock any note with Face ID / Touch ID (passcode as fallback). Each seal is rendered as real sealing wax (an uneven rim with drips, a pressed die with a beaded border and blackletter S, gloss and air bubbles) and is unique to its note. Breaking a seal cracks it in two. Sealed notes hide their preview, are only searchable by title, and reseal when the app goes to the background.
- **Vigil**: a dark focus mode. A candle burns down over the session (25 minutes by default). Only the paragraph you are writing is in full ink. The screen stays awake.
- **Tomes**: optional, flat collections (Musings, Quests, Ledger, or your own). No nested folders.
- **The Ashes**: burned (deleted) notes wait 30 days before they are gone for good.
- **Share as manuscript page**: renders a note as an illuminated image. Notes can also be shared as text, or the whole codex exported as Markdown.
- **The Chamber** (settings): Vellum (light), Candlelight (dark) or "By the sun" (follows the system), four rubric inks, book-hand or plain type, canonical hours (Vespers, Compline…) instead of clock time, quill sounds and haptics.

The look: parchment with grain and soft stains (generated in code, no texture files), gilded initials, frosted round buttons, a floating writing toolbar, and a lit beeswax candle for Vigil.

A clickable web prototype of the same design lives in [`prototype/scriptorium.html`](prototype/scriptorium.html).

Everything stays on the device: no account, no analytics, no network.

## Requirements

- Xcode 16 or later (the project uses Xcode 16's folder-synced project format)
- iOS 17.0 or later, iPhone

## Run it

1. Open `Scriptorium.xcodeproj` in Xcode.
2. Select the **Scriptorium** target → **Signing & Capabilities** → choose your **Team**.
   If `com.dbay13.scriptorium` is taken, change the bundle identifier.
3. Pick an iPhone simulator or your device and press **Run** (⌘R).

Any file added inside `Scriptorium/` is picked up by the project automatically.

## Project layout

```
Scriptorium/
  App/            App entry, root view, privacy cover
  Model/          Scroll (SwiftData), dates and canonical hours
  Design/         Palette, typefaces, settings environment, wax seal renderer, paper texture, ornaments
  Editor/         ManuscriptTextView (TextKit 1 editor) and the editor screen
  Features/       Scrolls (home), Welcome, Seal, Vigil, Chamber (settings) + Ashes, Share
  Services/       Seal keeper and Face ID, notices (toasts), quill sound/haptics, first-run seeding and Ashes sweep
  Resources/Fonts Cinzel, EB Garamond, UnifrakturMaguntia (SIL Open Font License, licenses included)
  Assets.xcassets App icon, accent color, launch screen
  PrivacyInfo.xcprivacy
Config/Info.plist Launch screen, encryption declaration
docs/APP_STORE.md Listing copy and submission checklist
```

## Notes for development

- The data model gives every property a default value, so iCloud sync can be switched on later:
  add the iCloud (CloudKit) and Background Modes (Remote notifications) capabilities, then pass a
  `ModelConfiguration(cloudKitDatabase: .automatic)` to the model container.
- Bundled fonts are static weights cut from the Google Fonts variable fonts and registered at launch
  (`FontRegistrar`). If a font fails to load, the app falls back to the system serif.
- The quill scratch sound is synthesized at runtime, so the app ships no audio files.

See [`docs/APP_STORE.md`](docs/APP_STORE.md) for App Store submission.
