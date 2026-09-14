import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ headless: true });
const base = process.env.TEST_BASE_URL || 'http://127.0.0.1:4325';
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let refreshes = 0, logouts = 0, failPlan = false;
  const user = { id: 'session-user', email: 'session@example.com' };
  await page.addInitScript(() => {
    if (!sessionStorage.getItem('pushnow.web.session')) sessionStorage.setItem('pushnow.web.session', JSON.stringify({ accessToken: 'expired-test', refreshToken: 'refresh-test' }));
  });
  await page.route('https://api.pushnow.dev/**', async route => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path === '/v1/auth/refresh') {
      refreshes++;
      assert.equal(req.postDataJSON().refreshToken, 'refresh-test');
      return route.fulfill({ json: { accessToken: 'new-test', refreshToken: 'rotated-test', user } });
    }
    if (path === '/v1/auth/logout') {
      logouts++; assert.equal(req.postDataJSON().refreshToken, 'rotated-test');
      return route.fulfill({ status: 204 });
    }
    if (req.headers().authorization === 'Bearer expired-test') {
      await new Promise(resolve => setTimeout(resolve, path === '/v1/me' ? 10 : 150));
      return route.fulfill({ status: 401, json: { code: 'session_expired' } });
    }
    if (path === '/v1/me/plan' && failPlan) return route.fulfill({ status: 503, json: { code: 'temporarily_unavailable' } });
    const data = path === '/v1/me' ? { user } : path === '/v1/me/plan' ? { membership: { plan: 'free', used_today: 0, remaining_today: 50 } }
      : path === '/v1/secure/devices' ? { devices: [] } : path === '/v2/keys' ? { keys: [] } : { logs: [], next_cursor: null };
    await route.fulfill({ json: data });
  });
  await page.goto(`${base}/dashboard/`);
  await page.locator('[data-user-email]').filter({ hasText: user.email }).waitFor();
  await page.locator('[data-nav-account]:not([hidden])').waitFor();
  assert.equal(refreshes, 1, 'late 401 responses must not rotate the session again');
  assert.equal(await page.locator('[data-nav-login]').isVisible(), false);
  failPlan = true;
  await page.locator('[data-refresh]').click();
  await page.locator('[data-dashboard-message]').filter({ hasText: 'temporarily_unavailable' }).waitFor();
  assert.equal(await page.evaluate(() => !!sessionStorage.getItem('pushnow.web.session')), true, '503 must not log the user out');
  assert.equal(await page.locator('[data-nav-account]').isVisible(), true);
  await page.locator('[data-sign-out]').click();
  await page.locator('[data-nav-login]:not([hidden])').waitFor();
  assert.equal(logouts, 1);
  assert.equal(await page.evaluate(() => sessionStorage.getItem('pushnow.web.session')), null);
  assert.equal(await page.locator('[data-user-email]').textContent(), '--');
  console.log('PASS session refresh coalescing, signed-in navigation, transient errors, remote logout and cleanup');
  await page.close();
} finally { await browser.close(); }
