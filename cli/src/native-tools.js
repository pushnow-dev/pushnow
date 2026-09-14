import { execFileSync } from 'node:child_process';

let arm64 = process.arch === 'arm64';
if (process.platform === 'darwin' && !arm64) {
  try { arm64 = execFileSync('/usr/sbin/sysctl', ['-n', 'hw.optional.arm64'], { encoding: 'utf8', timeout: 5000 }).trim() === '1'; }
  catch { /* Intel or unavailable host capability probe: use the default executable. */ }
}

// A translated Node process otherwise starts Swift under Rosetta as well.
export function nativeCommand(program, args = []) {
  return process.platform === 'darwin' && arm64 ? ['/usr/bin/arch', ['-arm64', program, ...args]] : [program, args];
}
