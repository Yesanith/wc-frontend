import { defineConfig, devices } from '@playwright/test';

// the site as it is served: the pages of github, or what BASE_URL says (a build served on this computer, for one)
export const BASE_URL = process.env.BASE_URL ?? 'https://yesanith.github.io/wc-frontend';

export default defineConfig({
  testDir: './tests',
  // the app is a download of some megabytes drawn on a canvas, and a first look can be slow
  timeout: 120_000,
  expect: { timeout: 30_000 },
  retries: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    ...devices['Desktop Chrome'],
    // wide enough for the bar of a site, which begins at 1280 pixels, with the search as a box from 1700
    // (lib/widgets/site_header.dart, siteBarLayout)
    viewport: { width: 1760, height: 900 },
    locale: 'en-US',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
});
