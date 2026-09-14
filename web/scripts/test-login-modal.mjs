import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.TEST_BASE_URL || 'http://127.0.0.1:4326';
const browser = await chromium.launch({ headless: true });
try {
  for (const [path, width, mode] of [['/', 1440, 'code'], ['/zh-Hans/', 390, 'password'], ['/docs/', 390, 'code']]) {
    const page = await browser.newPage({ viewport: { width, height: 900 } });
    const requests = [];
    await page.route('https://api.pushnow.dev/**', async route => {
      const req = route.request(), path = new URL(req.url()).pathname;
      requests.push({ method: req.method(), path });
      const user = { id: 'login-test', email: 'login@example.com' };
      const json = path.includes('/auth/') ? { accessToken: 'test-session', user }
        : path === '/v1/me' ? { user } : path === '/v1/me/plan' ? { membership: { plan: 'free', remaining_today: 50 } }
        : path === '/v1/secure/devices' ? { devices: [] } : path === '/v2/keys' ? { keys: [] } : { logs: [] };
      await route.fulfill({ status: path.endsWith('/email/start') ? 202 : 200, json });
    });
    await page.addInitScript(() => {
      window.turnstile = {
        ready(callback) { callback(); },
        render() { return 'login-test-widget'; },
        getResponse() { return window.__loginTestTurnstileToken || ''; },
        reset() { window.__loginTestTurnstileToken = ''; }
      };
    });
    await page.goto(base + path);
    await page.locator('[data-nav-login]').click();
    const modal = page.locator('[data-login-modal]');
    await modal.waitFor();
    const box = await modal.locator('[role=dialog]').boundingBox();
    assert(Math.abs(box.x + box.width / 2 - width / 2) < 2);
    assert(Math.abs(box.y + box.height / 2 - 450) < 2);
    await modal.locator(`[data-login-mode=${mode}]`).click();
    await modal.locator('[name=email]').fill('login@example.com');
    if (mode === 'password') await modal.locator('[name=password]').fill('Not-a-real-password-42');
    else await modal.locator('[name=emailCode]').fill('123456');
    if (mode === 'code') await modal.locator('[data-login-send-code]').click();
    else await modal.locator('[data-login-submit-password]').click();
    assert.equal(requests.filter(r => r.path.includes('/auth/')).length, 0);
    await page.evaluate(() => { window.__loginTestTurnstileToken = 'test-turnstile-token'; });
    if (mode === 'code') {
      await modal.locator('[data-login-send-code]').click();
      assert(requests.some(r => r.path === '/v1/auth/email/start'));
    }
    await modal.locator(mode === 'password' ? '[name=password]' : '[name=emailCode]').press('Enter');
    await page.waitForURL(/\/dashboard\/?$/);
    await page.locator('[data-nav-account]:not([hidden])').waitFor();
    assert(!page.url().includes('?'));
    assert(requests.some(r => r.path === (mode === 'code' ? '/v1/auth/email/verify' : '/v1/auth/password/login')));
    assert.equal(await page.locator('[data-nav-login]').isVisible(), false);
    console.log(`PASS ${path} ${width}px: centered ${mode} login, Turnstile gate, Enter submission, clean URL, dashboard redirect and signed-in state`);
    await page.close();
  }
} finally { await browser.close(); }
