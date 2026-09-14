import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ headless: true });
try {
  for (const [locale, width] of [['zh-Hans/', 390], ['', 1440]]) {
    const page = await browser.newPage({ viewport: { width, height: 900 } });
    const calls = [];
    const key = { id: 'key-1', source_id: 'sender-1', source_name: 'Build server', key_prefix: 'pn_test', created_at: new Date().toISOString(), expires_at: null, last_used_at: null, revoked_at: null };
    await page.addInitScript(() => sessionStorage.setItem('pushnow.web.session', JSON.stringify({ access_token: 'test-only' })));
    await page.route('https://api.pushnow.dev/**', async route => {
      const req = route.request(), url = new URL(req.url()); calls.push([req.method(), url.pathname, url.search, req.postData()]);
      let data = {};
      if (url.pathname === '/v1/me') data = { user: { email: 'test@example.com', id: 'test-user' } };
      if (url.pathname === '/v1/me/plan') data = { membership: { plan: 'free' } };
      if (url.pathname === '/v1/secure/devices') data = { devices: [] };
      if (url.pathname === '/v2/keys') data = { keys: [key] };
      if (url.pathname === '/v1/sources/sender-1/keys') data = { source_key: 'new-secret-once', key };
      if (url.pathname === '/v2/logs') data = { logs: [{ message_id: 'message-1', source_id: 'sender-1', source_name: 'Build server', key_id: 'key-1', created_at: new Date().toISOString(), deliveries: [{ device_id: 'device-1', device_name: 'iPhone', status: 'accepted', attempts: 1, accepted_at: new Date().toISOString() }] }], next_cursor: url.searchParams.has('cursor') ? null : 'page2' };
      await route.fulfill({ json: data });
    });
    await page.goto(`${process.env.TEST_BASE_URL || 'http://127.0.0.1:4325'}/${locale}dashboard/`);
    const root = page.locator('[data-keys-logs]');
    await root.locator('[data-key-list] .entry').waitFor();
    await root.locator('[data-add-key] button').click();
    await root.locator('[data-secret-panel]:not([hidden])').waitFor();
    assert.equal(await root.locator('[data-secret]').textContent(), 'new-secret-once');
    assert.equal(await page.evaluate(() => JSON.stringify(sessionStorage).includes('new-secret-once')), false);
    await root.locator('[data-dismiss]').click();
    assert.equal(await root.locator('[data-secret]').textContent(), '');
    await root.locator('[data-key-list] input').fill('2099-01-01T12:00');
    await root.locator('[data-key-list] button').nth(0).click();
    await page.waitForFunction(() => document.querySelector('[data-key-message]').textContent === '');
    assert(calls.some(c => c[0] === 'PATCH' && JSON.parse(c[3]).expires_at));
    page.once('dialog', d => d.dismiss());
    await root.locator('[data-key-list] button').nth(2).click();
    assert(!calls.some(c => c[0] === 'DELETE'));
    page.once('dialog', d => d.accept());
    await root.locator('[data-key-list] button').nth(2).click();
    await page.waitForTimeout(150);
    assert(calls.some(c => c[0] === 'DELETE'));
    await root.locator('[data-log-filter]').selectOption('key-1');
    await page.waitForTimeout(150);
    await root.locator('[data-more]').click();
    await page.waitForTimeout(150);
    assert(calls.some(c => c[2].includes('key_id=key-1') && c[2].includes('cursor=page2')));
    assert((await root.locator('[data-log-list]').textContent()).includes(locale ? '服务商已接受' : 'Provider accepted'));
    await root.scrollIntoViewIfNeeded();
    assert(await root.evaluate(e => e.scrollWidth <= e.clientWidth + 1));
    await page.screenshot({ path: `/tmp/pushnow-keys-${width}.png`, fullPage: true });
    await page.locator('[data-sign-out]').click();
    await page.locator('[data-dashboard][hidden]').waitFor({ state: 'attached' });
    assert.equal(await root.locator('[data-key-list]').textContent(), '');
    console.log(`${locale || 'en'} ${width}px: create, expiry, revoke confirm, filter, pagination, secret cleanup passed`);
    await page.close();
  }
} finally { await browser.close(); }
