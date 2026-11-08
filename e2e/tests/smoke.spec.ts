import { expect, type Page, test } from '@playwright/test';
import { BASE_URL } from '../playwright.config';

/**
 * Flutter draws on a canvas, so what a person reads is not in the page until its accessibility tree is switched on, which a click on the
 * placeholder it leaves out of sight does. The errors the page throws are kept, to say there were none.
 */
async function open(page: Page, hash = ''): Promise<string[]> {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(`${BASE_URL}/app/${hash}`);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 90_000 });
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.click());
  await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 60_000 });
  return errors;
}

/**
 * What is written in the app, found whether Flutter put it in the page as text or as the label of its element: it does the one for a button and the
 * other for a line of text, and which for which is not the test's to know
 */
const written = (page: Page, text: string | RegExp) => page.getByText(text).or(page.getByLabel(text)).first();

/**
 * A link to an item or to an event opens over the page, a sheet and a page of its own, and what is under them is out of the tree the browser reads the app by: the bar of a
 * site is not there to be waited for. The visitor only chooses to go on.
 */
async function goOn(page: Page) {
  await page.getByRole('button', { name: 'Continue as guest' }).first().click();
}

/** a visitor who has not signed in looks around as a guest */
async function asGuest(page: Page) {
  await goOn(page);
  // the bar of a site: its groups open under their name
  await expect(written(page, /^Economy$/)).toBeVisible();
}

test.describe('what a link to the site shows', () => {
  for (const path of ['/', '/app/', '/tr/privacy.html', '/privacy.html']) {
    test(`${path} has its name, what it is and a picture`, async ({ request }) => {
      const html = await (await request.get(`${BASE_URL}${path}`)).text();
      expect(html).toMatch(/<meta property="og:title" content="[^"]*Wondrous Compass[^"]*">/);
      expect(html).toMatch(/<meta property="og:description" content="[^"]+">/);
      expect(html).toMatch(/<meta property="og:image" content="https:\/\/[^"]+\.png">/);
      expect(html).toMatch(/<link rel="canonical" href="https:\/\/[^"]+">/);
      expect(html).toContain('name="twitter:card"');
    });
  }

  test('the picture is there', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/app/icons/Icon-512.png`);
    expect(response.status()).toBe(200);
    expect(response.headers()['content-type']).toContain('image/png');
  });
});

test.describe('the app in a browser', () => {
  test('a visitor is shown what the app is, and how to begin', async ({ page }) => {
    const errors = await open(page);
    await expect(page).toHaveTitle(/Wondrous Compass/);
    await expect(written(page, 'Your Guild Wars 2 companion')).toBeAttached();
    await expect(page.getByRole('button', { name: 'Get started' }).first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'Continue as guest' }).first()).toBeVisible();
    await page.screenshot({ path: 'screenshots/landing.png' });
    expect(errors).toEqual([]);
  });

  test('a guest gets the app with the bar of a site, and a page has its own address', async ({ page }) => {
    const errors = await open(page);
    await asGuest(page);
    await page.screenshot({ path: 'screenshots/guest-home.png' });

    // a page that stands alone
    await written(page, /^Daily$/).click();
    await expect(page).toHaveURL(/#\/daily$/);
    await expect(page).toHaveTitle(/ · Wondrous Compass$/);

    // a page of a group, which opens under its name
    await written(page, /^Economy$/).click();
    // the name in the app is Trading Post, and the menu may name it as a menu item
    await page.getByRole('menuitem', { name: /trading post/i }).or(written(page, /^Trading Post$/i)).first().click();
    await expect(page).toHaveURL(/#\/trading$/);
    await page.screenshot({ path: 'screenshots/trading.png' });

    // the back and forward buttons go between pages
    await page.goBack();
    await expect(page).toHaveURL(/#\/daily$/);
    await page.goForward();
    await expect(page).toHaveURL(/#\/trading$/);
    expect(errors).toEqual([]);
  });

  test('a link to a page opens it, and a refresh stays on it', async ({ page }) => {
    const errors = await open(page, '#/wiki');
    await asGuest(page);
    await expect(page).toHaveURL(/#\/wiki$/);
    await expect(page).toHaveTitle(/ · Wondrous Compass$/);
    await page.reload();
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 90_000 });
    await expect(page).toHaveURL(/#\/wiki$/);
    expect(errors).toEqual([]);
  });

  test('a link to an item keeps its address, opens the sheet of the item and can be copied from it', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    const errors = await open(page, '#/item/19721');
    await goOn(page);
    // the address is the item's, not the page behind it, while the sheet is open
    await expect(page).toHaveURL(/#\/item\/19721$/);
    // the sheet is open: it has the button that copies its address
    const copy = written(page, 'Copy link to this page');
    await expect(copy).toBeAttached({ timeout: 60_000 });
    await copy.click();
    // a copied link is the public address of the app, whichever server the test runs against
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe('https://yesanith.github.io/wc-frontend/app/#/item/19721');
    await page.reload();
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 90_000 });
    await expect(page).toHaveURL(/#\/item\/19721$/);
    expect(errors).toEqual([]);
  });

  test('a link to a public event asks a guest to sign in, and keeps its address', async ({ page }) => {
    const errors = await open(page, '#/event/3f2a9c1e-5b7d-4e8a-9c6b-0d1e2f3a4b5c');
    await goOn(page);
    await expect(page).toHaveURL(/#\/event\/3f2a9c1e-5b7d-4e8a-9c6b-0d1e2f3a4b5c$/);
    // the page of the event is open, and a guest is told what to do: not what the database refused
    await expect(written(page, /Sign in with Discord in Settings/)).toBeAttached({ timeout: 60_000 });
    await expect(page.getByText(/OpenEventFailure|went wrong/)).toHaveCount(0);
    expect(errors).toEqual([]);
  });

  test('the search finds a page and goes to it', async ({ page }) => {
    const errors = await open(page);
    await asGuest(page);
    // the bar has the search as a box when it has room for it, else as a button that opens it in a window
    const box = page.getByRole('textbox', { name: /Search items and pages/ });
    const button = page.getByRole('button', { name: /Search items and pages/ });
    await expect(box.or(button).first()).toBeVisible();
    if (!(await box.isVisible())) await button.first().click();
    const search = box.first();
    await search.click();
    await search.fill('daily');
    // the hit of the page, named with what it is under it ("Daily", "Page")
    await expect(written(page, /^Daily(\s+Page)?$/)).toBeAttached();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#\/daily$/);
    expect(errors).toEqual([]);
  });
});
