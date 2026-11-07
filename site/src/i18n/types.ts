import en from "./dictionaries/en.json";

/**
 * Shape of the translation catalogue. `en.json` is the source of truth: every
 * other locale mirrors its keys and may leave values empty to fall back to
 * English.
 */
export type Dictionary = typeof en;
