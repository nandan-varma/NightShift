# App Store Connect — reference

Everything needed to work with this app's App Store Connect listing without re-discovering it from scratch. Written 2026-08-06 after the 5.2.5 rejection/resubmission cycle. Keep this updated whenever ASC state changes meaningfully (new build, metadata edits, rejection, domain change).

## App identity

| | |
|---|---|
| App name (ASC) | Twilight: Warm Display |
| Subtitle | Warm display on a schedule |
| Apple ID | `6796829257` |
| Bundle ID | `com.nandanvarma.NightShift` (**intentionally never renamed** — see below) |
| SKU | `nightshift-macos` |
| Team ID | `72CW7UW6RB` (Nandan Varma Pericharla) |
| Team/Issuer ID (ASC API) | `11e6aed2-036d-4d97-951f-5e0ba0fa8e15` |
| Category | Utilities |
| Pricing | Free, 175 countries |
| Age rating | 4+ (172 regions; Brazil ALL, Korea 00+, Vietnam exceptions) |
| ASC app URL | https://appstoreconnect.apple.com/apps/6796829257/appstore |
| Version page | https://appstoreconnect.apple.com/apps/6796829257/distribution/macos/version/inflight |
| TestFlight builds | https://appstoreconnect.apple.com/apps/6796829257/testflight/macos |

**Why the bundle ID still says "NightShift":** Apple's own guidance warns against changing the Bundle ID post-registration — it would break update continuity and register what is effectively a new app. Only the product/target/scheme names, in-app strings, and ASC-facing metadata were renamed to Twilight; `com.nandanvarma.NightShift` (and `.NightShiftTests` / `.NightShiftUITests`) stay as-is permanently. Don't "fix" this.

## Current metadata (as of build 1.0 (2), submitted 2026-08-06)

**Promotional Text:**
> Warm your display automatically at sunset, cool it back at sunrise — a native, offline, zero-dependency alternative to f.lux for your menu bar.

**Description:**
> Twilight warms your Mac's display color temperature automatically as the sun sets, and cools it back at sunrise — a native, lightweight alternative to f.lux that lives quietly in your menu bar.
>
> FEATURES
> - Automatic sunrise/sunset scheduling based on your location, computed fully offline with no network calls beyond a one-time address lookup
> - Smooth, eased transitions centered on sunset and sunrise, not abrupt jumps
> - Manual Day, Night, and Off modes whenever you want to override the schedule
> - Optional bedtime wind-down that gradually warms the display further as your bedtime approaches
> - Adjustable day and night color temperatures
> - Launch at login
> - Zero external dependencies — built entirely on AppKit, SwiftUI, CoreGraphics, and CoreLocation
>
> Twilight has no Dock icon, restores your display to neutral instantly when you quit or switch modes, and automatically reapplies its settings after sleep or display changes so your screen never gets stuck warm.

**Keywords:** `blue light,color temp,eye strain,warm display,flux,screen filter,sunset,menu bar`

**Support URL:** https://twilight.nandan.fyi/support
**Marketing URL:** https://twilight.nandan.fyi

**App Review Notes:**
> Twilight has no user accounts or sign-in of any kind, so "Sign-in required" has been left unchecked.
>
> The app warms the display's color temperature using CGSetDisplayTransferByFormula, a public CoreGraphics/Quartz Display Services API — no private frameworks are used. This is the same class of technique used by f.lux; Twilight does not use CoreBrightness or any private Night Shift API.
>
> Location is used only to compute local sunrise/sunset times entirely offline (NOAA solar-position formulas). The only network call in the entire app is a one-time CLGeocoder lookup when a user manually types a city or address during onboarding/settings; there is no continuous location tracking and no CLLocationManager usage.

**Screenshots:** 1 of 10 slots used (Mac, 2880×1800), showing the live renamed app's menu bar popover. 9 slots free — a good easy win if asked to "improve the listing." No app preview video yet.

