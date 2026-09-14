import type { ChallengeType } from "./contracts";

export interface AuthMailer {
  sendVerificationEmail(input: VerificationEmailInput): Promise<string>;
}

export type VerificationEmailInput = {
  email: string;
  code: string;
  challengeType: ChallengeType;
  appBaseURL: string;
  from: string;
  locale: string;
};

export class CloudflareAuthMailer implements AuthMailer {
  constructor(private readonly binding: SendEmail) {}

  async sendVerificationEmail(input: VerificationEmailInput): Promise<string> {
    const title = input.challengeType === "email_change" ? "Verify your new JiZhi email" : "Sign in to JiZhi";
    const actionText = input.challengeType === "email_change" ? "verify your new email" : "sign in";
    const link = `${input.appBaseURL}/auth/verify?email=${encodeURIComponent(input.email)}&code=${encodeURIComponent(input.code)}`;
    const result = await this.binding.send({
      to: input.email,
      from: input.from,
      subject: title,
      text: `Use code ${input.code} to ${actionText}. This code expires soon.\n\n${link}`,
      html: renderEmail(title, actionText, input.code, link)
    });
    return result.messageId;
  }
}

function renderEmail(title: string, actionText: string, code: string, link: string): string {
  return `<!doctype html>
<html>
  <body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#111827;background:#f9fafb;padding:24px;">
    <main style="max-width:520px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:14px;padding:28px;">
      <p style="margin:0 0 8px;color:#6b7280;font-size:13px;">JiZhi</p>
      <h1 style="margin:0 0 16px;font-size:22px;line-height:1.25;">${escapeHtml(title)}</h1>
      <p style="margin:0 0 18px;color:#374151;">Use this code to ${escapeHtml(actionText)}:</p>
      <p style="letter-spacing:6px;font-size:30px;font-weight:700;margin:0 0 20px;">${escapeHtml(code)}</p>
      <p style="margin:0 0 20px;color:#6b7280;">The code expires in 10 minutes. If this was not you, you can ignore this email.</p>
      <a href="${escapeHtml(link)}" style="display:inline-block;background:#111827;color:#fff;text-decoration:none;border-radius:10px;padding:12px 16px;">Open JiZhi</a>
    </main>
  </body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
