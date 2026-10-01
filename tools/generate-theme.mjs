#!/usr/bin/env node
/**
 * Theme token generator.
 *
 * Sources of truth (must have identical token key sets):
 *   docs/theme/garage-minimal-dark.json
 *   docs/theme/garage-minimal-light.json
 *
 * Outputs (all committed; re-run after editing either JSON):
 *   web/src/app/theme-tokens.css
 *   fleet-portal/src/app/theme-tokens.css
 *   mobile/lib/core/theme/dco_tokens.g.dart
 *
 * Run: node tools/generate-theme.mjs   (or `npm run gen:theme` from web/ or fleet-portal/)
 * Rules: docs/design-system.md
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const META_KEYS = ["themeName", "version", "mode", "platforms", "description"];

const readTheme = (name) =>
  JSON.parse(readFileSync(join(repoRoot, "docs/theme", name), "utf8"));

const dark = readTheme("garage-minimal-dark.json");
const light = readTheme("garage-minimal-light.json");

// ---------------------------------------------------------------- validation

function leafKeys(obj, prefix = "") {
  const out = [];
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${k}` : k;
    if (META_KEYS.includes(path)) continue;
    // usageNotes is prose documentation, not a token — excluded from parity/format checks.
    if (path === "usageNotes" || path.startsWith("usageNotes.")) continue;
    if (v && typeof v === "object" && !Array.isArray(v)) out.push(...leafKeys(v, path));
    else out.push(path);
  }
  return out;
}

const darkKeys = leafKeys(dark);
const lightKeys = leafKeys(light);
const missingInLight = darkKeys.filter((k) => !lightKeys.includes(k));
const extraInLight = lightKeys.filter((k) => !darkKeys.includes(k));
if (missingInLight.length || extraInLight.length) {
  console.error("Token key sets differ between dark and light themes.");
  if (missingInLight.length) console.error("  missing in light:", missingInLight.join(", "));
  if (extraInLight.length) console.error("  extra in light:", extraInLight.join(", "));
  process.exit(1);
}

const HEX_RE = /^#[0-9A-F]{6}([0-9A-F]{2})?$/i;
const COLORISH = new Set([
  ...darkKeys.filter((k) => k.includes("background") || k.includes("text") || k.includes("border") ||
    k.includes("icon") || k.includes("status") || k.includes("feedback") || k.includes("chart") ||
    k.includes("overlay") || k === "accent" || k === "link" || k === "inverse" ||
    k.endsWith(".fg") || k.endsWith(".bg") || k.startsWith("button.")),
]);

function get(obj, path) {
  return path.split(".").reduce((o, k) => (o == null ? o : o[k]), obj);
}

for (const theme of [dark, light]) {
  for (const key of darkKeys) {
    const v = get(theme, key);
    const isColor = COLORISH.has(key);
    if (isColor && v !== "transparent" && !HEX_RE.test(String(v))) {
      console.error(`Bad color in ${theme.themeName}: ${key} = ${v}`);
      process.exit(1);
    }
  }
}

// ------------------------------------------------------------------ CSS out

const cssVars = [
  ["--bg-primary", "background.primary"],
  ["--bg-secondary", "background.secondary"],
  ["--bg-card", "background.card"],
  ["--bg-input", "background.input"],
  ["--bg-nav", "background.nav"],
  ["--bg-nav-active", "background.navActive"],
  ["--bg-overlay", "background.overlay"],
  ["--bg-skeleton", "background.skeleton"],
  ["--text-primary", "text.primary"],
  ["--text-secondary", "text.secondary"],
  ["--text-tertiary", "text.tertiary"],
  ["--text-caption", "text.caption"],
  ["--accent", "text.accent"],
  ["--on-accent", "text.onAccent"],
  ["--text-disabled", "text.disabled"],
  ["--link", "text.link"],
  ["--inverse", "text.inverse"],
  ["--btn-primary-bg", "button.primary.background"],
  ["--btn-primary-hover", "button.primary.backgroundHover"],
  ["--btn-primary-pressed", "button.primary.backgroundPressed"],
  ["--btn-primary-disabled", "button.primary.backgroundDisabled"],
  ["--btn-primary-text", "button.primary.text"],
  ["--btn-secondary-bg", "button.secondary.background"],
  ["--btn-secondary-hover", "button.secondary.backgroundHover"],
  ["--btn-secondary-pressed", "button.secondary.backgroundPressed"],
  ["--btn-secondary-border", "button.secondary.border"],
  ["--btn-destructive-text", "button.destructive.text"],
  ["--btn-destructive-hover", "button.destructive.backgroundHover"],
  ["--icon-active", "icon.active"],
  ["--icon-inactive", "icon.inactive"],
  ["--border-subtle", "border.subtle"],
  ["--border-default", "border.default"],
  ["--border-divider", "border.divider"],
  ["--border-focus", "border.focus"],
  ["--status-success", "status.success.fg"],
  ["--status-success-bg", "status.success.bg"],
  ["--status-warning", "status.warning.fg"],
  ["--status-warning-bg", "status.warning.bg"],
  ["--status-danger", "status.danger.fg"],
  ["--status-danger-bg", "status.danger.bg"],
  ["--status-info", "status.info.fg"],
  ["--status-info-bg", "status.info.bg"],
  ["--input-bg", "input.background"],
  ["--input-border", "input.border"],
  ["--input-placeholder", "input.placeholder"],
  ["--input-error", "input.errorBorder"],
  ["--chart-fuel", "chart.fuel"],
  ["--chart-maintenance", "chart.maintenance"],
  ["--chart-insurance", "chart.insurance"],
  ["--chart-parking", "chart.parking"],
  ["--chart-tolls", "chart.tolls"],
  ["--chart-parts", "chart.parts"],
  ["--chart-other", "chart.other"],
  ["--radius-sm", "radius.sm", "px"],
  ["--radius-md", "radius.md", "px"],
  ["--radius-lg", "radius.lg", "px"],
  ["--radius-xl", "radius.xl", "px"],
  ["--motion-fast", "motion.fast", "ms"],
  ["--motion-base", "motion.base", "ms"],
  ["--motion-slow", "motion.slow", "ms"],
  ["--ease-out-quart", "motion.easing"],
];

const cssSections = [
  ["background", ["--bg-"]],
  ["text", ["--text-", "--accent", "--on-accent", "--link", "--inverse"]],
  ["button", ["--btn-"]],
  ["icon", ["--icon-"]],
  ["border", ["--border-"]],
  ["status", ["--status-"]],
  ["input", ["--input-"]],
  ["chart", ["--chart-"]],
  ["radius", ["--radius-"]],
  ["motion", ["--motion-", "--ease-"]],
];

function cssValue(theme, jsonPath, suffix) {
  const raw = String(get(theme, jsonPath));
  if (suffix === "px") return `${raw}px`;
  if (suffix === "ms") return `${raw}ms`;
  return raw.toLowerCase();
}

function cssBlock(theme, scheme) {
  const lines = [];
  lines.push(`html.${scheme} {`);
  lines.push(`  color-scheme: ${scheme};`);
  let comment = null;
  for (const [varName, jsonPath, suffix] of cssVars) {
    const section = cssSections.find(([, prefixes]) =>
      prefixes.some((p) => varName === p || varName.startsWith(p)),
    )?.[0];
    if (section !== comment) {
      if (comment !== null) lines.push("");
      lines.push(`  /* ${section} */`);
      comment = section;
    }
    lines.push(`  ${varName}: ${cssValue(theme, jsonPath, suffix)};`);
  }
  lines.push("}");
  return lines.join("\n");
}

function selectorBlock(scheme, theme) {
  const body = cssBlock(theme, scheme).replace(/^html\.\w+ \{\n/, "").replace(/\n\}$/, "");
  const sel = scheme === "light" ? ":root,\nhtml.light" : "html.dark";
  return `${sel} {\n${body}\n}`;
}

const css = `/* AUTO-GENERATED by tools/generate-theme.mjs — DO NOT EDIT.
 * Sources: docs/theme/garage-minimal-dark.json + garage-minimal-light.json
 * Rules: docs/design-system.md. Do not one-off hex in components.
 * Default (no class / first paint) is dark; the pre-paint script in layout.tsx
 * applies html.light / html.dark from the dco_theme cookie or prefers-color-scheme.
 */

