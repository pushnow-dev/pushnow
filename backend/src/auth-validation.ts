import { AuthHttpError } from "./crypto";

export function assertValidPasswordInput(passwordInput: unknown): string {
  if (typeof passwordInput !== "string") {
    throw new AuthHttpError(400, "invalid_password", "请输入有效密码");
  }
  const password = passwordInput.trim();
  if (password.length < 8 || password.length > 128) {
    throw new AuthHttpError(400, "invalid_password", "密码长度需为 8 到 128 个字符");
  }
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    throw new AuthHttpError(400, "weak_password", "密码需同时包含字母和数字");
  }
  return password;
}
