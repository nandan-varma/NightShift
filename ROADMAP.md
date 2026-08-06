# Twilight — App Store Release Roadmap

Tracks everything between "code compiles" and "live on the Mac App Store." Check items off as you go. Last updated 2026-07-16.

## ✅ Done (this session)

Code changes, all committed to the working tree (not yet git-committed — review and commit when ready):

- [x] **App Sandbox enabled.** `Twilight/Twilight.entitlements` added with `com.apple.security.app-sandbox` and `com.apple.security.network.client` (needed for `CLGeocoder`'s network lookup). Wired via `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj`. Removed the unused `ENABLE_USER_SELECTED_FILES` setting (the app never opens a file picker).
- [x] **Privacy manifest added.** `Twilight/PrivacyInfo.xcprivacy` declares `UserDefaults` required-reason API usage (reason `CA92.1`) — mandatory for new App Store submissions.
- [x] **Info.plist cleanup.**
  - `NSHumanReadableCopyright` set to "© 2026 Nandan Varma" (was empty).
  - `LSApplicationCategoryType` set to `public.app-category.utilities`.
  - `ITSAppUsesNonExemptEncryption` set to `NO` (standard HTTPS only — this skips the export-compliance question on every future upload).
  - Removed `NSLocationWhenInUseUsageDescription` — the app only uses `CLGeocoder.geocodeAddressString` (one-shot forward geocoding), never `CLLocationManager`, so this permission string was unused and would have raised reviewer questions about a permission the app never actually requests.
- [x] **App icon generated.** `AppIcon.appiconset` previously had zero image files. Drew a new icon programmatically (`CoreGraphics`, day→night gradient disc on a dark squircle) and populated all 10 required sizes (16–1024px), with `Contents.json` updated to reference them.
- [x] **Shared Xcode scheme** added at `Twilight.xcodeproj/xcshareddata/xcschemes/Twilight.xcscheme` — previously only existed as a personal, unshared scheme, which would have broken CI/archiving for anyone else (or a clean checkout).
- [x] **Verified**: sandboxed build compiles clean (`xcodebuild build`) and all 35 unit tests pass under the new entitlements.
- [x] **Marketing site scaffolded** at `website/` (Astro + Tailwind v4, static output) with Home, Privacy Policy, Support, and Terms of Use pages. Builds clean, ready to deploy to Vercel.

## 🚧 Remaining — code / project

- [ ] **Test the sandboxed build for real.** Automated tests passed, but manually exercise the app with sandbox on: onboarding → location resolution → menu bar toggle → bedtime ramp → display sleep/wake reconfiguration → quit-restores-display. Sandbox can change runtime behavior tests don't cover.
- [ ] **Watch for App Review friction on `CGSetDisplayTransferByFormula`.** This is a public CoreGraphics API and needs no special entitlement, but display-gamma-adjusting apps have a history of review scrutiny. Not a fixable code issue up front — just be ready to explain the mechanism in App Review notes if asked (see below).
- [ ] Commit the working tree changes (there's a backlog of uncommitted edits beyond this session's App Store work — review with `git status`/`git diff` before committing).
- [ ] Bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` if this isn't truly "1.0" (currently 1.0 / build 1).

## ✅ Done (2026-07-31 session — see `NIGHTSHIFT.md` for full detail)

- [x] Bundle ID `com.nandanvarma.NightShift` registered for App Store distribution.
- [x] App record created in App Store Connect — listed as **"NightShift: Warm Display"** (plain "NightShift" was already taken), Apple ID `6796829257`.
- [x] App Store Connect metadata filled in: name/subtitle/description/keywords, category Utilities, Support/Privacy/Marketing URLs (`https://nightshift.nandan.fyi/...`), age rating 4+, pricing Free (175 countries).
- [x] App Privacy questionnaire answered: Coarse Location, Data Not Linked to You, used for App Functionality only, no tracking.
- [x] Export compliance auto-resolved to "no" from `ITSAppUsesNonExemptEncryption = NO`, confirmed at upload — no prompt.
- [x] One screenshot (2880×1800, menu bar popover in Auto mode) captured from a real Debug build and uploaded.
- [x] App Review notes written explaining `CGSetDisplayTransferByFormula` (public API) and the one-time geocoding/no-continuous-location behavior.
- [x] Website deployed to Vercel (`https://nightshift.nandan.fyi`, custom domain live).
- [x] Mac Installer Distribution cert created (new cert type for this account) + provisioning profile "NightShift App Store" (portal artifact name unchanged by the 2026-08-06 rename — see below).
- [x] Archived, exported (signed `.pkg`), and uploaded build 1.0 (1) — `processingState: VALID`, attached to the version.

## ✅ Done (2026-08-06 session — Guideline 5.2.5 rejection, renamed to Twilight)

Apple rejected build 1.0 (1) under **Guideline 5.2.5 – Legal – Intellectual Property**: the app name used "Night Shift" in a way that could be confused with Apple's own Night Shift feature.

- [x] Renamed the app throughout the codebase: `NightShift/` → `Twilight/`, `NightShiftTests/` → `TwilightTests/`, `NightShiftUITests/` → `TwilightUITests/`, `NightShift.xcodeproj` → `Twilight.xcodeproj`, target/scheme/product names, in-app strings (onboarding, menu bar accessibility labels, quit menu, about text), CI workflow, and `scripts/notarize-and-package.sh`.
- [x] **`PRODUCT_BUNDLE_IDENTIFIER` deliberately left unchanged** (`com.nandanvarma.NightShift` / `.NightShiftTests` / `.NightShiftUITests`) — Apple's guidance explicitly warns against changing the Bundle ID, since it would break update continuity and effectively register a new app.
- [x] App Store Connect app Name/Subtitle already read "Twilight: Warm Display" / "Warm display on a schedule" (updated in an earlier, untracked session).
- [x] App Store Connect **Promotional Text, Description, and Keywords** edited to drop the "Night Shift" term (kept the f.lux comparison, since f.lux isn't Apple's trademark). Keywords list no longer starts with `night shift`.
- [x] **Replaced the uploaded screenshot** — the old one was a pre-rename capture whose menu bar popover literally read "Night Shift: Scheduled" baked into the image, which was almost certainly the actual reviewer-visible trigger for 5.2.5, not just the wording. Built the renamed app locally, ran it, captured a fresh 2880×1800 popover screenshot showing "Twilight: Scheduled", and uploaded it in place of the old one. Saved (not resubmitted).
- [x] **Uploaded a new build (1.0, build 2) and attached it to the version.** The build attached to the version was still the pre-rename binary from Jul 31 — metadata fixes alone wouldn't have prevented a repeat 5.2.5 rejection since Apple re-reviews the running app. Bumped `CURRENT_PROJECT_VERSION` to 2, archived with the `Apple Distribution` cert + `NightShift App Store` provisioning profile (`scripts/ExportOptions-AppStore.plist`, new file — App Store method, separate from the existing `developer-id` export used for GitHub releases), exported a signed `.pkg`, and uploaded via `xcrun altool` using the `peek-ci` App Store Connect API key. Verified pre-upload that the archived `.app` has `CFBundleName=Twilight`, `CFBundleVersion=2`, correct signature. Build finished Apple's processing (~15 min) and was swapped in on the Version 1.0 page, replacing build 1. **Version status flipped from "1.0 Rejected" to "1.0 Prepare for Submission"** — confirms the rejected-build state is cleared.

## 🚧 Still remaining

- [x] **Website moved to `twilight.nandan.fyi`.** Domain already configured/aliased on Vercel; redeployed the site to production (`vercel --prod`, live and returning 200) and it auto-aliased to `twilight.nandan.fyi`. Updated App Store Connect Support URL and Marketing URL to `https://twilight.nandan.fyi/support` / `https://twilight.nandan.fyi` and saved. `nightshift.nandan.fyi` still resolves to the same deployment (old alias not removed) but is no longer referenced from ASC metadata.
- [ ] **Submit for review** — everything is staged in App Store Connect but nobody has clicked "Add for Review" yet, left as a deliberate checkpoint. Distribution → macOS App Version 1.0 → review everything → "Add for Review".
- [ ] More screenshots (up to 10) and/or an app preview video — only one screenshot uploaded so far.
- [ ] Once live, replace the `#` placeholder Mac App Store links in `website/src/pages/index.astro` with `https://apps.apple.com/app/id6796829257`.
- [ ] EU trader status (Digital Services Act) — standing non-blocking banner in ASC, same as other apps on this account.
- [ ] Respond to any App Review feedback if it comes back with questions.

## Notes for future reference

- The project uses Xcode's newer **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`) — dropping a new file into `Twilight/` is enough for it to be picked up as a build/resource input; you don't need to manually add it to `project.pbxproj` (this is how `PrivacyInfo.xcprivacy` and the entitlements file work without explicit file references).
- App icon source: `CoreGraphics` script (not checked into the repo — it was a one-off scratch script). If you want to regenerate or tweak the icon, recreate a small Swift script that draws to a `CGContext` and rasterizes to PNG at 1024×1024, then downsample with `sips -z <size> <size>` for the other 9 sizes.
