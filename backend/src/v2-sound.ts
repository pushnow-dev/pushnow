import { fail } from './secure-validation';

export type NotificationSound = 'default' | 'silent' | 'chime';

export function notificationSound(value: unknown): NotificationSound | undefined {
 if (value === undefined) return undefined;
 if (value === 'default' || value === 'silent' || value === 'chime') return value;
 return fail(400, 'invalid_sound');
}

export function apnsSound(sound?: NotificationSound | null): {sound?: string} {
 if (sound === 'silent') return {};
 return {sound: sound === 'chime' ? 'pushnow-chime.wav' : 'default'};
}
