import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';

const site = process.env.PUBLIC_SITE_URL ?? 'https://absenkok.vercel.app';

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

const allowedDomains = [site, process.env.VERCEL_PROJECT_PRODUCTION_URL, process.env.VERCEL_BRANCH_URL, process.env.VERCEL_URL]
  .map(toAllowedDomain)
  .filter(Boolean)
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
