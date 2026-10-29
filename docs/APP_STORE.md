# App Store submission

Everything needed to list Scriptorium, plus the steps to ship it.

## Listing copy

| Field | Text | Limit |
| --- | --- | --- |
| App name | Scriptorium: Sealed Diary | 30 |
| Subtitle | A private medieval journal | 30 |
| Category | Lifestyle (secondary: Productivity) | |
| Age rating | 4+ | |
| Price | Free, with in-app purchases (see `docs/MONETIZATION.md`) | |

App names must be unique on the store. If "Scriptorium: Sealed Diary" is taken, try "Scriptorium Diary" or "Scriptorium – Sealed Journal".

**Promotional text** (170 characters, can change without review):

> A private diary sealed in wax. A page for every day, a question when it is blank, and a seal with thine own initial.

**Keywords** (100 characters, comma-separated, no spaces):

```
journal,diary,private,lock,mood,tracker,prompts,gratitude,medieval,fantasy,writing,wax,seal,quill
```

**Description:**

> Scriptorium is a private diary dressed as a medieval manuscript, and every secret in it is sealed in wax.
>
> A PAGE FOR EVERY DAY
> Open it and today's page is waiting. When it is blank, a gentle question waits with it. A gilt calendar shows the days you have kept.
>
> SEALED IN WAX
> Press a wax seal onto any page. Only Face ID, Touch ID or your passcode can break it, and it cracks in two when you do. Seal the whole diary too, so it asks for your face each time it opens.
>
> KEEP THY HUMOURS
> Mark each day sanguine, choleric, melancholic or phlegmatic: mood tracking the medieval way. See which humour ruled your month.
>
> WRITE BY CANDLELIGHT
> Begin a vigil and the page goes dark. A single candle burns down as you write, and only the paragraph you are working on stays in full ink.
>
> AND A FEW SMALL JOYS
> • Illuminated initials, gilt and blackletter, at the head of every page
> • Checklists you tick with a tap
> • Time told in the old hours: Matins, Vespers, Compline
> • An evening bell to remind you to write
> • The Ashes: burned pages wait thirty days before they are gone
> • Share a page as an illuminated manuscript image, or export everything
> • Vellum, Candlelight, or let the sun decide
>
> BECOME A PATRON
> One payment, yours forever: a seal stamped with your own initial, nine waxes, iCloud sync and widgets. Writing, sealing and the diary lock are always free.
>
> PRIVATE BY DESIGN
> No account. No tracking. No analytics. Your pages never leave your devices.

## In-app purchases

Create these in App Store Connect (all StoreKit 2):

| Product ID | Type | Price | Name |
| --- | --- | --- | --- |
| `patron` | Non-consumable | $7.99 | The Patronage |
| `signet.royal` | Non-consumable | $1.99 | The Royal House |
| `signet.garden` | Non-consumable | $0.99 | The Walled Garden |
| `signet.wayfarer` | Non-consumable | $1.99 | The Wayfarer |
| `signet.hallows` | Non-consumable | $0.99 | All Hallows' Wax (sold Oct 1 – Nov 2) |
| `candle.taper` | Consumable | $1.99 | A taper |
| `candle.beeswax` | Consumable | $4.99 | A beeswax candle |
| `candle.chandelier` | Consumable | $9.99 | A chandelier |

Every purchase screen needs a **Restore purchases** button. Physical goods (the printed book and the brass
seal) are sold outside in-app purchase, through a web checkout, which Apple allows for physical items.
Join the **App Store Small Business Program** so Apple's commission is 15% instead of 30%.

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app makes no network requests and includes no third-party SDKs.
The privacy manifest (`Scriptorium/PrivacyInfo.xcprivacy`) declares no tracking and one required-reason API
(UserDefaults, reason `CA92.1`, for the app's own settings).

## Screenshots

Required: the 6.9" iPhone set, **1320 × 2868** portrait (or 1290 × 2796). Apple scales these down for smaller iPhones.
Up to 10 screenshots; 4 to 6 is the sweet spot.

Five marketing frames to make at full size, using the prototype as the guide:

1. "A page for every day." (the Chronicle: today's question and the gilt calendar)
2. "Thine own seal." (the Patronage: an initial pressed into gold wax)
3. "Seal thy secrets." (a sealed page cracking open)
4. "Keep thy humours." (an entry marked sanguine, and the month's tally)
5. "Write by candlelight." (Vigil mode)

To capture the raw screens: run on the **iPhone 16 Pro Max** simulator, add a few good-looking pages, then
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
