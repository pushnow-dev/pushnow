import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { certificateText, suite, decode, bytes } from '../src/crypto.js';
import { prepareMessageV2 } from '../src/v2-client.js';
import { encryptAttachment, v2AAD } from '../src/v2-crypto.js';
import { fixtureV2 } from './v2-fixtures.js';
import { nativeCommand } from '../src/native-tools.js';

function compile(args) { const [program, options] = nativeCommand('/usr/bin/xcrun', args); execFileSync(program, options); }

const directory = await mkdtemp(join(tmpdir(), 'pushnow-v2-native-'));
try {
  const binary = join(directory, 'hpke');
  compile(['swiftc', fileURLToPath(new URL('./HPKEInterop.swift', import.meta.url)), '-o', binary]);
  const f = await fixtureV2();
  const message = await prepareMessageV2(f.config, f.directory, { title: 'Encrypted archive', body: 'Full \u4f60\u597d content', links: [], attachments: [] });
  for (const purpose of ['message', 'preview']) {
    const input = { privateKey: f.archiveKey.privateKey, senderPublicKey: f.sender.publicKey,
      envelope: purpose === 'message' ? message : message.preview,
      aad: Buffer.from(v2AAD(purpose, f.config, message.message_id, message.archive_id)).toString('utf8'),
      info: 'pushnow-v2', identityPublicKey: f.config.identity_public_key, certificate: f.config.archive.certificate,
      certificateText: certificateText('archive', f.config.user_id, f.config.archive.id, f.config.archive.public_key) };
    const result = spawnSync(binary, [], { input: JSON.stringify(input), encoding: 'utf8' });
    assert.equal(result.status, 0, 'Native HPKE must decrypt v2 envelope');
    const output = JSON.parse(result.stdout);
    assert.equal(JSON.parse(output.plaintext).title, 'Encrypted archive');
    const recipient = await suite.createRecipientContext({ recipientKey: await suite.kem.deserializePrivateKey(decode(f.archiveKey.privateKey)),
      senderPublicKey: await suite.kem.deserializePublicKey(decode(output.senderPublicKey)), enc: decode(output.enc), info: bytes('pushnow-v2') });
    assert.equal(Buffer.from(await recipient.open(decode(output.ciphertext), bytes(input.aad))).toString('utf8'), output.plaintext);
    assert.notEqual(spawnSync(binary, [], { input: JSON.stringify({ ...input, aad: `${input.aad}x` }), encoding: 'utf8' }).status, 0);
  }
  const attachmentBinary = join(directory, 'attachment');
  compile(['swiftc', fileURLToPath(new URL('./V2AttachmentInterop.swift', import.meta.url)), '-o', attachmentBinary]);
  const plain = Buffer.from('Private attachment \u4f60\u597d');
  const attachment = await encryptAttachment(f.config, plain, { name: 'test.txt', mime: 'text/plain' });
  const input = { ...attachment.descriptor, ciphertext: attachment.ciphertext.toString('base64'),
    aad: JSON.stringify([2, 'attachment', f.config.user_id, f.config.source_id, attachment.descriptor.id]) };
  const result = spawnSync(attachmentBinary, [], { input: JSON.stringify(input) });
  assert.equal(result.status, 0); assert.deepEqual(result.stdout, plain);
  assert.notEqual(spawnSync(attachmentBinary, [], { input: JSON.stringify({ ...input, aad: 'tampered' }) }).status, 0);
  console.log('PASS v2 message/preview Node <-> CryptoKit, archive certificate, AES-GCM attachment, metadata tamper rejection');
  const nativeBinary = join(directory, 'production-v2');
  const root = fileURLToPath(new URL('../../', import.meta.url));
  compile(['swiftc', fileURLToPath(new URL('./NativeV2Validation.swift', import.meta.url)),
    ...['SecureCrypto.swift', 'SecureModels.swift', 'SecureV2Crypto.swift', 'SecureV2Models.swift'].map(name => join(root, 'JiZhi/Services/Encryption', name)),
    join(root, 'JiZhi/Services/Networking/APIJSONCoding.swift'), '-o', nativeBinary]);
  const nativeInput = { message: { ...message, user_id: f.config.user_id, source_id: f.config.source_id,
    source_public_key: f.sender.publicKey, source_certificate: f.directory.source_certificate },
    local: { user_id: f.config.user_id, device_id: f.devices[0].id, private_key: f.privateKeys[0], identity_public_key: f.config.identity_public_key },
    archive: { archive: f.config.archive, private_key: f.archiveKey.privateKey },
    attachment: attachment.descriptor, ciphertext: attachment.ciphertext.toString('base64'), expected_attachment: plain.toString('base64') };
  const nativeResult = spawnSync(nativeBinary, [], { input: JSON.stringify(nativeInput), encoding: 'utf8' });
  assert.equal(nativeResult.status, 0, 'Production Swift v2 validation must pass');
  console.log(nativeResult.stdout.trim());
} finally { await rm(directory, { recursive: true, force: true }); }
