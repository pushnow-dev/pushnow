import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { certificateText, decryptForTest, messageAAD } from '../src/crypto.js';
import { prepareMessage } from '../src/client.js';
import { fixture } from './fixtures.js';
import { nativeCommand } from '../src/native-tools.js';

function compile(args) { const [program, options] = nativeCommand('/usr/bin/xcrun', args); execFileSync(program, options); }

const temp = await mkdtemp(join(tmpdir(), 'pushnow-hpke-'));
try {
  const binary = join(temp, 'interop');
  compile(['swiftc', fileURLToPath(new URL('./HPKEInterop.swift', import.meta.url)), '-o', binary]);
  const f = await fixture();
  const plaintext = { title: 'Cross-language test', body: 'Confidential: \u4f60\u597d \ud83d\udd12' };
  const message = await prepareMessage(f.config, f.devices, plaintext);
  for (let i = 0; i < 2; i++) {
    const metadata = { user_id: f.config.user_id, source_id: f.config.source_id, device_id: f.devices[i].id,
      message_id: message.message_id, expires_at: message.expires_at };
    const input = {
      privateKey: f.privateKeys[i], senderPublicKey: f.sender.publicKey, envelope: message.envelopes[i],
      aad: Buffer.from(messageAAD(metadata)).toString('utf8'), identityPublicKey: f.config.identity_public_key,
      certificate: f.devices[i].certificate,
      certificateText: certificateText('device', f.config.user_id, f.devices[i].id, f.devices[i].public_key),
    };
    const result = spawnSync(binary, [], { input: JSON.stringify(input), encoding: 'utf8' });
    assert.equal(result.status, 0, 'Swift must verify certificate and decrypt Node ciphertext');
    const output = JSON.parse(result.stdout);
    assert.deepEqual(JSON.parse(output.plaintext), plaintext);
    assert.deepEqual(await decryptForTest(f.privateKeys[i], output.senderPublicKey, output, metadata), plaintext);
    const tampered = spawnSync(binary, [], { input: JSON.stringify({ ...input, aad: input.aad + 'tamper' }), encoding: 'utf8' });
    assert.notEqual(tampered.status, 0, 'Swift must reject modified authenticated metadata');
  }
  console.log('PASS: two-device Node -> CryptoKit and CryptoKit -> Node Auth HPKE, ECDSA certificates, tamper rejection');
  const native = join(temp, 'native-validation');
  const rootPath = fileURLToPath(new URL('../../', import.meta.url));
  compile(['swiftc', fileURLToPath(new URL('./NativeValidation.swift', import.meta.url)),
    join(rootPath, 'JiZhi/Services/Encryption/SecureCrypto.swift'),
    join(rootPath, 'JiZhi/Services/Encryption/SecureModels.swift'),
    join(rootPath, 'JiZhi/Services/Encryption/SecureV2Models.swift'), '-o', native]);
  const nativeInput = {
    messages: message.envelopes.map((envelope) => ({ ...envelope, user_id: f.config.user_id,
      source_id: f.config.source_id, message_id: message.message_id, expires_at: message.expires_at,
      source_public_key: f.sender.publicKey, source_certificate: f.directory.source_certificate,
      created_at: new Date().toISOString() })),
    keys: f.devices.map((device, i) => ({ user_id: f.config.user_id, device_id: device.id,
      private_key: f.privateKeys[i], identity_public_key: f.config.identity_public_key,
      identity_private_key: f.identityPrivateKey })),
    devices: f.devices.map((device) => ({ ...device, last_seen_at: new Date().toISOString(), created_at: new Date().toISOString() })),
    expected: plaintext,
  };
  const nativeResult = spawnSync(native, [], { input: JSON.stringify(nativeInput), encoding: 'utf8' });
  assert.equal(nativeResult.status, 0, `Production Swift validation failed: ${nativeResult.stderr.slice(0, 400)}`);
  console.log(nativeResult.stdout.trim());
} finally {
  await rm(temp, { recursive: true, force: true });
}
