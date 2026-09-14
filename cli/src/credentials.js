import { spawn } from 'node:child_process';
import { mkdir, open, rename, unlink, chmod } from 'node:fs/promises';
import { constants } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { nativeCommand } from './native-tools.js';

function run(program, args, input) {
  return new Promise((resolve, reject) => {
    const [nativeProgram, nativeArgs] = nativeCommand(program, args);
    const child = spawn(nativeProgram, nativeArgs, { stdio: ['pipe', 'pipe', 'pipe'] });
    let output = ''; child.stdout.on('data', chunk => { output += chunk; });
    child.stderr.resume();
    child.on('error', () => reject(new Error('Credential helper unavailable')));
    child.on('close', code => code === 0 ? resolve(output) : reject(new Error('Credential helper failed; unlock your login keychain and retry')));
    child.stdin.on('error', () => {}); child.stdin.end(input);
  });
}

async function keychain(operation, value) {
  const source = fileURLToPath(new URL('../native/keychain.swift', import.meta.url));
  const hash = createHash('sha256').update(await readFile(source)).digest('hex').slice(0, 16);
  const directory = join(homedir(), 'Library', 'Caches', 'dev.pushnow.cli');
  await mkdir(directory, { recursive: true, mode: 0o700 }); await chmod(directory, 0o700);
  const binary = join(directory, `keychain-${hash}`);
  try { const file = await open(binary, constants.O_RDONLY | constants.O_NOFOLLOW); await file.close(); }
  catch (error) {
    if (error.code !== 'ENOENT') throw new Error('Credential helper path is unsafe');
    const temporary = `${binary}-${randomUUID()}`;
    await run('/usr/bin/xcrun', ['swiftc', source, '-o', temporary], '');
    await chmod(temporary, 0o700); await rename(temporary, binary);
  }
  const output = await run(binary, [], JSON.stringify({ operation, ...(value === undefined ? {} : { value }) }));
  return operation === 'read' ? JSON.parse(output) : undefined;
}

export function credentialStore({ platform = process.platform, directory = join(homedir(), '.config', 'pushnow') } = {}) {
  const path = join(directory, 'credentials.json');
  async function privateDirectory() { await mkdir(directory, { recursive: true, mode: 0o700 }); await chmod(directory, 0o700); }
  return {
    async read() {
      if (platform === 'darwin') return keychain('read');
      let file;
      try { file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW); }
      catch (error) { if (error.code === 'ENOENT') return null; throw new Error('Cannot read credential store'); }
      try {
        const info = await file.stat();
        if (!info.isFile() || (info.mode & 0o077)) throw new Error('Credential file must have permissions 600');
        return JSON.parse(await file.readFile('utf8'));
      } finally { await file.close(); }
    },
    async write(value) {
      if (platform === 'darwin') return keychain('write', value);
      await privateDirectory();
      const temporary = `${path}.${randomUUID()}`;
      const file = await open(temporary, 'wx', 0o600);
      try { await file.writeFile(JSON.stringify(value)); } finally { await file.close(); }
      await rename(temporary, path);
    },
    async delete() {
      if (platform === 'darwin') return keychain('delete');
      try { await unlink(path); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    },
  };
}
