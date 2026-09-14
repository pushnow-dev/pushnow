import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { nativeCommand } from '../src/native-tools.js';

const directory = await mkdtemp(join(tmpdir(), 'pushnow-keychain-test-'));
const test_namespace = randomUUID();
let binary;
function operation(operation, value) {
  const result = spawnSync(binary, [], { input: JSON.stringify({ operation, value, test_namespace }), encoding: 'utf8' });
  assert.equal(result.status, 0, 'Keychain helper operation must succeed');
  return operation === 'read' ? JSON.parse(result.stdout) : null;
}
try {
  binary = join(directory, 'keychain');
  const [program, args] = nativeCommand('/usr/bin/xcrun', ['swiftc', fileURLToPath(new URL('../native/keychain.swift', import.meta.url)), '-o', binary]);
  execFileSync(program, args);
  assert.equal(operation('read'), null);
  operation('write', { disposable: 'ephemeral-test-only' });
  assert.deepEqual(operation('read'), { disposable: 'ephemeral-test-only' });
  operation('write', { disposable: 'updated-test-only' });
  assert.deepEqual(operation('read'), { disposable: 'updated-test-only' });
  operation('delete'); assert.equal(operation('read'), null);
  console.log('PASS macOS Keychain helper write/update/read/delete in unique test namespace; no real CLI credentials touched');
} finally {
  if (binary) { try { operation('delete'); } catch { /* Compilation or unavailable keychain may prevent cleanup. */ } }
  await rm(directory, { recursive: true, force: true });
}
