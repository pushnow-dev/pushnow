import { describe, expect, it } from 'vitest';
import { corsHeaders } from '../src/http';

const env = {CORS_ORIGINS:'https://pushnow.dev,http://127.0.0.1:4325'} as unknown as Env;
const headers = (origin: string, requested: string) => new Headers(corsHeaders(new Request('https://api.pushnow.dev/v2/messages', {
 method:'OPTIONS', headers:{origin,'access-control-request-headers':requested},
}), env));

describe('dashboard extra request header CORS', () => {
 it('allows bounded X- header names only for configured origins', () => {
  const result = headers('https://pushnow.dev','Authorization,Content-Type,X-Workflow-Run,X-Trace-ID');
  expect(result.get('access-control-allow-origin')).toBe('https://pushnow.dev');
  expect(result.get('access-control-allow-headers')).toContain('x-workflow-run');
  expect(result.get('access-control-allow-headers')).toContain('x-trace-id');
  expect(result.get('vary')).toContain('Access-Control-Request-Headers');
 });
 it('does not reflect an untrusted origin or its custom headers', () => {
  const result = headers('https://untrusted.invalid','x-custom');
  expect(result.get('access-control-allow-origin')).not.toBe('https://untrusted.invalid');
  expect(result.get('access-control-allow-headers')).not.toContain('x-custom');
 });
 it('retains required auth headers but rejects unknown standard headers and malformed custom names', () => {
  const result = headers('https://pushnow.dev','cookie,host,x-bad_name,x-good');
  const allowed = result.get('access-control-allow-headers')!.split(',');
  expect(allowed).toContain('authorization');
  expect(allowed).toContain('x-good');
  for (const name of ['cookie','host','x-bad_name']) expect(allowed).not.toContain(name);
 });
 it('rejects an over-limit custom header set without broadening defaults', () => {
  const result = headers('https://pushnow.dev',Array.from({length:11},(_,i)=>`x-test-${i}`).join(','));
  expect(result.get('access-control-allow-headers')).not.toContain('x-test-');
 });
});
