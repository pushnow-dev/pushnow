import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { image } from '@kit.ImageKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { API_BASE_URL } from './AppConfig';
import { authService } from './AuthService';
import { secureCrypto } from './SecureCrypto';

export interface SecureAttachment {
  id: string; name: string; mime: string; size: number;
  key: string; nonce: string; sha256: string; read_token: string;
}

export class SecureAttachmentService {
  async bytes(attachment: SecureAttachment, user: string, source: string): Promise<Uint8Array> {
    const epoch = authService.generation;
    this.check(epoch, user);
    if (!/^[0-9a-f-]{36}$/i.test(attachment.id) || !Number.isInteger(attachment.size) ||
      attachment.size < 0 || attachment.size > 20 * 1024 * 1024 || !/^[0-9a-f]{64}$/.test(attachment.sha256)) {
      throw new Error('invalid_attachment');
    }
    const token = await authService.requireAccessToken();
    this.check(epoch, user);
    const client = http.createHttp();
    let ciphertext: Uint8Array;
    try {
      const result = await client.request(`${API_BASE_URL}/v2/attachments/${attachment.id}`, {
        method: http.RequestMethod.GET,
        header: { Authorization: `Bearer ${token}` },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        maxLimit: 20 * 1024 * 1024 + 16,
        connectTimeout: 20000, readTimeout: 60000
      });
      this.check(epoch, user);
      if (result.responseCode !== 200 || !(result.result instanceof ArrayBuffer)) throw new Error('attachment_download_failed');
      ciphertext = new Uint8Array(result.result);
    } finally { client.destroy(); }
    if (ciphertext.length !== attachment.size + 16) throw new Error('attachment_size_mismatch');
    const aad = `[2,"attachment",${JSON.stringify(user)},${JSON.stringify(source)},${JSON.stringify(attachment.id)}]`;
    const plaintext = await secureCrypto.aesOpen(secureCrypto.decode(attachment.key), secureCrypto.decode(attachment.nonce), ciphertext, aad);
    this.check(epoch, user);
    const hash = cryptoFramework.createMd('SHA256');
    await hash.update({ data: plaintext });
    const hex = Array.from((await hash.digest()).data).map((value: number) => value.toString(16).padStart(2, '0')).join('');
    if (hex !== attachment.sha256 || plaintext.length !== attachment.size) throw new Error('attachment_integrity_failed');
    this.check(epoch, user);
    return plaintext;
  }

  text(bytes: Uint8Array): string { return secureCrypto.utf8(bytes); }

  async image(bytes: Uint8Array): Promise<image.PixelMap> {
    const source = image.createImageSource(bytes.buffer as ArrayBuffer);
    try {
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0 || info.size.width * info.size.height > 40000000) {
        throw new Error('image_too_large');
      }
      return await source.createPixelMap();
    } finally { source.release(); }
  }

  async save(bytes: Uint8Array, name: string, context: common.UIAbilityContext): Promise<void> {
    const epoch = authService.generation;
    const user = authService.current.userID;
    this.check(epoch, user);
    const documentPicker = new picker.DocumentViewPicker(context);
    const safeName = name.replace(/[\\/\u0000-\u001f]/g, '_').slice(0, 160) || 'attachment';
    const options: picker.DocumentSaveOptions = { newFileNames: [safeName] };
    const uris = await documentPicker.save(options);
    this.check(epoch, user);
    if (uris.length === 0) return;
    const file = await fileIo.open(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      let offset = 0;
      while (offset < bytes.length) {
        this.check(epoch, user);
        const chunk = bytes.slice(offset);
        const written = await fileIo.write(file.fd, chunk.buffer as ArrayBuffer);
        if (written <= 0) throw new Error('attachment_save_failed');
        offset += written;
      }
    } finally { await fileIo.close(file); }
  }

  private check(epoch: number, user: string): void {
    if (epoch !== authService.generation || !authService.current.verified || user !== authService.current.userID) throw new Error('session_changed');
  }
}
export const secureAttachmentService = new SecureAttachmentService();