**Trademark rule for all metadata edits:** never let "Night Shift" (Apple's own feature name) appear in Name, Subtitle, Promotional Text, Description, Keywords, or screenshots/previews. Comparisons to **f.lux** are fine (third-party, not Apple). This is the exact thing that got build 1 rejected under 5.2.5 — see Rejection history below.

## Website / domain

- Marketing site source: `website/` (Astro + Tailwind v4, static output).
- Vercel project: `nightshift` (`prj_V458rQWCtlnEVEqdGef49m06NzZL`, team `nandanvarmas-projects`, org `team_Gu5E9rhAOm9aCnHbK1lCf9jA`). `.vercel/project.json` in `website/` links to it.
- Deploy: `cd website && vercel --prod`. Auto-aliases to `twilight.nandan.fyi` (already configured in Vercel/DNS as of 2026-08-06).
- `nightshift.nandan.fyi` still resolves to the same deployment (old alias, not removed) but nothing in ASC references it anymore — don't reintroduce it into metadata.
- No hardcoded domain strings anywhere in `website/src` — the site itself is domain-agnostic, so a future domain change is Vercel-alias-only, no code change needed.
- `website/src/pages/index.astro` has a `#` placeholder where the Mac App Store link goes — replace with `https://apps.apple.com/app/id6796829257` once the app is actually live on the Store.

## Signing identities (local keychain, this machine)

```
security find-identity -v
```
| Identity | Used for |
|---|---|
| `Apple Development: nandanvarma@icloud.com (HW3S9CMM2W)` | Local Debug builds (automatic signing) |
| `Developer ID Application: Nandan Varma Pericharla (72CW7UW6RB)` | GitHub Releases DMG — `scripts/notarize-and-package.sh` + `scripts/ExportOptions.plist` (method `developer-id`) |
| `Apple Distribution: Nandan Varma Pericharla (72CW7UW6RB)` | **App Store Connect archive/export** — signs the `.app` |
| `3rd Party Mac Developer Installer: Nandan Varma Pericharla (72CW7UW6RB)` | **App Store Connect archive/export** — signs the `.pkg` installer |

Provisioning profile: **`NightShift App Store`** (`~/Library/MobileDevice/Provisioning Profiles/ef9271f5-bf04-4ee1-b0cf-7aa7fc1c7264.mobileprovision`), covers `com.nandanvarma.NightShift`, expires 2027-07-25. Name is stale (pre-rename) but valid — don't regenerate it just to rename it.

App Store Connect API key (for unattended uploads via `altool`):
- Key ID: `YBMFD8G6Z5` (named "peek-ci" in ASC, role: Developer)
- Issuer ID: `11e6aed2-036d-4d97-951f-5e0ba0fa8e15`
- Private key file: `~/.appstoreconnect/private_keys/AuthKey_YBMFD8G6Z5.p8` (never print/paste this file's contents anywhere)
- Manage/rotate at: https://appstoreconnect.apple.com/access/integrations/api

## Build & submit runbook

This is the exact sequence used to go from "code changes merged" to "new build waiting for review." No manual Xcode Organizer/Transporter step needed — it's fully scriptable from this repo given the credentials above are present on the machine.

```sh
cd /Users/nandan/dev/NightShift

# 1. Bump the build number (CURRENT_PROJECT_VERSION) — ASC rejects re-uploading
#    a version+build pair that's already been used. Check the current value
#    first, then bump ALL 6 occurrences (app target + both test targets,
#    Debug + Release) to keep them consistent, e.g. going from 2 to 3:
grep -n "CURRENT_PROJECT_VERSION" Twilight.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = 2;/CURRENT_PROJECT_VERSION = 3;/g' Twilight.xcodeproj/project.pbxproj

# 2. Archive with the App Store distribution identity (NOT the Developer ID
#    one baked into the Release config for GitHub releases — override on
#    the command line so scripts/notarize-and-package.sh's config is untouched).
rm -rf /tmp/TwilightAppStore
xcodebuild \
  -project Twilight.xcodeproj -scheme Twilight -configuration Release \
  -archivePath /tmp/TwilightAppStore/Twilight.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="NightShift App Store" \
  archive

# 3. Export a signed .pkg using scripts/ExportOptions-AppStore.plist
#    (method: app-store-connect; separate file from ExportOptions.plist,
#    which is the developer-id one — don't conflate them).
xcodebuild -exportArchive \
  -archivePath /tmp/TwilightAppStore/Twilight.xcarchive \
  -exportPath /tmp/TwilightAppStore/export \
  -exportOptionsPlist scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates

# 4. Sanity-check the archived .app before uploading (cheap, catches a stale
#    branding/version mistake before it costs a build-number slot):
/usr/libexec/PlistBuddy -c "Print :CFBundleName" \
  /tmp/TwilightAppStore/Twilight.xcarchive/Products/Applications/Twilight.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  /tmp/TwilightAppStore/Twilight.xcarchive/Products/Applications/Twilight.app/Contents/Info.plist

# 5. Upload via altool + the API key (no Apple ID password, no 2FA prompt).
xcrun altool --upload-app -f /tmp/TwilightAppStore/export/Twilight.pkg -t macos \
  --apiKey YBMFD8G6Z5 --apiIssuer 11e6aed2-036d-4d97-951f-5e0ba0fa8e15
```

Then in the browser (ASC has no API for this step that `altool` covers):
1. Wait for processing — check https://appstoreconnect.apple.com/apps/6796829257/testflight/macos until the new build shows **"Ready to Submit"** (took ~15 min last time, budget up to ~30).
2. Go to the version page → **Build** section → click the current build's thumbnail/link → **Delete** (this doesn't delete the build itself, just unassigns it from the version) → **Add Build** → select the new build number → **Done** → **Save**.
3. Selecting a new build automatically flips version status from `Rejected` to `Prepare for Submission` — that's the confirmation the swap worked.
4. Click **Update Review** (top right) → lands on the submission detail page → click **Resubmit to App Review**. Status becomes **Waiting for Review**.

## Rejection history

**Submission `dcdf753d-5d60-4f21-ad90-baa761d582f0`, reviewed 2026-08-06, build 1.0 (1):** Rejected under **Guideline 5.2.5 — Legal: Intellectual Property (Apple Products)**. Cause: app name/metadata used "Night Shift" in a way confusable with Apple's own Night Shift feature. Root cause was broader than just the app name field — the uploaded **screenshot itself** had "Night Shift: Scheduled" baked into the pixels (it was a pre-rename capture), and Keywords literally listed `night shift` as a search term. Fixed by: renaming everywhere in metadata, replacing the screenshot with a fresh capture of the renamed running app, and — critically — **uploading an entirely new build**, since the build attached to the version at the time of the fix still predated the app-level rename and would have shown the old branding to a reviewer regardless of what the metadata said. Build 1.0 (2), submitted same day, is the first build that actually reflects the Twilight rename end-to-end.

**Lesson for next time:** if a rejection is about anything visible in the running app (name, icon, in-app text, trademark, UI content) — not just listing copy — assume the currently-attached build is suspect too. Check its upload date against the code fix's commit date before resubmitting. Metadata-only fixes don't help if Apple re-runs an old binary.

## What "give this a review" means going forward

When asked to handle an App Store review (new rejection, or just resubmitting after fixes):
1. Read the rejection message in full (ASC → App Review → View Submission) before assuming it's the same category of issue as last time.
2. Check whether the issue is metadata-only or requires an app code change + new build.
3. If a new build is needed, follow the runbook above — it's fully scriptable, no need to open Xcode UI.
4. Re-check every metadata field against the **trademark rule** above before resubmitting, not just the field Apple flagged — the 5.2.5 rejection had three separate instances (name, keywords, screenshot) but Apple's message only explicitly named one.
5. Update this file and `ROADMAP.md` with what changed.
6. Don't click final resubmit without it being clear the user wants that — but once they say "do everything" / "submit" / equivalent, the full runbook including the final ASC resubmit click is in scope.
