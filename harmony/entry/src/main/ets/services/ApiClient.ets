import { http } from '@kit.NetworkKit';
import { API_BASE_URL } from './AppConfig';

interface RequestHeaders {
  'content-type': string;
  Authorization?: string;
}

interface ApiFailure { code?: string; }

class EmptyResponse {
}

export class ApiClient {
  resolveToken?: (token: string) => Promise<string>;
  sessionGeneration?: () => number;
  async get<T>(path: string, token?: string): Promise<T> {
    return this.request<T>(http.RequestMethod.GET, path, undefined, token);
  }

  async post<T>(path: string, body: object, token?: string): Promise<T> {
    return this.request<T>(http.RequestMethod.POST, path, JSON.stringify(body), token);
  }

  async put<T>(path: string, body: object, token?: string): Promise<T> {
    return this.request<T>(http.RequestMethod.PUT, path, JSON.stringify(body), token);
  }

  async patch<T>(path: string, body: object, token?: string): Promise<T> {
    return this.request<T>('PATCH' as http.RequestMethod, path, JSON.stringify(body), token);
  }

  async delete(path: string, token?: string): Promise<void> {
    await this.request<EmptyResponse>(http.RequestMethod.DELETE, path, undefined, token);
  }

  private errorCode(raw: string): string {
    try { return (JSON.parse(raw) as ApiFailure).code ?? 'request_failed'; } catch { return 'request_failed'; }
  }

  private async request<T>(method: http.RequestMethod, path: string, body?: string, token?: string): Promise<T> {
    const epoch = this.sessionGeneration ? this.sessionGeneration() : 0;
    const authenticated = token !== undefined && token.length > 0;
    if (authenticated && this.resolveToken) token = await this.resolveToken(token!);
    if (authenticated && this.sessionGeneration && this.sessionGeneration() !== epoch) throw new Error('session_changed');
    const client = http.createHttp();
    const url = `${API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
    const header: RequestHeaders = { 'content-type': 'application/json' };
    if (token && token.length > 0) {
      header.Authorization = `Bearer ${token}`;
    }
    try {
      const options: http.HttpRequestOptions = {
        method,
        header,
        extraData: body,
        maxLimit: 32 * 1024 * 1024,
        connectTimeout: 20000,
        readTimeout: 20000
      };
      const response = await client.request(url, options);
      if (authenticated && this.sessionGeneration && this.sessionGeneration() !== epoch) throw new Error('session_changed');
      const statusCode = Number(response.responseCode);
      const raw = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`HTTP_${statusCode}: ${this.errorCode(raw)}`);
      }
      return raw.length > 0 ? JSON.parse(raw) as T : new EmptyResponse() as T;
    } finally {
      client.destroy();
    }
  }
}

export const apiClient = new ApiClient();
