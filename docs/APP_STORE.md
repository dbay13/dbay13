# App Store submission

Everything needed to list Scriptorium, plus the steps to ship it.

## Listing copy

| Field | Text | Limit |
| --- | --- | --- |
| App name | Scriptorium: Quiet Notes | 30 |
| Subtitle | A quiet medieval notebook | 30 |
| Category | Productivity (secondary: Lifestyle) | |
| Age rating | 4+ | |
| Price | Your choice. Free with a one-time "Patron" unlock would suit it later. | |

App names must be unique on the store. If "Scriptorium: Quiet Notes" is taken, try "Scriptorium Notes" or "Scriptorium – Writing Desk".

**Promotional text** (170 characters, can change without review):

> Write as the scribes did. One quiet page, illuminated initials, wax-sealed secrets and a candle that burns while you focus.

**Keywords** (100 characters, comma-separated, no spaces):

```
notes,notepad,journal,medieval,fantasy,minimalist,writing,diary,private,lock,focus,checklist,quill
```

**Description:**

> Scriptorium is a quiet chamber for your thoughts: a minimalist notebook dressed as a medieval manuscript.
>
> ONE PAGE, NO CLUTTER
> Open it and write. The first line becomes the title, and every word is kept as you type. No folders to tend, no formatting to fight.
>
> ILLUMINATED
> Each scroll opens with a blackletter initial set in a gilt frame, with your words flowing around it, as in a monastery manuscript.
>
> SEAL WHAT IS PRIVATE
> Press a wax seal onto any scroll. Only Face ID, Touch ID or your passcode can break it. Sealed scrolls hide their contents everywhere in the app.
>
> WRITE BY CANDLELIGHT
> Begin a Vigil and the page goes dark. A single candle burns down as you write, and only the paragraph you are working on stays in full ink.
>
> AND A FEW SMALL JOYS
> • Checklists you tick with a tap
> • Tomes to gather scrolls of a kind
> • The Ashes: burned scrolls wait thirty days before they are gone
> • Share any scroll as an illuminated manuscript page
> • Vellum, Candlelight, or let the sun decide
> • Four rubric inks: Vermilion, Lapis, Verdigris and Tyrian
> • Time told in the old hours: Matins, Vespers, Compline
> • Optional quill scratch sounds and haptics
> • Export everything as Markdown
>
> PRIVATE BY DESIGN
> No account. No tracking. No analytics. Your scrolls never leave your iPhone.

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app makes no network requests and includes no third-party SDKs.
The privacy manifest (`Scriptorium/PrivacyInfo.xcprivacy`) declares no tracking and one required-reason API
(UserDefaults, reason `CA92.1`, for the app's own settings).

## Screenshots

Required: the 6.9" iPhone set, **1320 × 2868** portrait (or 1290 × 2796). Apple scales these down for smaller iPhones.
Up to 10 screenshots; 4 to 6 is the sweet spot.

The design canvas has four marketing frames to recreate at full size:

1. "Write as the scribes did." (editor with illuminated initial)
2. "Write by candlelight." (Vigil mode)
3. "Seal thy secrets." (sealed scroll)
4. "Every scroll, one codex." (home list)

To capture the raw screens: run on the **iPhone 16 Pro Max** simulator, add a few good-looking scrolls, then
press ⌘S in the Simulator. Place those captures in the marketing frames.

## Submission checklist

- [ ] Apple Developer Program membership active
- [ ] In Xcode: set **Team**, confirm bundle ID (`com.dbay13.scriptorium` or your own)
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for each upload
- [ ] Run on a real iPhone: Face ID seal and unseal, Vigil timer, checklist taps, share image, Markdown export
- [ ] Test with Dynamic Type at the largest size and with VoiceOver on the home list
- [ ] Test light, dark and "By the sun", and all four inks
- [ ] App Store Connect → new app, same bundle ID, SKU e.g. `scriptorium-ios`
- [ ] Fill in listing copy, keywords, category, age rating (4+)
- [ ] Support URL and Privacy Policy URL (a short page stating "no data is collected" is enough)
- [ ] Upload screenshots (6.9")
- [ ] Xcode → Product → Archive → Distribute App → App Store Connect
- [ ] Export compliance is already answered in `Config/Info.plist` (`ITSAppUsesNonExemptEncryption = NO`)
- [ ] Review notes: "No login required. To try seals, open any scroll, tap the lock icon, then go back and reopen it."
- [ ] Submit for review

## Ideas for version 1.1

- Home Screen and Lock Screen widgets ("Scroll of the day", quick new scroll)
- iCloud sync (the model is already CloudKit-ready; see README)
- iPad layout with a two-column codex
- Shortcuts / App Intents: "Add to my Ledger"
- Alternate app icons (Candlelight, Lapis)
