import { common } from '@kit.AbilityKit';

let context: common.UIAbilityContext | undefined = undefined;

export function initializeLocalization(value: common.UIAbilityContext): void { context = value; }

// Stable resource identifiers keep English the development language without
// putting translated text in business logic. The system chooses the locale.
export function tr(source: string, args: string[] = []): string {
  let hash: number = 0;
  for (let index = 0; index < source.length; index++) hash = (hash * 31 + source.charCodeAt(index)) >>> 0;
  let value = source;
  try { if (context) value = context.resourceManager.getStringByNameSync(`pn_${hash.toString(16)}`); } catch { value = source; }
  args.forEach((argument: string, index: number) => { value = value.replace(`{${index}}`, argument); });
  return value;
}

export function localizedError(error: Error): string {
  switch (error.message) {
    case 'login_required': return tr('Sign in to continue.');
    case 'invalid_session':
    case 'session_changed': return tr('Your account session changed. Sign in again.');
    case 'device_approval_pending': return tr('Approve this device from a trusted device first.');
    case 'history_access_pending': return tr('History access is pending. Grant access from a trusted device.');
    case 'trusted_device_required': return tr('This action requires a trusted device.');
    case 'invalid_authorization_code': return tr('Enter a valid 8-character authorization code.');
    case 'authorization_expired': return tr('The authorization code expired. Request a new code.');
    case 'identity_changed':
    case 'archive_identity_changed':
    case 'device_approval_invalid': return tr('Encrypted data verification failed. Do not approve until you verify the device and account.');
    default: return error.message;
  }
}
