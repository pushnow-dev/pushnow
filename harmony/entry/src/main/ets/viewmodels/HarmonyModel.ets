import { tr, initializeLocalization, localizedError } from '../support/Localization';
import { secureCrypto } from '../services/SecureCrypto';
import { common } from '@kit.AbilityKit';
import { AuthSession, InboxItem, SecureDevice } from '../models/JiZhiModels';
import { authService } from '../services/AuthService';
import { deviceService } from '../services/DeviceService';
import { inboxService } from '../services/InboxService';
import { secureDeviceEnrollmentService } from '../services/SecureDeviceEnrollmentService';
import { secureArchiveService } from '../services/SecureArchiveService';
import { senderAuthorizationService, SenderAuthorization, AuthorizedSender } from '../services/SenderAuthorizationService';

@Observed
export class HarmonyModel {
  session: AuthSession = new AuthSession();
  items: InboxItem[] = [];
  devices: SecureDevice[] = [];
  senders: AuthorizedSender[] = [];
  authorization?: SenderAuthorization;
  busy: boolean = false;
  error: string = '';
  notice: string = '';
  pairingCode: string = '';
  pairingDeviceID: string = '';
  senderFingerprint: string = '';
  accountFingerprint: string = '';
  pushState: string = tr('Not checked in this session');
  private initialized: boolean = false;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    initializeLocalization(context);
    this.pushState = tr('Not checked in this session');
    if (this.initialized) return;
    await this.perform(async () => {
      await deviceService.initialize(context);
      await authService.initialize(context);
      await secureDeviceEnrollmentService.initialize(context);
      this.initialized = true;
      this.session = authService.current;
      if (this.session.verified) await this.load();
    });
  }

  async refresh(): Promise<void> { await this.perform(async () => { await this.load(); }); }

  private async load(): Promise<void> {
    this.items = [];
    this.session = authService.current;
    if (!this.session.verified) { this.clear(); return; }
    const token = await authService.requireAccessToken();
    this.session = authService.current;
    await secureDeviceEnrollmentService.enroll(this.session);
    this.devices = await deviceService.list(token);
    // Clear old cleartext before fetching. Errors remain visible, never demo content.
    this.items = [];
    const current = this.devices.find((device: SecureDevice) => device.current);
    if (current?.status !== 'active') {
      this.notice = tr('Bind this device, then approve it from a trusted device.');
      return;
    }
    if (!secureDeviceEnrollmentService.identityEstablished()) await secureDeviceEnrollmentService.acceptApproval(this.session);
    this.senders = await senderAuthorizationService.list();
    this.items = await inboxService.items(this.session);
  }

  async sendCode(email: string): Promise<void> {
    await this.perform(async () => { await authService.startEmail(email.trim()); this.notice = tr('Verification code sent'); });
  }

  async login(email: string, code: string): Promise<void> {
    await this.perform(async () => {
      this.clear();
      this.session = await authService.verifyEmail(email.trim(), code.trim());
      await secureDeviceEnrollmentService.enroll(this.session);
      await this.load();
    });
  }

  async passwordLogin(email: string, password: string): Promise<void> {
    await this.perform(async () => {
      this.clear();
      this.session = await authService.loginWithPassword(email.trim(), password);
      await secureDeviceEnrollmentService.enroll(this.session);
      await this.load();
    });
  }

  async logout(): Promise<void> {
    await this.perform(async () => {
      this.clear();
      try { await authService.logout(); }
      finally {
        secureDeviceEnrollmentService.clear();
        this.session = authService.current;
        this.clear();
      }
    });
  }

  async bind(): Promise<void> {
    await this.perform(async () => {
      const device = await secureDeviceEnrollmentService.enroll(this.session);
      this.pairingCode = await secureDeviceEnrollmentService.pairingCode(this.session);
      this.notice = device.status === 'active' ? tr('Device is active') : tr('Compare pairing codes on your trusted device before approval');
      await this.load();
    });
  }

  async accept(): Promise<void> {
    await this.perform(async () => {
      await secureDeviceEnrollmentService.acceptApproval(this.session);
      await this.load();
    });
  }

  async approve(device: SecureDevice): Promise<void> {
    await this.perform(async () => {
      if (this.pairingDeviceID !== device.id || !this.pairingCode) throw new Error(tr('Compare this device pairing code first'));
      await secureDeviceEnrollmentService.approveDevice(this.session, device);
      await this.load();
    });
  }

  async showPairing(device: SecureDevice): Promise<void> {
    await this.perform(async () => {
      this.pairingCode = '';
      this.pairingDeviceID = '';
      this.pairingCode = await secureDeviceEnrollmentService.pairingCode(this.session, device);
      this.pairingDeviceID = device.id;
    });
  }

  async grantHistory(device: SecureDevice): Promise<void> {
    await this.perform(async () => { await secureArchiveService.grant(device); this.notice = tr('Encrypted history access granted'); });
  }

  async registerPush(): Promise<void> {
    await this.perform(async () => {
      const token = await deviceService.registerSecurePush(await authService.requireAccessToken());
      if (!token) throw new Error(tr('Push token unavailable'));
      this.pushState = tr('Registered');
      await this.load();
    });
  }

  async notifications(device: SecureDevice, enabled: boolean): Promise<void> {
    await this.perform(async () => {
      await deviceService.updateNotifications(await authService.requireAccessToken(), device.id, enabled);
      await this.load();
    });
  }

  async rename(device: SecureDevice, name: string): Promise<void> {
    await this.perform(async () => {
      await deviceService.rename(await authService.requireAccessToken(), device.id, name.trim());
      await this.load();
    });
  }

  async lookup(code: string): Promise<void> {
    await this.perform(async () => {
      this.authorization = undefined;
      this.authorization = await senderAuthorizationService.lookup(code);
      this.senderFingerprint = await secureCrypto.fingerprint(this.authorization.public_key);
      this.accountFingerprint = await secureCrypto.fingerprint(secureDeviceEnrollmentService.identityPublicKey());
    });
  }

  async authorize(): Promise<void> {
    await this.perform(async () => {
      if (!this.authorization) throw new Error(tr('Look up an authorization code first'));
      await senderAuthorizationService.approve(this.authorization, true);
      this.authorization = undefined;
      this.senders = await senderAuthorizationService.list();
      this.notice = tr('Sender authorized');
    });
  }

  async revokeSender(id: string): Promise<void> {
    await this.perform(async () => {
      await senderAuthorizationService.revoke(id);
      this.senders = await senderAuthorizationService.list();
    });
  }

  async read(item: InboxItem): Promise<void> {
    await this.perform(async () => {
      await inboxService.markRead(await authService.requireAccessToken(), item.id);
      await this.load();
      this.notice = item.requiresAck ? tr('Message acknowledged') : tr('Marked as read');
    });
  }

  async remove(item: InboxItem): Promise<void> {
    await this.perform(async () => {
      await inboxService.remove(await authService.requireAccessToken(), item.id);
      await this.load();
    });
  }

  private clear(): void {
    this.items = []; this.devices = []; this.senders = [];
    this.authorization = undefined; this.senderFingerprint = ''; this.accountFingerprint = ''; this.pairingCode = ''; this.pairingDeviceID = ''; this.pushState = tr('Not checked in this session');
  }

  private async perform(action: () => Promise<void>): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.error = ''; this.notice = '';
    try { await action(); }
    catch (error) { this.error = localizedError(error as Error); }
    finally { this.busy = false; }
  }
}
