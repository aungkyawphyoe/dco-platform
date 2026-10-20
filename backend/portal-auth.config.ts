import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'node:url';
const portal = process.env.PORTAL === 'fleet-portal' ? 'fleet-portal' : 'web';
export default defineConfig({
  resolve: { alias: { '@': fileURLToPath(new URL(`../${portal}/src`, import.meta.url)) } },
  test: { environment: 'node', include: ['test/portal-auth.check.ts'] },
});
