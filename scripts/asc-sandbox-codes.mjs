import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync, readFileSync, chmodSync } from 'node:fs';

let offerID = process.argv[2];
const label = process.argv[3];
if (!(offerID === 'create' || /^[a-zA-Z0-9-]+$/.test(offerID ?? '')) || !/^(plus|pro)$/.test(label ?? '')) throw Error('Expected offer ID or create and plus/pro label');
const directory = new URL('../.secrets/', import.meta.url);
mkdirSync(directory, { recursive: true, mode: 0o700 });
const file = new URL(`asc-sandbox-${label}-20260913.json`, directory);
const auth = spawnSync('asc', ['auth', 'token', '--confirm'], { encoding: 'utf8' });
if (auth.status !== 0) throw Error('ASC authentication failed');
const token = auth.stdout.trim();
if (!/^[A-Za-z0-9_.-]+$/.test(token)) throw Error('Unexpected authentication response');
function request(method, path, body) {
  const args = ['--silent', '--show-error', '--fail-with-body', '--max-time', '60', '--config', '-', '--request', method,
    `https://api.appstoreconnect.apple.com/v1/${path}`];
  if (body) args.push('--data-binary', JSON.stringify(body));
  const response = spawnSync('curl', args, { encoding: 'utf8', input: `header = "Authorization: Bearer ${token}"\nheader = "Content-Type: application/json"\n`, maxBuffer: 2 * 1024 * 1024 });
  if (response.status !== 0) {
    let detail = 'API request failed';
    try { detail = JSON.parse(response.stdout).errors?.map(e => `${e.status} ${e.code}: ${e.detail}`).join('; ') ?? detail; } catch {}
    throw Error(detail);
  }
  return response.stdout;
}
if (offerID === 'create') {
  const subscription = label === 'plus' ? '6811365720' : '6811365836';
  const name = `PUSHNOW_SANDBOX_${label.toUpperCase()}_20260913`;
  const existing = JSON.parse(request('GET', `subscriptions/${subscription}/offerCodes`)).data ?? [];
  let offer = existing.find(item => item.attributes.name === name);
  if (!offer) offer = JSON.parse(request('POST', 'subscriptionOfferCodes', {
    data: { type: 'subscriptionOfferCodes', attributes: {
      name, customerEligibilities: ['NEW', 'EXISTING', 'EXPIRED'], duration: 'ONE_MONTH',
      numberOfPeriods: 1, offerEligibility: 'REPLACE_INTRO_OFFERS', offerMode: 'FREE_TRIAL', autoRenewEnabled: false
    }, relationships: {
      subscription: { data: { type: 'subscriptions', id: subscription } },
      prices: { data: [{ type: 'subscriptionOfferCodePrices', id: '${price1}' }] }
    } }, included: [{ type: 'subscriptionOfferCodePrices', id: '${price1}', relationships: {
      territory: { data: { type: 'territories', id: 'CHN' } }
    } }]
  })).data;
  if (offer.attributes.offerMode !== 'FREE_TRIAL' || offer.attributes.autoRenewEnabled !== false || offer.attributes.duration !== 'ONE_MONTH' || offer.attributes.numberOfPeriods !== 1) throw Error('Offer terms do not match authorized sandbox validation');
  offerID = offer.id;
  console.log(JSON.stringify({ offerID, label, offerMode: offer.attributes.offerMode, autoRenewEnabled: offer.attributes.autoRenewEnabled }));
}
let batch;
if (existsSync(file)) batch = JSON.parse(readFileSync(file, 'utf8')).batch;
else {
  const result = JSON.parse(request('POST', 'subscriptionOfferCodeOneTimeUseCodes', { data: {
    type: 'subscriptionOfferCodeOneTimeUseCodes', attributes: { environment: 'SANDBOX', numberOfCodes: 10, expirationDate: '2026-10-13' },
    relationships: { offerCode: { data: { type: 'subscriptionOfferCodes', id: offerID } } }
  } }));
  batch = result.data;
  writeFileSync(file, JSON.stringify({ batch }), { mode: 0o600, flag: 'wx' });
}
const verified = JSON.parse(request('GET', `subscriptionOfferCodeOneTimeUseCodes/${batch.id}`)).data;
if (verified.attributes.environment !== 'SANDBOX' || verified.attributes.numberOfCodes !== 10) throw Error('Sandbox batch verification failed; no codes downloaded');
const codes = request('GET', `subscriptionOfferCodeOneTimeUseCodes/${batch.id}/values`);
writeFileSync(file, JSON.stringify({ batch: verified, codes }), { mode: 0o600 });
chmodSync(file, 0o600);
console.log(JSON.stringify({ offerID, label, batchID: batch.id, environment: verified.attributes.environment, count: verified.attributes.numberOfCodes, expirationDate: verified.attributes.expirationDate, saved: file.pathname }));