${selectorBlock("light", light)}

${selectorBlock("dark", dark)}
`;

// ----------------------------------------------------------------- Dart out

const hexToDart = (hex) => {
  if (hex.toLowerCase() === "transparent") return "Color(0x00000000)";
  const h = hex.replace("#", "").toUpperCase();
  if (h.length === 8) return `Color(0x${h.slice(6, 8)}${h.slice(0, 6)})`; // #RRGGBBAA -> AARRGGBB
  return `Color(0xFF${h})`;
};

const color = (theme, path) => hexToDart(String(get(theme, path)));
const number = (theme, path) => String(get(theme, path));

function dcoBackground(t) {
  return `DcoBackground(
      primary: ${color(t, "background.primary")},
      secondary: ${color(t, "background.secondary")},
      card: ${color(t, "background.card")},
      input: ${color(t, "background.input")},
      nav: ${color(t, "background.nav")},
      navActive: ${color(t, "background.navActive")},
      overlay: ${color(t, "background.overlay")},
      skeleton: ${color(t, "background.skeleton")},
    )`;
}

function dcoText(t) {
  return `DcoTextColors(
      primary: ${color(t, "text.primary")},
      secondary: ${color(t, "text.secondary")},
      tertiary: ${color(t, "text.tertiary")},
      caption: ${color(t, "text.caption")},
      accent: ${color(t, "text.accent")},
      onAccent: ${color(t, "text.onAccent")},
      disabled: ${color(t, "text.disabled")},
      link: ${color(t, "text.link")},
      inverse: ${color(t, "text.inverse")},
    )`;
}

const TRANSPARENT = "Color(0x00000000)";

function dcoButton(t, variant) {
  const p = `button.${variant}`;
  const has = (k) => get(t, `${p}.${k}`) !== undefined;
  const hover = color(t, `${p}.backgroundHover`);
  const parts = {
    background: color(t, `${p}.background`),
    backgroundHover: hover,
    backgroundPressed: has("backgroundPressed") ? color(t, `${p}.backgroundPressed`) : hover,
    backgroundDisabled: has("backgroundDisabled") ? color(t, `${p}.backgroundDisabled`) : TRANSPARENT,
    text: color(t, `${p}.text`),
    textDisabled: has("textDisabled") ? color(t, `${p}.textDisabled`) : color(t, "text.disabled"),
    border: color(t, `${p}.border`),
  };
  return `DcoButtonColors(
      background: ${parts.background},
      backgroundHover: ${parts.backgroundHover},
      backgroundPressed: ${parts.backgroundPressed},
      backgroundDisabled: ${parts.backgroundDisabled},
      text: ${parts.text},
      textDisabled: ${parts.textDisabled},
      border: ${parts.border},
    )`;
}

function dcoButtons(t) {
  return `DcoButtons(
      primary: ${dcoButton(t, "primary")},
      secondary: ${dcoButton(t, "secondary")},
      tertiary: ${dcoButton(t, "tertiary")},
      destructive: ${dcoButton(t, "destructive")},
    )`;
}

function dcoIcons(t) {
  return `DcoIconColors(
      active: ${color(t, "icon.active")},
      inactive: ${color(t, "icon.inactive")},
      onAccent: ${color(t, "icon.onAccent")},
      inverse: ${color(t, "icon.inverse")},
    )`;
}

function dcoBorders(t) {
  return `DcoBorders(
      subtle: ${color(t, "border.subtle")},
      defaultColor: ${color(t, "border.default")},
      divider: ${color(t, "border.divider")},
      highlight: ${color(t, "border.highlight")},
      focus: ${color(t, "border.focus")},
    )`;
}

function dcoStatus(t) {
  const s = (name) => ({
    fg: color(t, `status.${name}.fg`),
    bg: color(t, `status.${name}.bg`),
  });
  const success = s("success"), warning = s("warning"), danger = s("danger"), info = s("info");
  return `DcoStatus(
      successFg: ${success.fg},
      successBg: ${success.bg},
      warningFg: ${warning.fg},
      warningBg: ${warning.bg},
      dangerFg: ${danger.fg},
      dangerBg: ${danger.bg},
      infoFg: ${info.fg},
      infoBg: ${info.bg},
    )`;
}

function dcoFeedback(t) {
  return `DcoFeedback(
      overdue: ${color(t, "feedback.overdue")},
      dueSoon: ${color(t, "feedback.dueSoon")},
      healthy: ${color(t, "feedback.healthy")},
      queuedSync: ${color(t, "feedback.queuedSync")},
    )`;
}

function dcoInput(t) {
  return `DcoInputColors(
      background: ${color(t, "input.background")},
      border: ${color(t, "input.border")},
      borderFocus: ${color(t, "input.borderFocus")},
      placeholder: ${color(t, "input.placeholder")},
      errorBorder: ${color(t, "input.errorBorder")},
    )`;
}

function dcoChart(t) {
  const names = ["fuel", "maintenance", "insurance", "parking", "tolls", "parts", "other"];
  const entries = names.map((n) => `${n}: ${color(t, `chart.${n}`)}`);
  return `DcoChartColors(\n      ${entries.join(",\n      ")},\n    )`;
}

function dcoRadius(t) {
  const keys = ["sm", "md", "lg", "xl", "full"];
  return `DcoRadius(${keys.map((k) => `${k}: ${number(t, `radius.${k}`)}`).join(", ")})`;
}

function dcoSpace(t) {
  const keys = ["1", "2", "3", "4", "5", "6", "7"];
  return `DcoSpace(${keys.map((k) => `s${k}: ${number(t, `space.${k}`)}`).join(", ")})`;
}

function dcoMotion(t) {
  return `DcoMotion(fast: ${number(t, "motion.fast")}, base: ${number(t, "motion.base")}, slow: ${number(t, "motion.slow")})`;
}

// Dart presentation shadows are not part of the JSON contract (JSON elevation is
// CSS-only); kept here so both modes share them exactly as the app does today.
const dartShadows = `const DcoShadows _dcoShadows = DcoShadows(
  card: [
    BoxShadow(
      color: Color(0x1A0A1118),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0D0A1118),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ],
  elevated: [
    BoxShadow(
      color: Color(0x260A1118),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A0A1118),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ],
);`;

function dcoTokensConst(t) {
  return `static const garageMinimal${t.mode === "dark" ? "Dark" : "Light"} = DcoTokens(
    background: ${dcoBackground(t)},
    text: ${dcoText(t)},
    button: ${dcoButtons(t)},
    icon: ${dcoIcons(t)},
    border: ${dcoBorders(t)},
    status: ${dcoStatus(t)},
    feedback: ${dcoFeedback(t)},
    input: ${dcoInput(t)},
    chart: ${dcoChart(t)},
    radius: ${dcoRadius(t)},
    space: ${dcoSpace(t)},
    motion: ${dcoMotion(t)},
    shadows: _dcoShadows,
  );`;
}

const dart = `// AUTO-GENERATED by tools/generate-theme.mjs — DO NOT EDIT.
// Sources: docs/theme/garage-minimal-dark.json + garage-minimal-light.json
// Rules: docs/design-system.md. If a screen needs a new color, add it there first.
part of 'dco_tokens.dart';

${dartShadows}

class DcoTokenValues {
  DcoTokenValues._();

${dcoTokensConst(dark)}

${dcoTokensConst(light)}
}
`;

// --------------------------------------------------------------------- write

const outputs = [
  ["web/src/app/theme-tokens.css", css],
  ["fleet-portal/src/app/theme-tokens.css", css],
  ["mobile/lib/core/theme/dco_tokens.g.dart", dart],
];

for (const [rel, content] of outputs) {
  writeFileSync(join(repoRoot, rel), content);
  console.log("wrote", rel);
}
console.log(`validated ${darkKeys.length} token leaves per mode`);
