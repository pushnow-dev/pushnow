import type { APIRoute } from "astro";
import { site } from "../data/site";

export const GET: APIRoute = () => new Response(
  `User-agent: *\nAllow: /\n\nUser-agent: Googlebot\nAllow: /\n\nUser-agent: Bingbot\nAllow: /\n\nUser-agent: GPTBot\nAllow: /\n\nUser-agent: ChatGPT-User\nAllow: /\n\nUser-agent: PerplexityBot\nAllow: /\n\nUser-agent: ClaudeBot\nAllow: /\n\nUser-agent: anthropic-ai\nAllow: /\n\nSitemap: ${site.domain}/sitemap.xml\n`,
  { headers: { "Content-Type": "text/plain; charset=utf-8" } }
);
