import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';

const site = process.env.PUBLIC_SITE_URL ?? 'https://www.absenkok.app';

function toAllowedDomain(value) {
  if (!value) return null;

  try {
    const normalized = value.startsWith('http://') || value.startsWith('https://')
      ? value
      : `https://${value}`;
    const url = new URL(normalized);
    return {
      protocol: url.protocol.replace(':', ''),
      hostname: url.hostname,
      ...(url.port ? { port: url.port } : {}),
    };
  } catch {
    return null;
  }
}

// Collect all known origins: the canonical site, Vercel system URLs, and any
// extra custom domains provided via PUBLIC_EXTRA_ALLOWED_DOMAINS (comma-separated).
// For every hostname we also add its www / non-www counterpart so a Cloudflare
// redirect from www ↔ apex never triggers Astro's CSRF rejection.
const rawSources = [
  site,
  process.env.VERCEL_PROJECT_PRODUCTION_URL,
  process.env.VERCEL_BRANCH_URL,
  process.env.VERCEL_URL,
  ...(process.env.PUBLIC_EXTRA_ALLOWED_DOMAINS ?? '').split(',').map(s => s.trim()).filter(Boolean),
];

const allowedDomains = rawSources
  .flatMap((value) => {
    const parsed = toAllowedDomain(value);
    if (!parsed) return [];
    const variants = [parsed];
    // Auto-add www ↔ non-www counterpart.
    if (parsed.hostname.startsWith('www.')) {
      variants.push({ ...parsed, hostname: parsed.hostname.slice(4) });
    } else if (!parsed.hostname.includes('.vercel.app')) {
      variants.push({ ...parsed, hostname: `www.${parsed.hostname}` });
    }
    return variants;
  })
  .filter((pattern, index, patterns) => {
    return patterns.findIndex((candidate) =>
      candidate.protocol === pattern.protocol &&
      candidate.hostname === pattern.hostname &&
      candidate.port === pattern.port
    ) === index;
  });

export default defineConfig({
  site,
  // `output: 'server'` makes the safe default for `/portal/*` pages — any new
  // page added under `/portal/` will be server-rendered (and therefore run
  // through the auth middleware) unless it explicitly opts into prerender.
  // Marketing pages such as `src/pages/index.astro` set
  // `export const prerender = true` to remain statically generated.
  output: 'server',
  adapter: vercel(),
  integrations: [sitemap()],
  security: {
    allowedDomains,
  },
  vite: {
    plugins: [tailwindcss()],
  },
});
