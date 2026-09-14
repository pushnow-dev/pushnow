import { describe, expect, it } from 'vitest';
import { AuthHttpError } from '../src/crypto';
import { errorResponse, jsonResponse } from '../src/http';

describe('browser-readable error responses', () => {
  it('preserves CORS for expired sessions so the browser can refresh', () => {
    const response = errorResponse(new AuthHttpError(401, 'session_expired', 'Sign in again'), 'qa', {
      'access-control-allow-origin': 'https://pushnow.dev', vary: 'Origin'
    });
    expect(response.status).toBe(401);
    expect(response.headers.get('access-control-allow-origin')).toBe('https://pushnow.dev');
    expect(response.headers.get('vary')).toBe('Origin');
  });
  it('preserves both CORS and retry guidance for suspended senders', async () => {
    const error = Object.assign(new AuthHttpError(429, 'sender_suspended', 'Paused'), {retryAfterSeconds:900});
    const response = errorResponse(error, 'qa', new Headers({'access-control-allow-origin':'https://pushnow.dev'}));
    expect(response.headers.get('retry-after')).toBe('900');
    expect(response.headers.get('access-control-allow-origin')).toBe('https://pushnow.dev');
    expect((await response.json() as {retry_after:number}).retry_after).toBe(900);
  });
  it('accepts tuple headers without losing their values', () => {
    expect(jsonResponse({}, 200, [['x-test','ok']]).headers.get('x-test')).toBe('ok');
  });
});
