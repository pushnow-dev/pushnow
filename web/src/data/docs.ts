import { parseFrontmatter } from "astro/markdown";
import { createSatteriMarkdownProcessor } from "@astrojs/markdown-satteri";

export type DocsLang = "en" | "zh-Hans";
export interface TryRequest { method: string; path: string; auth?: "source" | "session"; body?: string }
export interface DocPage {
  slug: string; lang: DocsLang; title: string; description: string; order: number;
  html: string; markdown: string;
  headings: Array<{ depth: number; slug: string; text: string }>;
  tryRequest?: TryRequest;
}

// Astro's Markdown pipeline handles GFM; raw HTML and unsafe URL schemes cannot execute.
const renderer = await createSatteriMarkdownProcessor({
  gfm: true, smartypants: false, syntaxHighlight: false,
  features: { rawHtml: false },
  hastPlugins: [{
    name: "docs-safe-content",
    raw(node, context) { context.removeNode(node); },
    element: {
      filter: ["a", "img"],
      visit(node, context) {
        const property = node.tagName === "a" ? "href" : "src";
        const value = node.properties?.[property];
        if (typeof value !== "string") return;
        try {
          const url = new URL(value, "https://pushnow.dev");
          const protocols = node.tagName === "a" ? ["https:", "http:", "mailto:"] : ["https:", "http:"];
          if (!protocols.includes(url.protocol)) context.setProperty(node, property, null);
        } catch { context.setProperty(node, property, null); }
      }
    }
  }]
});
export const renderDocsMarkdown = (markdown: string) => renderer.render(markdown);
const sources = import.meta.glob<string>("../docs/{en,zh-Hans}/*.md", { query: "?raw", import: "default", eager: true });
const pages: DocPage[] = await Promise.all(Object.entries(sources).map(async ([file, raw]) => {
  const { frontmatter: meta, content } = parseFrontmatter(raw);
  const segments = file.split("/");
  const lang = segments.at(-2) as DocsLang;
  const slug = segments.at(-1)!.replace(/\.md$/, "");
  const rendered = await renderDocsMarkdown(content);
  return {
    slug, lang, title: String(meta.title || slug), description: String(meta.description || ""),
    order: Number(meta.order || 99), html: rendered.code, markdown: content,
    headings: rendered.metadata.headings,
    tryRequest: meta.tryMethod && meta.tryPath ? {
      method: String(meta.tryMethod), path: String(meta.tryPath), auth: meta.tryAuth as TryRequest["auth"],
      body: meta.tryBody ? (typeof meta.tryBody === "string" ? meta.tryBody : JSON.stringify(meta.tryBody, null, 2)) : undefined
    } : undefined
  };
}));
export const docsFor = (lang: string) => pages.filter(page => page.lang === (lang === "zh-Hans" ? "zh-Hans" : "en")).sort((a, b) => a.order - b.order);
export const docBySlug = (lang: string, slug: string) => docsFor(lang).find(page => page.slug === slug) ?? docsFor(lang)[0];
export const docStaticPaths = () => pages.map(({ lang, slug }) => ({ lang, slug }));
