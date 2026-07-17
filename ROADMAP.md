# NightShift — App Store Release Roadmap

Tracks everything between "code compiles" and "live on the Mac App Store." Check items off as you go. Last updated 2026-07-16.

## ✅ Done (this session)

Code changes, all committed to the working tree (not yet git-committed — review and commit when ready):

- [x] **App Sandbox enabled.** `NightShift/NightShift.entitlements` added with `com.apple.security.app-sandbox` and `com.apple.security.network.client` (needed for `CLGeocoder`'s network lookup). Wired via `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj`. Removed the unused `ENABLE_USER_SELECTED_FILES` setting (the app never opens a file picker).
- [x] **Privacy manifest added.** `NightShift/PrivacyInfo.xcprivacy` declares `UserDefaults` required-reason API usage (reason `CA92.1`) — mandatory for new App Store submissions.
- [x] **Info.plist cleanup.**
  - `NSHumanReadableCopyright` set to "© 2026 Nandan Varma" (was empty).
  - `LSApplicationCategoryType` set to `public.app-category.utilities`.
  - `ITSAppUsesNonExemptEncryption` set to `NO` (standard HTTPS only — this skips the export-compliance question on every future upload).
  - Removed `NSLocationWhenInUseUsageDescription` — the app only uses `CLGeocoder.geocodeAddressString` (one-shot forward geocoding), never `CLLocationManager`, so this permission string was unused and would have raised reviewer questions about a permission the app never actually requests.
- [x] **App icon generated.** `AppIcon.appiconset` previously had zero image files. Drew a new icon programmatically (`CoreGraphics`, day→night gradient disc on a dark squircle) and populated all 10 required sizes (16–1024px), with `Contents.json` updated to reference them.
- [x] **Shared Xcode scheme** added at `NightShift.xcodeproj/xcshareddata/xcschemes/NightShift.xcscheme` — previously only existed as a personal, unshared scheme, which would have broken CI/archiving for anyone else (or a clean checkout).
- [x] **Verified**: sandboxed build compiles clean (`xcodebuild build`) and all 35 unit tests pass under the new entitlements.
- [x] **Marketing site scaffolded** at `website/` (Astro + Tailwind v4, static output) with Home, Privacy Policy, Support, and Terms of Use pages. Builds clean, ready to deploy to Vercel.

## 🚧 Remaining — code / project

- [ ] **Test the sandboxed build for real.** Automated tests passed, but manually exercise the app with sandbox on: onboarding → location resolution → menu bar toggle → bedtime ramp → display sleep/wake reconfiguration → quit-restores-display. Sandbox can change runtime behavior tests don't cover.
- [ ] **Watch for App Review friction on `CGSetDisplayTransferByFormula`.** This is a public CoreGraphics API and needs no special entitlement, but display-gamma-adjusting apps have a history of review scrutiny. Not a fixable code issue up front — just be ready to explain the mechanism in App Review notes if asked (see below).
- [ ] Commit the working tree changes (there's a backlog of uncommitted edits beyond this session's App Store work — review with `git status`/`git diff` before committing).
- [ ] Bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` if this isn't truly "1.0" (currently 1.0 / build 1).

## 🚧 Remaining — Apple Developer / App Store Connect

- [ ] Confirm bundle ID `com.nandanvarma.NightShift` is registered for App Store distribution (not just development) on the [Apple Developer portal](https://developer.apple.com/account).
- [ ] Create the app record in [App Store Connect](https://appstoreconnect.apple.com).
- [ ] Fill in App Store Connect metadata:
  - [ ] App name, subtitle, description, keywords
  - [ ] Category: Utilities (matches `LSApplicationCategoryType`)
  - [ ] Support URL → `https://<your-vercel-domain>/support`
  - [ ] Privacy Policy URL → `https://<your-vercel-domain>/privacy`
  - [ ] Marketing URL (optional) → site root
  - [ ] Age rating questionnaire
  - [ ] Pricing (Free)
- [ ] Answer the App Privacy questionnaire in App Store Connect (separate from the in-binary privacy manifest) — declare that location (coarse, one-time, not linked to identity) is collected and used only for app functionality, not shared or used for tracking.
- [ ] Export compliance question — should auto-resolve to "no" thanks to `ITSAppUsesNonExemptEncryption = NO`, but confirm at upload time.
- [ ] **Screenshots** — at least one Mac screenshot set (recommended 1280×800 or 1440×900) showing the menu bar popover and/or onboarding flow. Needs a real build running on an actual Mac, not the illustrative mockup on the marketing site.
- [ ] App Review notes — briefly explain the color-temperature mechanism (`CGSetDisplayTransferByFormula`, public API, no private frameworks) since this is the app's least-common request type.

## 🚧 Remaining — website (`website/`)

- [ ] Deploy to Vercel: `cd website && npx vercel --prod` (or connect the repo in the Vercel dashboard with project root `website/`).
- [ ] Point support/privacy policy URLs in App Store Connect at the deployed domain.
- [ ] Once the App Store listing is live, replace the `#` placeholder Mac App Store links in `website/src/pages/index.astro` (two spots: hero CTA and the `#download` section) with the real listing URL.
- [ ] Optional: swap the illustrative CSS mockup on the homepage for a real screenshot once you have one.
- [ ] Optional: custom domain in Vercel instead of the default `*.vercel.app`.

## 🚧 Remaining — final submission

- [ ] Archive in Xcode (`Product → Archive`) using the now-shared `NightShift` scheme, or `xcodebuild -scheme NightShift -archivePath ... archive`.
- [ ] Validate and upload via Xcode Organizer (or `xcodebuild -exportArchive` / `altool`/`notarytool` if scripting it).
- [ ] Submit for review in App Store Connect.
- [ ] Respond to any App Review feedback — the gamma-adjustment mechanism is the most likely thing to draw a question; the "no continuous location" fact is the second most likely.

## Notes for future reference

- The project uses Xcode's newer **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`) — dropping a new file into `NightShift/` is enough for it to be picked up as a build/resource input; you don't need to manually add it to `project.pbxproj` (this is how `PrivacyInfo.xcprivacy` and the entitlements file work without explicit file references).
- App icon source: `CoreGraphics` script (not checked into the repo — it was a one-off scratch script). If you want to regenerate or tweak the icon, recreate a small Swift script that draws to a `CGContext` and rasterizes to PNG at 1024×1024, then downsample with `sips -z <size> <size>` for the other 9 sizes.
