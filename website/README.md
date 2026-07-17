# nightshift-website

Marketing site for NightShift — landing page, Privacy Policy, Support, and Terms of Use. Built with [Astro](https://astro.build) + Tailwind CSS v4, static output, zero JS framework.

## Develop

```sh
npm install
npm run dev
```

## Build

```sh
npm run build   # outputs to dist/
npm run preview # serve the production build locally
```

## Deploy to Vercel

No config needed — Vercel auto-detects Astro's static output. From this directory:

```sh
npx vercel
npx vercel --prod
```

Or connect the repo in the Vercel dashboard and set the project root to `website/`.

## Before going live

- Replace the `#` placeholder Mac App Store links in `src/pages/index.astro` with the real App Store URL once the listing is approved.
- Update `lastUpdated` in `src/pages/privacy.astro` and `src/pages/terms.astro` if their content changes after launch.
