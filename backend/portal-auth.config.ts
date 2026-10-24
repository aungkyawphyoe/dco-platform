import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'node:url';
const portal = process.env.PORTAL === 'fleet-portal' ? 'fleet-portal' : 'web';
export default defineConfig({
  resolve: { alias: { 'next/server': fileURLToPath(new URL(`../${portal}/node_modules/next/server.js`, import.meta.url)), '@': fileURLToPath(new URL(`../${portal}/src`, import.meta.url)) } },
  test: { environment: 'node', include: ['test/portal-auth.check.ts'] },
});
