#!/usr/bin/env node
// Validates Play Store listing copy against the Play Console limits:
//   app title 30 · short description 80 · full description 4000
// Run: node marketing/play-store/listing/validate.mjs
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const LIMITS = {
  "title.txt": 30,
  "short-description.txt": 80,
  "full-description.txt": 4000,
};

const root = dirname(fileURLToPath(import.meta.url));
const locales = readdirSync(root).filter((name) =>
  statSync(join(root, name)).isDirectory(),
);

let failed = false;

for (const locale of locales.sort()) {
  console.log(`\n${locale}`);
  for (const [file, limit] of Object.entries(LIMITS)) {
    let text;
    try {
      text = readFileSync(join(root, locale, file), "utf8");
    } catch {
      console.log(`  ${file.padEnd(24)} MISSING`);
      failed = true;
      continue;
    }

    const body = text.replace(/\n$/, "");
    const count = [...body].length;
    const ok = count > 0 && count <= limit;
    if (!ok) failed = true;
    console.log(
      `  ${file.padEnd(24)} ${String(count).padStart(5)} / ${limit}  ${ok ? "ok" : "FAIL"}`,
    );

    if (/\s$/.test(body)) {
      console.log("    trailing whitespace");
      failed = true;
    }
    if (/\n\n\n/.test(body)) {
      console.log("    more than one blank line in a row");
      failed = true;
    }
  }
}

console.log(
  failed
    ? "\nListing copy does not meet the Play Console limits."
    : "\nListing copy meets the Play Console limits.",
);
process.exit(failed ? 1 : 0);
