/**
 * Tier rendering helpers for the admin Skor Tier page.
 *
 * Source of truth for tier ladder is the Postgres function
 * `compute_employee_score`; this file only handles *display* concerns
 * (colour, glow class, label). Keep the ordering and tier list in sync
 * with that SQL.
 */

export type Tier = 'SSS' | 'SS' | 'S' | 'A' | 'B' | 'C' | 'D' | 'F';
export type TierGroup = 'top' | 'mid' | 'low';

export const TIER_ORDER: Tier[] = ['SSS', 'SS', 'S', 'A', 'B', 'C', 'D', 'F'];

/**
 * Coarse three-bucket grouping used by the Skor Tier overview's
 * green/yellow/red column hint. Inside each column, sub-tier order is
 * preserved.
 */
export function tierGroup(tier: Tier | null | undefined): TierGroup {
  if (!tier) return 'low';
  if (tier === 'SSS' || tier === 'SS' || tier === 'S' || tier === 'A') return 'top';
  if (tier === 'B' || tier === 'C') return 'mid';
  return 'low';
}

/**
 * Card style classes per tier. Designed for a "Devil-May-Cry-style"
 * stylisation on the top tiers without becoming over-the-top:
 *  - SSS: gold gradient ribbon, animated pulse, subtle gold glow
 *  - SS:  gold ribbon, static gold glow, no pulse
 *  - S:   silver ribbon, soft silver glow
 *  - A:   bronze ribbon, no glow
 *  - B-C: muted slate, no special FX
 *  - D-F: red accent ribbon
 *
 * Animation classes (`animate-pulse-tier`) are defined in `global.css`
 * to avoid relying on Tailwind plugins.
 */
export interface TierStyle {
  ribbon: string;     // ribbon background classes
  glow: string;       // outer glow class on the card
  ringText: string;   // tier letter colour
  pulse: boolean;     // whether to apply the SSS pulse class
  label: string;      // human-readable rank label
}

export function tierStyle(tier: Tier | null | undefined): TierStyle {
  switch (tier) {
    case 'SSS':
      return {
        ribbon: 'bg-gradient-to-r from-yellow-300 via-amber-400 to-yellow-300 text-amber-950',
        glow: 'tier-glow-sss',
        ringText: 'text-amber-300 drop-shadow-[0_0_10px_rgba(251,191,36,0.5)]',
        pulse: true,
        label: 'Legendary',
      };
    case 'SS':
      return {
        ribbon: 'bg-gradient-to-r from-amber-400 to-yellow-500 text-amber-950',
        glow: 'tier-glow-ss',
        ringText: 'text-amber-300',
        pulse: false,
        label: 'Elite',
      };
    case 'S':
      return {
        ribbon: 'bg-gradient-to-r from-slate-300 to-slate-400 text-slate-900',
        glow: 'tier-glow-s',
        ringText: 'text-slate-200',
        pulse: false,
        label: 'Excellent',
      };
    case 'A':
      return {
        ribbon: 'bg-gradient-to-r from-orange-400 to-amber-500 text-orange-950',
        glow: '',
        ringText: 'text-orange-200',
        pulse: false,
        label: 'Solid',
      };
    case 'B':
      return {
        ribbon: 'bg-emerald-500 text-emerald-950',
        glow: '',
        ringText: 'text-emerald-200',
        pulse: false,
        label: 'Average',
      };
    case 'C':
      return {
        ribbon: 'bg-sky-500 text-sky-950',
        glow: '',
        ringText: 'text-sky-200',
        pulse: false,
        label: 'Below avg',
      };
    case 'D':
      return {
        ribbon: 'bg-rose-500 text-rose-50',
        glow: '',
        ringText: 'text-rose-300',
        pulse: false,
        label: 'Poor',
      };
    case 'F':
    default:
      return {
        ribbon: 'bg-gradient-to-r from-rose-700 to-red-800 text-rose-50',
        glow: '',
        ringText: 'text-rose-300',
        pulse: false,
        label: 'Critical',
      };
  }
}

const CAP_LABEL: Record<string, string> = {
  new_employee: 'Karyawan baru — di-cap di A',
  parttime: 'Part-time — di-cap di A',
};

export function tierCappedLabel(reason: string | null | undefined): string | null {
  if (!reason) return null;
  return CAP_LABEL[reason] ?? null;
}

/** Format a 0-100 score as `87.4` (one decimal) for compact display. */
export function formatScore(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  return value.toFixed(1);
}
