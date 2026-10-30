# Nocturnal for iPhone: App Store submission

Everything App Store Connect asks for, ready to paste. The screenshots are made by the tests below and arranged by
`appstore-screenshots.html` (1320 × 2868, the 6.9-inch size, the only one App Store Connect requires).

## App information

| Field | Value |
|---|---|
| Name | Nocturnal (if taken: Nocturnal: Lid Shut AI) |
| Subtitle | Lid shut. AI keeps working. |
| Bundle ID | tools.nocturnal.ios (widgets: tools.nocturnal.ios.widgets) |
| SKU | nocturnal-ios |
| Primary category | Utilities |
| Secondary category | Developer Tools |
| Content rights | Doesn't contain, show or access third-party content |
| Age rating | Answer None / No to every question: 4+ |
| Price | Free |
| Copyright | 2026 Alexander Bell |
| Support URL | https://nocturnal.tools/support |
| Marketing URL | https://nocturnal.tools |
| Privacy Policy URL | https://nocturnal.tools/privacy |

## Promotional text (170 max)

Close the lid. Your AI keeps working. Check on your computer, keep it awake for an hour or always, and put it to sleep from your iPhone.

## Description

Nocturnal keeps your laptop working with the lid shut while your AI agents work, then lets it sleep when the work is done. This is its iPhone app.

See your computer from anywhere: whether it's working or asleep, what your agents are doing, its battery and how long it has left.

Change it from anywhere: Off, When busy, for an hour or eight, or Always. Put it to sleep, or wake it at its next check-in.

Widgets for the Home Screen and Lock Screen show its state and battery, and the Home Screen widget switches modes without opening the app. Keep it awake for a set time and the Lock Screen and Dynamic Island count down to the end.

Pair once: open Nocturnal on your computer, choose Pair a Phone and scan the code. Every message between the phone and the computer is end-to-end encrypted. No account, no tracking, nothing collected.

Nocturnal for Mac, Windows and Linux is free and open source at nocturnal.tools. No computer yet? Tap Try the Demo.

## Keywords (100 max)

keep awake,lid closed,clamshell,laptop,mac,sleep,battery,ai agent,coding,remote,wake,widget,insomnia

No app or company names (Claude, Codex, Amphetamine and so on): Apple rejects other brands in keywords.

## What's New (version 1.0)

First release.

## App Review information

- Sign-in required: **No**
- Contact: your name, phone and email
- Notes (paste as is):

> Nocturnal for iPhone is the companion to Nocturnal, a free, open-source app for Mac, Windows and Linux (https://nocturnal.tools) that keeps a laptop awake with the lid closed while AI coding agents work. The phone pairs with a computer by scanning a QR code that Nocturnal shows on it.
>
> To review without a computer: on the first screen tap Try the Demo. A pretend computer inside the app answers every control, and nothing is sent anywhere. Everything works in the demo:
> - The band at the bottom: Off, When busy, 1/2/4/8 hours, Always (tap or drag).
> - The button at the bottom right: Sleep (with a few seconds to undo), then Wake.
> - The gear at the top right: every setting.
> - Widgets: add Nocturnal from the widget gallery (small, medium, and the Lock Screen sizes). In the demo they show the demo computer, and the medium widget's buttons change its mode.
> - Live Activity: tap 2 on the band (two hours). The Lock Screen and Dynamic Island count down to the end. Tap When busy to end it.
>
> Leave the demo with Exit Demo at the top left. No account or login exists. The camera is used only to scan the pairing code.

## App Privacy

**Data Not Collected.** Nothing is collected by the developer or anyone else:
- No analytics, ads, tracking or third-party SDKs.
- The only network traffic goes to a message relay (ntfy.sh, or one the user runs) and is end-to-end encrypted (AES-256-GCM through Apple's CryptoKit). The relay sees only sealed text and keeps it a few hours.
- The pairing key stays in the Keychain on this device and never moves to another one.
- The last status shown is kept on the phone, shared only with the app's own widgets through its app group.

Privacy manifests: `NocturnalPhone/PrivacyInfo.xcprivacy` and `NocturnalWidgets/PrivacyInfo.xcprivacy` (UserDefaults: CA92.1 for the app's own status, 1C8F.1 for the app group shared with the widgets).

## Export compliance

The app uses only the encryption built into iOS (CryptoKit: AES-GCM and SHA-256) and HTTPS, so
`ITSAppUsesNonExemptEncryption` is `NO` in the build and App Store Connect shouldn't ask. If it does ask which
algorithms the app implements, the answer is **None of the algorithms mentioned above**: it calls Apple's own
encryption and implements none itself.

## Checklist

1. In Xcode, pick your team under Signing & Capabilities for **both** targets (NocturnalPhone and NocturnalWidgetsExtension). The app IDs and the app group `group.tools.nocturnal` are registered on the developer site.
2. Product › Archive with "Any iOS Device" selected, then Distribute App › App Store Connect › Upload.
3. In App Store Connect: paste the fields above, upload the five screenshots in order, fill App Privacy (Data Not Collected), add the build, and Submit for Review.
4. Screenshots: run the UI test `testMarketingShots` (the app's screens) and the unit test `WidgetShots` (the widgets); both write to `dist/review` next to the project. Open `appstore-screenshots.html` beside those images and save each of the five at 1320 × 2868.
