import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

// Original two-note synthesis. No recordings, proprietary sounds, randomness or timestamps.
const output = new URL('../Resources/pushnow-chime.wav', import.meta.url);
const rate = 44100;
const duration = 1.25;
const frames = Math.round(rate * duration);
const wave = Buffer.alloc(44 + frames * 2);
wave.write('RIFF', 0);
wave.writeUInt32LE(wave.length - 8, 4);
wave.write('WAVEfmt ', 8);
wave.writeUInt32LE(16, 16);
wave.writeUInt16LE(1, 20); // Uncompressed linear PCM.
wave.writeUInt16LE(1, 22); // Mono.
wave.writeUInt32LE(rate, 24);
wave.writeUInt32LE(rate * 2, 28);
wave.writeUInt16LE(2, 32);
wave.writeUInt16LE(16, 34);
wave.write('data', 36);
wave.writeUInt32LE(frames * 2, 40);

function note(time, start, frequency) {
  const elapsed = time - start;
  if (elapsed <= 0) return 0;
  const attack = Math.min(1, elapsed / 0.012);
  const envelope = attack * Math.exp(-elapsed * 6);
  const phase = 2 * Math.PI * frequency * elapsed;
  return envelope * (Math.sin(phase) + 0.18 * Math.sin(phase * 2));
}

let peak = 0;
let squares = 0;
for (let index = 0; index < frames; index += 1) {
  const time = index / rate;
  const fade = Math.min(1, (frames - 1 - index) / (rate * 0.08));
  const amplitude = 0.34 * fade * (note(time, 0, 783.990872) + note(time, 0.19, 1046.502261));
  const sample = Math.round(amplitude * 32767);
  if (Math.abs(sample) >= 32767) throw new Error('Clipped sample');
  peak = Math.max(peak, Math.abs(sample));
  squares += sample * sample;
  wave.writeInt16LE(sample, 44 + index * 2);
}

if (duration >= 30 || peak === 0) throw new Error('Invalid alert duration or silent asset');
const argumentsList = process.argv.slice(2);
if (argumentsList.length > 1 || (argumentsList.length === 1 && argumentsList[0] !== '--check')) {
  throw new Error('Usage: node generate-notification-chime.mjs [--check]');
}
if (argumentsList[0] === '--check') {
  if (!readFileSync(output).equals(wave)) throw new Error('Asset differs from deterministic synthesis');
} else {
  writeFileSync(output, wave);
}
console.log(JSON.stringify({
  file: output.pathname, format: 'WAVE linear PCM', channels: 1, bitsPerSample: 16,
  sampleRate: rate, frames, durationSeconds: frames / rate, bytes: wave.length,
  peak, rms: Math.sqrt(squares / frames), sha256: createHash('sha256').update(wave).digest('hex')
}, null, 2));
