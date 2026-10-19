/**
 * Deterministic tone rotation for cards and pills. Class names map to the
 * site-local utilities in globals.css; choosing by index keeps colour variety
 * without components ever hard-coding a hex value.
 */

const CARD_TONES = ["tone-gold", "tone-info", "tone-mint", "tone-violet"] as const;

const PILL_TONES = [
  "pill-gold",
  "pill-info",
  "pill-mint",
  "pill-violet",
  "pill-fuel",
  "pill-parts",
] as const;

export function cardTone(index: number): string {
  return CARD_TONES[index % CARD_TONES.length];
}

export function pillTone(index: number): string {
  return PILL_TONES[index % PILL_TONES.length];
}
