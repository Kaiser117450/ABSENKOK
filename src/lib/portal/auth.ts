import { createHash } from 'node:crypto';

/**
 * Shared portal auth helpers.
 * All helpers are pure functions with no Astro or Supabase imports so they
 * can be used in middleware, endpoints, and pages without circular deps.
 */

/** Routes that are considered portal-protected (require auth). */
export const PROTECTED_PORTAL_PREFIXES = ['/portal'] as const;

/** Routes inside /portal that are always public (login + auth endpoints). */
const PUBLIC_PORTAL_PATHS = new Set([
  '/portal/login',
  '/portal/auth/search',
  '/portal/auth/sign-in',
  '/portal/auth/sign-out',
]);

/**
 * Returns true when the path is a portal route that requires authentication.
 * Marketing routes and portal public paths always return false.
 */
export function isProtectedPortalRoute(pathname: string): boolean {
  if (!pathname.startsWith('/portal')) return false;
  if (PUBLIC_PORTAL_PATHS.has(pathname)) return false;
  // Trailing-slash variants
  if (PUBLIC_PORTAL_PATHS.has(pathname.replace(/\/$/, ''))) return false;
  return true;
}

/**
 * Derive the hidden portal auth email from a stable employee UUID.
 * Format: employee+<uuid>@portal.absenkok.internal
 * The UUID is the source-of-truth; name and code are mutable and unsafe as keys.
 */
export function buildPortalAuthEmail(employeeId: string): string {
  return `employee+${employeeId}@portal.absenkok.internal`;
}

/**
 * Normalize a raw search string for name search queries.
 * Trims whitespace, lowercases, and collapses internal runs of whitespace.
 * Matches the normalization applied on the DB side (portal_search_name column).
 */
export function normalizeSearchText(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Derive the deterministic internal password for a portal auth user.
 * The employee never sees or types this — it's an implementation detail
 * so we can use Supabase Auth sessions without requiring a real password.
 */
export function buildPortalAuthPassword(employeeId: string): string {
  const secret = import.meta.env.PORTAL_SECRET ?? 'enakko-portal-default-secret';
  const digest = createHash('sha256')
    .update(`${secret}:${employeeId}`)
    .digest('base64url')
    .slice(0, 32);

  return `portal-${digest}`;
}

/** Minimum query length before a search request should be sent. */
export const SEARCH_MIN_LENGTH = 2;

/** Maximum result count returned by the search endpoint. */
export const SEARCH_MAX_RESULTS = 8;
