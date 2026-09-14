/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_TURNSTILE_SITE_KEY?: string;
}

interface Window {
  turnstile?: {
    ready(callback: () => void): void;
    render(container: Element, options: { sitekey: string; action?: string; theme?: "auto" | "light" | "dark"; callback?: () => void }): string;
    getResponse(widgetID?: string): string;
    reset(widgetID?: string): void;
  };
}
