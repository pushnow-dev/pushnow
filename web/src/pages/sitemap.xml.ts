import type { APIRoute } from 'astro';
import { languages, pathFor, site } from '../data/site';
import { docsFor } from '../data/docs';
const slugs = ['', 'guide', 'api', 'docs', 'privacy', 'terms', 'support'];
const lastmod = '2026-09-14';
const escapeXml = (value: string) => value.replace(/[<>&'"]/g, char => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[char]!));
const pageExists = (lang: string, slug: string) => !slug.startsWith('docs/') || docsFor(lang).some(doc => `docs/${doc.slug}` === slug);
const alternateLinks = (slug: string) => [
  ...languages
    .filter(language => pageExists(language.code, slug))
    .map(language => `    <xhtml:link rel="alternate" hreflang="${language.locale}" href="${escapeXml(`${site.domain}${pathFor(language.code, slug)}`)}" />`),
  `    <xhtml:link rel="alternate" hreflang="x-default" href="${escapeXml(`${site.domain}${pathFor('en', slug)}`)}" />`
].join('\n');
export const GET: APIRoute = () => {
  const uniqueSlugs = [...new Set([...slugs, ...languages.flatMap(language => docsFor(language.code).map(doc => `docs/${doc.slug}`))])];
  const urls = languages.flatMap(language => uniqueSlugs
    .filter(slug => pageExists(language.code, slug))
    .map(slug => ({ slug, url: `${site.domain}${pathFor(language.code, slug)}` })));
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${urls.map(({ slug, url }) => `  <url>\n    <loc>${escapeXml(url)}</loc>\n    <lastmod>${lastmod}</lastmod>\n${alternateLinks(slug)}\n  </url>`).join('\n')}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml; charset=utf-8' } }
  );
};
