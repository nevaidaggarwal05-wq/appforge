import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

/** URL-safe slug: "My App!" -> "my-app". Returns empty string if input is non-ASCII only. */
export function slugify(s: string): string {
  return s.toLowerCase().trim()
    .replace(/[^\w\s-]/g, '')
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Slugify with fallback — guarantees a non-empty result. Use in API routes. */
export function slugifyOrFallback(s: string, fallback: string): string {
  const slug = slugify(s);
  return slug.length > 0 ? slug : fallback;
}

/** Validate hex color like "#1A1A2E" or "#fff" */
export function isValidHex(s: string): boolean {
  return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(s);
}
